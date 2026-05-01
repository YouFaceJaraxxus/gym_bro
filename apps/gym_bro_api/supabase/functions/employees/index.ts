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
] as const;

const SELECT_ET_COLS = [
  "employee_trainer.id",
  "employee_trainer.user_id",
  "employee_trainer.gym_id",
  "employee_trainer.trainer_id",
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

async function getGymName(gymId: string): Promise<string> {
  const row = await db
    .selectFrom("business")
    .innerJoin("gym", "gym.id", "business.id")
    .select(["business.name"])
    .where("gym.id", "=", gymId)
    .executeTakeFirst();
  return row?.name ?? "the gym";
}

async function createInviteNotification(opts: {
  userId: string;
  gymId: string;
  gymName: string;
  inviterId: string;
  employeeType: "employee" | "employee_trainer";
}) {
  const isTrainer = opts.employeeType === "employee_trainer";
  const roleLabel = isTrainer ? "Employee Trainer" : "Employee";
  await db
    .insertInto("notification")
    .values({
      user_id: opts.userId,
      type: "employee_gym_invite",
      title: `You've been invited to join ${opts.gymName}`,
      body: `You have a pending invitation to work at ${opts.gymName} as ${roleLabel}.`,
      metadata: JSON.stringify({
        invite_status: "pending",
        inviter_id: opts.inviterId,
        gym_id: opts.gymId,
        gym_name: opts.gymName,
        employee_type: opts.employeeType,
      }),
    })
    .execute();
}

// ── Handler ───────────────────────────────────────────────────────────────────

Deno.serve(async (req: Request) => {
  const { user, error: authError } = await requireAuth(req);
  if (!user) return jsonError(authError ?? "Unauthorized", 401);

  const url = new URL(req.url);
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
        // Brand-new user: pre-create via Supabase auth invite and insert immediately.
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
      return jsonError("You cannot add yourself as an employee", 400);
    }

    // ── Duplicate guard ───────────────────────────────────────────────────────
    const existingEmployee = await db
      .selectFrom("employee")
      .select(["id"])
      .where("user_id", "=", resolvedUserId)
      .where("gym_id", "=", gym_id)
      .executeTakeFirst();
    if (existingEmployee) {
      return jsonError("This user is already an employee at this gym", 409);
    }

    const existingEt = await db
      .selectFrom("employee_trainer")
      .select(["id"])
      .where("user_id", "=", resolvedUserId)
      .where("gym_id", "=", gym_id)
      .executeTakeFirst();
    if (existingEt) {
      return jsonError("This user is already an employee trainer at this gym", 409);
    }

    // ── Existing user: send invite notification ───────────────────────────────
    if (!isNewUser) {
      const gymName = await getGymName(gym_id);
      await createInviteNotification({
        userId: resolvedUserId,
        gymId: gym_id,
        gymName,
        inviterId: callerInternal.id,
        employeeType: employee_type,
      });
      return json({ invited: true, user_id: resolvedUserId }, 200);
    }

    // ── New user: insert immediately (they accept by setting up their account) ─
    if (employee_type === "employee") {
      const row = await db
        .insertInto("employee")
        .values({ user_id: resolvedUserId, gym_id })
        .returningAll()
        .executeTakeFirstOrThrow();
      await db
        .updateTable("users")
        .set({ role: "employee" })
        .where("id", "=", resolvedUserId)
        .execute();
      return json(row, 201);
    } else {
      // employee_trainer: find or create the trainer row first
      let trainerRow = await db
        .selectFrom("trainer")
        .select(["id"])
        .where("user_id", "=", resolvedUserId)
        .where("gym_id", "=", gym_id)
        .executeTakeFirst();

      if (!trainerRow) {
        trainerRow = await db
          .insertInto("trainer")
          .values({ user_id: resolvedUserId, gym_id })
          .returning(["id"])
          .executeTakeFirstOrThrow();
      }

      const row = await db
        .insertInto("employee_trainer")
        .values({ user_id: resolvedUserId, gym_id, trainer_id: trainerRow.id })
        .returningAll()
        .executeTakeFirstOrThrow();
      await db
        .updateTable("users")
        .set({ role: "employee_trainer" })
        .where("id", "=", resolvedUserId)
        .execute();
      return json(row, 201);
    }
  }

  // ── GET /employees — optional ?user_id= and/or ?gym_id= filters ──────────────
  if (req.method === "GET" && !id) {
    const userId = url.searchParams.get("user_id");
    const gymId = url.searchParams.get("gym_id");
    let query = db
      .selectFrom("employee")
      .innerJoin("users", "users.id", "employee.user_id")
      .select(SELECT_COLS);
    if (userId) query = query.where("employee.user_id", "=", userId);
    if (gymId) query = query.where("employee.gym_id", "=", gymId);
    return json(await query.execute());
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
    return json(row);
  }

  // ── DELETE /employees/:id ─────────────────────────────────────────────────────
  if (req.method === "DELETE" && id) {
    const result = await db.deleteFrom("employee").where("id", "=", id).executeTakeFirst();
    if (!result.numDeletedRows) return jsonError("Employee not found", 404);
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
