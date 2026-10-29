import { db } from "../_shared/config.ts";
import { forbidden, isSuperUser, json, jsonError, requireCaller } from "../_shared/auth.ts";
import { pgCode, reconcileRoles } from "../_shared/roles.ts";

// ── Path parsing ──────────────────────────────────────────────────────────────

function parseId(pathname: string): string | null {
  const match = pathname.match(/^\/shop-owners\/([^/]+)$/);
  return match ? match[1] : null;
}

// ── Handler ───────────────────────────────────────────────────────────────────

Deno.serve(async (req: Request) => {
  const { caller, response } = await requireCaller(req);
  if (response) return response;

  const url = new URL(req.url);
  const id = parseId(url.pathname);

  // ── POST /shop-owners — super user only ────────────────────────────────────
  if (req.method === "POST" && !id) {
    if (!isSuperUser(caller)) return forbidden();
    const body = await req.json().catch(() => null);
    const { user_id, shop_id } = body ?? {};
    if (!user_id || !shop_id) return jsonError("user_id and shop_id are required", 400);

    try {
      const row = await db.transaction().execute(async (trx) => {
        const inserted = await trx
          .insertInto("shop_owner")
          .values({ user_id, shop_id })
          .returningAll()
          .executeTakeFirstOrThrow();
        await reconcileRoles(trx, [user_id]);
        return inserted;
      });
      return json(row, 201);
    } catch (err) {
      const code = pgCode(err);
      if (code === "23505") return jsonError("This user already owns this shop", 409);
      if (code === "23503") return jsonError("User or shop not found", 400);
      throw err;
    }
  }

  // ── GET /shop-owners — optional ?user_id= and/or ?shop_id= filters ─────────
  if (req.method === "GET" && !id) {
    const userId = url.searchParams.get("user_id");
    const shopId = url.searchParams.get("shop_id");
    let query = db.selectFrom("shop_owner").selectAll();
    if (userId) query = query.where("user_id", "=", userId);
    if (shopId) query = query.where("shop_id", "=", shopId);
    return json(await query.execute());
  }

  // ── GET /shop-owners/:id ───────────────────────────────────────────────────
  if (req.method === "GET" && id) {
    const row = await db
      .selectFrom("shop_owner")
      .selectAll()
      .where("id", "=", id)
      .executeTakeFirst();
    if (!row) return jsonError("Shop owner not found", 404);
    return json(row);
  }

  // ── DELETE /shop-owners/:id — super user only ──────────────────────────────
  if (req.method === "DELETE" && id) {
    if (!isSuperUser(caller)) return forbidden();
    const existing = await db
      .selectFrom("shop_owner")
      .select(["id", "user_id"])
      .where("id", "=", id)
      .executeTakeFirst();
    if (!existing) return jsonError("Shop owner not found", 404);

    await db.transaction().execute(async (trx) => {
      await trx.deleteFrom("shop_owner").where("id", "=", id).execute();
      await reconcileRoles(trx, [existing.user_id]);
    });
    return new Response(null, { status: 204 });
  }

  return jsonError("Not found", 404);
});
