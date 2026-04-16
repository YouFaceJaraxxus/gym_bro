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

function parsePath(pathname: string): { id: string | null; action: string | null } {
  const withAction = pathname.match(/^\/members\/([^/]+)\/([^/]+)$/);
  if (withAction) return { id: withAction[1], action: withAction[2] };
  const idOnly = pathname.match(/^\/members\/([^/]+)$/);
  return { id: idOnly ? idOnly[1] : null, action: null };
}

// ── Handler ───────────────────────────────────────────────────────────────────

Deno.serve(async (req: Request) => {
  const { user, error: authError } = await requireAuth(req);
  if (!user) return jsonError(authError ?? "Unauthorized", 401);

  const url = new URL(req.url);
  const { id, action } = parsePath(url.pathname);

  // ── POST /members ─────────────────────────────────────────────────────────────
  // Accepts either user_id (existing user) or email + name + last_name + username
  // (new user to be invited). In the invite path Supabase sends a "set password" email.
  if (req.method === "POST" && !id) {
    const body = await req.json().catch(() => null);
    const { user_id, gym_id, email, name, last_name, username } = body ?? {};
    if (!gym_id) return jsonError("gym_id is required", 400);

    let resolvedUserId: string = user_id;

    if (!resolvedUserId) {
      if (!email) return jsonError("user_id or email is required", 400);

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
            "name, last_name, and username are required when inviting a new member",
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

        const insert: UserInsert = { email, name, last_name, username, auth_id: data.user.id };
        const newUser = await db
          .insertInto("users")
          .values(insert)
          .returning(["id"])
          .executeTakeFirstOrThrow();

        resolvedUserId = newUser.id;
      }
    }

    const row = await db
      .insertInto("member")
      .values({ user_id: resolvedUserId, gym_id })
      .returningAll()
      .executeTakeFirstOrThrow();
    await db.updateTable("users").set({ role: "member" }).where("id", "=", resolvedUserId).execute();
    return json(row, 201);
  }

  // ── GET /members — optional ?user_id= and/or ?gym_id= filters ────────────────
  if (req.method === "GET" && !id) {
    const userId = url.searchParams.get("user_id");
    const gymId = url.searchParams.get("gym_id");
    let query = db.selectFrom("member").selectAll();
    if (userId) query = query.where("user_id", "=", userId);
    if (gymId) query = query.where("gym_id", "=", gymId);
    return json(await query.execute());
  }

  // ── GET /members/:id ──────────────────────────────────────────────────────────
  if (req.method === "GET" && id && !action) {
    const row = await db.selectFrom("member").selectAll().where("id", "=", id).executeTakeFirst();
    if (!row) return jsonError("Member not found", 404);
    return json(row);
  }

  // ── DELETE /members/:id ───────────────────────────────────────────────────────
  if (req.method === "DELETE" && id && !action) {
    const result = await db.deleteFrom("member").where("id", "=", id).executeTakeFirst();
    if (!result.numDeletedRows) return jsonError("Member not found", 404);
    return new Response(null, { status: 204 });
  }

  // ── POST /members/:id/resend-invite ──────────────────────────────────────────
  if (req.method === "POST" && id && action === "resend-invite") {
    const row = await db
      .selectFrom("member")
      .innerJoin("users", "users.id", "member.user_id")
      .select(["users.email"])
      .where("member.id", "=", id)
      .executeTakeFirst();
    if (!row) return jsonError("Member not found", 404);

    const redirectTo = Deno.env.get("APP_INVITE_REDIRECT_URL") ?? "gymbroo://auth/callback";
    const { error: inviteErr } = await supabaseAdmin.auth.admin.inviteUserByEmail(
      row.email,
      { redirectTo },
    );
    if (inviteErr) return jsonError(inviteErr.message, 400);

    return json({ success: true });
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
