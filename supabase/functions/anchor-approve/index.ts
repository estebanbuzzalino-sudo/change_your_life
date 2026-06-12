import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const EMAIL_REGEX = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
const MAX_DAYS = 30;
const MAX_MINUTES = 60 * 24 * 30;
const DEFAULT_MINUTES = 60;
const PERMANENT_UNTIL = "2099-12-31T23:59:59.000Z";

function jsonResponse(status: number, body: unknown) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function generateId(prefix: string) {
  return `${prefix}_${crypto.randomUUID().replace(/-/g, "").slice(0, 20)}`;
}

function parsePositiveInt(value: unknown): number | null {
  const parsed = Number(value);
  return Number.isFinite(parsed) && parsed > 0 ? Math.trunc(parsed) : null;
}

function resolveUnlockUntil(
  durationMode: string,
  minutes: unknown,
  days: unknown,
  approvedAt: string,
): { unlockUntil: string; minutesForGrant: number; label: string } {
  if (durationMode === "permanent") {
    return { unlockUntil: PERMANENT_UNTIL, minutesForGrant: DEFAULT_MINUTES, label: "permanente" };
  }
  if (durationMode === "days") {
    const d = Math.min(Math.max(parsePositiveInt(days) ?? 1, 1), MAX_DAYS);
    const mins = Math.min(d * 24 * 60, MAX_MINUTES);
    const until = new Date(new Date(approvedAt).getTime() + d * 24 * 60 * 60 * 1000).toISOString();
    return { unlockUntil: until, minutesForGrant: mins, label: `${d} día(s)` };
  }
  // default: minutes
  const m = Math.min(Math.max(parsePositiveInt(minutes) ?? DEFAULT_MINUTES, 1), MAX_MINUTES);
  const until = new Date(new Date(approvedAt).getTime() + m * 60 * 1000).toISOString();
  return { unlockUntil: until, minutesForGrant: m, label: `${m} minutos` };
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return jsonResponse(405, { ok: false, error: { code: "METHOD_NOT_ALLOWED" } });
  }

  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch {
    return jsonResponse(400, { ok: false, error: { code: "INVALID_JSON" } });
  }

  const requestId = typeof body.requestId === "string" ? body.requestId.trim() : "";
  const anchorEmail = typeof body.anchorEmail === "string"
    ? body.anchorEmail.trim().toLowerCase()
    : "";
  const durationMode = typeof body.durationMode === "string"
    ? body.durationMode.trim().toLowerCase()
    : "minutes";
  const minutesInput = body.minutes;
  const daysInput = body.days;

  if (!requestId) {
    return jsonResponse(400, { ok: false, error: { code: "MISSING_REQUEST_ID" } });
  }
  if (!anchorEmail || !EMAIL_REGEX.test(anchorEmail)) {
    return jsonResponse(400, { ok: false, error: { code: "INVALID_ANCHOR_EMAIL" } });
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
  const supabase = createClient(supabaseUrl, serviceRoleKey);

  // Verify the request belongs to this anchor and is still pending.
  const { data: unlockReq, error: fetchErr } = await supabase
    .from("unlock_requests")
    .select(
      "id, installation_id, package_name, app_name, requester_name, minutes, status, token_used_at, token_expires_at, friend_email",
    )
    .eq("id", requestId)
    .maybeSingle();

  if (fetchErr) {
    return jsonResponse(500, { ok: false, error: { code: "DB_ERROR", message: fetchErr.message } });
  }
  if (!unlockReq) {
    return jsonResponse(404, { ok: false, error: { code: "NOT_FOUND" } });
  }
  if ((unlockReq.friend_email ?? "").toLowerCase() !== anchorEmail) {
    return jsonResponse(403, { ok: false, error: { code: "FORBIDDEN" } });
  }
  if (unlockReq.token_used_at) {
    return jsonResponse(409, { ok: false, error: { code: "ALREADY_APPROVED" } });
  }
  if (new Date(unlockReq.token_expires_at).getTime() <= Date.now()) {
    return jsonResponse(410, { ok: false, error: { code: "TOKEN_EXPIRED" } });
  }
  if (unlockReq.status !== "pending_approval") {
    return jsonResponse(409, { ok: false, error: { code: "NOT_APPROVABLE", status: unlockReq.status } });
  }

  const approvedAt = new Date().toISOString();
  const { unlockUntil, minutesForGrant, label } = resolveUnlockUntil(
    durationMode,
    minutesInput,
    daysInput,
    approvedAt,
  );

  // Mark as approved.
  const { error: updateErr } = await supabase
    .from("unlock_requests")
    .update({ status: "approved", token_used_at: approvedAt })
    .eq("id", requestId)
    .eq("status", "pending_approval")
    .is("token_used_at", null);

  if (updateErr) {
    return jsonResponse(500, { ok: false, error: { code: "UPDATE_FAILED", message: updateErr.message } });
  }

  // Create unlock grant.
  const grantId = generateId("ugr");
  const { data: grant, error: grantErr } = await supabase
    .from("unlock_grants")
    .insert({
      id: grantId,
      request_id: requestId,
      installation_id: unlockReq.installation_id,
      package_name: unlockReq.package_name,
      app_name: unlockReq.app_name,
      minutes: minutesForGrant,
      unlock_until: unlockUntil,
      approved_at: approvedAt,
    })
    .select("id, unlock_until, approved_at")
    .maybeSingle();

  if (grantErr) {
    console.error(`[anchor-approve] grantInsertError requestId=${requestId} error=${grantErr.message}`);
    // Roll back status so the request can be retried.
    await supabase
      .from("unlock_requests")
      .update({ status: "pending_approval", token_used_at: null })
      .eq("id", requestId);
    return jsonResponse(500, { ok: false, error: { code: "GRANT_FAILED", message: grantErr.message } });
  }

  console.log(
    `[anchor-approve] approved requestId=${requestId} grantId=${grantId} anchorEmail=${anchorEmail} unlockUntil=${unlockUntil}`,
  );

  return jsonResponse(200, {
    ok: true,
    data: {
      requestId,
      grantId: grant?.id ?? grantId,
      packageName: unlockReq.package_name,
      appName: unlockReq.app_name,
      unlockUntil: grant?.unlock_until ?? unlockUntil,
      approvedAt: grant?.approved_at ?? approvedAt,
      durationLabel: label,
    },
  });
});
