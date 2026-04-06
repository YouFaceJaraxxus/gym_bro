import { db, supabaseAdmin, supabaseUrl, supabaseAnonKey, superAdminPass } from "../_shared/config.ts";
import type { AuthSession, UserInsert, UserUpdate } from "../../types/schema/public.ts";

const SAFE_COLUMNS = [
  "id",
  "username",
  "email",
  "name",
  "last_name",
  "role",
  "auth_id",
  "created_at",
  "updated_at",
] as const;

// ── Auth helpers ──────────────────────────────────────────────────────────────

async function requireAuth(req: Request) {
  const token = req.headers.get("Authorization")?.replace(/^Bearer\s+/i, "");
  if (!token) return { user: null, error: "Missing Authorization header" };
  const { data: { user }, error } = await supabaseAdmin.auth.getUser(token);
  return { user: error ? null : user, error: error?.message ?? null };
}

function authFetch(path: string, body: unknown): Promise<Response> {
  return fetch(`${supabaseUrl}/auth/v1${path}`, {
    method: "POST",
    headers: { "Content-Type": "application/json", apikey: supabaseAnonKey },
    body: JSON.stringify(body),
  });
}

// ── Path parsing ──────────────────────────────────────────────────────────────

const STATIC_SEGMENTS = new Set(["signup", "signin", "google", "refresh", "me", "test"]);

function parseSegment(pathname: string): string | null {
  const match = pathname.match(/^\/users\/([^/]+)$/);
  return match ? match[1] : null;
}

// ── Handler ───────────────────────────────────────────────────────────────────

Deno.serve(async (req: Request) => {
  const { pathname } = new URL(req.url);
  const segment = parseSegment(pathname);
  const id = segment && !STATIC_SEGMENTS.has(segment) ? segment : null;

  // ── POST /users/signup ────────────────────────────────────────────────────────
  // Creates a Supabase Auth user and a public profile. Sends a verification email.
  if (req.method === "POST" && segment === "signup") {
    const body = await req.json().catch(() => null);
    const { email, password, username, name, last_name, role } = body ?? {};

    if (!email || !password || !username || !name || !last_name) {
      return jsonError("Missing required fields: email, password, username, name, last_name", 400);
    }

    const { data, error } = await supabaseAdmin.auth.admin.createUser({
      email,
      password,
      email_confirm: false,
      user_metadata: { username, name, last_name },
    });

    if (error) return jsonError(error.message, 400);

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

    const { gym_id } = body ?? {};

    const user = await db
      .insertInto("users")
      .values(insert)
      .returning(SAFE_COLUMNS)
      .executeTakeFirstOrThrow();

    let role_assignment = null;
    if (role && gym_id && role in gymRoleTables) {
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

  // ── GET /users/me ─────────────────────────────────────────────────────────────
  if (req.method === "GET" && segment === "me") {
    const profile = await db
      .selectFrom("users")
      .select(SAFE_COLUMNS)
      .where("auth_id", "=", user.id)
      .executeTakeFirst();

    if (!profile) return jsonError("Profile not found", 404);
    return json(profile);
  }

  // ── GET /users ────────────────────────────────────────────────────────────────
  if (req.method === "GET" && !segment) {
    const users = await db.selectFrom("users").select(SAFE_COLUMNS).execute();
    return json(users);
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
  if (req.method === "PUT" && id) {
    const body = await req.json().catch(() => null);
    if (!body || Object.keys(body).length === 0) {
      return jsonError("Request body must not be empty", 400);
    }

    const { id: _id, created_at: _ca, auth_id: _aid, ...fields } = body;
    const update: UserUpdate = { ...fields };

    const u = await db
      .updateTable("users")
      .set(update)
      .where("id", "=", id)
      .returning(SAFE_COLUMNS)
      .executeTakeFirst();

    if (!u) return jsonError("User not found", 404);
    return json(u);
  }

  // ── DELETE /users/:id ─────────────────────────────────────────────────────────
  if (req.method === "DELETE" && id) {
    const result = await db
      .deleteFrom("users")
      .where("id", "=", id)
      .executeTakeFirst();

    if (!result.numDeletedRows) return jsonError("User not found", 404);
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
