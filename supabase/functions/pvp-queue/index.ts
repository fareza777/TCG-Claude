import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import {
  createClient,
  type SupabaseClient,
} from "jsr:@supabase/supabase-js@2";

type QueueAction = "join" | "leave";

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

function supabaseForUser(token: string) {
  const url = Deno.env.get("SUPABASE_URL");
  const key = Deno.env.get("SUPABASE_ANON_KEY") ??
    Deno.env.get("SUPABASE_PUBLISHABLE_KEY");
  if (!url || !key) throw new Error("Supabase public function key is missing");
  return createClient(url, key, {
    auth: { persistSession: false, autoRefreshToken: false },
    global: { headers: { Authorization: `Bearer ${token}` } },
  });
}

async function initializeMatch(
  matchId: string,
  admin: SupabaseClient,
): Promise<Response | null> {
  const serverUrl = Deno.env.get("PVP_SERVER_URL");
  const secret = Deno.env.get("PVP_INTERNAL_AUTH_SECRET");
  if (!serverUrl || !secret) {
    return json({ error: "pvp_server_not_configured", matchId }, 503);
  }
  const { data: players, error: playersError } = await admin
    .from("pvp_match_players")
    .select("user_id,seat,deck_snapshot")
    .eq("match_id", matchId);
  if (playersError || !players || players.length !== 2) {
    console.error("pvp match player snapshot lookup failed", playersError);
    return json({ error: "match_initialization_unavailable", matchId }, 503);
  }
  const response = await fetch(
    `${serverUrl.replace(/\/$/, "")}/internal/v1/matches/${encodeURIComponent(matchId)}/initialize`,
    {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "X-Pvp-Internal-Secret": secret,
      },
      body: JSON.stringify({ matchId, players }),
    },
  );
  if (!response.ok) {
    console.error("pvp match initialization failed", response.status);
    return json({ error: "match_initialization_unavailable", matchId }, 503);
  }
  return null;
}

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);
  const token = bearer(req);
  if (!token) return json({ error: "unauthorized" }, 401);

  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const url = Deno.env.get("SUPABASE_URL");
  if (!serviceKey || !url) return json({ error: "server_not_configured" }, 500);

  const admin = createClient(url, serviceKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { data: userData, error: userError } = await admin.auth.getUser(token);
  if (userError || !userData.user) return json({ error: "unauthorized" }, 401);

  let body: { action?: unknown; deckSnapshot?: unknown };
  try {
    body = await req.json() as { action?: unknown; deckSnapshot?: unknown };
  } catch {
    return json({ error: "invalid_body" }, 400);
  }

  const action = body.action as QueueAction | undefined;
  if (action !== "join" && action !== "leave") {
    return json({ error: "invalid_action" }, 400);
  }

  const userClient = supabaseForUser(token);
  if (action === "leave") {
    const { error } = await userClient.rpc("pvp_leave_queue");
    if (error) {
      console.error("pvp queue leave failed", error);
      return json({ error: "queue_unavailable" }, 503);
    }
    return json({ status: "cancelled" });
  }

  if (!Array.isArray(body.deckSnapshot) || body.deckSnapshot.length !== 40) {
    return json({ error: "deck_must_contain_40_cards" }, 400);
  }
  if (body.deckSnapshot.some((id) => typeof id !== "string" || !id.trim())) {
    return json({ error: "deck_contains_invalid_card_id" }, 400);
  }

  const { data, error } = await userClient.rpc("pvp_join_queue", {
    p_deck_snapshot: body.deckSnapshot,
  });
  if (error) {
    console.error("pvp queue join failed", error);
    return json({ error: "queue_unavailable" }, 503);
  }

  const result = data as { status?: string; matchId?: string | null } | null;
  if (result?.status !== "matched" || !result.matchId) {
    return json({ status: "queued", matchId: null });
  }

  const initializationFailure = await initializeMatch(result.matchId, admin);
  if (initializationFailure) return initializationFailure;
  return json({ status: "matched", matchId: result.matchId });
});
