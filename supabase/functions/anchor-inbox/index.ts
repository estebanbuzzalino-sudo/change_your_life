import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "GET, OPTIONS",
};

const EMAIL_REGEX = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

function jsonResponse(status: number, body: unknown) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "GET") {
    return jsonResponse(405, { ok: false, error: { code: "METHOD_NOT_ALLOWED" } });
  }

  const url = new URL(req.url);
  const email = (url.searchParams.get("email") ?? "").trim().toLowerCase();

  if (!email || !EMAIL_REGEX.test(email)) {
    return jsonResponse(400, {
      ok: false,
      error: { code: "INVALID_EMAIL", message: "email query param is required and must be valid" },
    });
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
  const supabase = createClient(supabaseUrl, serviceRoleKey);

  const { data, error } = await supabase
    .from("unlock_requests")
    .select(
      "id, installation_id, package_name, app_name, requester_name, friend_name, minutes, status, requested_at, token_expires_at",
    )
    .eq("friend_email", email)
    .eq("status", "pending_approval")
    .is("token_used_at", null)
    .gt("token_expires_at", new Date().toISOString())
    .order("requested_at", { ascending: false })
    .limit(50);

  if (error) {
    console.error(`[anchor-inbox] db_error email=${email} error=${error.message}`);
    return jsonResponse(500, {
      ok: false,
      error: { code: "DB_ERROR", message: error.message },
    });
  }

  const requests = (data ?? []).map((r) => ({
    requestId: r.id,
    installationId: r.installation_id,
    packageName: r.package_name,
    appName: r.app_name,
    requesterName: r.requester_name,
    friendName: r.friend_name,
    minutes: r.minutes,
    status: r.status,
    requestedAt: r.requested_at,
    tokenExpiresAt: r.token_expires_at,
  }));

  console.log(
    `[anchor-inbox] email=${email} found=${requests.length}`,
  );

  return jsonResponse(200, {
    ok: true,
    data: { requests, count: requests.length },
  });
});
