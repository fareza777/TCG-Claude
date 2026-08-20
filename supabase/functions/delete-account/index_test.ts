import {
  assertEquals,
} from "jsr:@std/assert@1";
import {
  AccountDeletionAdmin,
  handleDeleteAccount,
} from "./index.ts";

function adminFor(
  userId: string | null,
  deleted: string[],
): AccountDeletionAdmin {
  return {
    auth: {
      getUser: async () => ({
        data: { user: userId == null ? null : { id: userId } },
        error: userId == null ? new Error("unauthorized") : null,
      }),
      admin: {
        deleteUser: async (id) => {
          deleted.push(id);
          return { error: null };
        },
      },
    },
  };
}

Deno.test("deletes only the user resolved from the bearer token", async () => {
  const deleted: string[] = [];
  const response = await handleDeleteAccount(
    new Request("https://example.test/delete-account", {
      method: "POST",
      headers: {
        Authorization: "Bearer valid-session",
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ confirm: true, userId: "someone-else" }),
    }),
    adminFor("verified-user", deleted),
  );

  assertEquals(response.status, 200);
  assertEquals(deleted, ["verified-user"]);
});

Deno.test("requires an authenticated user and explicit confirmation", async () => {
  const deleted: string[] = [];
  const missingConfirmation = await handleDeleteAccount(
    new Request("https://example.test/delete-account", {
      method: "POST",
      headers: {
        Authorization: "Bearer valid-session",
        "Content-Type": "application/json",
      },
      body: JSON.stringify({}),
    }),
    adminFor("verified-user", deleted),
  );
  const unauthorized = await handleDeleteAccount(
    new Request("https://example.test/delete-account", {
      method: "POST",
      headers: {
        Authorization: "Bearer invalid-session",
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ confirm: true }),
    }),
    adminFor(null, deleted),
  );

  assertEquals(missingConfirmation.status, 400);
  assertEquals(unauthorized.status, 401);
  assertEquals(deleted, []);
});
