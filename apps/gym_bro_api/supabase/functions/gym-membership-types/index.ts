import { db } from "../_shared/config.ts";
import { canManageGym, forbidden, json, jsonError, requireCaller } from "../_shared/auth.ts";
import type { GymMembershipTypeInsert, GymMembershipTypeUpdate } from "../../types/schema/public.ts";
import { pgCode } from "../_shared/roles.ts";

// ── Path parsing ──────────────────────────────────────────────────────────────

function parseId(pathname: string): string | null {
  const match = pathname.match(/^\/gym-membership-types\/([^/]+)$/);
  return match ? match[1] : null;
}

// ── Handler ───────────────────────────────────────────────────────────────────

Deno.serve(async (req: Request) => {
  const { caller, response } = await requireCaller(req);
  if (response) return response;

  const url = new URL(req.url);
  const id = parseId(url.pathname);

  // ── POST /gym-membership-types ────────────────────────────────────────────────
  if (req.method === "POST" && !id) {
    const body = await req.json().catch(() => null);
    const { name, monthly_cost, gym_id, is_active } = body ?? {};
    if (!name || monthly_cost == null || !gym_id) {
      return jsonError("Missing required fields: name, monthly_cost, gym_id", 400);
    }
    if (!(await canManageGym(caller, gym_id))) return forbidden();

    const insert: GymMembershipTypeInsert = {
      name,
      monthly_cost,
      gym_id,
      ...(is_active != null && { is_active }),
    };
    try {
      const row = await db
        .insertInto("gym_membership_type")
        .values(insert)
        .returningAll()
        .executeTakeFirstOrThrow();
      return json(row, 201);
    } catch (err) {
      if (pgCode(err) === "23503") return jsonError("Gym not found", 400);
      throw err;
    }
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
  // Updatable: name, monthly_cost, is_active (gym_id is immutable).
  if (req.method === "PUT" && id) {
    const body = await req.json().catch(() => null);
    if (!body || typeof body !== "object") return jsonError("Body must not be empty", 400);
    const update: GymMembershipTypeUpdate = {};
    if (body.name !== undefined) update.name = body.name;
    if (body.monthly_cost !== undefined) update.monthly_cost = body.monthly_cost;
    if (body.is_active !== undefined) update.is_active = body.is_active;
    if (Object.keys(update).length === 0) return jsonError("Body must not be empty", 400);

    const existing = await db
      .selectFrom("gym_membership_type")
      .select(["gym_id"])
      .where("id", "=", id)
      .executeTakeFirst();
    if (!existing) return jsonError("Membership type not found", 404);
    if (!(await canManageGym(caller, existing.gym_id))) return forbidden();

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
    const existing = await db
      .selectFrom("gym_membership_type")
      .select(["gym_id"])
      .where("id", "=", id)
      .executeTakeFirst();
    if (!existing) return jsonError("Membership type not found", 404);
    if (!(await canManageGym(caller, existing.gym_id))) return forbidden();

    try {
      await db.deleteFrom("gym_membership_type").where("id", "=", id).execute();
    } catch (err) {
      if (pgCode(err) === "23503") {
        return jsonError(
          "This membership type is used by memberships or invoices — deactivate it instead",
          409,
        );
      }
      throw err;
    }
    return new Response(null, { status: 204 });
  }

  return jsonError("Not found", 404);
});
