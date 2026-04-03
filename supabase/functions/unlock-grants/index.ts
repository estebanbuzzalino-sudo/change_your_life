import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, x-installation-id",
  "Access-Control-Allow-Methods": "GET, OPTIONS",
};

function generateId(prefix: string) {
  return `${prefix}_${crypto.randomUUID().replace(/-/g, "").slice(0, 20)}`;
}

function jsonResponse(status: number, body: unknown) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json",
      "Cache-Control": "no-store",
    },
  });
}

function errorResponse(
  status: number,
  code: string,
  message: string,
  requestId: string,
  serverTime: string,
  details: Record<string, unknown> = {},
) {
  return jsonResponse(status, {
    ok: false,
    error: {
      code,
      message,
      details,
    },
    meta: {
      requestId,
      serverTime,
    },
  });
}

function isActiveRoute(pathname: string) {
  const parts = pathname.split("/").filter(Boolean);
  return parts.length > 0 && parts[parts.length - 1] === "active";
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  const requestId = generateId("srv");
  const serverTime = new Date().toISOString();
  const requestUrl = new URL(req.url);

  if (req.method !== "GET") {
    return errorResponse(
      405,
      "METHOD_NOT_ALLOWED",
      "Only GET is allowed",
      requestId,
      serverTime,
    );
  }

  if (!isActiveRoute(requestUrl.pathname)) {
    return errorResponse(
      404,
      "ENDPOINT_NOT_FOUND",
      "Use GET /unlock-grants/active",
      requestId,
      serverTime,
    );
  }

  const installationId = req.headers.get("x-installation-id")?.trim() ?? "";
  if (!installationId) {
    return errorResponse(
      400,
      "MISSING_HEADER",
      "X-Installation-Id is required",
      requestId,
      serverTime,
    );
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

  if (!supabaseUrl || !serviceRoleKey) {
    return errorResponse(
      500,
      "MISSING_ENV",
      "Missing Supabase environment configuration",
      requestId,
      serverTime,
    );
  }

  const supabase = createClient(supabaseUrl, serviceRoleKey);

  const { data, error } = await supabase
    .from("unlock_grants")
    .select("*")
    .eq("installation_id", installationId)
    .gt("unlock_until", serverTime)
    .order("unlock_until", { ascending: true });

  if (error) {
    return errorResponse(
      500,
      "DB_SELECT_FAILED",
      error.message,
      requestId,
      serverTime,
      { installationId },
    );
  }

  const serverMillis = Date.parse(serverTime);
  const byPackage = new Map<string, {
    packageName: string;
    unlockUntil: string;
    requestId: string | null;
    appName: string | null;
    minutes: number | null;
  }>();

  for (const rawGrant of data ?? []) {
    const grant = rawGrant as Record<string, unknown>;
    const packageName = String(grant.package_name ?? grant.packageName ?? "").trim();
    const unlockUntil = String(grant.unlock_until ?? grant.unlockUntil ?? "").trim();
    if (!packageName || !unlockUntil) continue;

    const unlockUntilMillis = Date.parse(unlockUntil);
    if (!Number.isFinite(unlockUntilMillis) || unlockUntilMillis <= serverMillis) {
      continue;
    }

    const requestGrantId = String(grant.request_id ?? grant.requestId ?? "").trim();
    const appName = String(grant.app_name ?? grant.appName ?? "").trim();
    const minutesRaw = Number(grant.minutes);
    const minutes = Number.isFinite(minutesRaw) && minutesRaw > 0 ? minutesRaw : null;

    const existing = byPackage.get(packageName);
    if (!existing || Date.parse(existing.unlockUntil) < unlockUntilMillis) {
      byPackage.set(packageName, {
        packageName,
        unlockUntil,
        requestId: requestGrantId || null,
        appName: appName || null,
        minutes,
      });
    }
  }

  const grants = Array.from(byPackage.values()).sort((a, b) => {
    return Date.parse(a.unlockUntil) - Date.parse(b.unlockUntil);
  });

  console.log(
    `[unlock-grants] requestId=${requestId} installationId=${installationId} active=${grants.length}`,
  );

  return jsonResponse(200, {
    ok: true,
    data: {
      installationId,
      serverTime,
      grants,
      count: grants.length,
      v: 1,
    },
    meta: {
      requestId,
      serverTime,
    },
  });
});
