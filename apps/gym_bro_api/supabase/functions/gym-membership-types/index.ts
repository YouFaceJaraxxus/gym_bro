import { db, supabaseAdmin } from "../_shared/config.ts";
import type { GymMembershipTypeInsert, GymMembershipTypeUpdate } from "../../types/schema/public.ts";

// ── Auth ──────────────────────────────────────────────────────────────────────

async function requireAuth(req: Request) {
  const token = req.headers.get("Authorization")?.replace(/^Bearer\s+/i, "");
  if (!token) return { user: null, error: "Missing Authorization header" };
  const { data: { user }, error } = await supabaseAdmin.auth.getUser(token);
  return { user: error ? null : user, error: error?.message ?? null };
}

// ── Path parsing ──────────────────────────────────────────────────────────────

function parseId(pathname: string): string | null {
  const match = pathname.match(/^\/gym-membership-types\/([^/]+)$/);
  return match ? match[1] : null;
}

// ── Handler ───────────────────────────────────────────────────────────────────

Deno.serve(async (req: Request) => {
  const { user, error: authError } = await requireAuth(req);
  if (!user) return jsonError(authError ?? "Unauthorized", 401);

  const url = new URL(req.url);
  const id = parseId(url.pathname);

  // ── POST /gym-membership-types ────────────────────────────────────────────────
  if (req.method === "POST" && !id) {
    const body = await req.json().catch(() => null);
    const { name, monthly_cost, gym_id, is_active } = body ?? {};
    if (!name || monthly_cost == null || !gym_id) {
      return jsonError("Missing required fields: name, monthly_cost, gym_id", 400);
    }
    const insert: GymMembershipTypeInsert = {
      name,
      monthly_cost,
      gym_id,
      ...(is_active != null && { is_active }),
    };
    const row = await db
      .insertInto("gym_membership_type")
      .values(insert)
      .returningAll()
      .executeTakeFirstOrThrow();
    return json(row, 201);
  }

  // ── GET /gym-membership-types — optional ?gym_id= and/or ?is_active= ─────────
  if (req.method === "GET" && !id) {
    const gymId = url.searchParams.get("gym_id");
    const isActiveParam = url.searchParams.get("is_active");
    let query = db.selectFrom("gym_membership_type").selectAll();
    if (gymId) query = query.where("gym_id", "=", gymId);
    if (isActiveParam != null) {
      query = query.where("is_active", "=", isActiveParam === "true");
    }
    return json(await query.execute());
  }

  // ── GET /gym-membership-types/:id ─────────────────────────────────────────────
  if (req.method === "GET" && id) {
    const row = await db
      .selectFrom("gym_membership_type")
      .selectAll()
      .where("id", "=", id)
      .executeTakeFirst();
    if (!row) return jsonError("Membership type not found", 404);
    return json(row);
  }

  // ── PUT /gym-membership-types/:id ─────────────────────────────────────────────
  if (req.method === "PUT" && id) {
    const body = await req.json().catch(() => null);
    if (!body || Object.keys(body).length === 0) return jsonError("Body must not be empty", 400);
    const { id: _id, gym_id: _gym, ...fields } = body; // gym_id is immutable
    const update: GymMembershipTypeUpdate = fields;
    const row = await db
      .updateTable("gym_membership_type")
      .set(update)
      .where("id", "=", id)
      .returningAll()
      .executeTakeFirst();
    if (!row) return jsonError("Membership type not found", 404);
    return json(row);
  }

  // ── DELETE /gym-membership-types/:id ──────────────────────────────────────────
  if (req.method === "DELETE" && id) {
    const result = await db
      .deleteFrom("gym_membership_type")
      .where("id", "=", id)
      .executeTakeFirst();
    if (!result.numDeletedRows) return jsonError("Membership type not found", 404);
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
