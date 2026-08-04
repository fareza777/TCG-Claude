import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

function bearer(req: Request): string | null {
  const value = req.headers.get("Authorization") ?? "";
  const token = value.replace(/^Bearer\s+/i, "").trim();
  return token || null;
}

function statusFor(errorCode: unknown): number {
  switch (errorCode) {
    case undefined:
    case null:
      return 200;
    case "not_a_player":
      return 403;
    case "match_not_found":
      return 404;
    case "stale_revision":
      return 409;
    case "invalid_payload":
      return 400;
    default:
      return 422;
  }
}

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);
  const token = bearer(req);
  if (!token) return json({ error: "unauthorized" }, 401);

  const url = Deno.env.get("SUPABASE_URL");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const serverUrl = Deno.env.get("PVP_SERVER_URL");
  const internalSecret = Deno.env.get("PVP_INTERNAL_AUTH_SECRET");
  if (!url || !serviceKey || !serverUrl || !internalSecret) {
    return json({ error: "server_not_configured" }, 500);
  }

  const admin = createClient(url, serviceKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { data: userData, error: userError } = await admin.auth.getUser(token);
  if (userError || !userData.user) return json({ error: "unauthorized" }, 401);
  const actorUserId = userData.user.id;

  let body: { action?: unknown; matchId?: unknown; command?: unknown };
  try {
    body = await req.json() as {
      action?: unknown;
      matchId?: unknown;
      command?: unknown;
    };
  } catch {
    return json({ error: "invalid_body" }, 400);
  }

  const matchId = typeof body.matchId === "string" ? body.matchId : "";
  if (!matchId) return json({ error: "match_id_required" }, 400);

  const base = `${serverUrl.replace(/\/$/, "")}/internal/v1/matches/${encodeURIComponent(matchId)}`;
  const headers = {
    "Content-Type": "application/json",
    "X-Pvp-Internal-Secret": internalSecret,
  };

  let response: Response;
  if (body.action === "reconnect") {
    response = await fetch(
      `${base}/projection?userId=${encodeURIComponent(actorUserId)}`,
      { headers: { "X-Pvp-Internal-Secret": internalSecret } },
    );
  } else {
    if (!body.command || typeof body.command !== "object") {
      return json({ error: "command_required" }, 400);
    }
    response = await fetch(`${base}/commands`, {
      method: "POST",
      headers,
      body: JSON.stringify({ actorUserId, command: body.command }),
    });
  }

  let payload: unknown;
  try {
    payload = await response.json();
  } catch {
    return json({ error: "pvp_server_invalid_response" }, 502);
  }
  return json(payload, response.ok ? 200 : statusFor((payload as { errorCode?: unknown })?.errorCode));
});
