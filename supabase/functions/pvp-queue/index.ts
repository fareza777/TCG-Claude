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

/// Releases a match that could not be started.
///
/// pvp_join_queue creates the match row before the engine exists, and it
/// refuses to queue anyone holding a 'starting' match. Without this, a single
/// failed initialization locks both players out of PvP permanently. The
/// pvp-reap-stale-matches cron is the backstop for when this never runs.
async function abandonMatch(
  matchId: string,
  admin: SupabaseClient,
  reason: string,
): Promise<void> {
  const { error } = await admin.rpc("pvp_abandon_match", {
    p_match_id: matchId,
    p_reason: reason,
  });
  if (error) {
    // The reaper will still pick it up within a few minutes.
    console.error("pvp match abandon failed", matchId, error);
  }
}

async function initializeMatch(
  matchId: string,
  admin: SupabaseClient,
): Promise<Response | null> {
  const serverUrl = Deno.env.get("PVP_SERVER_URL");
  const secret = Deno.env.get("PVP_INTERNAL_AUTH_SECRET");
  if (!serverUrl || !secret) {
    await abandonMatch(matchId, admin, "pvp_server_not_configured");
    return json({ error: "pvp_server_not_configured", matchId }, 503);
  }
  const { data: rows, error: playersError } = await admin
    .from("pvp_match_players")
    .select("user_id,seat,deck_snapshot")
    .eq("match_id", matchId);
  if (playersError || !rows || rows.length !== 2) {
    console.error("pvp match player snapshot lookup failed", playersError);
    await abandonMatch(matchId, admin, "player_snapshot_missing");
    return json({ error: "match_initialization_unavailable", matchId }, 503);
  }

  // The service speaks camelCase; these are raw Postgres column names. Passing
  // the rows through unmapped made every initialization fail with 400.
  const players = rows.map((row) => ({
    userId: row.user_id,
    seat: row.seat,
    deckSnapshot: row.deck_snapshot,
  }));

  let response: Response;
  try {
    response = await fetch(
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
  } catch (error) {
    // Unreachable or sleeping service: the common case, and the one that used
    // to strand players.
    console.error("pvp server unreachable", error);
    await abandonMatch(matchId, admin, "pvp_server_unreachable");
    return json({ error: "match_initialization_unavailable", matchId }, 503);
  }

  if (!response.ok) {
    console.error("pvp match initialization failed", response.status);
    await abandonMatch(matchId, admin, "initialization_rejected");
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

  // Wake the match service while the queue runs. It scales to zero, and a
  // sleeping instance takes 1-2 seconds to start -- that pause used to land
  // on match initialization, the first thing both players wait on. A health
  // ping costs milliseconds and, with request-based billing, an idle warm
  // instance is free, so this replaces paying for a minimum instance.
  const warmupUrl = Deno.env.get("PVP_SERVER_URL");
  if (warmupUrl) {
    EdgeRuntime.waitUntil(
      fetch(`${warmupUrl.replace(/\/$/, "")}/health`).catch(() => {}),
    );
  }

  const { data, error } = await userClient.rpc("pvp_join_queue", {
    p_deck_snapshot: body.deckSnapshot,
  });
  if (error) {
    console.error("pvp queue join failed", error);
    // The RPC rejects illegal decks and double-queueing. Those are the
    // player's problem to fix, not a backend outage, so say which it is.
    const message = error.message ?? "";
    if (message.includes("deck is not legal")) {
      return json({ error: "deck_not_legal", detail: message }, 400);
    }
    if (message.includes("deck must contain")) {
      return json({ error: "deck_must_contain_40_cards" }, 400);
    }
    if (message.includes("already has an active match")) {
      return json({ error: "already_in_match" }, 409);
    }
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
