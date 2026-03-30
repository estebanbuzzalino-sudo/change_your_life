import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, x-installation-id, idempotency-key",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
};

const TOKEN_REGEX = /^[a-f0-9]{64}$/i;

function generateId(prefix: string) {
  return `${prefix}_${crypto.randomUUID().replace(/-/g, "").slice(0, 20)}`;
}

async function sha256(value: string) {
  const data = new TextEncoder().encode(value);
  const hashBuffer = await crypto.subtle.digest("SHA-256", data);
  const hashArray = Array.from(new Uint8Array(hashBuffer));
  return hashArray.map((b) => b.toString(16).padStart(2, "0")).join("");
}

function jsonResponse(status: number, body: unknown) {
  console.log(`[approvals] responseType=json status=${status}`);
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json",
    },
  });
}

function htmlResponse(status: number, html: string) {
  console.log(`[approvals] responseType=html status=${status}`);
  const headers = new Headers();
  for (const [key, value] of Object.entries(corsHeaders)) {
    headers.set(key, value);
  }
  headers.set("Content-Type", "text/html; charset=utf-8");
  headers.set("Content-Disposition", "inline");
  headers.set("Vary", "Accept");
  headers.set("Cache-Control", "no-store");

  return new Response(html, {
    status,
    headers,
  });
}

function wantsHtmlFromAccept(req: Request) {
  const accept = req.headers.get("accept")?.toLowerCase() ?? "";
  return accept.includes("text/html");
}

function resolveHtmlMode(method: string, rawView: string | null, acceptsHtml: boolean) {
  const view = (rawView ?? "").trim().toLowerCase();

  if (view === "html") return true;
  if (view === "json") return false;

  // Stable contract: GET without view stays JSON.
  if (method === "GET") return false;

  // Backward-compatible behavior for POST when view is omitted.
  return acceptsHtml;
}

function escapeHtml(value: unknown) {
  const text = String(value ?? "");
  return text
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#39;");
}

function statusColor(kind: "ok" | "pending" | "error") {
  if (kind === "ok") return "#0f766e";
  if (kind === "pending") return "#a16207";
  return "#b91c1c";
}

function renderApprovalPage(params: {
  title: string;
  heading: string;
  statusLabel: string;
  statusKind: "ok" | "pending" | "error";
  appName?: string;
  requesterName?: string;
  minutes?: number;
  message?: string;
  approveActionPath?: string;
  showApproveButton?: boolean;
}) {
  const color = statusColor(params.statusKind);
  const appName = params.appName ? escapeHtml(params.appName) : "-";
  const requesterName = params.requesterName ? escapeHtml(params.requesterName) : "-";
  const minutes = typeof params.minutes === "number" ? params.minutes : null;
  const message = params.message ? escapeHtml(params.message) : "";
  const approveActionPath = params.approveActionPath
    ? escapeHtml(params.approveActionPath)
    : "";
  const showApproveButton = Boolean(params.showApproveButton && approveActionPath);

  return `<!doctype html>
<html lang="es">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>${escapeHtml(params.title)}</title>
  <style>
    :root { color-scheme: light dark; }
    body {
      margin: 0;
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
      background: #f3f4f6;
      color: #111827;
    }
    .wrap {
      max-width: 720px;
      margin: 32px auto;
      padding: 0 16px;
    }
    .card {
      background: #ffffff;
      border-radius: 12px;
      border: 1px solid #e5e7eb;
      padding: 20px;
      box-shadow: 0 1px 2px rgba(0, 0, 0, 0.06);
    }
    h1 {
      margin: 0 0 12px 0;
      font-size: 24px;
      line-height: 1.2;
    }
    .status {
      display: inline-block;
      margin-bottom: 16px;
      padding: 6px 10px;
      border-radius: 999px;
      border: 1px solid ${color};
      color: ${color};
      font-weight: 600;
      font-size: 14px;
    }
    .grid {
      display: grid;
      grid-template-columns: 170px 1fr;
      gap: 8px 12px;
      margin: 16px 0;
    }
    .label {
      color: #4b5563;
      font-weight: 600;
    }
    .value {
      color: #111827;
      word-break: break-word;
    }
    .msg {
      margin: 14px 0 18px;
      color: #374151;
    }
    .btn {
      appearance: none;
      border: none;
      border-radius: 10px;
      background: #2563eb;
      color: #fff;
      padding: 12px 16px;
      font-size: 16px;
      font-weight: 600;
      cursor: pointer;
    }
    .hint {
      margin-top: 14px;
      color: #6b7280;
      font-size: 13px;
    }
  </style>
</head>
<body>
  <div class="wrap">
    <div class="card">
      <h1>${escapeHtml(params.heading)}</h1>
      <div class="status">${escapeHtml(params.statusLabel)}</div>

      <div class="grid">
        <div class="label">App</div>
        <div class="value">${appName}</div>
        <div class="label">Solicitante</div>
        <div class="value">${requesterName}</div>
        <div class="label">Duracion</div>
        <div class="value">${minutes === null ? "-" : `${minutes} minutos`}</div>
      </div>

      ${message ? `<div class="msg">${message}</div>` : ""}

      ${showApproveButton
      ? `<form method="POST" action="${approveActionPath}">
        <button class="btn" type="submit">Aprobar desbloqueo</button>
      </form>
      <div class="hint">Al aprobar, se habilitara el desbloqueo temporal.</div>`
      : ""}
    </div>
  </div>
</body>
</html>`;
}

function renderSimpleHtmlError(
  status: number,
  title: string,
  statusLabel: string,
  message: string,
  appName?: string,
  requesterName?: string,
  minutes?: number,
) {
  return htmlResponse(
    status,
    renderApprovalPage({
      title,
      heading: title,
      statusLabel,
      statusKind: "error",
      message,
      appName,
      requesterName,
      minutes,
      showApproveButton: false,
    }),
  );
}

function errorResponse(
  status: number,
  code: string,
  message: string,
  requestIdMeta: string,
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
      requestId: requestIdMeta,
      serverTime,
    },
  });
}

function parseTokenRoute(pathname: string) {
  const parts = pathname.split("/").filter(Boolean);
  const approvalsIndex = parts.lastIndexOf("approvals");
  if (approvalsIndex === -1) {
    return { token: null as string | null, action: null as string | null };
  }

  return {
    token: parts[approvalsIndex + 1] ?? null,
    action: parts[approvalsIndex + 2] ?? null,
  };
}

function normalizeToken(rawToken: string | null) {
  if (!rawToken) return "";

  let token = rawToken;
  try {
    token = decodeURIComponent(token);
  } catch {
    // Keep original token when URI decode fails.
  }

  return token
    .trim()
    .replace(/^[<>"'`]+|[<>"'`]+$/g, "")
    .replace(/\s+/g, "");
}

function buildApproveUrl(requestUrl: URL, token: string, forceHtmlView = false) {
  const parts = requestUrl.pathname.split("/").filter(Boolean);
  const approvalsIndex = parts.lastIndexOf("approvals");
  let url: URL;

  if (approvalsIndex === -1) {
    url = new URL(`/approvals/${token}/approve`, requestUrl.origin);
  } else {
    const prefix = parts.slice(0, approvalsIndex).join("/");
    const basePath = prefix ? `/${prefix}` : "";
    url = new URL(
      `${basePath}/approvals/${token}/approve`,
      requestUrl.origin,
    );
  }

  if (forceHtmlView) {
    url.searchParams.set("view", "html");
  }

  return url.toString();
}

function isTokenExpired(tokenExpiresAt: string) {
  const expiresAt = new Date(tokenExpiresAt).getTime();
  if (Number.isNaN(expiresAt)) {
    return true;
  }
  return expiresAt <= Date.now();
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    console.log("[approvals] OPTIONS request");
    return new Response("ok", { headers: corsHeaders });
  }

  const requestUrl = new URL(req.url);
  const viewRaw = requestUrl.searchParams.get("view");
  const viewNormalized = (viewRaw ?? "").trim().toLowerCase();
  const acceptsHtml = wantsHtmlFromAccept(req);
  const wantsBrowserHtml = resolveHtmlMode(req.method, viewRaw, acceptsHtml);
  const requestIdMeta = generateId("srv");
  const serverTime = new Date().toISOString();

  console.log(`[approvals] request.url=${req.url}`);
  console.log(`[approvals] viewRaw=${viewRaw ?? ""} viewNormalized=${viewNormalized}`);
  console.log(`[approvals] acceptsHtml=${acceptsHtml} wantsHtml=${wantsBrowserHtml} method=${req.method}`);

  if (req.method !== "GET" && req.method !== "POST") {
    if (wantsBrowserHtml) {
      return renderSimpleHtmlError(
        405,
        "Metodo no permitido",
        "Metodo invalido",
        "Solo se permiten GET y POST.",
      );
    }

    return errorResponse(
      405,
      "METHOD_NOT_ALLOWED",
      "Only GET and POST are allowed",
      requestIdMeta,
      serverTime,
    );
  }

  const { token, action } = parseTokenRoute(requestUrl.pathname);
  const normalizedToken = normalizeToken(token);

  if (!normalizedToken) {
    if (wantsBrowserHtml) {
      return renderSimpleHtmlError(
        400,
        "Link invalido",
        "Token invalido",
        "El link de aprobacion no tiene token valido.",
      );
    }

    return errorResponse(
      400,
      "INVALID_TOKEN_FORMAT",
      "Token is required in URL path",
      requestIdMeta,
      serverTime,
    );
  }

  if (!TOKEN_REGEX.test(normalizedToken)) {
    if (wantsBrowserHtml) {
      return renderSimpleHtmlError(
        400,
        "Link invalido",
        "Token invalido",
        "El formato del token no es valido.",
      );
    }

    return errorResponse(
      400,
      "INVALID_TOKEN_FORMAT",
      "Token format is invalid",
      requestIdMeta,
      serverTime,
    );
  }

  if (req.method === "GET" && action) {
    if (wantsBrowserHtml) {
      return renderSimpleHtmlError(
        404,
        "Ruta no encontrada",
        "Ruta invalida",
        "La ruta solicitada no existe.",
      );
    }

    return errorResponse(
      404,
      "ENDPOINT_NOT_FOUND",
      "Endpoint not found",
      requestIdMeta,
      serverTime,
    );
  }

  if (req.method === "POST" && action !== "approve") {
    if (wantsBrowserHtml) {
      return renderSimpleHtmlError(
        404,
        "Ruta no encontrada",
        "Ruta invalida",
        "La ruta solicitada no existe.",
      );
    }

    return errorResponse(
      404,
      "ENDPOINT_NOT_FOUND",
      "Endpoint not found",
      requestIdMeta,
      serverTime,
    );
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

  if (!supabaseUrl || !serviceRoleKey) {
    if (wantsBrowserHtml) {
      return renderSimpleHtmlError(
        500,
        "Error interno",
        "Configuracion invalida",
        "Faltan variables de entorno del backend.",
      );
    }

    return errorResponse(
      500,
      "MISSING_ENV",
      "Missing Supabase environment configuration",
      requestIdMeta,
      serverTime,
    );
  }

  const supabase = createClient(supabaseUrl, serviceRoleKey);
  const tokenHash = await sha256(normalizedToken);

  const selectFields =
    "id, installation_id, package_name, app_name, requester_name, friend_name, friend_email, minutes, status, requested_at, token_expires_at, token_used_at";

  const { data: existingRequest, error: selectError } = await supabase
    .from("unlock_requests")
    .select(selectFields)
    .eq("token_hash", tokenHash)
    .limit(1)
    .maybeSingle();

  if (selectError) {
    if (wantsBrowserHtml) {
      return renderSimpleHtmlError(
        500,
        "Error de base de datos",
        "Error interno",
        "No se pudo consultar la solicitud.",
      );
    }

    return errorResponse(
      500,
      "DB_SELECT_FAILED",
      selectError.message,
      requestIdMeta,
      serverTime,
    );
  }

  if (!existingRequest) {
    if (wantsBrowserHtml) {
      return renderSimpleHtmlError(
        404,
        "Solicitud no encontrada",
        "Token invalido",
        "El token no existe o no corresponde a una solicitud valida.",
      );
    }

    return errorResponse(
      404,
      "TOKEN_NOT_FOUND",
      "Approval token was not found",
      requestIdMeta,
      serverTime,
    );
  }

  if (existingRequest.token_used_at) {
    if (wantsBrowserHtml) {
      return renderSimpleHtmlError(
        409,
        "Solicitud ya aprobada",
        "Token ya utilizado",
        "Este link ya fue usado. No se puede aprobar nuevamente.",
        existingRequest.app_name,
        existingRequest.requester_name,
        existingRequest.minutes,
      );
    }

    return errorResponse(
      409,
      "TOKEN_ALREADY_USED",
      "This approval token was already consumed",
      requestIdMeta,
      serverTime,
      { requestId: existingRequest.id },
    );
  }

  if (isTokenExpired(existingRequest.token_expires_at)) {
    await supabase
      .from("unlock_requests")
      .update({ status: "expired" })
      .eq("id", existingRequest.id)
      .eq("status", "pending_approval")
      .is("token_used_at", null);

    if (wantsBrowserHtml) {
      return renderSimpleHtmlError(
        410,
        "Token vencido",
        "Token expirado",
        "Este link vencio y ya no se puede usar.",
        existingRequest.app_name,
        existingRequest.requester_name,
        existingRequest.minutes,
      );
    }

    return errorResponse(
      410,
      "TOKEN_EXPIRED",
      "Approval token has expired",
      requestIdMeta,
      serverTime,
      { requestId: existingRequest.id },
    );
  }

  if (existingRequest.status !== "pending_approval") {
    if (wantsBrowserHtml) {
      return renderSimpleHtmlError(
        409,
        "Solicitud no aprobable",
        "Estado no valido",
        `La solicitud esta en estado '${existingRequest.status}'.`,
        existingRequest.app_name,
        existingRequest.requester_name,
        existingRequest.minutes,
      );
    }

    return errorResponse(
      409,
      "REQUEST_NOT_APPROVABLE",
      "Request is not in pending_approval status",
      requestIdMeta,
      serverTime,
      { requestId: existingRequest.id, status: existingRequest.status },
    );
  }

  if (req.method === "GET") {
    if (wantsBrowserHtml) {
      const approvePath = buildApproveUrl(requestUrl, normalizedToken, true);
      return htmlResponse(
        200,
        renderApprovalPage({
          title: "Aprobar desbloqueo",
          heading: "Solicitud de desbloqueo temporal",
          statusLabel: "Pendiente de aprobacion",
          statusKind: "pending",
          appName: existingRequest.app_name,
          requesterName: existingRequest.requester_name,
          minutes: existingRequest.minutes,
          message: "Si aprobas, la app quedara desbloqueada temporalmente.",
          approveActionPath: approvePath,
          showApproveButton: true,
        }),
      );
    }

    return jsonResponse(200, {
      ok: true,
      data: {
        requestId: existingRequest.id,
        status: existingRequest.status,
        packageName: existingRequest.package_name,
        appName: existingRequest.app_name,
        requesterName: existingRequest.requester_name,
        friendName: existingRequest.friend_name,
        minutes: existingRequest.minutes,
        requestedAt: existingRequest.requested_at,
        tokenExpiresAt: existingRequest.token_expires_at,
        v: 1,
      },
      meta: {
        requestId: requestIdMeta,
        serverTime,
      },
    });
  }

  const approvedAtIso = new Date().toISOString();

  const { data: approvedRequest, error: approveUpdateError } = await supabase
    .from("unlock_requests")
    .update({
      status: "approved",
      token_used_at: approvedAtIso,
    })
    .eq("id", existingRequest.id)
    .eq("status", "pending_approval")
    .is("token_used_at", null)
    .gt("token_expires_at", approvedAtIso)
    .select(selectFields)
    .limit(1)
    .maybeSingle();

  if (approveUpdateError) {
    if (wantsBrowserHtml) {
      return renderSimpleHtmlError(
        500,
        "Error al aprobar",
        "Error interno",
        "No se pudo actualizar el estado de la solicitud.",
        existingRequest.app_name,
        existingRequest.requester_name,
        existingRequest.minutes,
      );
    }

    return errorResponse(
      500,
      "DB_UPDATE_FAILED",
      approveUpdateError.message,
      requestIdMeta,
      serverTime,
    );
  }

  if (!approvedRequest) {
    if (wantsBrowserHtml) {
      return renderSimpleHtmlError(
        409,
        "Solicitud ya aprobada",
        "Token ya utilizado",
        "Este link ya fue usado o dejo de estar disponible.",
        existingRequest.app_name,
        existingRequest.requester_name,
        existingRequest.minutes,
      );
    }

    return errorResponse(
      409,
      "TOKEN_ALREADY_USED",
      "This approval token was already consumed",
      requestIdMeta,
      serverTime,
      { requestId: existingRequest.id },
    );
  }

  const minutes = Number.isFinite(approvedRequest.minutes) && approvedRequest.minutes > 0
    ? approvedRequest.minutes
    : 60;
  const unlockUntil = new Date(
    new Date(approvedAtIso).getTime() + minutes * 60 * 1000,
  ).toISOString();

  const generatedGrantId = generateId("ugr");
  const grantBasePayload = {
    request_id: approvedRequest.id,
    installation_id: approvedRequest.installation_id,
    package_name: approvedRequest.package_name,
    unlock_until: unlockUntil,
  };

  let createdGrant: Record<string, unknown> | null = null;
  let grantInsertError: { code?: string; message?: string } | null = null;

  const grantPayloadCandidates: Record<string, unknown>[] = [
    { ...grantBasePayload, id: generatedGrantId, minutes, app_name: approvedRequest.app_name, approved_at: approvedAtIso },
    { ...grantBasePayload, id: generatedGrantId, minutes, app_name: approvedRequest.app_name },
    { ...grantBasePayload, id: generatedGrantId, minutes, approved_at: approvedAtIso },
    { ...grantBasePayload, id: generatedGrantId, minutes },
    { ...grantBasePayload, id: generatedGrantId, app_name: approvedRequest.app_name, approved_at: approvedAtIso },
    { ...grantBasePayload, id: generatedGrantId, app_name: approvedRequest.app_name },
    { ...grantBasePayload, id: generatedGrantId, approved_at: approvedAtIso },
    { ...grantBasePayload, id: generatedGrantId },
    { ...grantBasePayload, minutes, app_name: approvedRequest.app_name, approved_at: approvedAtIso },
    { ...grantBasePayload, minutes, app_name: approvedRequest.app_name },
    { ...grantBasePayload, minutes, approved_at: approvedAtIso },
    { ...grantBasePayload, minutes },
    { ...grantBasePayload, app_name: approvedRequest.app_name, approved_at: approvedAtIso },
    { ...grantBasePayload, app_name: approvedRequest.app_name },
    { ...grantBasePayload, approved_at: approvedAtIso },
    { ...grantBasePayload },
  ];

  // Compatibilidad de schema: soporta tablas con/sin app_name, approved_at y minutes.
  for (const payload of grantPayloadCandidates) {
    const { data, error } = await supabase
      .from("unlock_grants")
      .insert(payload)
      .select("*")
      .limit(1)
      .maybeSingle();

    createdGrant = data as Record<string, unknown> | null;
    grantInsertError = error as { code?: string; message?: string } | null;

    if (!grantInsertError) {
      break;
    }

    const errorMessage = (grantInsertError.message ?? "").toLowerCase();
    const schemaCompatibilityError =
      errorMessage.includes("app_name") ||
      errorMessage.includes("approved_at") ||
      errorMessage.includes("minutes");

    if (!schemaCompatibilityError) {
      break;
    }
  }

  const grantMinutes = (grant: Record<string, unknown> | null | undefined) => {
    const value = Number(grant?.minutes);
    return Number.isFinite(value) && value > 0 ? value : minutes;
  };

  const grantUnlockUntil = (grant: Record<string, unknown> | null | undefined) => {
    const value = grant?.unlock_until ?? grant?.unlockUntil;
    return typeof value === "string" && value.length > 0 ? value : unlockUntil;
  };

  const grantApprovedAt = (grant: Record<string, unknown> | null | undefined) => {
    const value = grant?.approved_at ?? grant?.approvedAt ?? grant?.created_at ?? grant?.createdAt;
    return typeof value === "string" && value.length > 0 ? value : approvedAtIso;
  };

  const grantId = (grant: Record<string, unknown> | null | undefined) => {
    const value = grant?.id;
    return typeof value === "string" && value.length > 0 ? value : generatedGrantId;
  };

  if (grantInsertError) {
    if (grantInsertError.code === "23505") {
      const { data: existingGrant } = await supabase
        .from("unlock_grants")
        .select("*")
        .eq("request_id", approvedRequest.id)
        .limit(1)
        .maybeSingle();

      if (existingGrant) {
        const existingGrantRecord = existingGrant as Record<string, unknown>;

        if (wantsBrowserHtml) {
          return htmlResponse(
            200,
            renderApprovalPage({
              title: "Desbloqueo aprobado",
              heading: "Desbloqueo aprobado",
              statusLabel: "Aprobado",
              statusKind: "ok",
              appName: approvedRequest.app_name,
              requesterName: approvedRequest.requester_name,
              minutes: grantMinutes(existingGrantRecord),
              message: `Desbloqueo activo hasta ${grantUnlockUntil(existingGrantRecord)}.`,
              showApproveButton: false,
            }),
          );
        }

        return jsonResponse(200, {
          ok: true,
          data: {
            requestId: approvedRequest.id,
            status: "approved",
            packageName: approvedRequest.package_name,
            appName: approvedRequest.app_name,
            minutes: grantMinutes(existingGrantRecord),
            approvedAt: grantApprovedAt(existingGrantRecord),
            unlockUntil: grantUnlockUntil(existingGrantRecord),
            grantId: grantId(existingGrantRecord),
            v: 1,
          },
          meta: {
            requestId: requestIdMeta,
            serverTime,
          },
        });
      }
    }

    await supabase
      .from("unlock_requests")
      .update({
        status: "pending_approval",
        token_used_at: null,
      })
      .eq("id", approvedRequest.id)
      .eq("status", "approved")
      .eq("token_used_at", approvedAtIso);

    if (wantsBrowserHtml) {
      return renderSimpleHtmlError(
        500,
        "Error al crear desbloqueo",
        "Error interno",
        "No se pudo generar el desbloqueo temporal.",
        approvedRequest.app_name,
        approvedRequest.requester_name,
        approvedRequest.minutes,
      );
    }

    return errorResponse(
      500,
      "DB_INSERT_FAILED",
      grantInsertError.message,
      requestIdMeta,
      serverTime,
    );
  }

  if (wantsBrowserHtml) {
    return htmlResponse(
      200,
      renderApprovalPage({
        title: "Desbloqueo aprobado",
        heading: "Desbloqueo aprobado",
        statusLabel: "Aprobado",
        statusKind: "ok",
        appName: approvedRequest.app_name,
        requesterName: approvedRequest.requester_name,
        minutes: grantMinutes(createdGrant),
        message: `Desbloqueo activo hasta ${grantUnlockUntil(createdGrant)}.`,
        showApproveButton: false,
      }),
    );
  }

  return jsonResponse(200, {
    ok: true,
    data: {
      requestId: approvedRequest.id,
      status: "approved",
      packageName: approvedRequest.package_name,
      appName: approvedRequest.app_name,
      minutes: grantMinutes(createdGrant),
      approvedAt: grantApprovedAt(createdGrant),
      unlockUntil: grantUnlockUntil(createdGrant),
      grantId: grantId(createdGrant),
      v: 1,
    },
    meta: {
      requestId: requestIdMeta,
      serverTime,
    },
  });
});
