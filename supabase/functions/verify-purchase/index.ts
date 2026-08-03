// Verifies a Google Play purchase receipt and records it as the player's
// server-side entitlement.
//
// The client already grants Gold locally the moment Play reports a purchase —
// a paying player must never be blocked by a backend outage. This function is
// what makes that grant durable: the row it writes is what survives reinstall,
// and what a refund is clawed back from.
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";
import { importPKCS8, SignJWT } from "npm:jose@5";

/// Keep in sync with app/lib/services/purchase_catalog.dart.
const GOLD_PRODUCTS: Record<string, number> = {
  gold_500: 500,
};

const ANDROID_PUBLISHER_SCOPE =
  "https://www.googleapis.com/auth/androidpublisher";
const TOKEN_ENDPOINT = "https://oauth2.googleapis.com/token";

/// Google's purchaseState for a completed payment. 1 is canceled, 2 is pending.
const PURCHASE_STATE_PURCHASED = 0;

interface ServiceAccount {
  client_email: string;
  private_key: string;
}

interface PlayReceipt {
  purchaseState?: number;
  orderId?: string;
  consumptionState?: number;
  acknowledgementState?: number;
}

/// Access tokens live an hour; reuse one while the isolate stays warm.
let cachedToken: { value: string; expiresAt: number } | null = null;

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

function readServiceAccount(): ServiceAccount {
  const raw = Deno.env.get("GOOGLE_SERVICE_ACCOUNT_JSON");
  if (!raw) throw new Error("GOOGLE_SERVICE_ACCOUNT_JSON is not configured");

  const parsed = JSON.parse(raw) as ServiceAccount;
  if (!parsed.client_email || !parsed.private_key) {
    throw new Error(
      "GOOGLE_SERVICE_ACCOUNT_JSON lacks client_email or private_key",
    );
  }
  return parsed;
}

async function googleAccessToken(): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  if (cachedToken && cachedToken.expiresAt > now + 60) return cachedToken.value;

  const account = readServiceAccount();
  // A key pasted into the dashboard keeps its newlines escaped.
  const pem = account.private_key.replace(/\\n/g, "\n");
  const assertion = await new SignJWT({ scope: ANDROID_PUBLISHER_SCOPE })
    .setProtectedHeader({ alg: "RS256" })
    .setIssuer(account.client_email)
    .setAudience(TOKEN_ENDPOINT)
    .setIssuedAt(now)
    .setExpirationTime(now + 3600)
    .sign(await importPKCS8(pem, "RS256"));

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

  const payload = await response.json() as {
    access_token: string;
    expires_in: number;
  };
  cachedToken = {
    value: payload.access_token,
    expiresAt: now + payload.expires_in,
  };
  return payload.access_token;
}

async function fetchReceipt(
  productId: string,
  purchaseToken: string,
): Promise<PlayReceipt> {
  const packageName = Deno.env.get("ANDROID_PACKAGE_NAME");
  if (!packageName) throw new Error("ANDROID_PACKAGE_NAME is not configured");

  const url =
    `https://androidpublisher.googleapis.com/androidpublisher/v3/applications/${
      encodeURIComponent(packageName)
    }/purchases/products/${encodeURIComponent(productId)}/tokens/${
      encodeURIComponent(purchaseToken)
    }`;

  const response = await fetch(url, {
    headers: { Authorization: `Bearer ${await googleAccessToken()}` },
  });
  if (!response.ok) {
    // A rejected credential should not be reused on the next attempt.
    if (response.status === 401 || response.status === 403) cachedToken = null;
    throw new Error(
      `androidpublisher responded ${response.status}: ${await response.text()}`,
    );
  }
  return await response.json() as PlayReceipt;
}

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);

  const admin = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    { auth: { persistSession: false } },
  );

  const bearer = (req.headers.get("Authorization") ?? "").replace(
    /^Bearer\s+/i,
    "",
  );
  const { data: userData, error: userError } = await admin.auth.getUser(bearer);
  const user = userData?.user;
  if (userError || !user) return json({ error: "unauthorized" }, 401);

  let body: { productId?: unknown; purchaseToken?: unknown };
  try {
    body = await req.json();
  } catch {
    return json({ error: "invalid_body" }, 400);
  }

  const productId = String(body.productId ?? "");
  const purchaseToken = String(body.purchaseToken ?? "").trim();
  const goldAmount = GOLD_PRODUCTS[productId];

  if (goldAmount === undefined) return json({ error: "unknown_product" }, 400);
  if (!purchaseToken) return json({ error: "missing_purchase_token" }, 400);

  // Settle a token we have already seen before spending a Google API call.
  const { data: existing } = await admin
    .from("purchases")
    .select("user_id, gold_amount, state")
    .eq("purchase_token", purchaseToken)
    .maybeSingle();

  if (existing) {
    if (existing.user_id !== user.id) {
      return json({ error: "token_belongs_to_another_account" }, 409);
    }
    return json({
      granted: false,
      alreadyRecorded: true,
      goldAmount: existing.gold_amount,
      state: existing.state,
    });
  }

  let receipt: PlayReceipt;
  try {
    receipt = await fetchReceipt(productId, purchaseToken);
  } catch (error) {
    console.error("play verification failed", error);
    return json({ error: "verification_unavailable" }, 503);
  }

  if (receipt.purchaseState !== PURCHASE_STATE_PURCHASED) {
    return json({
      error: "purchase_not_completed",
      purchaseState: receipt.purchaseState ?? null,
    }, 402);
  }

  const { error: insertError } = await admin.from("purchases").insert({
    user_id: user.id,
    product_id: productId,
    purchase_token: purchaseToken,
    order_id: receipt.orderId ?? null,
    gold_amount: goldAmount,
    raw_receipt: receipt,
  });

  if (insertError) {
    // 23505: a concurrent call for the same token won the race.
    if (insertError.code === "23505") {
      return json({ granted: false, alreadyRecorded: true, goldAmount });
    }
    console.error("purchase insert failed", insertError);
    return json({ error: "record_failed" }, 500);
  }

  return json({ granted: true, goldAmount });
});
