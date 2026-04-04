import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, x-installation-id, idempotency-key",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const DEFAULT_UNLOCK_MINUTES = 60;
const E164_REGEX = /^\+[1-9][0-9]{7,14}$/;
const NOTIFICATION_MODES = new Set(["email_only", "whatsapp_only", "email_and_whatsapp"]);

type NotificationMode = "email_only" | "whatsapp_only" | "email_and_whatsapp";
type NotificationChannel = "email" | "whatsapp";
type NotificationStatus = "queued" | "sent" | "failed" | "skipped";

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

function asTrimmedString(value: unknown) {
  return typeof value === "string" ? value.trim() : "";
}

function parseMinutes(value: unknown) {
  const parsed = Number(value);
  if (!Number.isFinite(parsed) || parsed <= 0) {
    return DEFAULT_UNLOCK_MINUTES;
  }
  return Math.floor(parsed);
}

function parseNotificationMode(value: unknown): NotificationMode | null {
  const raw = asTrimmedString(value).toLowerCase();
  const normalized = raw.length === 0 ? "email_only" : raw;
  if (!NOTIFICATION_MODES.has(normalized)) {
    return null;
  }
  return normalized as NotificationMode;
}

function ensureWhatsappAddress(value: string) {
  return value.startsWith("whatsapp:") ? value : `whatsapp:${value}`;
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

function formatEmailRequestedAt(isoDate: string) {
  const date = new Date(isoDate);
  if (Number.isNaN(date.getTime())) return isoDate;

  const formatter = new Intl.DateTimeFormat("es-AR", {
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
    second: "2-digit",
    hour12: false,
    timeZone: "America/Argentina/Buenos_Aires",
  });

  return `${formatter.format(date)} (GMT-3)`;
}

async function createNotificationRecord(
  supabase: ReturnType<typeof createClient>,
  params: {
    requestId: string;
    channel: NotificationChannel;
    provider: string;
    target: string;
    status: NotificationStatus;
    payload?: Record<string, unknown>;
    providerMessageId?: string | null;
    providerStatus?: string | null;
    errorCode?: string | null;
    errorMessage?: string | null;
  },
) {
  const id = generateId("urn");
  const { error } = await supabase
    .from("unlock_request_notifications")
    .insert({
      id,
      request_id: params.requestId,
      channel: params.channel,
      provider: params.provider,
      target: params.target,
      status: params.status,
      provider_message_id: params.providerMessageId ?? null,
      provider_status: params.providerStatus ?? null,
      error_code: params.errorCode ?? null,
      error_message: params.errorMessage ?? null,
      payload: params.payload ?? {},
    });

  if (error) {
    console.warn(
      `[unlock-requests] notification_insert_failed requestId=${params.requestId} channel=${params.channel} error=${error.message}`,
    );
  }
}

async function sendEmailViaResend(params: {
  resendApiKey: string;
  fromEmail: string;
  friendEmail: string;
  subject: string;
  html: string;
}) {
  const response = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${params.resendApiKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      from: params.fromEmail,
      to: [params.friendEmail],
      subject: params.subject,
      html: params.html,
    }),
  });

  const text = await response.text();
  let providerMessageId: string | null = null;
  let providerStatus: string | null = null;
  if (text.length > 0) {
    try {
      const parsed = JSON.parse(text) as Record<string, unknown>;
      providerMessageId = asTrimmedString(parsed.id);
      providerStatus = asTrimmedString(parsed.status);
    } catch {
      // Ignore parse errors; keep raw text for diagnostics.
    }
  }

  return {
    ok: response.ok,
    status: response.status,
    text,
    providerMessageId: providerMessageId || null,
    providerStatus: providerStatus || null,
  };
}

async function sendWhatsappViaTwilio(params: {
  accountSid: string;
  authToken: string;
  from: string;
  toE164: string;
  body: string;
}) {
  const endpoint = `https://api.twilio.com/2010-04-01/Accounts/${params.accountSid}/Messages.json`;
  const form = new URLSearchParams();
  form.set("From", ensureWhatsappAddress(params.from));
  form.set("To", ensureWhatsappAddress(params.toE164));
  form.set("Body", params.body);

  const response = await fetch(endpoint, {
    method: "POST",
    headers: {
      "Authorization": `Basic ${btoa(`${params.accountSid}:${params.authToken}`)}`,
      "Content-Type": "application/x-www-form-urlencoded",
    },
    body: form.toString(),
  });

  const text = await response.text();
  let providerMessageId: string | null = null;
  let providerStatus: string | null = null;
  let errorCode: string | null = null;
  let errorMessage: string | null = null;
  if (text.length > 0) {
    try {
      const parsed = JSON.parse(text) as Record<string, unknown>;
      providerMessageId = asTrimmedString(parsed.sid);
      providerStatus = asTrimmedString(parsed.status);
      errorCode = asTrimmedString(parsed.code);
      errorMessage = asTrimmedString(parsed.message);
    } catch {
      // Ignore parse errors; keep raw text for diagnostics.
    }
  }

  return {
    ok: response.ok,
    status: response.status,
    text,
    providerMessageId: providerMessageId || null,
    providerStatus: providerStatus || null,
    errorCode: errorCode || null,
    errorMessage: errorMessage || null,
  };
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

    const rawBody = await req.json();
    if (typeof rawBody !== "object" || rawBody === null) {
      return jsonResponse(422, {
        ok: false,
        error: {
          code: "VALIDATION_ERROR",
          message: "Body must be a JSON object",
          details: {},
        },
        meta: { requestId: requestIdMeta, serverTime },
      });
    }
    const body = rawBody as Record<string, unknown>;

    const packageName = asTrimmedString(body.packageName ?? body.package_name);
    const appName = asTrimmedString(body.appName ?? body.app_name);
    const requesterName = asTrimmedString(body.requesterName ?? body.requester_name).length > 0
      ? asTrimmedString(body.requesterName ?? body.requester_name)
      : "Usuario";
    const friendName = asTrimmedString(body.friendName ?? body.friend_name);
    const friendEmail = asTrimmedString(body.friendEmail ?? body.friend_email);
    const friendWhatsappE164 = asTrimmedString(
      body.friendWhatsappE164 ?? body.friend_whatsapp_e164,
    );
    const notificationMode = parseNotificationMode(
      body.notificationMode ?? body.notification_mode,
    );
    const minutes = parseMinutes(body.minutes);
    const v = Number(body.v) || 1;

    if (!notificationMode) {
      return jsonResponse(422, {
        ok: false,
        error: {
          code: "VALIDATION_ERROR",
          message: "notificationMode must be email_only, whatsapp_only or email_and_whatsapp",
          details: {},
        },
        meta: { requestId: requestIdMeta, serverTime },
      });
    }

    if (!packageName || !appName) {
      return jsonResponse(422, {
        ok: false,
        error: {
          code: "VALIDATION_ERROR",
          message: "packageName and appName are required",
          details: {},
        },
        meta: { requestId: requestIdMeta, serverTime },
      });
    }

    if (notificationMode === "email_only" && friendEmail.length === 0) {
      return jsonResponse(422, {
        ok: false,
        error: {
          code: "VALIDATION_ERROR",
          message: "friendEmail is required when notificationMode is email_only",
          details: {},
        },
        meta: { requestId: requestIdMeta, serverTime },
      });
    }

    if (friendWhatsappE164.length > 0 && !E164_REGEX.test(friendWhatsappE164)) {
      return jsonResponse(422, {
        ok: false,
        error: {
          code: "VALIDATION_ERROR",
          message: "friend_whatsapp_e164 must be E.164 format, for example +5491112345678",
          details: {},
        },
        meta: { requestId: requestIdMeta, serverTime },
      });
    }

    if (notificationMode === "whatsapp_only" && friendWhatsappE164.length === 0) {
      return jsonResponse(422, {
        ok: false,
        error: {
          code: "VALIDATION_ERROR",
          message: "friend_whatsapp_e164 is required when notificationMode is whatsapp_only",
          details: {},
        },
        meta: { requestId: requestIdMeta, serverTime },
      });
    }

    if (
      notificationMode === "email_and_whatsapp" &&
      (friendWhatsappE164.length === 0 || friendEmail.length === 0)
    ) {
      return jsonResponse(422, {
        ok: false,
        error: {
          code: "VALIDATION_ERROR",
          message: "friendEmail and friend_whatsapp_e164 are required when notificationMode is email_and_whatsapp",
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
    const twilioAccountSid = Deno.env.get("TWILIO_ACCOUNT_SID") ?? "";
    const twilioAuthToken = Deno.env.get("TWILIO_AUTH_TOKEN") ?? "";
    const twilioWhatsappFrom = Deno.env.get("TWILIO_WHATSAPP_FROM") ?? "";
    const whatsappEnabled = (Deno.env.get("WHATSAPP_ENABLED") ?? "true").trim().toLowerCase() !== "false";

    const supabase = createClient(supabaseUrl, serviceRoleKey);

    const baseInsertPayload = {
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
    };
    const extendedInsertPayload = {
      ...baseInsertPayload,
      friend_whatsapp_e164: friendWhatsappE164 || null,
      notification_mode: notificationMode,
    };

    let { error: insertError } = await supabase
      .from("unlock_requests")
      .insert(extendedInsertPayload);

    // Compatibilidad con esquemas viejos si aun no corrieron la migracion.
    if (insertError) {
      const message = insertError.message.toLowerCase();
      const missingNewColumns = message.includes("friend_whatsapp_e164") ||
        message.includes("notification_mode");
      if (missingNewColumns) {
        const retry = await supabase.from("unlock_requests").insert(baseInsertPayload);
        insertError = retry.error;
      }
    }

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

    const requestedAtLabel = formatEmailRequestedAt(requestedAt.toISOString());

    const emailHtml = `
      <h2>Solicitud de desbloqueo temporal</h2>
      <p>Hola ${friendName || "responsable"},</p>
      <p>Se solicita tu aprobacion para desbloquear temporalmente una app por ${minutes} minutos.</p>
      <p><strong>App bloqueada:</strong> ${appName}</p>
      <p><strong>Solicitante:</strong> ${requesterName}</p>
      <p><strong>Fecha y hora:</strong> ${requestedAtLabel}</p>
      <p>
        <a href="${approvalLink}" style="display:inline-block;padding:12px 18px;background:#2563eb;color:white;text-decoration:none;border-radius:8px;">
          Aprobar desbloqueo
        </a>
      </p>
      <p>Si el boton no funciona, copia este link:</p>
      <p>${approvalLink}</p>
    `;

    const shouldSendEmail = notificationMode !== "whatsapp_only";
    const shouldAttemptWhatsapp = notificationMode !== "email_only";
    let emailSent = false;

    if (shouldSendEmail) {
      const emailSubject = `Solicitud de desbloqueo temporal (${minutes} min) - ${appName}`;
      const emailPayload = {
        subject: emailSubject,
        from: fromEmail,
        to: friendEmail,
        minutes,
        appName,
        requesterName,
        friendName,
        requestedAt: requestedAt.toISOString(),
        notificationMode,
      };
      await createNotificationRecord(supabase, {
        requestId,
        channel: "email",
        provider: "resend",
        target: friendEmail,
        status: "queued",
        payload: emailPayload,
      });

      const resendResponse = await sendEmailViaResend({
        resendApiKey,
        fromEmail,
        friendEmail,
        subject: emailSubject,
        html: emailHtml,
      });

      if (!resendResponse.ok) {
        await createNotificationRecord(supabase, {
          requestId,
          channel: "email",
          provider: "resend",
          target: friendEmail,
          status: "failed",
          providerMessageId: resendResponse.providerMessageId,
          providerStatus: resendResponse.providerStatus,
          errorCode: `http_${resendResponse.status}`,
          errorMessage: resendResponse.text,
          payload: emailPayload,
        });
        return jsonResponse(503, {
          ok: false,
          error: {
            code: "EMAIL_DELIVERY_FAILED",
            message: resendResponse.text,
            details: {},
          },
          meta: { requestId: requestIdMeta, serverTime },
        });
      }

      await createNotificationRecord(supabase, {
        requestId,
        channel: "email",
        provider: "resend",
        target: friendEmail,
        status: "sent",
        providerMessageId: resendResponse.providerMessageId,
        providerStatus: resendResponse.providerStatus,
        payload: emailPayload,
      });
      emailSent = true;
    } else {
      await createNotificationRecord(supabase, {
        requestId,
        channel: "email",
        provider: "resend",
        target: friendEmail || "not_configured",
        status: "skipped",
        errorCode: "CHANNEL_DISABLED",
        errorMessage: "notificationMode=whatsapp_only",
        payload: {
          appName,
          requesterName,
          friendName,
          requestedAt: requestedAt.toISOString(),
          minutes,
          notificationMode,
        },
      });
    }

    let whatsappSent = false;
    let whatsappError: string | null = null;

    if (shouldAttemptWhatsapp) {
      const whatsappPayload = {
        appName,
        packageName,
        requesterName,
        friendName,
        requestedAt: requestedAt.toISOString(),
        minutes,
        approvalLink,
        notificationMode,
      };
      await createNotificationRecord(supabase, {
        requestId,
        channel: "whatsapp",
        provider: "twilio",
        target: friendWhatsappE164,
        status: "queued",
        payload: whatsappPayload,
      });

      if (!whatsappEnabled) {
        whatsappError = "whatsapp_disabled";
        await createNotificationRecord(supabase, {
          requestId,
          channel: "whatsapp",
          provider: "twilio",
          target: friendWhatsappE164,
          status: "skipped",
          errorCode: "WHATSAPP_DISABLED",
          errorMessage: "WHATSAPP_ENABLED is false",
          payload: whatsappPayload,
        });
      } else if (!twilioAccountSid || !twilioAuthToken || !twilioWhatsappFrom) {
        whatsappError = "missing_twilio_config";
        await createNotificationRecord(supabase, {
          requestId,
          channel: "whatsapp",
          provider: "twilio",
          target: friendWhatsappE164,
          status: "failed",
          errorCode: "MISSING_TWILIO_CONFIG",
          errorMessage: "TWILIO_ACCOUNT_SID, TWILIO_AUTH_TOKEN and TWILIO_WHATSAPP_FROM are required",
          payload: whatsappPayload,
        });
      } else {
        const whatsappBody =
          `Solicitud de desbloqueo temporal\n` +
          `App bloqueada: ${appName}\n` +
          `Solicitante: ${requesterName}\n` +
          `Aprobar desbloqueo: ${approvalLink}`;

        const twilioResponse = await sendWhatsappViaTwilio({
          accountSid: twilioAccountSid,
          authToken: twilioAuthToken,
          from: twilioWhatsappFrom,
          toE164: friendWhatsappE164,
          body: whatsappBody,
        });

        if (!twilioResponse.ok) {
          whatsappError = twilioResponse.errorCode || `http_${twilioResponse.status}`;
          await createNotificationRecord(supabase, {
            requestId,
            channel: "whatsapp",
            provider: "twilio",
            target: friendWhatsappE164,
            status: "failed",
            providerMessageId: twilioResponse.providerMessageId,
            providerStatus: twilioResponse.providerStatus,
            errorCode: twilioResponse.errorCode || `http_${twilioResponse.status}`,
            errorMessage: twilioResponse.errorMessage || twilioResponse.text,
            payload: whatsappPayload,
          });
        } else {
          whatsappSent = true;
          await createNotificationRecord(supabase, {
            requestId,
            channel: "whatsapp",
            provider: "twilio",
            target: friendWhatsappE164,
            status: "sent",
            providerMessageId: twilioResponse.providerMessageId,
            providerStatus: twilioResponse.providerStatus,
            payload: whatsappPayload,
          });
        }
      }
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
        emailSent,
        notificationMode,
        friendWhatsappE164: friendWhatsappE164 || null,
        whatsappAttempted: shouldAttemptWhatsapp,
        whatsappSent,
        whatsappError,
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
