import { db, supabaseAdmin } from "../_shared/config.ts";
import type { MembershipInsert, MembershipUpdate } from "../../types/schema/public.ts";

// ── Auth ──────────────────────────────────────────────────────────────────────

async function requireAuth(req: Request) {
  const token = req.headers.get("Authorization")?.replace(/^Bearer\s+/i, "");
  if (!token) return { user: null, error: "Missing Authorization header" };
  const { data: { user }, error } = await supabaseAdmin.auth.getUser(token);
  return { user: error ? null : user, error: error?.message ?? null };
}

// ── Path parsing ──────────────────────────────────────────────────────────────

function parseId(pathname: string): string | null {
  const match = pathname.match(/^\/memberships\/([^/]+)$/);
  return match ? match[1] : null;
}

// ── Handler ───────────────────────────────────────────────────────────────────

Deno.serve(async (req: Request) => {
  const { user, error: authError } = await requireAuth(req);
  if (!user) return jsonError(authError ?? "Unauthorized", 401);

  const url = new URL(req.url);
  const id = parseId(url.pathname);

  // ── POST /memberships ─────────────────────────────────────────────────────────
  if (req.method === "POST" && !id) {
    const body = await req.json().catch(() => null);
    const { user_id, current_membership_type_id, from_date, to_date, is_active } = body ?? {};
    if (!user_id || !current_membership_type_id || !from_date || !to_date) {
      return jsonError(
        "Missing required fields: user_id, current_membership_type_id, from_date, to_date",
        400,
      );
    }
    const insert: MembershipInsert = {
      user_id,
      current_membership_type_id,
      from_date,
      to_date,
      ...(is_active != null && { is_active }),
    };
    const row = await db
      .insertInto("membership")
      .values(insert)
      .returningAll()
      .executeTakeFirstOrThrow();
    return json(row, 201);
  }

  // ── GET /memberships — optional ?user_id= and/or ?is_active= filters ─────────
  if (req.method === "GET" && !id) {
    const userId = url.searchParams.get("user_id");
    const isActiveParam = url.searchParams.get("is_active");
    let query = db.selectFrom("membership").selectAll();
    if (userId) query = query.where("user_id", "=", userId);
    if (isActiveParam != null) {
      query = query.where("is_active", "=", isActiveParam === "true");
    }
    return json(await query.execute());
  }

  // ── GET /memberships/:id ──────────────────────────────────────────────────────
  if (req.method === "GET" && id) {
    const row = await db
      .selectFrom("membership")
      .selectAll()
      .where("id", "=", id)
      .executeTakeFirst();
    if (!row) return jsonError("Membership not found", 404);
    return json(row);
  }

  // ── PUT /memberships/:id ──────────────────────────────────────────────────────
  // Updatable: to_date, is_active, current_membership_type_id.
  if (req.method === "PUT" && id) {
    const body = await req.json().catch(() => null);
    if (!body || Object.keys(body).length === 0) return jsonError("Body must not be empty", 400);
    const { id: _id, user_id: _uid, from_date: _fd, ...fields } = body; // user_id and from_date are immutable
    const update: MembershipUpdate = { ...fields, last_updated_date: new Date().toISOString() };
    const row = await db
      .updateTable("membership")
      .set(update)
      .where("id", "=", id)
      .returningAll()
      .executeTakeFirst();
    if (!row) return jsonError("Membership not found", 404);
    return json(row);
  }

  // ── DELETE /memberships/:id ───────────────────────────────────────────────────
  if (req.method === "DELETE" && id) {
    const result = await db.deleteFrom("membership").where("id", "=", id).executeTakeFirst();
    if (!result.numDeletedRows) return jsonError("Membership not found", 404);
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
