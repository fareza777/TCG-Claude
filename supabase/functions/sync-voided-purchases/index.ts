// Marks purchases Google has voided, so a refund or chargeback stops counting
// as an entitlement.
//
// Meant to be called on a schedule with the service role key, not by the app.
// The client picks the change up on its next sync and takes the Gold back.
//
// The Google OAuth helper below is deliberately duplicated from
// verify-purchase rather than shared: each Edge Function is its own deployment
// unit, and coupling them would mean redeploying a verified payment path to
// change a reporting job.
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";
import { importPKCS8, SignJWT } from "npm:jose@5";

const ANDROID_PUBLISHER_SCOPE =
  "https://www.googleapis.com/auth/androidpublisher";
const TOKEN_ENDPOINT = "https://oauth2.googleapis.com/token";

/// Google keeps voided purchases queryable for 30 days, so a daily run has a
/// wide margin even if several are missed.
// Keep a small clock-skew margin: Google's endpoint rejects a start time that
// falls even slightly beyond its 30-day window.
const DEFAULT_LOOKBACK_DAYS = 28;

interface VoidedPurchase {
  purchaseToken?: string;
  orderId?: string;
  voidedTimeMillis?: string;
  voidedReason?: number;
}

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

async function googleAccessToken(): Promise<string> {
  const raw = Deno.env.get("GOOGLE_SERVICE_ACCOUNT_JSON");
  if (!raw) throw new Error("GOOGLE_SERVICE_ACCOUNT_JSON is not configured");

  const account = JSON.parse(raw) as {
    client_email: string;
    private_key: string;
  };
  const now = Math.floor(Date.now() / 1000);
  const assertion = await new SignJWT({ scope: ANDROID_PUBLISHER_SCOPE })
    .setProtectedHeader({ alg: "RS256" })
    .setIssuer(account.client_email)
    .setAudience(TOKEN_ENDPOINT)
    .setIssuedAt(now)
    .setExpirationTime(now + 3600)
    .sign(await importPKCS8(account.private_key.replace(/\\n/g, "\n"), "RS256"));

  const response = await fetch(TOKEN_ENDPOINT, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion,
    }),
  });
  if (!response.ok) {
    throw new Error(`Google token exchange failed (${response.status})`);
  }
  return ((await response.json()) as { access_token: string }).access_token;
}

/// Walks every page Google offers, so a busy window is not silently truncated.
async function fetchVoidedPurchases(startTimeMillis: number) {
  const packageName = Deno.env.get("ANDROID_PACKAGE_NAME");
  if (!packageName) throw new Error("ANDROID_PACKAGE_NAME is not configured");

  const accessToken = await googleAccessToken();
  const base =
    `https://androidpublisher.googleapis.com/androidpublisher/v3/applications/${
      encodeURIComponent(packageName)
    }/purchases/voidedpurchases`;

  const voided: VoidedPurchase[] = [];
  let pageToken: string | undefined;

  do {
    const params = new URLSearchParams({
      startTime: String(startTimeMillis),
      maxResults: "1000",
    });
    if (pageToken) params.set("token", pageToken);

    const response = await fetch(`${base}?${params}`, {
      headers: { Authorization: `Bearer ${accessToken}` },
    });
    if (!response.ok) {
      throw new Error(
        `voidedpurchases responded ${response.status}: ${await response.text()}`,
      );
    }

    const page = await response.json() as {
      voidedPurchases?: VoidedPurchase[];
      tokenPagination?: { nextPageToken?: string };
    };
    voided.push(...(page.voidedPurchases ?? []));
    pageToken = page.tokenPagination?.nextPageToken;
  } while (pageToken);

  return voided;
}

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);

  // This job is not for players. A signed-in user's JWT clears the gateway, so
  // the service role key is checked explicitly here.
  // Supabase's legacy default name is still supported, but keeping an
  // explicitly configured secret makes scheduled invocations deterministic
  // across projects that have moved to the newer secret-key names.
  const serviceKey =
    Deno.env.get("SHARDFALL_SERVICE_ROLE_KEY") ??
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ??
    "";
  if (!serviceKey) return json({ error: "server_key_not_configured" }, 500);
  const bearer = (req.headers.get("Authorization") ?? "").replace(
    /^Bearer\s+/i,
    "",
  );
  if (bearer !== serviceKey) return json({ error: "forbidden" }, 403);

  let lookbackDays = DEFAULT_LOOKBACK_DAYS;
  try {
    const body = await req.json() as { lookbackDays?: unknown };
    const requested = Number(body?.lookbackDays);
    if (Number.isFinite(requested) && requested > 0) lookbackDays = requested;
  } catch {
    // No body is the normal case for a scheduled run.
  }

  let voided: VoidedPurchase[];
  try {
    voided = await fetchVoidedPurchases(
      Date.now() - lookbackDays * 24 * 60 * 60 * 1000,
    );
  } catch (error) {
    console.error("voided purchase lookup failed", error);
    return json({ error: "lookup_unavailable" }, 503);
  }

  const tokens = voided
    .map((entry) => entry.purchaseToken?.trim())
    .filter((token): token is string => !!token);

  if (tokens.length === 0) return json({ checked: 0, refunded: 0 });

  const admin = createClient(
    Deno.env.get("SUPABASE_URL")!,
    serviceKey,
    { auth: { persistSession: false } },
  );

  // Scoped to 'granted' so a repeat run is a no-op rather than a rewrite.
  const { data, error } = await admin
    .from("purchases")
    .update({ state: "refunded" })
    .in("purchase_token", tokens)
    .eq("state", "granted")
    .select("purchase_token");

  if (error) {
    console.error("refund marking failed", error);
    return json({ error: "update_failed" }, 500);
  }

  return json({ checked: tokens.length, refunded: data?.length ?? 0 });
});
