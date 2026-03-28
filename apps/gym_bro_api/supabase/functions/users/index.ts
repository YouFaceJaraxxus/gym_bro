import { createClient } from "jsr:@supabase/supabase-js@2";

const supabase = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
);

/** Hash a password using SHA-256 via Web Crypto (not bcrypt — use a proper
 *  password hashing library like argon2 in production). */
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
    const { data, error } = await supabase
      .from("users")
      .select("id, username, email, name, last_name, created_at, updated_at");

    if (error) return jsonError(error.message, 500);
    return json(data);
  }

  // ── GET /users/:id ──────────────────────────────────────────────────────────
  if (req.method === "GET" && id) {
    const { data, error } = await supabase
      .from("users")
      .select("id, username, email, name, last_name, created_at, updated_at")
      .eq("id", id)
      .maybeSingle();

    if (error) return jsonError(error.message, 500);
    if (!data) return jsonError("User not found", 404);
    return json(data);
  }

  // ── POST /users ─────────────────────────────────────────────────────────────
  if (req.method === "POST" && !id) {
    const body = await req.json().catch(() => null);
    const { username, email, password, name, last_name } = body ?? {};

    if (!username || !email || !password || !name || !last_name) {
      return jsonError(
        "Missing required fields: username, email, password, name, last_name",
        400,
      );
    }

    const hashed = await hashPassword(password);
    const { data, error } = await supabase
      .from("users")
      .insert({ username, email, password: hashed, name, last_name })
      .select("id, username, email, name, last_name, created_at, updated_at")
      .single();

    if (error) return jsonError(error.message, 409);
    return json(data, 201);
  }

  // ── PUT /users/:id ──────────────────────────────────────────────────────────
  if (req.method === "PUT" && id) {
    const body = await req.json().catch(() => null);
    if (!body || Object.keys(body).length === 0) {
      return jsonError("Request body must not be empty", 400);
    }

    // Prevent id/created_at overrides; hash password if provided
    const { id: _id, created_at: _ca, ...fields } = body;
    if (fields.password) fields.password = await hashPassword(fields.password);

    const { data, error } = await supabase
      .from("users")
      .update(fields)
      .eq("id", id)
      .select("id, username, email, name, last_name, created_at, updated_at")
      .maybeSingle();

    if (error) return jsonError(error.message, 500);
    if (!data) return jsonError("User not found", 404);
    return json(data);
  }

  // ── DELETE /users/:id ───────────────────────────────────────────────────────
  if (req.method === "DELETE" && id) {
    const { error, count } = await supabase
      .from("users")
      .delete({ count: "exact" })
      .eq("id", id);

    if (error) return jsonError(error.message, 500);
    if (count === 0) return jsonError("User not found", 404);
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
