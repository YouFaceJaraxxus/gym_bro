import { sql } from "npm:kysely@^0.27";
import { removeObjects } from "../_shared/media.ts";
import { db, supabaseAdmin, supabaseUrl, supabaseAnonKey } from "../_shared/config.ts";
import {
  canStaffGym,
  canStaffShop,
  isSuperUser,
  json,
  jsonError,
  requireAuth,
  requireCaller,
  staffsAnyBusiness,
  type Caller,
} from "../_shared/auth.ts";
import { myBusinesses, pendingInviteCount, pgCode } from "../_shared/business.ts";
import { isTimezone } from "../_shared/plans.ts";
import type { AuthSession, NotificationType, UserInsert, UserUpdate } from "../../types/schema/public.ts";

const SAFE_COLUMNS = [
  "id",
  "username",
  "email",
  "name",
  "last_name",
  "is_super_user",
  "is_trainer",
  "avatar_url",
  "auth_id",
  "created_at",
  "updated_at",
] as const;

/** What any signed-in user may see about someone else. */
const PUBLIC_COLUMNS = ["id", "username", "name", "last_name", "is_trainer", "avatar_url"] as const;

const NOTIFICATION_TYPES: readonly NotificationType[] = [
  "business_invite",
  "business_join",
  "business_review",
  "member_invite",
  "news",
  "events",
  "training",
  "training_update",
  "class_reminder",
  "shop_item_update",
  "purchase_made",
  "membership_expiring",
  "invoice_issued",
  "member_subscription_extended",
  "member_join",
  "post_comment",
  "shift_assigned",
  "order_update",
  "payment_received",
  "session_comment",
  "follow",
  "follow_request",
  "follow_accepted",
  "friend_request",
  "friend_accepted",
  "chat_message",
  "group_added",
  "post_reaction",
  "comment_reply",
  "streak",
  "challenge",
  "wrapped",
];

const WEIGHT_UNITS = ["kg", "lb"] as const;
const THEME_MODES = ["system", "light", "dark"] as const;
const FITNESS_GOALS = ["lose_fat", "build_muscle", "get_stronger", "stay_fit", "endurance"] as const;

type SettingsBody = {
  push_enabled: boolean;
  muted_types: NotificationType[];
  weight_unit: (typeof WEIGHT_UNITS)[number];
  theme_mode: (typeof THEME_MODES)[number];
  locale: string | null;
  weekly_workout_target: number;
  show_on_gym_boards: boolean;
  timezone: string | null;
  fitness_goal: (typeof FITNESS_GOALS)[number] | null;
  goal_weight_kg: number | null;
  // null: worked out from body weight on the client.
  water_goal_ml: number | null;
  water_cups: number[];
  water_reminders: boolean;
  onboarded_at: string | null;
};

const DEFAULT_SETTINGS: SettingsBody = {
  push_enabled: true,
  muted_types: [],
  weight_unit: "kg",
  theme_mode: "system",
  locale: null,
  weekly_workout_target: 3,
  show_on_gym_boards: true,
  timezone: null,
  fitness_goal: null,
  goal_weight_kg: null,
  water_goal_ml: null,
  water_cups: [250, 500],
  water_reminders: false,
  onboarded_at: null,
};

// ── Auth helpers ──────────────────────────────────────────────────────────────

function authFetch(path: string, body: unknown): Promise<Response> {
  return fetch(`${supabaseUrl}/auth/v1${path}`, {
    method: "POST",
    headers: { "Content-Type": "application/json", apikey: supabaseAnonKey },
    body: JSON.stringify(body),
  });
}

/**
 * Sets the password of the user behind `accessToken` with GoTrue's own
 * endpoint. auth.admin.updateUserById would sign out every session, including
 * the one the app is using; this keeps it (GoTrue ends the others). Returns an
 * error message, or null on success.
 */
async function setOwnPassword(accessToken: string, password: string): Promise<string | null> {
  const res = await fetch(`${supabaseUrl}/auth/v1/user`, {
    method: "PUT",
    headers: { "Content-Type": "application/json", apikey: supabaseAnonKey, Authorization: `Bearer ${accessToken}` },
    body: JSON.stringify({ password }),
  });
  if (res.ok) return null;
  return authErrorMessage(await res.json().catch(() => null), "Could not set the password");
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
 * True when the caller may (re)send an invite to `userId` or see their email:
 * they staff a gym where that user is a member, or are owner or staff of a
 * business where that user is on the team or was invited to it.
 */
async function canInvite(caller: Caller, userId: string): Promise<boolean> {
  if (isSuperUser(caller)) return true;
  const gyms = await db.selectFrom("member").select("gym_id").where("user_id", "=", userId).execute();
  for (const { gym_id } of gyms) {
    if (await canStaffGym(caller, gym_id)) return true;
  }
  const teams = await db.selectFrom("business_member").select("business_id").distinct()
    .where("user_id", "=", userId).execute();
  for (const { business_id } of teams) {
    if ((await canStaffGym(caller, business_id)) || (await canStaffShop(caller, business_id))) return true;
  }
  return false;
}

/**
 * The signed-in user's own profile plus what they do: the businesses they're
 * on the team of (with their roles) and unanswered team invites. The app
 * builds its menu from this.
 */
async function withAccess<T extends { id: string }>(profile: T) {
  const [businesses, pending_invites] = await Promise.all([
    myBusinesses(profile.id),
    pendingInviteCount(profile.id),
  ]);
  return { ...profile, businesses, pending_invites };
}

function isUniqueViolation(err: unknown): boolean {
  return (err as { code?: string })?.code === "23505";
}

/** Name of the constraint a pg error tripped, e.g. "users_username_key". */
function pgConstraint(err: unknown): string | undefined {
  return (err as { constraint?: string })?.constraint;
}

/** The error message GoTrue put in a failed response body. */
function authErrorMessage(raw: unknown, fallback: string): string {
  const err = raw as { error_description?: string; msg?: string; message?: string } | null;
  return err?.error_description ?? err?.msg ?? err?.message ?? fallback;
}

/**
 * Mints a session for an existing auth user without their password: a
 * magic-link token generated with the service role, verified straight away.
 */
async function mintSession(email: string): Promise<{ session: AuthSession } | { error: string; status: number }> {
  const { data: linkData, error: linkErr } = await supabaseAdmin.auth.admin.generateLink({
    type: "magiclink",
    email,
  });
  if (linkErr) return { error: linkErr.message, status: 500 };

  const res = await authFetch("/verify", {
    type: "magiclink",
    token_hash: linkData.properties.hashed_token,
  });
  const raw = await res.json().catch(() => null);
  if (!res.ok) return { error: authErrorMessage(raw, "Could not create a session"), status: res.status };
  return { session: raw as AuthSession };
}

/**
 * Copies a confirmed email change from Supabase Auth onto the public profile.
 * GoTrue only switches auth.users.email once the new address is confirmed, so
 * a mismatch means the change went through.
 */
async function syncConfirmedEmail(
  profile: { id: string; email: string },
  authEmail: string | undefined,
): Promise<string> {
  if (!authEmail || authEmail.toLowerCase() === profile.email.toLowerCase()) return profile.email;
  try {
    await db.updateTable("users").set({ email: authEmail }).where("id", "=", profile.id).execute();
    return authEmail;
  } catch (err) {
    console.error("Could not sync confirmed email", profile.id, err);
    return profile.email;
  }
}

/** The caller's settings, or the defaults when they never saved any. */
async function loadSettings(userId: string): Promise<SettingsBody & { updated_at: string | null }> {
  const row = await db
    .selectFrom("user_settings")
    .select([
      "push_enabled",
      // pg can't parse arrays of a custom enum; text[] comes back as a JS array.
      sql<string[]>`muted_types::text[]`.as("muted_types"),
      "weight_unit",
      "theme_mode",
      "locale",
      "weekly_workout_target",
      "show_on_gym_boards",
      "timezone",
      "fitness_goal",
      sql<number | null>`goal_weight_kg::float8`.as("goal_weight_kg"),
      "water_goal_ml",
      "water_cups",
      "water_reminders",
      "onboarded_at",
      "updated_at",
    ])
    .where("user_id", "=", userId)
    .executeTakeFirst();
  if (!row) return { ...DEFAULT_SETTINGS, updated_at: null };
  return { ...row, muted_types: row.muted_types as NotificationType[] };
}

/** Validates a partial settings body. Returns the fields to write, or an error message. */
function parseSettings(body: Record<string, unknown>): Partial<SettingsBody> | string {
  const out: Partial<SettingsBody> = {};
  const known = [
    "push_enabled",
    "muted_types",
    "weight_unit",
    "theme_mode",
    "locale",
    "weekly_workout_target",
    "show_on_gym_boards",
    "timezone",
    "fitness_goal",
    "goal_weight_kg",
    "water_goal_ml",
    "water_cups",
    "water_reminders",
    "onboarded",
  ];
  const unknown = Object.keys(body).filter((k) => !known.includes(k) && k !== "updated_at" && k !== "user_id");
  if (unknown.length > 0) return `Unknown settings: ${unknown.join(", ")}`;

  if ("push_enabled" in body) {
    if (typeof body.push_enabled !== "boolean") return "push_enabled must be a boolean";
    out.push_enabled = body.push_enabled;
  }
  if ("muted_types" in body) {
    const types = body.muted_types;
    if (!Array.isArray(types)) return "muted_types must be an array";
    const invalid = types.filter((t) => !NOTIFICATION_TYPES.includes(t as NotificationType));
    if (invalid.length > 0) return `Invalid notification types: ${invalid.join(", ")}`;
    out.muted_types = [...new Set(types as NotificationType[])];
  }
  if ("weight_unit" in body) {
    if (!WEIGHT_UNITS.includes(body.weight_unit as SettingsBody["weight_unit"])) {
      return `weight_unit must be one of: ${WEIGHT_UNITS.join(", ")}`;
    }
    out.weight_unit = body.weight_unit as SettingsBody["weight_unit"];
  }
  if ("theme_mode" in body) {
    if (!THEME_MODES.includes(body.theme_mode as SettingsBody["theme_mode"])) {
      return `theme_mode must be one of: ${THEME_MODES.join(", ")}`;
    }
    out.theme_mode = body.theme_mode as SettingsBody["theme_mode"];
  }
  if ("locale" in body) {
    const locale = body.locale;
    if (locale !== null && (typeof locale !== "string" || !/^[a-z]{2,3}([-_][A-Za-z0-9]{2,8})?$/.test(locale))) {
      return "locale must be a language tag like 'en' or 'pt-BR', or null";
    }
    out.locale = locale as string | null;
  }
  if ("weekly_workout_target" in body) {
    const t = body.weekly_workout_target;
    if (typeof t !== "number" || !Number.isInteger(t) || t < 1 || t > 14) {
      return "weekly_workout_target must be a whole number from 1 to 14";
    }
    out.weekly_workout_target = t;
  }
  if ("show_on_gym_boards" in body) {
    if (typeof body.show_on_gym_boards !== "boolean") return "show_on_gym_boards must be a boolean";
    out.show_on_gym_boards = body.show_on_gym_boards;
  }
  if ("timezone" in body) {
    const tz = body.timezone;
    if (tz !== null && (typeof tz !== "string" || !isTimezone(tz))) return "timezone must be an IANA zone or null";
    out.timezone = tz as string | null;
  }
  if ("fitness_goal" in body) {
    const g = body.fitness_goal;
    if (g !== null && !FITNESS_GOALS.includes(g as (typeof FITNESS_GOALS)[number])) {
      return `fitness_goal must be one of: ${FITNESS_GOALS.join(", ")}, or null`;
    }
    out.fitness_goal = g as SettingsBody["fitness_goal"];
  }
  if ("goal_weight_kg" in body) {
    const w = body.goal_weight_kg;
    if (w !== null && (typeof w !== "number" || !Number.isFinite(w) || w < 20 || w > 400)) {
      return "goal_weight_kg must be a number from 20 to 400, or null";
    }
    out.goal_weight_kg = w === null ? null : Math.round(w * 10) / 10;
  }
  if ("water_goal_ml" in body) {
    const ml = body.water_goal_ml;
    if (ml !== null && (typeof ml !== "number" || !Number.isInteger(ml) || ml < 500 || ml > 8000)) {
      return "water_goal_ml must be a whole number from 500 to 8000, or null";
    }
    out.water_goal_ml = ml as number | null;
  }
  if ("water_cups" in body) {
    const cups = body.water_cups;
    if (
      !Array.isArray(cups) || cups.length < 1 || cups.length > 4 ||
      cups.some((c) => typeof c !== "number" || !Number.isInteger(c) || c < 50 || c > 2000)
    ) {
      return "water_cups must be 1 to 4 whole numbers from 50 to 2000 (ml)";
    }
    out.water_cups = cups as number[];
  }
  if ("water_reminders" in body) {
    if (typeof body.water_reminders !== "boolean") return "water_reminders must be a boolean";
    out.water_reminders = body.water_reminders;
  }
  // {onboarded: true} stamps onboarded_at (false clears it, to see the flow again).
  if ("onboarded" in body) {
    if (typeof body.onboarded !== "boolean") return "onboarded must be a boolean";
    out.onboarded_at = body.onboarded ? new Date().toISOString() : null;
  }
  return out;
}

/** A username derived from an email, made unique with a short random suffix on retries. */
function usernameCandidate(email: string, attempt: number): string {
  const base = (email.split("@")[0] ?? "user")
    .toLowerCase()
    .replace(/[^a-z0-9._-]/g, "")
    .slice(0, 40) || "user";
  if (attempt === 0) return base;
  const suffix = crypto.randomUUID().replace(/-/g, "").slice(0, 4 + attempt);
  return `${base}_${suffix}`;
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
  "change-email",
  "impersonate",
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
  // A super user creating an account for someone else gets it confirmed.
  if (req.method === "POST" && segment === "signup") {
    const body = await req.json().catch(() => null);
    const { email, password, username, name, last_name } = body ?? {};

    if (!email || !password || !username || !name || !last_name) {
      return jsonError("Missing required fields: email, password, username, name, last_name", 400);
    }
    if (String(password).length < 6) {
      return jsonError("Password must be at least 6 characters", 400);
    }

    const superCaller = await optionalSuperCaller(req);

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
    };

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

    // admin.createUser never emails anyone: ask GoTrue for the confirmation
    // email, whose link opens the app signed in. A send failure doesn't undo
    // the signup (POST /users/forgot-password also confirms the address).
    if (!superCaller) {
      const sent = await authFetch(`/resend?redirect_to=${encodeURIComponent(inviteRedirect())}`, {
        type: "signup",
        email,
      });
      if (!sent.ok) console.error(`signup: confirmation email to ${email} failed (${sent.status}): ${await sent.text()}`);
    }

    return json({ message: "Check your email to verify your account.", user }, 201);
  }

  // ── POST /users/signin ────────────────────────────────────────────────────────
  // Email + password sign in. Returns JWT access/refresh tokens + profile.
  // (Support access to someone else's account goes through the logged
  // POST /users/impersonate instead.)
  if (req.method === "POST" && segment === "signin") {
    const body = await req.json().catch(() => null);
    const { email, password } = body ?? {};

    if (!email || !password) return jsonError("email and password are required", 400);

    const res = await authFetch("/token?grant_type=password", { email, password });
    const raw = await res.json().catch(() => null);
    if (!res.ok) return jsonError(authErrorMessage(raw, "Sign in failed"), res.status);
    const session = raw as AuthSession;

    const profile = await db
      .selectFrom("users")
      .select(SAFE_COLUMNS)
      .where("auth_id", "=", session.user.id)
      .executeTakeFirst();

    return json({ ...session, profile: profile && await withAccess(profile) });
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
      const email = session.user.email;
      const meta = (session.user as { user_metadata?: Record<string, unknown> }).user_metadata ?? {};
      const fullName = typeof meta.full_name === "string" ? meta.full_name.trim() : "";
      const givenName = typeof meta.given_name === "string" ? meta.given_name.trim() : "";
      const familyName = typeof meta.family_name === "string" ? meta.family_name.trim() : "";
      const [firstFromFull, ...restFromFull] = fullName.split(/\s+/);
      const name = (givenName || firstFromFull || email.split("@")[0]).slice(0, 100);
      const lastName = (familyName || restFromFull.join(" ")).slice(0, 100);

      // The email's local part is often taken already; retry with a short
      // random suffix until the username is free.
      for (let attempt = 0; attempt < 5 && !profile; attempt++) {
        const insert: UserInsert = {
          username: usernameCandidate(email, attempt),
          email,
          name,
          last_name: lastName,
          auth_id: session.user.id,
        };
        try {
          profile = await db
            .insertInto("users")
            .values(insert)
            .returning(SAFE_COLUMNS)
            .executeTakeFirstOrThrow();
        } catch (err) {
          if (!isUniqueViolation(err)) throw err;
          if (pgConstraint(err) === "users_email_key") {
            return jsonError(
              "An account with this email already exists. Sign in with your password instead.",
              409,
              { code: "email_taken" },
            );
          }
          if (pgConstraint(err) !== "users_username_key") throw err;
        }
      }
      if (!profile) return jsonError("Couldn't pick a username, please try again", 409);
    }

    return json({ ...session, profile: profile && await withAccess(profile) });
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

    // 2. Confirm the email on the auth user and set the chosen password with
    //    the new session, which stays valid for the app.
    const { error: confirmErr } = await supabaseAdmin.auth.admin.updateUserById(
      session.user.id,
      { email_confirm: true },
    );
    if (confirmErr) return jsonError(confirmErr.message, 400);
    const passwordErr = await setOwnPassword(session.access_token, password);
    if (passwordErr) return jsonError(passwordErr, 400);

    // 3. Return the session alongside the public profile.
    const profile = await db
      .selectFrom("users")
      .select(SAFE_COLUMNS)
      .where("auth_id", "=", session.user.id)
      .executeTakeFirst();

    return json({ ...session, profile: profile && await withAccess(profile) });
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
    if (profile) profile.email = await syncConfirmedEmail(profile, user.email);

    return json({ authenticated: true, profile: profile && await withAccess(profile) });
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

    // The recovery session stays signed in (the app continues to /home).
    const token = req.headers.get("Authorization")!.replace(/^Bearer\s+/i, "");
    const passwordErr = await setOwnPassword(token, password);
    if (passwordErr) return jsonError(passwordErr, 400);

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

    const token = req.headers.get("Authorization")!.replace(/^Bearer\s+/i, "");
    const passwordErr = await setOwnPassword(token, new_password);
    if (passwordErr) return jsonError(passwordErr, 400);

    return json({ success: true });
  }

  // ── POST /users/change-email ─────────────────────────────────────────────────
  // {new_email, password}. Verifies the password, then asks GoTrue to start a
  // secure email change: it emails a confirmation link to the new address and
  // only switches the login email once that link is opened. GET /users/me
  // (and /users/test) copy the confirmed address onto the profile.
  if (req.method === "POST" && segment === "change-email") {
    const body = await req.json().catch(() => null);
    const newEmail = typeof body?.new_email === "string" ? body.new_email.trim().toLowerCase() : "";
    const password = body?.password;
    if (!newEmail || !password) return jsonError("new_email and password are required", 400);
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(newEmail)) return jsonError("Enter a valid email address", 400);
    if (!user.email) return jsonError("This account has no email to change", 400);
    if (newEmail === user.email.toLowerCase()) return jsonError("That's already your email", 400);

    const taken = await db.selectFrom("users").select("id").where("email", "=", newEmail).executeTakeFirst();
    if (taken) return jsonError("An account with this email already exists", 409, { code: "email_taken" });

    const check = await authFetch("/token?grant_type=password", { email: user.email, password });
    if (!check.ok) return jsonError("Password is incorrect", 400, { code: "invalid_password" });

    const token = req.headers.get("Authorization")!.replace(/^Bearer\s+/i, "");
    const res = await fetch(
      `${supabaseUrl}/auth/v1/user?redirect_to=${encodeURIComponent(inviteRedirect())}`,
      {
        method: "PUT",
        headers: {
          "Content-Type": "application/json",
          apikey: supabaseAnonKey,
          Authorization: `Bearer ${token}`,
        },
        body: JSON.stringify({ email: newEmail }),
      },
    );
    const raw = await res.json().catch(() => null);
    if (!res.ok) {
      const message = authErrorMessage(raw, "Could not start the email change");
      if (/already/i.test(message)) {
        return jsonError("An account with this email already exists", 409, { code: "email_taken" });
      }
      return jsonError(message, res.status >= 500 ? 502 : 400);
    }

    return json({
      success: true,
      pending_email: newEmail,
      message: `We sent a confirmation link to ${newEmail}. Your email changes once you open it.`,
    });
  }

  // Everything below needs the caller's public profile.
  const { caller, response } = await requireCaller(req);
  if (!caller) return response;

  // ── GET /users/me/settings ───────────────────────────────────────────────────
  // The caller's preferences; defaults when they never saved any.
  if (req.method === "GET" && pathname === "/users/me/settings") {
    return json(await loadSettings(caller.id));
  }

  // ── PUT /users/me/settings ───────────────────────────────────────────────────
  // Partial update: {push_enabled?, muted_types?, weight_unit?, theme_mode?, locale?,
  // weekly_workout_target?, show_on_gym_boards?, timezone?, fitness_goal?,
  // goal_weight_kg?, water_goal_ml?, water_cups?, water_reminders?, onboarded?}.
  // Returns the full settings after the write.
  if (req.method === "PUT" && pathname === "/users/me/settings") {
    const body = await req.json().catch(() => null);
    if (!body || typeof body !== "object" || Array.isArray(body)) {
      return jsonError("Request body must be a JSON object", 400);
    }
    const parsed = parseSettings(body as Record<string, unknown>);
    if (typeof parsed === "string") return jsonError(parsed, 400);
    if (Object.keys(parsed).length === 0) return jsonError("Nothing to update", 400);

    const now = new Date().toISOString();
    await db
      .insertInto("user_settings")
      .values({ user_id: caller.id, ...parsed, updated_at: now })
      .onConflict((oc) => oc.column("user_id").doUpdateSet({ ...parsed, updated_at: now }))
      .execute();

    return json(await loadSettings(caller.id));
  }

  // ── POST /users/impersonate ──────────────────────────────────────────────────
  // {user_id}. Super users only: returns a live session for another
  // (non-super) user plus their profile, for support. Every use is written to
  // admin_audit_log. The app keeps the admin's own session aside and restores
  // it when they're done (and logs the impersonated session out).
  if (req.method === "POST" && segment === "impersonate") {
    if (!isSuperUser(caller)) return jsonError("Only a super user can sign in as someone else", 403);

    const body = await req.json().catch(() => null);
    const targetId = body?.user_id;
    if (!targetId || typeof targetId !== "string") return jsonError("user_id is required", 400);

    const target = await db
      .selectFrom("users")
      .select(SAFE_COLUMNS)
      .where("id", "=", targetId)
      .executeTakeFirst()
      .catch((err) => {
        if (pgCode(err) === "22P02") return undefined; // not a uuid
        throw err;
      });
    if (!target) return jsonError("User not found", 404);
    if (target.is_super_user) return jsonError("You can't sign in as another super user", 403);
    if (!target.auth_id) return jsonError("This user has no login account yet", 409);

    const { data: authData, error: authErr } = await supabaseAdmin.auth.admin.getUserById(target.auth_id);
    const authEmail = authData?.user?.email;
    if (authErr || !authEmail) return jsonError("This user has no login account yet", 409);

    const minted = await mintSession(authEmail);
    if ("error" in minted) return jsonError(minted.error, minted.status);

    await db
      .insertInto("admin_audit_log")
      .values({
        actor_id: caller.id,
        action: "impersonate",
        target_user_id: target.id,
        metadata: { target_email: target.email, actor_email: caller.email },
      })
      .execute();

    return json({ ...minted.session, profile: await withAccess(target) });
  }

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

  // ── PUT /users/me/trainer {enabled} ───────────────────────────────────────────
  // Anyone can be a trainer. Switching it off also leaves every gym they train
  // at (and drops open trainer invites); their clients and classes stay.
  if (req.method === "PUT" && pathname === "/users/me/trainer") {
    const body = await req.json().catch(() => null);
    if (typeof body?.enabled !== "boolean") return jsonError("enabled (boolean) is required", 400);
    await db.transaction().execute(async (trx) => {
      await trx.updateTable("users").set({ is_trainer: body.enabled }).where("id", "=", caller.id).execute();
      if (!body.enabled) {
        await trx.deleteFrom("business_member").where("user_id", "=", caller.id).where("role", "=", "trainer")
          .execute();
      }
    });
    const profile = await db.selectFrom("users").select(SAFE_COLUMNS).where("id", "=", caller.id)
      .executeTakeFirstOrThrow();
    return json(await withAccess(profile));
  }

  // ── GET /users/me ─────────────────────────────────────────────────────────────
  // Also picks up a confirmed email change (see POST /users/change-email).
  if (req.method === "GET" && segment === "me") {
    const profile = await db
      .selectFrom("users")
      .select(SAFE_COLUMNS)
      .where("id", "=", caller.id)
      .executeTakeFirst();

    if (!profile) return jsonError("Profile not found", 404);
    profile.email = await syncConfirmedEmail(profile, caller.authUser.email);
    return json(await withAccess(profile));
  }

  // ── GET /users — optional ?email= filter ─────────────────────────────────────
  // The full list is super-user only (user admin). An exact ?email= lookup is
  // also open to anyone who owns or staffs a gym or shop (to add or invite
  // that person) and returns at most that one user.
  if (req.method === "GET" && !segment) {
    const emailFilter = url.searchParams.get("email")?.trim();
    const isSuper = isSuperUser(caller);
    if (!emailFilter) {
      if (!isSuper) return jsonError("Only a super user can list users", 403);
      return json(await db.selectFrom("users").select(SAFE_COLUMNS).execute());
    }
    if (!isSuper && !(await staffsAnyBusiness(caller))) {
      return jsonError("Only gym and shop staff can look users up by email", 403);
    }
    const match = await db
      .selectFrom("users")
      .select(isSuper ? SAFE_COLUMNS : [...PUBLIC_COLUMNS, "email"])
      .where(sql`lower(email)`, "=", emailFilter.toLowerCase())
      .limit(1)
      .executeTakeFirst();
    return json(match ? [match] : []);
  }

  // ── GET /users/:id ────────────────────────────────────────────────────────────
  // Any signed-in user gets the public profile. email and auth_id are only
  // included for the user themself, super users, and staff of a gym/shop the
  // user belongs to.
  if (req.method === "GET" && id) {
    const u = await db
      .selectFrom("users")
      .select(SAFE_COLUMNS)
      .where("id", "=", id)
      .executeTakeFirst()
      .catch((err) => {
        if (pgCode(err) === "22P02") return undefined; // not a uuid
        throw err;
      });

    if (!u) return jsonError("User not found", 404);
    if (u.id === caller.id || (await canInvite(caller, u.id))) return json(u);
    const { id: userId, username, name, last_name, is_trainer, avatar_url } = u;
    return json({ id: userId, username, name, last_name, is_trainer, avatar_url });
  }

  // ── PUT /users/:id ────────────────────────────────────────────────────────────
  // Users edit their own display fields. Only a super user can edit someone
  // else, change an email address, or make someone a super user.
  if (req.method === "PUT" && id) {
    const isSelf = id === caller.id;
    const isSuper = isSuperUser(caller);
    if (!isSelf && !isSuper) return jsonError("You can only edit your own profile", 403);

    const body = await req.json().catch(() => null);
    if (!body || Object.keys(body).length === 0) {
      return jsonError("Request body must not be empty", 400);
    }

    const allowed = isSuper
      ? ["username", "name", "last_name", "avatar_url", "email", "is_super_user"]
      : ["username", "name", "last_name", "avatar_url"];
    const rejected = Object.keys(body).filter((k) => !allowed.includes(k) && !["id", "created_at", "updated_at", "auth_id"].includes(k));
    if (rejected.length > 0) {
      return jsonError(`You can't change: ${rejected.join(", ")}`, 403);
    }

    const update: UserUpdate = {};
    for (const key of allowed) {
      if (key in body) (update as Record<string, unknown>)[key] = body[key];
    }
    if (update.is_super_user !== undefined && typeof update.is_super_user !== "boolean") {
      return jsonError("is_super_user must be a boolean", 400);
    }
    if (update.is_super_user === false && id === caller.id) {
      return jsonError("You can't remove your own super user access", 400);
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

    const owns = await db.selectFrom("business_member").select("business_id")
      .where("user_id", "=", id).where("role", "=", "owner").where("status", "=", "active").executeTakeFirst();
    if (owns) {
      return jsonError("This account owns a gym or shop. Delete those businesses first.", 409);
    }

    // Personal posts and stories go with the account (business posts stay,
    // authorless), and so do the private files behind them.
    const personalMedia = await db.selectFrom("post_image")
      .innerJoin("post", "post.id", "post_image.post_id")
      .select("post_image.storage_path")
      .where("post.author_id", "=", id)
      .where("post.business_id", "is", null)
      .where("post_image.storage_path", "is not", null)
      .execute();
    const storyMedia = await db.selectFrom("story").select("storage_path")
      .where("author_id", "=", id).where("storage_path", "is not", null).execute();
    const pendingUploads = await db.selectFrom("media_upload").select(["bucket", "storage_path"])
      .where("uploader_id", "=", id).where("claimed_at", "is", null).execute();
    const progressPhotos = await db.selectFrom("progress_photo").select("path").where("user_id", "=", id).execute();

    await db.transaction().execute(async (trx) => {
      await trx.deleteFrom("post").where("author_id", "=", id).where("business_id", "is", null).execute();
      // Team roles and follows cascade with the user.
      await trx.deleteFrom("member").where("user_id", "=", id).execute();

      const membershipIds = trx.selectFrom("membership").select("id").where("user_id", "=", id);
      await trx.deleteFrom("membership_invoice").where("membership_id", "in", membershipIds).execute();
      await trx.deleteFrom("membership").where("user_id", "=", id).execute();

      await trx.deleteFrom("users").where("id", "=", id).execute();
    });

    await removeObjects("user-media", [
      ...personalMedia.map((m) => m.storage_path!),
      ...storyMedia.map((m) => m.storage_path!),
      ...pendingUploads.filter((u) => u.bucket === "user-media").map((u) => u.storage_path),
    ]);
    await removeObjects("chat-media", pendingUploads.filter((u) => u.bucket === "chat-media").map((u) => u.storage_path));
    await removeObjects("progress-photos", [
      ...progressPhotos.map((p) => p.path),
      ...pendingUploads.filter((u) => u.bucket === "progress-photos").map((u) => u.storage_path),
    ]);

    if (target.auth_id) {
      const { error: authDelErr } = await supabaseAdmin.auth.admin.deleteUser(target.auth_id);
      if (authDelErr) console.error("Deleted profile but not auth user", target.auth_id, authDelErr.message);
    }

    return new Response(null, { status: 204 });
  }

  return jsonError("Not found", 404);
});
