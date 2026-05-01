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

// ── Helpers ───────────────────────────────────────────────────────────────────

async function getInternalUser(authId: string) {
  return db
    .selectFrom("users")
    .select(["id", "name", "last_name"])
    .where("auth_id", "=", authId)
    .executeTakeFirst();
}

async function getShopName(shopId: string): Promise<string> {
  const row = await db
    .selectFrom("business")
    .innerJoin("shop", "shop.id", "business.id")
    .select(["business.name"])
    .where("shop.id", "=", shopId)
    .executeTakeFirst();
  return row?.name ?? "the shop";
}

// ── Handler ───────────────────────────────────────────────────────────────────

Deno.serve(async (req: Request) => {
  const { user, error: authError } = await requireAuth(req);
  if (!user) return jsonError(authError ?? "Unauthorized", 401);

  const url = new URL(req.url);
  const id = parseId(url.pathname);

  // ── POST /shop-vendors ────────────────────────────────────────────────────────
  // For existing users: sends an invite notification (pending) instead of an
  // immediate insert. For new users (email invite path): inserts immediately
  // and sends the Supabase auth invite email to set up their account.
  if (req.method === "POST" && !id) {
    const body = await req.json().catch(() => null);
    const { user_id, shop_id, email, name, last_name, username } = body ?? {};

    if (!shop_id) return jsonError("shop_id is required", 400);

    // Resolve the calling user's internal ID (for self-add check + invite)
    const callerInternal = await getInternalUser(user.id);
    if (!callerInternal) return jsonError("Caller user not found", 404);

    let resolvedUserId: string = user_id;
    let isNewUser = false;

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
        isNewUser = true;
      }
    }

    // ── Self-add guard ────────────────────────────────────────────────────────
    if (resolvedUserId === callerInternal.id) {
      return jsonError("You cannot add yourself as a vendor", 400);
    }

    // ── Duplicate guard ───────────────────────────────────────────────────────
    const existingVendor = await db
      .selectFrom("shop_vendor")
      .select(["id"])
      .where("user_id", "=", resolvedUserId)
      .where("shop_id", "=", shop_id)
      .executeTakeFirst();
    if (existingVendor) {
      return jsonError("This user is already a vendor at this shop", 409);
    }

    // ── Existing user: send invite notification ───────────────────────────────
    if (!isNewUser) {
      const shopName = await getShopName(shop_id);
      await db
        .insertInto("notification")
        .values({
          user_id: resolvedUserId,
          type: "vendor_shop_invite",
          title: `You've been invited to join ${shopName}`,
          body: `You have a pending invitation to work at ${shopName} as a Vendor.`,
          metadata: JSON.stringify({
            invite_status: "pending",
            inviter_id: callerInternal.id,
            shop_id,
            shop_name: shopName,
          }),
        })
        .execute();
      return json({ invited: true, user_id: resolvedUserId }, 200);
    }

    // ── New user: insert immediately ──────────────────────────────────────────
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
