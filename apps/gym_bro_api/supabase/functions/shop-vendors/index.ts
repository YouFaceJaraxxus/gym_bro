import { db, supabaseAdmin } from "../_shared/config.ts";
import type { UserInsert } from "../../types/schema/public.ts";

// ── Auth ──────────────────────────────────────────────────────────────────────

async function requireAuth(req: Request) {
  const token = req.headers.get("Authorization")?.replace(/^Bearer\s+/i, "");
  if (!token) return { user: null, error: "Missing Authorization header" };
  const { data: { user }, error } = await supabaseAdmin.auth.getUser(token);
  return { user: error ? null : user, error: error?.message ?? null };
}

// ── Path parsing ──────────────────────────────────────────────────────────────

function parseId(pathname: string): string | null {
  const match = pathname.match(/^\/shop-vendors\/([^/]+)$/);
  return match ? match[1] : null;
}

// ── Columns returned alongside vendor rows ────────────────────────────────────

const SELECT_COLS = [
  "shop_vendor.id",
  "shop_vendor.user_id",
  "shop_vendor.shop_id",
  "users.email",
  "users.name",
  "users.last_name",
  "users.username",
  "users.role",
] as const;

// ── Handler ───────────────────────────────────────────────────────────────────

Deno.serve(async (req: Request) => {
  const { user, error: authError } = await requireAuth(req);
  if (!user) return jsonError(authError ?? "Unauthorized", 401);

  const url = new URL(req.url);
  const id = parseId(url.pathname);

  // ── POST /shop-vendors ────────────────────────────────────────────────────────
  // Accepts either user_id (existing user) or email + name + last_name + username
  // (new user to be created via invite email).
  if (req.method === "POST" && !id) {
    const body = await req.json().catch(() => null);
    const { user_id, shop_id, email, name, last_name, username } = body ?? {};

    if (!shop_id) return jsonError("shop_id is required", 400);

    let resolvedUserId: string = user_id;

    if (!resolvedUserId) {
      if (!email) return jsonError("Either user_id or email is required", 400);

      const existing = await db
        .selectFrom("users")
        .select(["id"])
        .where("email", "=", email)
        .executeTakeFirst();

      if (existing) {
        resolvedUserId = existing.id;
      } else {
        if (!name || !last_name || !username) {
          return jsonError(
            "name, last_name, and username are required when the email does not match an existing user",
            400,
          );
        }

        const redirectTo =
          Deno.env.get("APP_INVITE_REDIRECT_URL") ?? "gymbroo://auth/callback";

        const { data, error: inviteErr } = await supabaseAdmin.auth.admin.inviteUserByEmail(
          email,
          { redirectTo, data: { username, name, last_name } },
        );
        if (inviteErr) return jsonError(inviteErr.message, 400);

        const insert: UserInsert = {
          email,
          name,
          last_name,
          username,
          auth_id: data.user.id,
        };
        const newUser = await db
          .insertInto("users")
          .values(insert)
          .returning(["id"])
          .executeTakeFirstOrThrow();

        resolvedUserId = newUser.id;
      }
    }

    const row = await db
      .insertInto("shop_vendor")
      .values({ user_id: resolvedUserId, shop_id })
      .returningAll()
      .executeTakeFirstOrThrow();

    await db
      .updateTable("users")
      .set({ role: "shop_vendor" })
      .where("id", "=", resolvedUserId)
      .execute();

    return json(row, 201);
  }

  // ── GET /shop-vendors — optional ?user_id= and/or ?shop_id= filters ──────────
  if (req.method === "GET" && !id) {
    const userId = url.searchParams.get("user_id");
    const shopId = url.searchParams.get("shop_id");
    let query = db
      .selectFrom("shop_vendor")
      .innerJoin("users", "users.id", "shop_vendor.user_id")
      .select(SELECT_COLS);
    if (userId) query = query.where("shop_vendor.user_id", "=", userId);
    if (shopId) query = query.where("shop_vendor.shop_id", "=", shopId);
    return json(await query.execute());
  }

  // ── GET /shop-vendors/:id ─────────────────────────────────────────────────────
  if (req.method === "GET" && id) {
    const row = await db
      .selectFrom("shop_vendor")
      .innerJoin("users", "users.id", "shop_vendor.user_id")
      .select(SELECT_COLS)
      .where("shop_vendor.id", "=", id)
      .executeTakeFirst();
    if (!row) return jsonError("Vendor not found", 404);
    return json(row);
  }

  // ── DELETE /shop-vendors/:id ──────────────────────────────────────────────────
  if (req.method === "DELETE" && id) {
    const result = await db
      .deleteFrom("shop_vendor")
      .where("id", "=", id)
      .executeTakeFirst();
    if (!result.numDeletedRows) return jsonError("Vendor not found", 404);
    return new Response(null, { status: 204 });
  }

  return jsonError("Not found", 404);
});

function json(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

function jsonError(message: string, status: number): Response {
  return json({ error: message }, status);
}
