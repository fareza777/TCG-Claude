import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

type AuthUser = { id: string };

export interface AccountDeletionAdmin {
  auth: {
    getUser(token: string): Promise<{
      data: { user: AuthUser | null };
      error: unknown;
    }>;
    admin: {
      deleteUser(
        userId: string,
        shouldSoftDelete?: boolean,
      ): Promise<{ error: unknown }>;
    };
  };
}

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

export async function handleDeleteAccount(
  req: Request,
  admin: AccountDeletionAdmin,
): Promise<Response> {
  if (req.method !== "POST") {
    return json({ error: "method_not_allowed" }, 405);
  }

  const bearer = (req.headers.get("Authorization") ?? "").replace(
    /^Bearer\s+/i,
    "",
  );
  if (!bearer) return json({ error: "unauthorized" }, 401);

  let body: { confirm?: unknown };
  try {
    body = await req.json();
  } catch {
    return json({ error: "invalid_body" }, 400);
  }
  if (body.confirm !== true) {
    return json({ error: "confirmation_required" }, 400);
  }

  const { data, error: userError } = await admin.auth.getUser(bearer);
  if (userError || !data.user) return json({ error: "unauthorized" }, 401);

  // Never accept a user ID from the client. The verified access token is the
  // sole source of identity, so callers can delete only their own account.
  const { error: deleteError } = await admin.auth.admin.deleteUser(
    data.user.id,
    false,
  );
  if (deleteError) {
    console.error("account deletion failed", deleteError);
    return json({ error: "deletion_failed" }, 500);
  }

  return json({ deleted: true });
}

if (import.meta.main) {
  const admin = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    { auth: { persistSession: false } },
  ) as unknown as AccountDeletionAdmin;

  Deno.serve((req: Request) => handleDeleteAccount(req, admin));
}
