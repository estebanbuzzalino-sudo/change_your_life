import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, x-installation-id, idempotency-key",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function jsonResponse(status: number, body: unknown) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json",
    },
  });
}

function generateId(prefix: string) {
  return `${prefix}_${crypto.randomUUID().replace(/-/g, "").slice(0, 20)}`;
}

function generateToken() {
  const bytes = crypto.getRandomValues(new Uint8Array(32));
  return Array.from(bytes).map((b) => b.toString(16).padStart(2, "0")).join("");
}

async function sha256(value: string) {
  const data = new TextEncoder().encode(value);
  const hashBuffer = await crypto.subtle.digest("SHA-256", data);
  const hashArray = Array.from(new Uint8Array(hashBuffer));
  return hashArray.map((b) => b.toString(16).padStart(2, "0")).join("");
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return jsonResponse(405, {
      ok: false,
      error: {
        code: "METHOD_NOT_ALLOWED",
        message: "Only POST is allowed",
      },
      meta: {
        requestId: generateId("srv"),
        serverTime: new Date().toISOString(),
      },
    });
  }

  const requestIdMeta = generateId("srv");
  const serverTime = new Date().toISOString();

  try {
    const installationId = req.headers.get("x-installation-id");
    if (!installationId) {
      return jsonResponse(400, {
        ok: false,
        error: {
          code: "MISSING_HEADER",
          message: "X-Installation-Id is required",
          details: {},
        },
        meta: { requestId: requestIdMeta, serverTime },
      });
    }

    const body = await req.json();

    const packageName = body.packageName;
    const appName = body.appName;
    const requesterName = body.requesterName ?? "Usuario actual";
    const friendName = body.friendName ?? "";
    const friendEmail = body.friendEmail;
    const minutes = body.minutes ?? 60;
    const v = body.v ?? 1;

    if (!packageName || !appName || !friendEmail) {
      return jsonResponse(422, {
        ok: false,
        error: {
          code: "VALIDATION_ERROR",
          message: "packageName, appName and friendEmail are required",
          details: {},
        },
        meta: { requestId: requestIdMeta, serverTime },
      });
    }

    const requestId = generateId("urq");
    const token = generateToken();
    const tokenHash = await sha256(token);

    const requestedAt = new Date();
    const tokenExpiresAt = new Date(requestedAt.getTime() + 24 * 60 * 60 * 1000);

    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const resendApiKey = Deno.env.get("RESEND_API_KEY")!;
    const fromEmail = Deno.env.get("FROM_EMAIL")!;
    const approvalBaseUrl =
      Deno.env.get("APPROVAL_BASE_URL") ?? "https://oggqvcjtvfgyagaisvmj.functions.supabase.co/approvals";
    const approvalApiBaseUrl =
      Deno.env.get("APPROVAL_API_BASE_URL") ?? "https://oggqvcjtvfgyagaisvmj.functions.supabase.co";
    const approvalWebBaseUrl = Deno.env.get("APPROVAL_WEB_BASE_URL") ?? "";

    const supabase = createClient(supabaseUrl, serviceRoleKey);

    const { error: insertError } = await supabase
      .from("unlock_requests")
      .insert({
        id: requestId,
        installation_id: installationId,
        package_name: packageName,
        app_name: appName,
        requester_name: requesterName,
        friend_name: friendName,
        friend_email: friendEmail,
        minutes,
        status: "pending_approval",
        requested_at: requestedAt.toISOString(),
        token_hash: tokenHash,
        token_expires_at: tokenExpiresAt.toISOString(),
      });

    if (insertError) {
      return jsonResponse(500, {
        ok: false,
        error: {
          code: "DB_INSERT_FAILED",
          message: insertError.message,
          details: {},
        },
        meta: { requestId: requestIdMeta, serverTime },
      });
    }

    const approvalApiUrl = new URL(
      `${approvalBaseUrl.replace(/\/+$/, "")}/${token}`,
    );
    approvalApiUrl.searchParams.set("view", "html");

    let approvalLink = approvalApiUrl.toString();
    if (approvalWebBaseUrl.trim().length > 0) {
      const approvalWebUrl = new URL(approvalWebBaseUrl);
      approvalWebUrl.searchParams.set("token", token);
      approvalWebUrl.searchParams.set("v", "1");
      approvalWebUrl.searchParams.set("apiBase", approvalApiBaseUrl);
      approvalLink = approvalWebUrl.toString();
    }

    const emailHtml = `
      <h2>Solicitud de desbloqueo temporal</h2>
      <p>Hola ${friendName || "responsable"},</p>
      <p>Se solicita tu aprobación para desbloquear temporalmente una app por ${minutes} minutos.</p>
      <p><strong>App bloqueada:</strong> ${appName}</p>
      <p><strong>Package:</strong> ${packageName}</p>
      <p><strong>Solicitante:</strong> ${requesterName}</p>
      <p><strong>Fecha/Hora:</strong> ${requestedAt.toISOString()}</p>
      <p>
        <a href="${approvalLink}" style="display:inline-block;padding:12px 18px;background:#2563eb;color:white;text-decoration:none;border-radius:8px;">
          Aprobar desbloqueo
        </a>
      </p>
      <p>Si el botón no funciona, copiá este link:</p>
      <p>${approvalLink}</p>
      <p style="font-size:12px;color:#6b7280;">
        Fallback API: ${approvalApiUrl.toString()}
      </p>
    `;

    const resendResponse = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${resendApiKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        from: fromEmail,
        to: [friendEmail],
        subject: `Solicitud de desbloqueo temporal (${minutes} min) - ${appName}`,
        html: emailHtml,
      }),
    });

    if (!resendResponse.ok) {
      const resendErrorText = await resendResponse.text();
      return jsonResponse(503, {
        ok: false,
        error: {
          code: "EMAIL_DELIVERY_FAILED",
          message: resendErrorText,
          details: {},
        },
        meta: { requestId: requestIdMeta, serverTime },
      });
    }

    return jsonResponse(201, {
      ok: true,
      data: {
        requestId,
        status: "pending_approval",
        packageName,
        appName,
        minutes,
        requestedAt: requestedAt.toISOString(),
        tokenExpiresAt: tokenExpiresAt.toISOString(),
        emailSent: true,
        v,
      },
      meta: {
        requestId: requestIdMeta,
        serverTime,
      },
    });
  } catch (error) {
    return jsonResponse(500, {
      ok: false,
      error: {
        code: "INTERNAL_ERROR",
        message: error instanceof Error ? error.message : "Unknown error",
        details: {},
      },
      meta: {
        requestId: requestIdMeta,
        serverTime,
      },
    });
  }
});
