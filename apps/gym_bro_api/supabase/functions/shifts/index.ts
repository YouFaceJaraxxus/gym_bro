import { type Kysely, type RawBuilder, sql } from "npm:kysely@^0.27";
import { db } from "../_shared/config.ts";
import { canCoachAtGym, canManageGym, forbidden, json, jsonError, requireCaller } from "../_shared/auth.ts";
import { notify } from "../_shared/notify.ts";
import type { Database } from "../../types/schema/public.ts";

// ── Constants ─────────────────────────────────────────────────────────────────

const DAY_MS = 24 * 60 * 60 * 1000;
const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

/** Thrown inside a transaction to roll it back and answer with a 4xx. */
class HttpError extends Error {
  constructor(message: string, readonly status: number) {
    super(message);
  }
}

// ── Path helpers ──────────────────────────────────────────────────────────────
// /shifts          → { id: null, staff: false }
// /shifts/staff    → { id: null, staff: true }
// /shifts/:id      → { id, staff: false }

function parsePath(pathname: string): { id: string | null; staff: boolean } {
  if (/^\/shifts\/staff\/?$/.test(pathname)) return { id: null, staff: true };
  const single = pathname.match(/^\/shifts\/([^/]+)$/);
  return { id: single ? single[1] : null, staff: false };
}

// ── Small helpers ─────────────────────────────────────────────────────────────

function parseDate(value: unknown): Date | null {
  if (typeof value !== "string" || !value.trim()) return null;
  const d = new Date(value);
  return isNaN(d.getTime()) ? null : d;
}

function trimOrNull(value: unknown): string | null {
  if (typeof value !== "string") return null;
  const t = value.trim();
  return t ? t : null;
}

/** Monday 00:00 UTC of the current week. */
function startOfWeekUtc(now = new Date()): Date {
  const d = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate()));
  const dow = (d.getUTCDay() + 6) % 7; // Monday = 0
  return new Date(d.getTime() - dow * DAY_MS);
}

/** True when the user works at the gym as an employee, employee-trainer or trainer. */
async function isGymStaff(userId: string, gymId: string): Promise<boolean> {
  const { rows } = await sql<{ ok: number }>`
    SELECT 1 AS ok FROM employee WHERE user_id = ${userId} AND gym_id = ${gymId}
    UNION SELECT 1 FROM employee_trainer WHERE user_id = ${userId} AND gym_id = ${gymId}
    UNION SELECT 1 FROM trainer WHERE user_id = ${userId} AND gym_id = ${gymId}
  `.execute(db);
  return rows.length > 0;
}

type ShiftRow = {
  id: string;
  gym_id: string;
  user_id: string;
  starts_at: Date;
  ends_at: Date;
  note: string | null;
  created_by: string | null;
  created_at: Date;
  gym_name: string;
  name: string;
  last_name: string;
  avatar_url: string | null;
  user_name: string;
};

async function selectShifts(where: RawBuilder<unknown>[]): Promise<ShiftRow[]> {
  const whereSql = where.length ? sql`WHERE ${sql.join(where, sql` AND `)}` : sql``;
  const { rows } = await sql<ShiftRow>`
    SELECT s.*, b.name AS gym_name, u.name, u.last_name, u.avatar_url,
      TRIM(CONCAT(u.name, ' ', u.last_name)) AS user_name
    FROM staff_shift s
    JOIN business b ON b.id = s.gym_id
    JOIN users u ON u.id = s.user_id
    ${whereSql}
    ORDER BY s.starts_at, u.name
    LIMIT 1000
  `.execute(db);
  return rows;
}

/** Throws 409 when the user already has a shift overlapping [start, end). Call inside a transaction. */
async function assertNoOverlap(trx: Kysely<Database>, userId: string, start: Date, end: Date, excludeId?: string) {
  // Serialize writes per user so two concurrent requests can't both pass the check.
  await sql`SELECT pg_advisory_xact_lock(hashtext(${"staff_shift:" + userId}))`.execute(trx);
  const { rows } = await sql<{ id: string; gym_name: string }>`
    SELECT s.id, b.name AS gym_name FROM staff_shift s JOIN business b ON b.id = s.gym_id
    WHERE s.user_id = ${userId}
      AND s.starts_at < ${end.toISOString()} AND s.ends_at > ${start.toISOString()}
      ${excludeId ? sql`AND s.id <> ${excludeId}` : sql``}
    LIMIT 1
  `.execute(trx);
  if (rows.length) {
    throw new HttpError(`This person already has an overlapping shift at ${rows[0].gym_name}`, 409);
  }
}

async function gymNameOf(gymId: string): Promise<string> {
  const row = await db.selectFrom("business").select("name").where("id", "=", gymId).executeTakeFirst();
  return row?.name ?? "your gym";
}

// ── Postgres error mapping ────────────────────────────────────────────────────

function pgErrorResponse(e: unknown): Response {
  if (e instanceof HttpError) return jsonError(e.message, e.status);
  const err = e as { code?: string; message?: string; detail?: string } | null;
  switch (err?.code) {
    case "23505":
      return jsonError("Already exists", 409, { detail: err.detail });
    case "23503":
      return jsonError("Referenced record does not exist", 400, { detail: err.detail });
    case "23502":
    case "23514":
    case "22P02":
    case "22007":
    case "22008":
      return jsonError(err.message ?? "Invalid value", 400);
  }
  throw e;
}

// ── Handler ───────────────────────────────────────────────────────────────────

async function handler(req: Request): Promise<Response> {
  const { caller, response } = await requireCaller(req);
  if (response) return response;

  const url = new URL(req.url);
  const { id, staff } = parsePath(url.pathname);
  if (id && !UUID_RE.test(id)) return jsonError("Shift not found", 404);

  // ── GET /shifts/staff?gym_id= ─────────────────────────────────────────────────
  // {can_manage, staff: [{user_id, name, last_name, avatar_url, roles: [...]}]}
  if (req.method === "GET" && staff) {
    const gymId = url.searchParams.get("gym_id");
    if (!gymId || !UUID_RE.test(gymId)) return jsonError("gym_id is required", 400);
    if (!(await canCoachAtGym(caller, gymId))) return forbidden();

    const { rows } = await sql<{
      user_id: string;
      name: string;
      last_name: string;
      avatar_url: string | null;
      roles: string[];
    }>`
      SELECT u.id AS user_id, u.name, u.last_name, u.avatar_url,
        ARRAY_AGG(DISTINCT r.role ORDER BY r.role) AS roles
      FROM (
        SELECT user_id, 'employee' AS role FROM employee WHERE gym_id = ${gymId}
        UNION ALL SELECT user_id, 'employee_trainer' FROM employee_trainer WHERE gym_id = ${gymId}
        UNION ALL SELECT user_id, 'trainer' FROM trainer WHERE gym_id = ${gymId}
      ) r
      JOIN users u ON u.id = r.user_id
      GROUP BY u.id
      ORDER BY u.name, u.last_name
    `.execute(db);
    return json({ can_manage: await canManageGym(caller, gymId), staff: rows });
  }

  // ── GET /shifts?gym_id=&from=&to=  |  GET /shifts?mine=true[&from=&to=] ───────
  if (req.method === "GET" && !id) {
    const gymId = url.searchParams.get("gym_id");
    const mine = url.searchParams.get("mine") === "true" || !gymId;
    const fromParam = url.searchParams.get("from");
    const toParam = url.searchParams.get("to");

    const defaultFrom = mine ? new Date() : startOfWeekUtc();
    const from = fromParam ? parseDate(fromParam) : defaultFrom;
    const to = toParam
      ? parseDate(toParam)
      : new Date(Date.now() + (mine ? 30 : 14) * DAY_MS);
    if (!from || !to) return jsonError("from and to must be ISO-8601 timestamps", 400);

    const where: RawBuilder<unknown>[] = [
      sql`s.ends_at > ${from.toISOString()}`,
      sql`s.starts_at < ${to.toISOString()}`,
    ];
    if (mine) {
      where.push(sql`s.user_id = ${caller.id}`);
      if (gymId && UUID_RE.test(gymId)) where.push(sql`s.gym_id = ${gymId}`);
    } else {
      if (!UUID_RE.test(gymId!)) return jsonError("Invalid gym_id", 400);
      if (!(await canCoachAtGym(caller, gymId!))) return forbidden();
      where.push(sql`s.gym_id = ${gymId}`);
    }
    return json(await selectShifts(where));
  }

  // ── GET /shifts/:id ───────────────────────────────────────────────────────────
  if (req.method === "GET" && id) {
    const [row] = await selectShifts([sql`s.id = ${id}`]);
    if (!row) return jsonError("Shift not found", 404);
    if (row.user_id !== caller.id && !(await canCoachAtGym(caller, row.gym_id))) return forbidden();
    return json(row);
  }

  // ── POST /shifts {gym_id, user_id, starts_at, ends_at, note?} ─────────────────
  if (req.method === "POST" && !id) {
    const body = await req.json().catch(() => null);
    if (!body || typeof body !== "object") return jsonError("Invalid JSON body", 400);
    const { gym_id, user_id } = body;
    const start = parseDate(body.starts_at);
    const end = parseDate(body.ends_at);
    if (typeof gym_id !== "string" || !UUID_RE.test(gym_id)) return jsonError("gym_id is required", 400);
    if (typeof user_id !== "string" || !UUID_RE.test(user_id)) return jsonError("user_id is required", 400);
    if (!start || !end) return jsonError("starts_at and ends_at must be ISO-8601 timestamps", 400);
    if (end <= start) return jsonError("ends_at must be after starts_at", 400);
    if (!(await canManageGym(caller, gym_id))) return forbidden();
    if (!(await isGymStaff(user_id, gym_id))) {
      return jsonError("The user must be an employee, employee-trainer or trainer at this gym", 400);
    }

    const inserted = await db.transaction().execute(async (trx) => {
      await assertNoOverlap(trx, user_id, start, end);
      return await trx
        .insertInto("staff_shift")
        .values({
          gym_id,
          user_id,
          starts_at: start.toISOString(),
          ends_at: end.toISOString(),
          note: trimOrNull(body.note),
          created_by: caller.id,
        })
        .returning("id")
        .executeTakeFirstOrThrow();
    });

    const [row] = await selectShifts([sql`s.id = ${inserted.id}`]);
    if (user_id !== caller.id) {
      await notify([user_id], {
        type: "shift_assigned",
        title: "New shift",
        body: `You've been scheduled for a shift at ${row.gym_name}.`,
        metadata: { shift_id: row.id, gym_id, gym_name: row.gym_name },
      });
    }
    return json(row, 201);
  }

  // ── PUT /shifts/:id {user_id?, starts_at?, ends_at?, note?} ───────────────────
  if (req.method === "PUT" && id) {
    const body = await req.json().catch(() => null);
    if (!body || typeof body !== "object") return jsonError("Invalid JSON body", 400);
    const existing = await db.selectFrom("staff_shift").selectAll().where("id", "=", id).executeTakeFirst();
    if (!existing) return jsonError("Shift not found", 404);
    if (!(await canManageGym(caller, existing.gym_id))) return forbidden();

    const userId: string = body.user_id ?? existing.user_id;
    if (typeof userId !== "string" || !UUID_RE.test(userId)) return jsonError("Invalid user_id", 400);
    if (userId !== existing.user_id && !(await isGymStaff(userId, existing.gym_id))) {
      return jsonError("The user must be an employee, employee-trainer or trainer at this gym", 400);
    }
    const start = body.starts_at !== undefined ? parseDate(body.starts_at) : new Date(existing.starts_at);
    const end = body.ends_at !== undefined ? parseDate(body.ends_at) : new Date(existing.ends_at);
    if (!start || !end) return jsonError("starts_at and ends_at must be ISO-8601 timestamps", 400);
    if (end <= start) return jsonError("ends_at must be after starts_at", 400);

    await db.transaction().execute(async (trx) => {
      await assertNoOverlap(trx, userId, start, end, id);
      await trx
        .updateTable("staff_shift")
        .set({
          user_id: userId,
          starts_at: start.toISOString(),
          ends_at: end.toISOString(),
          ...("note" in body ? { note: trimOrNull(body.note) } : {}),
        })
        .where("id", "=", id)
        .execute();
    });

    const [row] = await selectShifts([sql`s.id = ${id}`]);
    const metadata = { shift_id: id, gym_id: existing.gym_id, gym_name: row.gym_name };
    const timeChanged = start.getTime() !== new Date(existing.starts_at).getTime() ||
      end.getTime() !== new Date(existing.ends_at).getTime();
    if (userId !== existing.user_id) {
      if (userId !== caller.id) {
        await notify([userId], {
          type: "shift_assigned",
          title: "New shift",
          body: `You've been scheduled for a shift at ${row.gym_name}.`,
          metadata,
        });
      }
      if (existing.user_id !== caller.id && new Date(existing.ends_at).getTime() > Date.now()) {
        await notify([existing.user_id], {
          type: "shift_assigned",
          title: "Shift removed",
          body: `One of your shifts at ${row.gym_name} was reassigned.`,
          metadata,
        });
      }
    } else if (timeChanged && userId !== caller.id) {
      await notify([userId], {
        type: "shift_assigned",
        title: "Shift changed",
        body: `The time of one of your shifts at ${row.gym_name} has changed.`,
        metadata,
      });
    }
    return json(row);
  }

  // ── DELETE /shifts/:id ────────────────────────────────────────────────────────
  if (req.method === "DELETE" && id) {
    const existing = await db.selectFrom("staff_shift").selectAll().where("id", "=", id).executeTakeFirst();
    if (!existing) return jsonError("Shift not found", 404);
    if (!(await canManageGym(caller, existing.gym_id))) return forbidden();

    await db.deleteFrom("staff_shift").where("id", "=", id).execute();
    if (existing.user_id !== caller.id && new Date(existing.ends_at).getTime() > Date.now()) {
      const gymName = await gymNameOf(existing.gym_id);
      await notify([existing.user_id], {
        type: "shift_assigned",
        title: "Shift cancelled",
        body: `One of your upcoming shifts at ${gymName} was cancelled.`,
        metadata: { shift_id: id, gym_id: existing.gym_id, gym_name: gymName },
      });
    }
    return new Response(null, { status: 204 });
  }

  return jsonError("Not found", 404);
}

Deno.serve(async (req: Request) => {
  try {
    return await handler(req);
  } catch (e) {
    return pgErrorResponse(e);
  }
});
