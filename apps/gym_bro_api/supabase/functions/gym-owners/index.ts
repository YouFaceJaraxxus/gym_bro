import { db } from "../_shared/config.ts";
import { forbidden, isSuperUser, json, jsonError, requireCaller } from "../_shared/auth.ts";
import { pgCode, reconcileRoles } from "../_shared/roles.ts";

// ── Path parsing ──────────────────────────────────────────────────────────────

function parseId(pathname: string): string | null {
  const match = pathname.match(/^\/gym-owners\/([^/]+)$/);
  return match ? match[1] : null;
}

// ── Columns returned alongside gym_owner rows (user display fields) ──────────

const SELECT_COLS = [
  "gym_owner.id",
  "gym_owner.user_id",
  "gym_owner.gym_id",
  "users.name",
  "users.last_name",
  "users.username",
  "users.avatar_url",
] as const;

// ── Handler ───────────────────────────────────────────────────────────────────

Deno.serve(async (req: Request) => {
  const { caller, response } = await requireCaller(req);
  if (response) return response;

  const url = new URL(req.url);
  const id = parseId(url.pathname);

  // ── POST /gym-owners — super user only ─────────────────────────────────────
  if (req.method === "POST" && !id) {
    if (!isSuperUser(caller)) return forbidden();
    const body = await req.json().catch(() => null);
    const { user_id, gym_id } = body ?? {};
    if (!user_id || !gym_id) return jsonError("user_id and gym_id are required", 400);

    try {
      const row = await db.transaction().execute(async (trx) => {
        const inserted = await trx
          .insertInto("gym_owner")
          .values({ user_id, gym_id })
          .returningAll()
          .executeTakeFirstOrThrow();
        await reconcileRoles(trx, [user_id]);
        return inserted;
      });
      return json(row, 201);
    } catch (err) {
      const code = pgCode(err);
      if (code === "23505") return jsonError("This user already owns this gym", 409);
      if (code === "23503") return jsonError("User or gym not found", 400);
      throw err;
    }
  }

  // ── GET /gym-owners — optional ?user_id= and/or ?gym_id= filters ───────────
  if (req.method === "GET" && !id) {
    const userId = url.searchParams.get("user_id");
    const gymId = url.searchParams.get("gym_id");
    let query = db
      .selectFrom("gym_owner")
      .innerJoin("users", "users.id", "gym_owner.user_id")
      .select(SELECT_COLS);
    if (userId) query = query.where("gym_owner.user_id", "=", userId);
    if (gymId) query = query.where("gym_owner.gym_id", "=", gymId);
    return json(await query.execute());
  }

  // ── GET /gym-owners/:id ────────────────────────────────────────────────────
  if (req.method === "GET" && id) {
    const row = await db
      .selectFrom("gym_owner")
      .innerJoin("users", "users.id", "gym_owner.user_id")
      .select(SELECT_COLS)
      .where("gym_owner.id", "=", id)
      .executeTakeFirst();
    if (!row) return jsonError("Gym owner not found", 404);
    return json(row);
  }

  // ── DELETE /gym-owners/:id — super user only ───────────────────────────────
  if (req.method === "DELETE" && id) {
    if (!isSuperUser(caller)) return forbidden();
    const existing = await db
      .selectFrom("gym_owner")
      .select(["id", "user_id"])
      .where("id", "=", id)
      .executeTakeFirst();
    if (!existing) return jsonError("Gym owner not found", 404);

    await db.transaction().execute(async (trx) => {
      await trx.deleteFrom("gym_owner").where("id", "=", id).execute();
      await reconcileRoles(trx, [existing.user_id]);
    });
    return new Response(null, { status: 204 });
  }

  return jsonError("Not found", 404);
});
