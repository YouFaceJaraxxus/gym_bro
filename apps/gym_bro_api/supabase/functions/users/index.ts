import { db } from "../_shared/config.ts";
import type { UserInsert, UserUpdate } from "../../types/schema/public.ts";

const SAFE_COLUMNS = [
  "id",
  "username",
  "email",
  "name",
  "last_name",
  "role",
  "created_at",
  "updated_at",
] as const;

async function hashPassword(plain: string): Promise<string> {
  const encoded = new TextEncoder().encode(plain);
  const hashBuffer = await crypto.subtle.digest("SHA-256", encoded);
  return Array.from(new Uint8Array(hashBuffer))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

function userIdFromPath(pathname: string): string | null {
  const match = pathname.match(/^\/users\/([^/]+)$/);
  return match ? match[1] : null;
}

Deno.serve(async (req: Request) => {
  const url = new URL(req.url);
  const id = userIdFromPath(url.pathname);

  // ── GET /users ──────────────────────────────────────────────────────────────
  if (req.method === "GET" && !id) {
    const users = await db
      .selectFrom("users")
      .select(SAFE_COLUMNS)
      .execute();

    return json(users);
  }

  // ── GET /users/:id ──────────────────────────────────────────────────────────
  if (req.method === "GET" && id) {
    const user = await db
      .selectFrom("users")
      .select(SAFE_COLUMNS)
      .where("id", "=", id)
      .executeTakeFirst();

    if (!user) return jsonError("User not found", 404);
    return json(user);
  }

  // ── POST /users ─────────────────────────────────────────────────────────────
  if (req.method === "POST" && !id) {
    const body = await req.json().catch(() => null);
    const { username, email, password, name, last_name, role } = body ?? {};

    if (!username || !email || !password || !name || !last_name) {
      return jsonError(
        "Missing required fields: username, email, password, name, last_name",
        400,
      );
    }

    const insert: UserInsert = {
      username,
      email,
      password: await hashPassword(password),
      name,
      last_name,
      ...(role && { role }),
    };

    const user = await db
      .insertInto("users")
      .values(insert)
      .returning(SAFE_COLUMNS)
      .executeTakeFirst();

    return json(user, 201);
  }

  // ── PUT /users/:id ──────────────────────────────────────────────────────────
  if (req.method === "PUT" && id) {
    const body = await req.json().catch(() => null);
    if (!body || Object.keys(body).length === 0) {
      return jsonError("Request body must not be empty", 400);
    }

    const { id: _id, created_at: _ca, ...fields } = body;
    const update: UserUpdate = {
      ...fields,
      ...(fields.password && { password: await hashPassword(fields.password) }),
    };

    const user = await db
      .updateTable("users")
      .set(update)
      .where("id", "=", id)
      .returning(SAFE_COLUMNS)
      .executeTakeFirst();

    if (!user) return jsonError("User not found", 404);
    return json(user);
  }

  // ── DELETE /users/:id ───────────────────────────────────────────────────────
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
