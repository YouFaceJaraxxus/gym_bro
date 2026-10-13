import { db, supabaseAdmin } from "../_shared/config.ts";
import { canStaffGym, forbidden, json, jsonError, requireCaller } from "../_shared/auth.ts";
import { gymOwnerIds, notify } from "../_shared/notify.ts";
import type { UserInsert } from "../../types/schema/public.ts";
import { pgCode } from "../_shared/roles.ts";

// ── Path parsing ──────────────────────────────────────────────────────────────

function parsePath(pathname: string): { id: string | null; action: string | null } {
  const withAction = pathname.match(/^\/members\/([^/]+)\/([^/]+)$/);
  if (withAction) return { id: withAction[1], action: withAction[2] };
  const idOnly = pathname.match(/^\/members\/([^/]+)$/);
  return { id: idOnly ? idOnly[1] : null, action: null };
}

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

/** Tells the new member and the gym owners about the join. */
async function notifyMemberJoined(userId: string, gymId: string, gymName: string): Promise<void> {
  const u = await db
    .selectFrom("users")
    .select(["name", "last_name"])
    .where("id", "=", userId)
    .executeTakeFirst();
  const fullName = u ? `${u.name} ${u.last_name}`.trim() : "A new member";
  const metadata = { gym_id: gymId, user_id: userId };

  await notify([userId], {
    type: "member_join",
    title: `You're now a member of ${gymName}`,
    body: `Welcome to ${gymName}!`,
    metadata,
  });
  const owners = (await gymOwnerIds(gymId)).filter((id) => id !== userId);
  await notify(owners, {
    type: "member_join",
    title: `${fullName} joined ${gymName}`,
    body: `${fullName} is now a member of ${gymName}.`,
    metadata,
  });
}

// ── Handler ───────────────────────────────────────────────────────────────────

Deno.serve(async (req: Request) => {
  const { caller, response } = await requireCaller(req);
  if (response) return response;

  const url = new URL(req.url);
  const { id, action } = parsePath(url.pathname);

  // ── POST /members ─────────────────────────────────────────────────────────────
  // Accepts either user_id (existing user) or email + name + last_name + username
  // (new user to be invited). In the invite path Supabase sends a "set password" email.
  if (req.method === "POST" && !id) {
    const body = await req.json().catch(() => null);
    const { user_id, gym_id, email, name, last_name, username } = body ?? {};
    if (!gym_id) return jsonError("gym_id is required", 400);

    const gymName = await getGymName(gym_id);
    if (!gymName) return jsonError("Gym not found", 404);
    if (!(await canStaffGym(caller, gym_id))) return forbidden();

    let existingUserId: string | null = user_id ?? null;
    if (!existingUserId) {
      if (!email) return jsonError("user_id or email is required", 400);
      const existing = await db
        .selectFrom("users")
        .select(["id"])
        .where("email", "=", email)
        .executeTakeFirst();
      existingUserId = existing?.id ?? null;
    }

    // ── Existing user: add the member row (users.role is left alone) ──────────
    if (existingUserId) {
      try {
        const row = await db
          .insertInto("member")
          .values({ user_id: existingUserId, gym_id })
          .returningAll()
          .executeTakeFirstOrThrow();
        await notifyMemberJoined(existingUserId, gym_id, gymName);
        return json(row, 201);
      } catch (err) {
        const code = pgCode(err);
        if (code === "23505") return jsonError("This user is already a member of this gym", 409);
        if (code === "23503") return jsonError("User not found", 400);
        throw err;
      }
    }

    // ── Brand-new user: auth invite email, then user + member rows atomically ─
    if (!name || !last_name || !username) {
      return jsonError(
        "name, last_name, and username are required when inviting a new member",
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

    let row;
    try {
      row = await db.transaction().execute(async (trx) => {
        const insert: UserInsert = { email, name, last_name, username, auth_id: data.user.id };
        const newUser = await trx
          .insertInto("users")
          .values(insert)
          .returning(["id"])
          .executeTakeFirstOrThrow();
        return trx
          .insertInto("member")
          .values({ user_id: newUser.id, gym_id })
          .returningAll()
          .executeTakeFirstOrThrow();
      });
    } catch (err) {
      // Don't leave an orphaned auth account behind.
      await supabaseAdmin.auth.admin.deleteUser(data.user.id).catch(() => {});
      if (pgCode(err) === "23505") return jsonError("A user with this email or username already exists", 409);
      throw err;
    }
    await notifyMemberJoined(row.user_id, gym_id, gymName);
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
  // users.role is never 'member'-specific beyond the default, so nothing to reset.
  if (req.method === "DELETE" && id && !action) {
    const existing = await db
      .selectFrom("member")
      .select(["id", "gym_id"])
      .where("id", "=", id)
      .executeTakeFirst();
    if (!existing) return jsonError("Member not found", 404);
    if (!(await canStaffGym(caller, existing.gym_id))) return forbidden();

    await db.deleteFrom("member").where("id", "=", id).execute();
    return new Response(null, { status: 204 });
  }

  // ── POST /members/:id/resend-invite ──────────────────────────────────────────
  if (req.method === "POST" && id && action === "resend-invite") {
    const row = await db
      .selectFrom("member")
      .innerJoin("users", "users.id", "member.user_id")
      .select(["users.email", "member.gym_id"])
      .where("member.id", "=", id)
      .executeTakeFirst();
    if (!row) return jsonError("Member not found", 404);
    if (!(await canStaffGym(caller, row.gym_id))) return forbidden();

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
