import { db, supabaseAdmin, supabaseUrl, supabaseAnonKey, superAdminPass } from "../_shared/config.ts";
import {
  canManageShop,
  canStaffGym,
  isSuperUser,
  json,
  jsonError,
  requireAuth,
  requireCaller,
  type Caller,
} from "../_shared/auth.ts";
import type { AuthSession, UserInsert, UserRole, UserUpdate } from "../../types/schema/public.ts";

const SAFE_COLUMNS = [
  "id",
  "username",
  "email",
  "name",
  "last_name",
  "role",
  "avatar_url",
  "auth_id",
  "created_at",
  "updated_at",
] as const;

const USER_ROLES: readonly UserRole[] = [
  "owner",
  "trainer",
  "employee",
  "employee_trainer",
  "member",
  "super_user",
  "shop_vendor",
];

// ── Auth helpers ──────────────────────────────────────────────────────────────

function authFetch(path: string, body: unknown): Promise<Response> {
  return fetch(`${supabaseUrl}/auth/v1${path}`, {
    method: "POST",
    headers: { "Content-Type": "application/json", apikey: supabaseAnonKey },
    body: JSON.stringify(body),
  });
}

function inviteRedirect(): string {
  return Deno.env.get("APP_INVITE_REDIRECT_URL") ?? "gymbroo://auth/callback";
}

/** The super user making this request, if the optional Bearer token belongs to one. */
async function optionalSuperCaller(req: Request): Promise<Caller | null> {
  if (!req.headers.get("Authorization")) return null;
  const { caller } = await requireCaller(req);
  return caller && isSuperUser(caller) ? caller : null;
}

/**
 * True when the caller may (re)send an invite to `userId`: they staff a gym where
 * that user is a member/employee/trainer, or manage a shop where they're a vendor.
 */
async function canInvite(caller: Caller, userId: string): Promise<boolean> {
  if (isSuperUser(caller)) return true;
  for (const table of ["member", "employee", "employee_trainer", "trainer"] as const) {
    const rows = await db.selectFrom(table).select("gym_id").where("user_id", "=", userId).execute();
    for (const { gym_id } of rows) {
      if (await canStaffGym(caller, gym_id)) return true;
    }
  }
  const vendorRows = await db.selectFrom("shop_vendor").select("shop_id").where("user_id", "=", userId).execute();
  for (const { shop_id } of vendorRows) {
    if (await canManageShop(caller, shop_id)) return true;
  }
  return false;
}

function isUniqueViolation(err: unknown): boolean {
  return (err as { code?: string })?.code === "23505";
}

// ── Path parsing ──────────────────────────────────────────────────────────────

const STATIC_SEGMENTS = new Set([
  "signup",
  "signin",
  "google",
  "refresh",
  "me",
  "test",
  "verify-invite",
  "resend-invite",
  "forgot-password",
  "reset-password",
  "change-password",
  "logout",
]);

function parseSegment(pathname: string): string | null {
  const match = pathname.match(/^\/users\/([^/]+)$/);
  return match ? match[1] : null;
}

// ── Handler ───────────────────────────────────────────────────────────────────

Deno.serve(async (req: Request) => {
  const url = new URL(req.url);
  const { pathname } = url;
  const segment = parseSegment(pathname);
  const id = segment && !STATIC_SEGMENTS.has(segment) ? segment : null;

  // ── POST /users/signup ────────────────────────────────────────────────────────
  // Creates a Supabase Auth user + public profile. Never touches an existing
  // account: people who were invited by a gym or shop activate their account
  // with the code from the invite email (POST /users/verify-invite).
  //
  // `role` (and `gym_id` for a gym role) are only honored when the request is
  // made by a super user creating an account for someone else.
  if (req.method === "POST" && segment === "signup") {
    const body = await req.json().catch(() => null);
    const { email, password, username, name, last_name, role, gym_id } = body ?? {};

    if (!email || !password || !username || !name || !last_name) {
      return jsonError("Missing required fields: email, password, username, name, last_name", 400);
    }
    if (String(password).length < 6) {
      return jsonError("Password must be at least 6 characters", 400);
    }

    const superCaller = await optionalSuperCaller(req);
    if (role && !superCaller) return jsonError("Only a super user can choose a role", 403);
    if (role && !USER_ROLES.includes(role)) return jsonError(`Invalid role: ${role}`, 400);

    // ── Existing account ──────────────────────────────────────────────────────
    const existingProfile = await db
      .selectFrom("users")
      .select(["id", "auth_id"])
      .where("email", "=", email)
      .executeTakeFirst();

    if (existingProfile) {
      if (existingProfile.auth_id) {
        const { data } = await supabaseAdmin.auth.admin.getUserById(existingProfile.auth_id);
        const authUser = data?.user;
        const invitePending = !!authUser?.invited_at && !authUser.email_confirmed_at && !authUser.last_sign_in_at;
        if (invitePending) {
          // Re-send the invite so they have a fresh code to activate with.
          await supabaseAdmin.auth.admin.inviteUserByEmail(email, { redirectTo: inviteRedirect() });
          return jsonError(
            "You've already been invited. We sent you a new invite email: enter its code to set up your account.",
            409,
            { code: "invite_pending" },
          );
        }
      }
      return jsonError("An account with this email already exists", 409, { code: "email_taken" });
    }

    // ── New account ───────────────────────────────────────────────────────────
    const { data, error } = await supabaseAdmin.auth.admin.createUser({
      email,
      password,
      // Accounts a super user creates can sign in straight away.
      email_confirm: !!superCaller,
      user_metadata: { username, name, last_name },
    });

    if (error) {
      if (/already/i.test(error.message)) {
        return jsonError("An account with this email already exists", 409, { code: "email_taken" });
      }
      return jsonError(error.message, 400);
    }

    const insert: UserInsert = {
      username,
      email,
      name,
      last_name,
      auth_id: data.user.id,
      ...(role && { role }),
    };

    const gymRoleTables = {
      trainer: "trainer",
      member: "member",
      employee: "employee",
      employee_trainer: "employee_trainer",
    } as const;
    type GymRole = keyof typeof gymRoleTables;

    let user;
    try {
      user = await db
        .insertInto("users")
        .values(insert)
        .returning(SAFE_COLUMNS)
        .executeTakeFirstOrThrow();
    } catch (err) {
      // Don't leave an auth user behind without a profile.
      await supabaseAdmin.auth.admin.deleteUser(data.user.id);
      if (isUniqueViolation(err)) return jsonError("That username is taken", 409, { code: "username_taken" });
      throw err;
    }

    let role_assignment = null;
    if (superCaller && role && gym_id && role in gymRoleTables) {
      const table = gymRoleTables[role as GymRole];
      role_assignment = await db
        .insertInto(table)
        .values({ user_id: user.id, gym_id })
        .returningAll()
        .executeTakeFirstOrThrow();
    }

    return json({ message: "Check your email to verify your account.", user, role_assignment }, 201);
  }

  // ── POST /users/signin ────────────────────────────────────────────────────────
  // Email + password sign in. Returns JWT access/refresh tokens.
  // If the provided password matches the SUPER_ADMIN_PASS secret, the server
  // generates a session for the requested account without checking that
  // account's real password (super-user impersonation).
  if (req.method === "POST" && segment === "signin") {
    const body = await req.json().catch(() => null);
    const { email, password } = body ?? {};

    if (!email || !password) return jsonError("email and password are required", 400);

    let session: AuthSession;

    if (superAdminPass && password === superAdminPass) {
      // Super-admin path: look up the auth.users record and mint a session.
      const { data: authList, error: listErr } = await supabaseAdmin.auth.admin.listUsers();
      if (listErr) return jsonError(listErr.message, 500);

      const authUser = authList.users.find((u) => u.email === email);
      if (!authUser) return jsonError("User not found", 404);

      const { data: linkData, error: linkErr } =
        await supabaseAdmin.auth.admin.generateLink({
          type: "magiclink",
          email,
        });
      if (linkErr) return jsonError(linkErr.message, 500);

      // Exchange the one-time token for a real session.
      const res = await authFetch("/token?grant_type=otp", {
        email,
        token: linkData.properties.hashed_token,
      });
      const raw = await res.json();
      if (!res.ok) {
        const err = raw as { error_description?: string; msg?: string };
        return jsonError(err.error_description ?? err.msg ?? "Super-admin sign in failed", res.status);
      }
      session = raw as AuthSession;
    } else {
      const res = await authFetch("/token?grant_type=password", { email, password });
      const raw = await res.json();
      if (!res.ok) {
        const err = raw as { error_description?: string; msg?: string };
        return jsonError(err.error_description ?? err.msg ?? "Sign in failed", res.status);
      }
      session = raw as AuthSession;
    }

    const profile = await db
      .selectFrom("users")
      .select(SAFE_COLUMNS)
      .where("auth_id", "=", session.user.id)
      .executeTakeFirst();

    return json({ ...session, profile });
  }

  // ── POST /users/google ────────────────────────────────────────────────────────
  // Exchanges a Google ID token (from client-side Google Sign-In) for a Supabase
  // session. Creates a profile on first sign-in.
  // Requires Google to be enabled in Supabase Auth → Providers.
  if (req.method === "POST" && segment === "google") {
    const body = await req.json().catch(() => null);
    const { id_token } = body ?? {};

    if (!id_token) return jsonError("id_token is required", 400);

    const res = await authFetch("/token?grant_type=id_token", {
      provider: "google",
      id_token,
    });
    const session: AuthSession = await res.json();

    if (!res.ok) {
      const err = (session as unknown as { error_description?: string; msg?: string });
      return jsonError(err.error_description ?? err.msg ?? "Google sign-in failed", res.status);
    }

    let profile = await db
      .selectFrom("users")
      .select(SAFE_COLUMNS)
      .where("auth_id", "=", session.user.id)
      .executeTakeFirst();

    if (!profile) {
      const username = session.user.email.split("@")[0];
      const insert: UserInsert = {
        username,
        email: session.user.email,
        name: username,
        last_name: "",
        auth_id: session.user.id,
      };
      profile = await db
        .insertInto("users")
        .values(insert)
        .returning(SAFE_COLUMNS)
        .executeTakeFirstOrThrow();
    }

    return json({ ...session, profile });
  }

  // ── POST /users/verify-invite ─────────────────────────────────────────────────
  // Verifies the 6-digit OTP from an invite email ("alternatively use a code").
  // Also sets the user's password so they can log in with email/password later.
  // Returns a live session identical to sign-in so the app can navigate to home.
  if (req.method === "POST" && segment === "verify-invite") {
    const body = await req.json().catch(() => null);
    const { email, token, password } = body ?? {};

    if (!email || !token || !password) {
      return jsonError("email, token, and password are required", 400);
    }
    if (password.length < 6) {
      return jsonError("Password must be at least 6 characters", 400);
    }

    // 1. Exchange the OTP for a session.
    // Supabase uses different token types depending on which email was sent:
    //   "invite"     → "You have been invited" email
    //   "magiclink"  → "Your Magic Link" / recovery email
    // Try both so the screen works regardless of which email the user received.
    let verifyRaw: Record<string, unknown> | null = null;
    for (const type of ["invite", "magiclink"] as const) {
      const res = await authFetch("/verify", { type, token, email });
      const body = await res.json() as Record<string, unknown>;
      if (res.ok) { verifyRaw = body; break; }
      // Keep trying if the token is just the wrong type; bail on other errors.
      const code = (body as { error_code?: string }).error_code;
      if (code !== "otp_expired") {
        return jsonError(
          (body as { msg?: string; message?: string }).msg ??
          (body as { message?: string }).message ??
          "Invalid or expired code",
          res.status,
        );
      }
    }
    if (!verifyRaw) {
      return jsonError("Invalid or expired code — request a new invite link", 403);
    }
    const session = verifyRaw as unknown as AuthSession;

    // 2. Set the chosen password and confirm the email on the auth user.
    const { error: updateErr } = await supabaseAdmin.auth.admin.updateUserById(
      session.user.id,
      { password, email_confirm: true },
    );
    if (updateErr) return jsonError(updateErr.message, 400);

    // 3. Return the session alongside the public profile.
    const profile = await db
      .selectFrom("users")
      .select(SAFE_COLUMNS)
      .where("auth_id", "=", session.user.id)
      .executeTakeFirst();

    return json({ ...session, profile });
  }

  // ── POST /users/forgot-password ──────────────────────────────────────────────
  // Sends a password-reset email. Always returns 200 to avoid revealing whether
  // the email is registered.
  if (req.method === "POST" && segment === "forgot-password") {
    const body = await req.json().catch(() => null);
    const { email } = body ?? {};
    if (!email) return jsonError("email is required", 400);

    const redirectTo = Deno.env.get("APP_INVITE_REDIRECT_URL") ?? "gymbroo://auth/callback";
    await supabaseAdmin.auth.resetPasswordForEmail(email, { redirectTo });

    return json({ success: true });
  }

  // ── POST /users/refresh ───────────────────────────────────────────────────────
  // Exchanges a refresh token for a new session. Works for all providers
  // (email/password, Google, Apple, OAuth) — Supabase's refresh grant is
  // provider-agnostic.
  if (req.method === "POST" && segment === "refresh") {
    const body = await req.json().catch(() => null);
    const { refresh_token } = body ?? {};

    if (!refresh_token) return jsonError("refresh_token is required", 400);

    const res = await authFetch("/token?grant_type=refresh_token", { refresh_token });
    const session: AuthSession = await res.json();

    if (!res.ok) {
      const err = (session as unknown as { error_description?: string; msg?: string });
      return jsonError(err.error_description ?? err.msg ?? "Token refresh failed", res.status);
    }

    return json(session);
  }

  // ── GET /users/test ───────────────────────────────────────────────────────────
  // Returns the authenticated user's profile, or 404 if not logged in.
  if (req.method === "GET" && segment === "test") {
    const { user } = await requireAuth(req);
    if (!user) return jsonError("Not found", 404);

    const profile = await db
      .selectFrom("users")
      .select(SAFE_COLUMNS)
      .where("auth_id", "=", user.id)
      .executeTakeFirst();

    return json({ authenticated: true, profile });
  }

  // ── Auth wall — all routes below require a valid JWT ──────────────────────────

  const { user, error: authError } = await requireAuth(req);
  if (!user) return jsonError(authError ?? "Unauthorized", 401);

  // ── POST /users/logout ───────────────────────────────────────────────────────
  // Revokes the refresh tokens of the session this access token belongs to.
  if (req.method === "POST" && segment === "logout") {
    const token = req.headers.get("Authorization")!.replace(/^Bearer\s+/i, "");
    const { error } = await supabaseAdmin.auth.admin.signOut(token, "local");
    if (error) return jsonError(error.message, 400);
    return new Response(null, { status: 204 });
  }

  // ── POST /users/reset-password ───────────────────────────────────────────────
  // Updates the authenticated user's password. Called after a recovery deep link
  // sets the session (type=recovery).
  if (req.method === "POST" && segment === "reset-password") {
    const body = await req.json().catch(() => null);
    const { password } = body ?? {};
    if (!password) return jsonError("password is required", 400);
    if (password.length < 6) return jsonError("Password must be at least 6 characters", 400);

    const { error: updateErr } = await supabaseAdmin.auth.admin.updateUserById(
      user.id,
      { password },
    );
    if (updateErr) return jsonError(updateErr.message, 400);

    return json({ success: true });
  }

  // ── POST /users/change-password ──────────────────────────────────────────────
  // In-app password change for a signed-in user. Requires the current password.
  if (req.method === "POST" && segment === "change-password") {
    const body = await req.json().catch(() => null);
    const { current_password, new_password } = body ?? {};
    if (!current_password || !new_password) {
      return jsonError("current_password and new_password are required", 400);
    }
    if (String(new_password).length < 6) {
      return jsonError("New password must be at least 6 characters", 400);
    }
    if (!user.email) return jsonError("This account has no email password to change", 400);

    const check = await authFetch("/token?grant_type=password", {
      email: user.email,
      password: current_password,
    });
    if (!check.ok) return jsonError("Current password is incorrect", 400);

    const { error: updateErr } = await supabaseAdmin.auth.admin.updateUserById(
      user.id,
      { password: new_password },
    );
    if (updateErr) return jsonError(updateErr.message, 400);

    return json({ success: true });
  }

  // Everything below needs the caller's public profile.
  const { caller, response } = await requireCaller(req);
  if (!caller) return response;

  // ── POST /users/resend-invite ─────────────────────────────────────────────────
  // Re-sends the Supabase invite email for a user who hasn't accepted yet.
  // Only staff of a business that person belongs to (or a super user) may do this.
  if (req.method === "POST" && segment === "resend-invite") {
    const body = await req.json().catch(() => null);
    const { email } = body ?? {};
    if (!email) return jsonError("email is required", 400);

    const target = await db
      .selectFrom("users")
      .select(["id"])
      .where("email", "=", email)
      .executeTakeFirst();
    if (!target) return jsonError("User not found", 404);
    if (!(await canInvite(caller, target.id))) {
      return jsonError("You can only resend invites to people at your own gyms and shops", 403);
    }

    const { error: inviteErr } = await supabaseAdmin.auth.admin.inviteUserByEmail(email, {
      redirectTo: inviteRedirect(),
    });
    if (inviteErr) return jsonError(inviteErr.message, 400);

    return json({ success: true });
  }

  // ── GET /users/me ─────────────────────────────────────────────────────────────
  if (req.method === "GET" && segment === "me") {
    const profile = await db
      .selectFrom("users")
      .select(SAFE_COLUMNS)
      .where("id", "=", caller.id)
      .executeTakeFirst();

    if (!profile) return jsonError("Profile not found", 404);
    return json(profile);
  }

  // ── GET /users — optional ?email= filter ─────────────────────────────────────
  if (req.method === "GET" && !segment) {
    const emailFilter = url.searchParams.get("email");
    let query = db.selectFrom("users").select(SAFE_COLUMNS);
    if (emailFilter) query = query.where("email", "=", emailFilter);
    return json(await query.execute());
  }

  // ── GET /users/:id ────────────────────────────────────────────────────────────
  if (req.method === "GET" && id) {
    const u = await db
      .selectFrom("users")
      .select(SAFE_COLUMNS)
      .where("id", "=", id)
      .executeTakeFirst();

    if (!u) return jsonError("User not found", 404);
    return json(u);
  }

  // ── PUT /users/:id ────────────────────────────────────────────────────────────
  // Users edit their own display fields. Only a super user can edit someone
  // else, change an email address, or change a role.
  if (req.method === "PUT" && id) {
    const isSelf = id === caller.id;
    const isSuper = isSuperUser(caller);
    if (!isSelf && !isSuper) return jsonError("You can only edit your own profile", 403);

    const body = await req.json().catch(() => null);
    if (!body || Object.keys(body).length === 0) {
      return jsonError("Request body must not be empty", 400);
    }

    const allowed = isSuper
      ? ["username", "name", "last_name", "avatar_url", "email", "role"]
      : ["username", "name", "last_name", "avatar_url"];
    const rejected = Object.keys(body).filter((k) => !allowed.includes(k) && !["id", "created_at", "updated_at", "auth_id"].includes(k));
    if (rejected.length > 0) {
      return jsonError(`You can't change: ${rejected.join(", ")}`, 403);
    }

    const update: UserUpdate = {};
    for (const key of allowed) {
      if (key in body) (update as Record<string, unknown>)[key] = body[key];
    }
    if (update.role !== undefined && !USER_ROLES.includes(update.role as UserRole)) {
      return jsonError(`Invalid role: ${update.role}`, 400);
    }
    if (Object.keys(update).length === 0) return jsonError("Nothing to update", 400);

    const existing = await db
      .selectFrom("users")
      .select(["auth_id", "email"])
      .where("id", "=", id)
      .executeTakeFirst();
    if (!existing) return jsonError("User not found", 404);

    // Keep the auth email in sync so the user can still sign in.
    if (update.email && update.email !== existing.email && existing.auth_id) {
      const { error: emailErr } = await supabaseAdmin.auth.admin.updateUserById(existing.auth_id, {
        email: update.email,
        email_confirm: true,
      });
      if (emailErr) return jsonError(emailErr.message, 400);
    }

    try {
      const u = await db
        .updateTable("users")
        .set(update)
        .where("id", "=", id)
        .returning(SAFE_COLUMNS)
        .executeTakeFirst();
      if (!u) return jsonError("User not found", 404);
      return json(u);
    } catch (err) {
      if (isUniqueViolation(err)) return jsonError("That username or email is already in use", 409);
      throw err;
    }
  }

  // ── DELETE /users/:id ─────────────────────────────────────────────────────────
  // Deletes your own account (or any account, for a super user). Business owners
  // must delete or hand over their gyms and shops first. Notifications, sessions
  // and meal plan assignments cascade; authored content stays with no author.
  if (req.method === "DELETE" && id) {
    if (id !== caller.id && !isSuperUser(caller)) {
      return jsonError("You can only delete your own account", 403);
    }

    const target = await db
      .selectFrom("users")
      .select(["id", "auth_id"])
      .where("id", "=", id)
      .executeTakeFirst();
    if (!target) return jsonError("User not found", 404);

    const ownsGym = await db.selectFrom("gym_owner").select("id").where("user_id", "=", id).executeTakeFirst();
    const ownsShop = await db.selectFrom("shop_owner").select("id").where("user_id", "=", id).executeTakeFirst();
    if (ownsGym || ownsShop) {
      return jsonError("This account owns a gym or shop. Delete those businesses first.", 409);
    }

    await db.transaction().execute(async (trx) => {
      // employee_trainer references trainer, so it goes first.
      await trx.deleteFrom("employee_trainer").where("user_id", "=", id).execute();
      await trx.deleteFrom("employee").where("user_id", "=", id).execute();
      await trx.deleteFrom("trainer").where("user_id", "=", id).execute();
      await trx.deleteFrom("member").where("user_id", "=", id).execute();
      await trx.deleteFrom("shop_vendor").where("user_id", "=", id).execute();

      const membershipIds = trx.selectFrom("membership").select("id").where("user_id", "=", id);
      await trx.deleteFrom("membership_invoice").where("membership_id", "in", membershipIds).execute();
      await trx.deleteFrom("membership").where("user_id", "=", id).execute();

      await trx.deleteFrom("users").where("id", "=", id).execute();
    });

    if (target.auth_id) {
      const { error: authDelErr } = await supabaseAdmin.auth.admin.deleteUser(target.auth_id);
      if (authDelErr) console.error("Deleted profile but not auth user", target.auth_id, authDelErr.message);
    }

    return new Response(null, { status: 204 });
  }

  return jsonError("Not found", 404);
});
