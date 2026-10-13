import { db } from "../_shared/config.ts";
import { canCoachAtGym, canManageGym, forbidden, json, jsonError, redactEmails, requireCaller } from "../_shared/auth.ts";
import { pgCode, assignRole, reconcileRoles } from "../_shared/roles.ts";

// ── Path parsing ──────────────────────────────────────────────────────────────

function parseId(pathname: string): string | null {
  const match = pathname.match(/^\/employee-trainers\/([^/]+)$/);
  return match ? match[1] : null;
}

// ── Columns returned alongside employee_trainer rows ─────────────────────────

const SELECT_COLS = [
  "employee_trainer.id",
  "employee_trainer.user_id",
  "employee_trainer.gym_id",
  "users.email",
  "users.name",
  "users.last_name",
  "users.username",
  "users.role",
  "users.avatar_url",
] as const;

// ── Handler ───────────────────────────────────────────────────────────────────

Deno.serve(async (req: Request) => {
  const { caller, response } = await requireCaller(req);
  if (response) return response;

  const url = new URL(req.url);
  const id = parseId(url.pathname);

  // ── POST /employee-trainers ───────────────────────────────────────────────────
  // Links (or creates) the user's trainer row at the gym, like the invite flow.
  if (req.method === "POST" && !id) {
    const body = await req.json().catch(() => null);
    const { user_id, gym_id } = body ?? {};
    if (!user_id || !gym_id) return jsonError("user_id and gym_id are required", 400);
    if (!(await canManageGym(caller, gym_id))) return forbidden();

    try {
      const row = await db.transaction().execute(async (trx) => {
        let trainerRow = await trx
          .selectFrom("trainer")
          .select(["id"])
          .where("user_id", "=", user_id)
          .where("gym_id", "=", gym_id)
          .executeTakeFirst();
        if (!trainerRow) {
          trainerRow = await trx
            .insertInto("trainer")
            .values({ user_id, gym_id })
            .returning(["id"])
            .executeTakeFirstOrThrow();
        }
        const inserted = await trx
          .insertInto("employee_trainer")
          .values({ user_id, gym_id, trainer_id: trainerRow.id })
          .returningAll()
          .executeTakeFirstOrThrow();
        await assignRole(trx, user_id, "employee_trainer");
        return inserted;
      });
      return json(row, 201);
    } catch (err) {
      const code = pgCode(err);
      if (code === "23505") return jsonError("This user is already an employee trainer at this gym", 409);
      if (code === "23503") return jsonError("User or gym not found", 400);
      throw err;
    }
  }

  // ── GET /employee-trainers — optional ?user_id= and/or ?gym_id= filters ──────
  // Returns rows with user info embedded; email only for the person themself
  // and people who coach/staff at that gym.
  if (req.method === "GET" && !id) {
    const userId = url.searchParams.get("user_id");
    const gymId = url.searchParams.get("gym_id");
    let query = db
      .selectFrom("employee_trainer")
      .innerJoin("users", "users.id", "employee_trainer.user_id")
      .select(SELECT_COLS);
    if (userId) query = query.where("employee_trainer.user_id", "=", userId);
    if (gymId) query = query.where("employee_trainer.gym_id", "=", gymId);
    return json(await redactEmails(caller, await query.execute(), (r) => r.gym_id, canCoachAtGym));
  }

  // ── GET /employee-trainers/:id ────────────────────────────────────────────────
  if (req.method === "GET" && id) {
    const row = await db
      .selectFrom("employee_trainer")
      .innerJoin("users", "users.id", "employee_trainer.user_id")
      .select(SELECT_COLS)
      .where("employee_trainer.id", "=", id)
      .executeTakeFirst();
    if (!row) return jsonError("Employee-trainer not found", 404);
    return json((await redactEmails(caller, [row], (r) => r.gym_id, canCoachAtGym))[0]);
  }

  // ── DELETE /employee-trainers/:id ─────────────────────────────────────────────
  // Also removes the linked trainer row so the person loses coaching access.
  if (req.method === "DELETE" && id) {
    const existing = await db
      .selectFrom("employee_trainer")
      .select(["id", "user_id", "gym_id", "trainer_id"])
      .where("id", "=", id)
      .executeTakeFirst();
    if (!existing) return jsonError("Employee-trainer not found", 404);
    if (!(await canManageGym(caller, existing.gym_id))) return forbidden();

    await db.transaction().execute(async (trx) => {
      await trx.deleteFrom("employee_trainer").where("id", "=", id).execute();
      if (existing.trainer_id) {
        await trx.deleteFrom("trainer").where("id", "=", existing.trainer_id).execute();
      }
      await reconcileRoles(trx, [existing.user_id]);
    });
    return new Response(null, { status: 204 });
  }

  return jsonError("Not found", 404);
});
