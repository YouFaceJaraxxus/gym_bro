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

// ── Handler ───────────────────────────────────────────────────────────────────

Deno.serve(async (req: Request) => {
  const { user, error: authError } = await requireAuth(req);
  if (!user) return jsonError(authError ?? "Unauthorized", 401);

  const url = new URL(req.url);
  const id = parseId(url.pathname);

  // ── POST /employees ───────────────────────────────────────────────────────────
  // Accepts either user_id (existing user) or email + name + last_name + username
  // (new user to be created). employee_type selects the table: "employee" (default)
  // or "employee_trainer".
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

    let resolvedUserId: string = user_id;

    if (!resolvedUserId) {
      if (!email) return jsonError("Either user_id or email is required", 400);

      // Find existing user by email
      const existing = await db
        .selectFrom("users")
        .select(["id"])
        .where("email", "=", email)
        .executeTakeFirst();

      if (existing) {
        resolvedUserId = existing.id;
      } else {
        // Pre-create the user via an invite — Supabase sends them a "set password" email.
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
      const row = await db
        .insertInto("employee_trainer")
        .values({ user_id: resolvedUserId, gym_id })
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
  // Returns employee rows with user info embedded.
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
