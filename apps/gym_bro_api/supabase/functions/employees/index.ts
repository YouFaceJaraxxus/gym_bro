import type { Kysely } from "npm:kysely@^0.27";
import { db, supabaseAdmin } from "../_shared/config.ts";
import { canCoachAtGym, canManageGym, forbidden, json, jsonError, redactEmails, requireCaller } from "../_shared/auth.ts";
import type { Database, UserInsert } from "../../types/schema/public.ts";
import { pgCode, assignRole, reconcileRoles } from "../_shared/roles.ts";

// ── Path parsing ──────────────────────────────────────────────────────────────

function parseId(pathname: string): string | null {
  const match = pathname.match(/^\/employees\/([^/]+)$/);
  return match ? match[1] : null;
}

// ── Columns returned alongside employee rows ──────────────────────────────────

const SELECT_COLS = [
  "employee.id",
  "employee.user_id",
  "employee.gym_id",
  "users.email",
  "users.name",
  "users.last_name",
  "users.username",
  "users.role",
  "users.avatar_url",
] as const;

type EmployeeType = "employee" | "employee_trainer";

// ── Helpers ───────────────────────────────────────────────────────────────────

async function getGymName(gymId: string): Promise<string | null> {
  const row = await db
    .selectFrom("business")
    .innerJoin("gym", "gym.id", "business.id")
    .select(["business.name"])
    .where("gym.id", "=", gymId)
    .executeTakeFirst();
  return row?.name ?? null;
}

/** Inserts the employee or employee_trainer row (creating the trainer row for the latter). */
async function insertStaffRow(
  trx: Kysely<Database>,
  userId: string,
  gymId: string,
  employeeType: EmployeeType,
) {
  if (employeeType === "employee") {
    const row = await trx
      .insertInto("employee")
      .values({ user_id: userId, gym_id: gymId })
      .returningAll()
      .executeTakeFirstOrThrow();
    await assignRole(trx, userId, "employee");
    return row;
  }

  let trainerRow = await trx
    .selectFrom("trainer")
    .select(["id"])
    .where("user_id", "=", userId)
    .where("gym_id", "=", gymId)
    .executeTakeFirst();
  if (!trainerRow) {
    trainerRow = await trx
      .insertInto("trainer")
      .values({ user_id: userId, gym_id: gymId })
      .returning(["id"])
      .executeTakeFirstOrThrow();
  }
  const row = await trx
    .insertInto("employee_trainer")
    .values({ user_id: userId, gym_id: gymId, trainer_id: trainerRow.id })
    .returningAll()
    .executeTakeFirstOrThrow();
  await assignRole(trx, userId, "employee_trainer");
  return row;
}

/** The staff row in the same shape as GET /employees rows, plus employee_type. */
async function staffRowWithUser(q: Kysely<Database>, userId: string, gymId: string, employeeType: EmployeeType) {
  const table = employeeType;
  const row = await q
    .selectFrom(table)
    .innerJoin("users", "users.id", `${table}.user_id`)
    .select([
      `${table}.id`,
      `${table}.user_id`,
      `${table}.gym_id`,
      "users.email",
      "users.name",
      "users.last_name",
      "users.username",
      "users.role",
      "users.avatar_url",
    ])
    .where(`${table}.user_id`, "=", userId)
    .where(`${table}.gym_id`, "=", gymId)
    .executeTakeFirstOrThrow();
  return { ...row, employee_type: employeeType };
}

// ── Handler ───────────────────────────────────────────────────────────────────

Deno.serve(async (req: Request) => {
  const { caller, response } = await requireCaller(req);
  if (response) return response;

  const url = new URL(req.url);

  // ── PUT /employees/role — matched before /:id ─────────────────────────────────
  // Moves a staff member between the employee and employee_trainer tables.
  if (req.method === "PUT" && url.pathname === "/employees/role") {
    const body = await req.json().catch(() => null);
    const { user_id, gym_id, employee_type } = body ?? {};
    if (!user_id || !gym_id) return jsonError("user_id and gym_id are required", 400);
    if (employee_type !== "employee" && employee_type !== "employee_trainer") {
      return jsonError("employee_type must be 'employee' or 'employee_trainer'", 400);
    }
    if (!(await canManageGym(caller, gym_id))) return forbidden();

    const result = await db.transaction().execute(async (trx) => {
      const [emp, et] = await Promise.all([
        trx.selectFrom("employee").select("id").where("user_id", "=", user_id).where("gym_id", "=", gym_id)
          .executeTakeFirst(),
        trx.selectFrom("employee_trainer").select("id").where("user_id", "=", user_id)
          .where("gym_id", "=", gym_id).executeTakeFirst(),
      ]);
      if (!emp && !et) return null;

      if (employee_type === "employee_trainer" && !et) {
        await trx.deleteFrom("employee").where("id", "=", emp!.id).execute();
        await insertStaffRow(trx, user_id, gym_id, "employee_trainer");
      } else if (employee_type === "employee" && !emp) {
        // The trainer row is left in place.
        await trx.deleteFrom("employee_trainer").where("id", "=", et!.id).execute();
        await insertStaffRow(trx, user_id, gym_id, "employee");
      }
      // Already in the target table → idempotent no-op.
      return staffRowWithUser(trx, user_id, gym_id, employee_type);
    });

    if (!result) return jsonError("This user is not an employee at this gym", 404);
    return json(result);
  }

  const id = parseId(url.pathname);

  // ── POST /employees ───────────────────────────────────────────────────────────
  // For existing users: sends an invite notification (pending) instead of an
  // immediate insert. For new users (email invite path): inserts immediately
  // and sends the Supabase auth invite email to set up their account.
  if (req.method === "POST" && !id) {
    const body = await req.json().catch(() => null);
    const {
      user_id,
      gym_id,
      employee_type = "employee",
      email,
      name,
      last_name,
      username,
    } = body ?? {};

    if (!gym_id) return jsonError("gym_id is required", 400);
    if (employee_type !== "employee" && employee_type !== "employee_trainer") {
      return jsonError("employee_type must be 'employee' or 'employee_trainer'", 400);
    }

    const gymName = await getGymName(gym_id);
    if (!gymName) return jsonError("Gym not found", 404);
    if (!(await canManageGym(caller, gym_id))) return forbidden();

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
        return jsonError("You cannot add yourself as an employee", 400);
      }

      const target = await db.selectFrom("users").select("id").where("id", "=", existingUserId)
        .executeTakeFirst();
      if (!target) return jsonError("User not found", 404);

      const existingEmployee = await db
        .selectFrom("employee")
        .select(["id"])
        .where("user_id", "=", existingUserId)
        .where("gym_id", "=", gym_id)
        .executeTakeFirst();
      if (existingEmployee) {
        return jsonError("This user is already an employee at this gym", 409);
      }

      const existingEt = await db
        .selectFrom("employee_trainer")
        .select(["id"])
        .where("user_id", "=", existingUserId)
        .where("gym_id", "=", gym_id)
        .executeTakeFirst();
      if (existingEt) {
        return jsonError("This user is already an employee trainer at this gym", 409);
      }

      const roleLabel = employee_type === "employee_trainer" ? "Employee Trainer" : "Employee";
      await db
        .insertInto("notification")
        .values({
          user_id: existingUserId,
          type: "employee_gym_invite",
          title: `You've been invited to join ${gymName}`,
          body: `You have a pending invitation to work at ${gymName} as ${roleLabel}.`,
          metadata: {
            invite_status: "pending",
            inviter_id: caller.id,
            gym_id,
            gym_name: gymName,
            employee_type,
          },
        })
        .execute();
      return json({ invited: true, user_id: existingUserId }, 200);
    }

    // ── Brand-new user: auth invite email, then user + staff rows atomically ──
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
        const insert: UserInsert = { email, name, last_name, username, auth_id: data.user.id };
        const newUser = await trx
          .insertInto("users")
          .values(insert)
          .returning(["id"])
          .executeTakeFirstOrThrow();
        return insertStaffRow(trx, newUser.id, gym_id, employee_type);
      });
      return json(row, 201);
    } catch (err) {
      // Don't leave an orphaned auth account behind.
      await supabaseAdmin.auth.admin.deleteUser(data.user.id).catch(() => {});
      if (pgCode(err) === "23505") return jsonError("A user with this email or username already exists", 409);
      throw err;
    }
  }

  // ── GET /employees — optional ?user_id= and/or ?gym_id= filters ──────────────
  // email only for the employee themself and people who coach/staff at that gym.
  if (req.method === "GET" && !id) {
    const userId = url.searchParams.get("user_id");
    const gymId = url.searchParams.get("gym_id");
    let query = db
      .selectFrom("employee")
      .innerJoin("users", "users.id", "employee.user_id")
      .select(SELECT_COLS);
    if (userId) query = query.where("employee.user_id", "=", userId);
    if (gymId) query = query.where("employee.gym_id", "=", gymId);
    return json(await redactEmails(caller, await query.execute(), (r) => r.gym_id, canCoachAtGym));
  }

  // ── GET /employees/:id ────────────────────────────────────────────────────────
  if (req.method === "GET" && id) {
    const row = await db
      .selectFrom("employee")
      .innerJoin("users", "users.id", "employee.user_id")
      .select(SELECT_COLS)
      .where("employee.id", "=", id)
      .executeTakeFirst();
    if (!row) return jsonError("Employee not found", 404);
    return json((await redactEmails(caller, [row], (r) => r.gym_id, canCoachAtGym))[0]);
  }

  // ── DELETE /employees/:id ─────────────────────────────────────────────────────
  if (req.method === "DELETE" && id) {
    const existing = await db
      .selectFrom("employee")
      .select(["id", "user_id", "gym_id"])
      .where("id", "=", id)
      .executeTakeFirst();
    if (!existing) return jsonError("Employee not found", 404);
    if (!(await canManageGym(caller, existing.gym_id))) return forbidden();

    await db.transaction().execute(async (trx) => {
      await trx.deleteFrom("employee").where("id", "=", id).execute();
      await reconcileRoles(trx, [existing.user_id]);
    });
    return new Response(null, { status: 204 });
  }

  return jsonError("Not found", 404);
});
