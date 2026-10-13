import { db, supabaseAdmin } from "../_shared/config.ts";
import { canManageShop, forbidden, json, jsonError, requireCaller } from "../_shared/auth.ts";
import type { UserInsert } from "../../types/schema/public.ts";
import { pgCode, reconcileRoles } from "../_shared/roles.ts";

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

async function getShopName(shopId: string): Promise<string | null> {
  const row = await db
    .selectFrom("business")
    .innerJoin("shop", "shop.id", "business.id")
    .select(["business.name"])
    .where("shop.id", "=", shopId)
    .executeTakeFirst();
  return row?.name ?? null;
}

// ── Handler ───────────────────────────────────────────────────────────────────

Deno.serve(async (req: Request) => {
  const { caller, response } = await requireCaller(req);
  if (response) return response;

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

    const shopName = await getShopName(shop_id);
    if (!shopName) return jsonError("Shop not found", 404);
    if (!(await canManageShop(caller, shop_id))) return forbidden();

    let existingUserId: string | null = user_id ?? null;
    if (!existingUserId) {
      if (!email) return jsonError("Either user_id or email is required", 400);
      const existing = await db
        .selectFrom("users")
        .select(["id"])
        .where("email", "=", email)
        .executeTakeFirst();
      existingUserId = existing?.id ?? null;
    }

    // ── Existing user: guards, then a pending invite notification ─────────────
    if (existingUserId) {
      if (existingUserId === caller.id) {
        return jsonError("You cannot add yourself as a vendor", 400);
      }

      const target = await db.selectFrom("users").select("id").where("id", "=", existingUserId)
        .executeTakeFirst();
      if (!target) return jsonError("User not found", 404);

      const existingVendor = await db
        .selectFrom("shop_vendor")
        .select(["id"])
        .where("user_id", "=", existingUserId)
        .where("shop_id", "=", shop_id)
        .executeTakeFirst();
      if (existingVendor) {
        return jsonError("This user is already a vendor at this shop", 409);
      }

      await db
        .insertInto("notification")
        .values({
          user_id: existingUserId,
          type: "vendor_shop_invite",
          title: `You've been invited to join ${shopName}`,
          body: `You have a pending invitation to work at ${shopName} as a Vendor.`,
          metadata: {
            invite_status: "pending",
            inviter_id: caller.id,
            shop_id,
            shop_name: shopName,
          },
        })
        .execute();
      return json({ invited: true, user_id: existingUserId }, 200);
    }

    // ── Brand-new user: auth invite email, then user + vendor rows atomically ─
    if (!name || !last_name || !username) {
      return jsonError(
        "name, last_name, and username are required when the email does not match an existing user",
        400,
      );
    }
    const usernameTaken = await db.selectFrom("users").select("id").where("username", "=", username)
      .executeTakeFirst();
    if (usernameTaken) return jsonError("Username is already taken", 409);

    const redirectTo = Deno.env.get("APP_INVITE_REDIRECT_URL") ?? "gymbroo://auth/callback";
    const { data, error: inviteErr } = await supabaseAdmin.auth.admin.inviteUserByEmail(
      email,
      { redirectTo, data: { username, name, last_name } },
    );
    if (inviteErr) return jsonError(inviteErr.message, 400);

    try {
      const row = await db.transaction().execute(async (trx) => {
        const insert: UserInsert = {
          email,
          name,
          last_name,
          username,
          auth_id: data.user.id,
          role: "shop_vendor",
        };
        const newUser = await trx
          .insertInto("users")
          .values(insert)
          .returning(["id"])
          .executeTakeFirstOrThrow();
        return trx
          .insertInto("shop_vendor")
          .values({ user_id: newUser.id, shop_id })
          .returningAll()
          .executeTakeFirstOrThrow();
      });
      return json(row, 201);
    } catch (err) {
      // Don't leave an orphaned auth account behind.
      await supabaseAdmin.auth.admin.deleteUser(data.user.id).catch(() => {});
      if (pgCode(err) === "23505") return jsonError("A user with this email or username already exists", 409);
      throw err;
    }
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
    const existing = await db
      .selectFrom("shop_vendor")
      .select(["id", "user_id", "shop_id"])
      .where("id", "=", id)
      .executeTakeFirst();
    if (!existing) return jsonError("Vendor not found", 404);
    if (!(await canManageShop(caller, existing.shop_id))) return forbidden();

    await db.transaction().execute(async (trx) => {
      await trx.deleteFrom("shop_vendor").where("id", "=", id).execute();
      await reconcileRoles(trx, [existing.user_id]);
    });
    return new Response(null, { status: 204 });
  }

  return jsonError("Not found", 404);
});
