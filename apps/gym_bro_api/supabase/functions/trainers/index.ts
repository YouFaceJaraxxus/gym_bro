import { db } from "../_shared/config.ts";
import { canManageGym, forbidden, json, jsonError, requireCaller } from "../_shared/auth.ts";
import { pgCode, reconcileRoles } from "../_shared/roles.ts";

// ── Path parsing ──────────────────────────────────────────────────────────────

function parseId(pathname: string): string | null {
  const match = pathname.match(/^\/trainers\/([^/]+)$/);
  return match ? match[1] : null;
}

// ── Columns returned alongside trainer rows (user display fields) ──────────

const SELECT_COLS = [
  "trainer.id",
  "trainer.user_id",
  "trainer.gym_id",
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

  // ── POST /trainers ────────────────────────────────────────────────────────────
  if (req.method === "POST" && !id) {
    const body = await req.json().catch(() => null);
    const { user_id, gym_id } = body ?? {};
    if (!user_id || !gym_id) return jsonError("user_id and gym_id are required", 400);
    if (!(await canManageGym(caller, gym_id))) return forbidden();

    try {
      const row = await db.transaction().execute(async (trx) => {
        const inserted = await trx
          .insertInto("trainer")
          .values({ user_id, gym_id })
          .returningAll()
          .executeTakeFirstOrThrow();
        await reconcileRoles(trx, [user_id]);
        return inserted;
      });
      return json(row, 201);
    } catch (err) {
      const code = pgCode(err);
      if (code === "23505") return jsonError("This user is already a trainer at this gym", 409);
      if (code === "23503") return jsonError("User or gym not found", 400);
      throw err;
    }
  }

  // ── GET /trainers — optional ?user_id= and/or ?gym_id= filters ───────────────
  if (req.method === "GET" && !id) {
    const userId = url.searchParams.get("user_id");
    const gymId = url.searchParams.get("gym_id");
    let query = db
      .selectFrom("trainer")
      .innerJoin("users", "users.id", "trainer.user_id")
      .select(SELECT_COLS);
    if (userId) query = query.where("trainer.user_id", "=", userId);
    if (gymId) query = query.where("trainer.gym_id", "=", gymId);
    return json(await query.execute());
  }

  // ── GET /trainers/:id ─────────────────────────────────────────────────────────
  if (req.method === "GET" && id) {
    const row = await db
      .selectFrom("trainer")
      .innerJoin("users", "users.id", "trainer.user_id")
      .select(SELECT_COLS)
      .where("trainer.id", "=", id)
      .executeTakeFirst();
    if (!row) return jsonError("Trainer not found", 404);
    return json(row);
  }

  // ── DELETE /trainers/:id ──────────────────────────────────────────────────────
  if (req.method === "DELETE" && id) {
    const existing = await db
      .selectFrom("trainer")
      .select(["id", "user_id", "gym_id"])
      .where("id", "=", id)
      .executeTakeFirst();
    if (!existing) return jsonError("Trainer not found", 404);
    if (!(await canManageGym(caller, existing.gym_id))) return forbidden();

    await db.transaction().execute(async (trx) => {
      await trx.deleteFrom("trainer").where("id", "=", id).execute();
      await reconcileRoles(trx, [existing.user_id]);
    });
    return new Response(null, { status: 204 });
  }

  return jsonError("Not found", 404);
});
