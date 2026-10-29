import { type RawBuilder, sql } from "npm:kysely@^0.27";
import { db } from "../_shared/config.ts";
import {
  type Caller,
  canCoachAtGym,
  canStaffGym,
  forbidden,
  isSuperUser,
  json,
  jsonError,
  requireCaller,
} from "../_shared/auth.ts";
import { notify } from "../_shared/notify.ts";
import { displayName, isBlockedBetween, isFollowing } from "../_shared/social.ts";
import {
  gymNameOf,
  isAcceptedCustomer,
  isTimezone,
  notifyPromoted,
  promoteWaitlist,
  topUpSeries,
} from "../_shared/class_series.ts";
import type { BookingStatus } from "../../types/schema/public.ts";

// ── Constants ─────────────────────────────────────────────────────────────────

const DAY_MS = 24 * 60 * 60 * 1000;
const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

// Bookings with status booked, attended or no_show occupy a seat (counted
// against capacity); waitlisted and cancelled don't.

/** Thrown inside a transaction to roll it back and answer with a 4xx. */
class HttpError extends Error {
  constructor(message: string, readonly status: number) {
    super(message);
  }
}

// ── Path helpers ──────────────────────────────────────────────────────────────
// /classes                              → { id: null, action: null }
// /classes/coaching-gyms                → { id: null, action: 'coaching_gyms' }
// /classes/:id                          → { id, action: null }
// /classes/:id/book                     → { id, action: 'book' }
// /classes/:id/addable                  → { id, action: 'addable' }
// /classes/:id/cancel-booking           → { id, action: 'cancel_booking' }
// /classes/:id/bookings/:bookingId      → { id, action: 'booking', bookingId }
// anything else                         → null (404)

type Action = "coaching_gyms" | "book" | "addable" | "cancel_booking" | "booking" | null;

function parsePath(pathname: string): { id: string | null; action: Action; bookingId?: string } | null {
  if (/^\/classes\/?$/.test(pathname)) return { id: null, action: null };
  if (/^\/classes\/coaching-gyms\/?$/.test(pathname)) return { id: null, action: "coaching_gyms" };

  const booking = pathname.match(/^\/classes\/([^/]+)\/bookings\/([^/]+)$/);
  if (booking) return { id: booking[1], action: "booking", bookingId: booking[2] };

  const book = pathname.match(/^\/classes\/([^/]+)\/book$/);
  if (book) return { id: book[1], action: "book" };

  const addable = pathname.match(/^\/classes\/([^/]+)\/addable$/);
  if (addable) return { id: addable[1], action: "addable" };

  const cancel = pathname.match(/^\/classes\/([^/]+)\/cancel-booking$/);
  if (cancel) return { id: cancel[1], action: "cancel_booking" };

  const single = pathname.match(/^\/classes\/([^/]+)$/);
  if (single) return { id: single[1], action: null };

  return null;
}

// ── Small helpers ─────────────────────────────────────────────────────────────

function parseDate(value: unknown): Date | null {
  if (typeof value !== "string" || !value.trim()) return null;
  const d = new Date(value);
  return isNaN(d.getTime()) ? null : d;
}

function isPositiveInt(value: unknown): value is number {
  return typeof value === "number" && Number.isInteger(value) && value > 0;
}

function trimOrNull(value: unknown): string | null {
  if (typeof value !== "string") return null;
  const t = value.trim();
  return t ? t : null;
}

/** Gyms where the user has any relationship: member, staff, trainer or owner. */
async function relatedGymIds(userId: string): Promise<Set<string>> {
  const { rows } = await sql<{ gym_id: string }>`
    SELECT gym_id FROM member           WHERE user_id = ${userId}
    UNION SELECT gym_id FROM trainer          WHERE user_id = ${userId}
    UNION SELECT gym_id FROM employee         WHERE user_id = ${userId}
    UNION SELECT gym_id FROM employee_trainer WHERE user_id = ${userId}
    UNION SELECT gym_id FROM gym_owner        WHERE user_id = ${userId}
  `.execute(db);
  return new Set(rows.map((r) => r.gym_id));
}

/** Gyms where the user coaches (canCoachAtGym): owners, employees, employee-trainers, trainers. */
async function coachGymIds(userId: string): Promise<Set<string>> {
  const { rows } = await sql<{ gym_id: string }>`
    SELECT gym_id FROM trainer          WHERE user_id = ${userId}
    UNION SELECT gym_id FROM employee         WHERE user_id = ${userId}
    UNION SELECT gym_id FROM employee_trainer WHERE user_id = ${userId}
    UNION SELECT gym_id FROM gym_owner        WHERE user_id = ${userId}
  `.execute(db);
  return new Set(rows.map((r) => r.gym_id));
}

async function isMember(userId: string, gymId: string): Promise<boolean> {
  const row = await db
    .selectFrom("member")
    .select("id")
    .where("user_id", "=", userId)
    .where("gym_id", "=", gymId)
    .executeTakeFirst();
  return !!row;
}

/** True when the user can be assigned as a class trainer at the gym. */
async function isTrainerAtGym(userId: string, gymId: string): Promise<boolean> {
  const { rows } = await sql<{ ok: number }>`
    SELECT 1 AS ok FROM trainer WHERE user_id = ${userId} AND gym_id = ${gymId}
    UNION SELECT 1 FROM employee_trainer WHERE user_id = ${userId} AND gym_id = ${gymId}
  `.execute(db);
  return rows.length > 0;
}

// ── Class rows ────────────────────────────────────────────────────────────────

type ClassRow = {
  id: string;
  gym_id: string;
  trainer_id: string | null;
  title: string;
  description: string | null;
  location: string | null;
  starts_at: Date;
  ends_at: Date;
  capacity: number;
  series_id: string | null;
  cancelled_at: Date | null;
  reminder_sent_at: Date | null;
  created_by: string | null;
  created_at: Date;
  updated_at: Date;
  gym_name: string;
  trainer_name: string | null;
  trainer_avatar_url: string | null;
  booked_count: number;
  waitlist_count: number;
  my_booking_id: string | null;
  my_booking_status: BookingStatus | null;
  my_waitlist_position: number | null;
  is_recurring: boolean;
  can_coach?: boolean;
};

/** Class columns + gym/trainer names, seat counts and the caller's own booking. */
async function selectClasses(callerId: string, where: RawBuilder<unknown>[]): Promise<ClassRow[]> {
  const whereSql = where.length ? sql`WHERE ${sql.join(where, sql` AND `)}` : sql``;
  const { rows } = await sql<ClassRow>`
    SELECT
      c.*,
      b.name AS gym_name,
      NULLIF(TRIM(CONCAT(t.name, ' ', t.last_name)), '') AS trainer_name,
      t.avatar_url AS trainer_avatar_url,
      (SELECT COUNT(*)::int FROM class_booking x
        WHERE x.class_id = c.id AND x.status IN ('booked', 'attended', 'no_show')) AS booked_count,
      (SELECT COUNT(*)::int FROM class_booking x
        WHERE x.class_id = c.id AND x.status = 'waitlisted') AS waitlist_count,
      cs.repeat <> 'none' AS is_recurring,
      mb.id AS my_booking_id,
      mb.status AS my_booking_status,
      CASE WHEN mb.status = 'waitlisted' THEN
        (SELECT COUNT(*)::int FROM class_booking x
          WHERE x.class_id = c.id AND x.status = 'waitlisted'
            AND (x.created_at, x.id) <= (mb.created_at, mb.id))
      END AS my_waitlist_position
    FROM gym_class c
    JOIN business b ON b.id = c.gym_id
    JOIN class_series cs ON cs.id = c.series_id
    LEFT JOIN users t ON t.id = c.trainer_id
    LEFT JOIN class_booking mb
      ON mb.class_id = c.id AND mb.user_id = ${callerId} AND mb.status <> 'cancelled'
    ${whereSql}
    ORDER BY c.starts_at, c.title
    LIMIT 1000
  `.execute(db);
  return rows;
}

async function selectClass(callerId: string, id: string): Promise<ClassRow | undefined> {
  const rows = await selectClasses(callerId, [sql`c.id = ${id}`]);
  return rows[0];
}

/** Adds can_coach to each row (true when the caller coaches at the class's gym). */
async function withCanCoach(caller: Caller, rows: ClassRow[]): Promise<ClassRow[]> {
  if (isSuperUser(caller)) return rows.map((r) => ({ ...r, can_coach: true }));
  const gyms = await coachGymIds(caller.id);
  return rows.map((r) => ({ ...r, can_coach: gyms.has(r.gym_id) }));
}

/** Booked + waitlisted user ids for the given classes, mapped to the first class each user is in. */
async function attendeesByUser(classIds: string[], statuses: BookingStatus[]): Promise<Map<string, string>> {
  const result = new Map<string, string>();
  if (classIds.length === 0) return result;
  const rows = await db
    .selectFrom("class_booking")
    .innerJoin("gym_class", "gym_class.id", "class_booking.class_id")
    .select(["class_booking.user_id", "class_booking.class_id"])
    .where("class_booking.class_id", "in", classIds)
    .where("class_booking.status", "in", statuses)
    .orderBy("gym_class.starts_at")
    .execute();
  for (const r of rows) if (!result.has(r.user_id)) result.set(r.user_id, r.class_id);
  return result;
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
  const route = parsePath(url.pathname);
  if (!route) return jsonError("Not found", 404);
  const { id, action, bookingId } = route;
  if (id && !UUID_RE.test(id)) return jsonError("Class not found", 404);
  if (bookingId && !UUID_RE.test(bookingId)) return jsonError("Booking not found", 404);

  // ── GET /classes/coaching-gyms ────────────────────────────────────────────────
  // Gyms where the caller can create classes, with the trainers that can be
  // assigned there: [{gym_id, gym_name, can_staff, trainers: [{user_id, name, last_name}]}]
  if (req.method === "GET" && action === "coaching_gyms") {
    const gymIds = isSuperUser(caller)
      ? (await db.selectFrom("gym").select("id").execute()).map((g) => g.id)
      : [...await coachGymIds(caller.id)];
    if (gymIds.length === 0) return json([]);

    const { rows } = await sql<{
      gym_id: string;
      gym_name: string;
      trainers: { user_id: string; name: string; last_name: string }[];
    }>`
      SELECT b.id AS gym_id, b.name AS gym_name,
        COALESCE((
          SELECT json_agg(json_build_object('user_id', u.id, 'name', u.name, 'last_name', u.last_name)
                          ORDER BY u.name, u.last_name)
          FROM users u
          WHERE u.id IN (
            SELECT user_id FROM trainer WHERE gym_id = b.id
            UNION SELECT user_id FROM employee_trainer WHERE gym_id = b.id
          )
        ), '[]'::json) AS trainers
      FROM business b
      WHERE b.id = ANY(${gymIds}::uuid[])
      ORDER BY b.name
    `.execute(db);

    const result = [];
    for (const r of rows) {
      result.push({ ...r, can_staff: await canStaffGym(caller, r.gym_id) });
    }
    return json(result);
  }

  // ── GET /classes ──────────────────────────────────────────────────────────────
  // ?gym_id= &from= &to= &trainer_id= &mine=true &include_cancelled=true
  if (req.method === "GET" && !id) {
    // Keeps timetables 90 days ahead even when the jobs cron isn't set up.
    await topUpSeries();
    const gymId = url.searchParams.get("gym_id");
    const trainerId = url.searchParams.get("trainer_id");
    const mine = url.searchParams.get("mine") === "true";
    const includeCancelled = url.searchParams.get("include_cancelled") === "true";
    const fromParam = url.searchParams.get("from");
    const toParam = url.searchParams.get("to");

    const from = fromParam ? parseDate(fromParam) : new Date();
    const to = toParam ? parseDate(toParam) : new Date((from ?? new Date()).getTime() + 14 * DAY_MS);
    if (!from || !to) return jsonError("from and to must be ISO-8601 timestamps", 400);
    if (gymId && !UUID_RE.test(gymId)) return jsonError("Invalid gym_id", 400);
    if (trainerId && !UUID_RE.test(trainerId)) return jsonError("Invalid trainer_id", 400);

    const where: RawBuilder<unknown>[] = [
      sql`c.ends_at > ${from.toISOString()}`,
      sql`c.starts_at < ${to.toISOString()}`,
    ];
    if (!includeCancelled) where.push(sql`c.cancelled_at IS NULL`);
    if (trainerId) where.push(sql`c.trainer_id = ${trainerId}`);

    if (mine) {
      where.push(sql`mb.id IS NOT NULL`);
      if (gymId) where.push(sql`c.gym_id = ${gymId}`);
    } else if (isSuperUser(caller)) {
      if (gymId) where.push(sql`c.gym_id = ${gymId}`);
    } else {
      const related = await relatedGymIds(caller.id);
      if (gymId) {
        if (!related.has(gymId)) return forbidden();
        where.push(sql`c.gym_id = ${gymId}`);
      } else {
        // Classes a trainer teaches elsewhere stay visible to them too, and
        // so do classes a coach added a non-member (a follower) to.
        const ids = [...related];
        where.push(sql`(c.gym_id = ANY(${ids}::uuid[]) OR c.trainer_id = ${caller.id} OR mb.id IS NOT NULL)`);
      }
    }

    return json(await withCanCoach(caller, await selectClasses(caller.id, where)));
  }

  // ── GET /classes/:id ──────────────────────────────────────────────────────────
  if (req.method === "GET" && id && !action) {
    const row = await selectClass(caller.id, id);
    if (!row) return jsonError("Class not found", 404);

    const canCoach = await canCoachAtGym(caller, row.gym_id);
    if (!canCoach && !row.my_booking_id && row.trainer_id !== caller.id) {
      const related = await relatedGymIds(caller.id);
      if (!related.has(row.gym_id)) return forbidden();
    }

    if (!canCoach) return json({ ...row, can_coach: false });

    const bookings = await db
      .selectFrom("class_booking")
      .innerJoin("users", "users.id", "class_booking.user_id")
      .select([
        "class_booking.id",
        "class_booking.user_id",
        "users.name",
        "users.last_name",
        "users.avatar_url",
        "class_booking.status",
        "class_booking.created_at",
      ])
      .where("class_booking.class_id", "=", id)
      .where("class_booking.status", "<>", "cancelled")
      .orderBy("class_booking.created_at")
      .orderBy("class_booking.id")
      .execute();
    return json({ ...row, can_coach: true, bookings });
  }

  // ── POST /classes ─────────────────────────────────────────────────────────────
  // {gym_id, title, description?, location?, starts_at, ends_at, capacity, trainer_id?, repeat_weeks?, timezone?}
  // One session, or the same slot weekly for repeat_weeks weeks, as a bounded
  // class_series (open-ended timetables go through /class-series).
  if (req.method === "POST" && !id) {
    const body = await req.json().catch(() => null);
    if (!body || typeof body !== "object") return jsonError("Invalid JSON body", 400);
    const { gym_id, capacity } = body;
    const title = trimOrNull(body.title);
    const startsAt = parseDate(body.starts_at);
    const endsAt = parseDate(body.ends_at);
    const repeatWeeks = body.repeat_weeks ?? 1;

    if (typeof gym_id !== "string" || !UUID_RE.test(gym_id)) return jsonError("gym_id is required", 400);
    if (!title) return jsonError("title is required", 400);
    if (!startsAt || !endsAt) return jsonError("starts_at and ends_at must be ISO-8601 timestamps", 400);
    if (endsAt <= startsAt) return jsonError("ends_at must be after starts_at", 400);
    if (!isPositiveInt(capacity)) return jsonError("capacity must be a positive integer", 400);
    if (!Number.isInteger(repeatWeeks) || repeatWeeks < 1 || repeatWeeks > 12) {
      return jsonError("repeat_weeks must be between 1 and 12", 400);
    }
    const durationMinutes = Math.round((endsAt.getTime() - startsAt.getTime()) / 60_000);
    if (durationMinutes < 5 || durationMinutes > 1440) {
      return jsonError("A class lasts between 5 minutes and 24 hours", 400);
    }
    if (body.timezone !== undefined && !(await isTimezone(body.timezone))) {
      return jsonError("timezone must be an IANA timezone name", 400);
    }
    const timezone: string = body.timezone ?? "UTC";
    if (!(await canCoachAtGym(caller, gym_id))) return forbidden();

    let trainerId: string | null = null;
    if (body.trainer_id) {
      if (typeof body.trainer_id !== "string" || !UUID_RE.test(body.trainer_id)) {
        return jsonError("Invalid trainer_id", 400);
      }
      if (!(await isTrainerAtGym(body.trainer_id, gym_id))) {
        return jsonError("The trainer must be a trainer or employee-trainer at this gym", 400);
      }
      // Plain trainers can only schedule their own classes.
      if (body.trainer_id !== caller.id && !(await canStaffGym(caller, gym_id))) {
        return forbidden("Trainers can only schedule their own classes");
      }
      trainerId = body.trainer_id;
    } else if (await isTrainerAtGym(caller.id, gym_id)) {
      trainerId = caller.id;
    }

    const ids = await db.transaction().execute(async (trx) => {
      const { rows: [local] } = await sql<{ day: string; last_day: string; time: string; dow: number }>`
        SELECT to_char(l, 'YYYY-MM-DD') AS day,
               to_char(l::date + ${7 * (repeatWeeks - 1)}::int, 'YYYY-MM-DD') AS last_day,
               to_char(l, 'HH24:MI:SS') AS time,
               EXTRACT(ISODOW FROM l)::int AS dow
        FROM (SELECT ${startsAt.toISOString()}::timestamptz AT TIME ZONE ${timezone} AS l) x
      `.execute(trx);
      const series = await trx.insertInto("class_series").values({
        gym_id,
        trainer_id: trainerId,
        title,
        description: trimOrNull(body.description),
        location: trimOrNull(body.location),
        capacity,
        duration_minutes: durationMinutes,
        repeat: repeatWeeks > 1 ? "weekly" : "none",
        weekdays: repeatWeeks > 1 ? [local.dow] : [],
        times: [local.time],
        timezone,
        starts_on: local.day,
        ends_on: local.last_day,
        generated_until: local.last_day,
        created_by: caller.id,
      }).returning("id").executeTakeFirstOrThrow();
      // Weekly in local time, so a daylight-saving change keeps the clock time.
      const { rows } = await sql<{ id: string }>`
        INSERT INTO gym_class (gym_id, trainer_id, title, description, location, starts_at, ends_at, slot_at,
                               capacity, series_id, created_by)
        SELECT s.gym_id, s.trainer_id, s.title, s.description, s.location,
               x.slot, x.slot + make_interval(mins => s.duration_minutes), x.slot, s.capacity, s.id, s.created_by
        FROM class_series s,
          (SELECT ((s2.starts_on + 7 * i) + s2.times[1]) AT TIME ZONE s2.timezone AS slot
           FROM class_series s2, generate_series(0, ${repeatWeeks - 1}::int) AS i WHERE s2.id = ${series.id}) x
        WHERE s.id = ${series.id}
        ORDER BY x.slot
        RETURNING id
      `.execute(trx);
      return rows.map((r) => r.id);
    });
    const rows = await selectClasses(caller.id, [sql`c.id = ANY(${ids}::uuid[])`]);
    return json(rows.map((r) => ({ ...r, can_coach: true })), 201);
  }

  // ── PUT /classes/:id ──────────────────────────────────────────────────────────
  // {title?, description?, location?, starts_at?, ends_at?, capacity?, trainer_id?, apply_to_series?}
  if (req.method === "PUT" && id && !action) {
    const body = await req.json().catch(() => null);
    if (!body || typeof body !== "object") return jsonError("Invalid JSON body", 400);

    const existing = await db.selectFrom("gym_class").selectAll().where("id", "=", id).executeTakeFirst();
    if (!existing) return jsonError("Class not found", 404);
    if (!(await canCoachAtGym(caller, existing.gym_id))) return forbidden();
    const isStaff = await canStaffGym(caller, existing.gym_id);
    if (!isStaff && existing.trainer_id !== caller.id && existing.created_by !== caller.id) {
      return forbidden("Trainers can only edit their own classes");
    }
    if (existing.cancelled_at) return jsonError("This class has been cancelled", 400);

    // Validate the incoming fields.
    const patch: {
      title?: string;
      description?: string | null;
      location?: string | null;
      capacity?: number;
      trainer_id?: string | null;
    } = {};
    if ("title" in body) {
      const t = trimOrNull(body.title);
      if (!t) return jsonError("title can't be empty", 400);
      patch.title = t;
    }
    if ("description" in body) patch.description = trimOrNull(body.description);
    if ("location" in body) patch.location = trimOrNull(body.location);
    if ("capacity" in body) {
      if (!isPositiveInt(body.capacity)) return jsonError("capacity must be a positive integer", 400);
      patch.capacity = body.capacity;
    }
    if ("trainer_id" in body) {
      if (body.trainer_id === null || body.trainer_id === "") {
        patch.trainer_id = null;
      } else {
        if (typeof body.trainer_id !== "string" || !UUID_RE.test(body.trainer_id)) {
          return jsonError("Invalid trainer_id", 400);
        }
        if (!(await isTrainerAtGym(body.trainer_id, existing.gym_id))) {
          return jsonError("The trainer must be a trainer or employee-trainer at this gym", 400);
        }
        if (body.trainer_id !== caller.id && !isStaff) {
          return forbidden("Trainers can only assign classes to themselves");
        }
        patch.trainer_id = body.trainer_id;
      }
    }

    const oldStart = new Date(existing.starts_at);
    const oldEnd = new Date(existing.ends_at);
    let startDelta = 0;
    let endDelta = 0;
    if (body.starts_at !== undefined) {
      const d = parseDate(body.starts_at);
      if (!d) return jsonError("starts_at must be an ISO-8601 timestamp", 400);
      startDelta = d.getTime() - oldStart.getTime();
    }
    if (body.ends_at !== undefined) {
      const d = parseDate(body.ends_at);
      if (!d) return jsonError("ends_at must be an ISO-8601 timestamp", 400);
      endDelta = d.getTime() - oldEnd.getTime();
    } else {
      endDelta = startDelta; // moving the start keeps the duration
    }

    const series = await db.selectFrom("class_series").select(["repeat", "timezone"])
      .where("id", "=", existing.series_id).executeTakeFirstOrThrow();
    const applyToSeries = body.apply_to_series === true && series.repeat !== "none";
    // The timetable follows edits to every upcoming session, or to a one-off.
    const syncTemplate = applyToSeries || series.repeat === "none";

    const outcome = await db.transaction().execute(async (trx) => {
      const targets = applyToSeries
        ? (await sql<{ id: string; starts_at: Date; ends_at: Date; location: string | null }>`
            SELECT id, starts_at, ends_at, location FROM gym_class
            WHERE series_id = ${existing.series_id} AND starts_at >= ${existing.starts_at}
              AND cancelled_at IS NULL
            ORDER BY starts_at
            FOR UPDATE
          `.execute(trx)).rows
        : (await sql<{ id: string; starts_at: Date; ends_at: Date; location: string | null }>`
            SELECT id, starts_at, ends_at, location FROM gym_class WHERE id = ${id} FOR UPDATE
          `.execute(trx)).rows;

      const changed: string[] = [];
      const promoted = new Map<string, string[]>();
      for (const t of targets) {
        const start = new Date(new Date(t.starts_at).getTime() + startDelta);
        const end = new Date(new Date(t.ends_at).getTime() + endDelta);
        if (end <= start) throw new HttpError("ends_at must be after starts_at", 400);

        if (patch.capacity !== undefined) {
          const { rows: [{ taken }] } = await sql<{ taken: number }>`
            SELECT COUNT(*)::int AS taken FROM class_booking
            WHERE class_id = ${t.id} AND status IN ('booked', 'attended', 'no_show')
          `.execute(trx);
          if (patch.capacity < taken) {
            throw new HttpError(`Capacity can't be below the ${taken} people already booked`, 400);
          }
        }

        await trx
          .updateTable("gym_class")
          .set({
            ...patch,
            starts_at: start.toISOString(),
            ends_at: end.toISOString(),
            ...(syncTemplate ? { slot_at: start.toISOString() } : {}),
            updated_at: sql<string>`NOW()`,
            // A moved class gets a fresh reminder.
            ...(startDelta !== 0 ? { reminder_sent_at: null } : {}),
          })
          .where("id", "=", t.id)
          .execute();

        const locationChanged = patch.location !== undefined && patch.location !== t.location;
        if (startDelta !== 0 || endDelta !== 0 || locationChanged) changed.push(t.id);

        if (patch.capacity !== undefined) {
          const ids = await promoteWaitlist(trx, t.id, patch.capacity);
          if (ids.length) promoted.set(t.id, ids);
        }
      }

      if (syncTemplate) {
        await trx.updateTable("class_series").set({ ...patch, updated_at: sql<string>`NOW()` })
          .where("id", "=", existing.series_id).execute();
        const newStart = new Date(oldStart.getTime() + startDelta).toISOString();
        if (series.repeat === "none") {
          await sql`
            UPDATE class_series SET
              starts_on = (${newStart}::timestamptz AT TIME ZONE timezone)::date,
              ends_on = (${newStart}::timestamptz AT TIME ZONE timezone)::date,
              generated_until = (${newStart}::timestamptz AT TIME ZONE timezone)::date,
              times = ARRAY[(${newStart}::timestamptz AT TIME ZONE timezone)::time],
              duration_minutes = LEAST(1440, GREATEST(5, duration_minutes + ${Math.round((endDelta - startDelta) / 60_000)}::int))
            WHERE id = ${existing.series_id}
          `.execute(trx);
        } else if (startDelta !== 0 || endDelta !== 0) {
          await sql`
            UPDATE class_series SET
              times = ARRAY(SELECT DISTINCT (t + make_interval(secs => ${startDelta / 1000}::double precision))::time
                            FROM unnest(times) t ORDER BY 1),
              duration_minutes = LEAST(1440, GREATEST(5, duration_minutes + ${Math.round((endDelta - startDelta) / 60_000)}::int))
            WHERE id = ${existing.series_id}
          `.execute(trx);
        }
      }
      return { changed, promoted };
    });

    // ── Notifications (after commit) ──
    const gymName = await gymNameOf(existing.gym_id);
    const title = patch.title ?? existing.title;
    const affected = await attendeesByUser(outcome.changed, ["booked", "waitlisted"]);
    const byClass = new Map<string, string[]>();
    for (const [userId, classId] of affected) {
      if (userId === caller.id) continue;
      byClass.set(classId, [...(byClass.get(classId) ?? []), userId]);
    }
    for (const [classId, userIds] of byClass) {
      await notify(userIds, {
        type: "events",
        title: `Class updated: ${title}`,
        body: applyToSeries
          ? `The time or location of ${title} at ${gymName} has changed for upcoming classes. Tap to see the details.`
          : `The time or location of ${title} at ${gymName} has changed. Tap to see the details.`,
        metadata: { class_id: classId, gym_id: existing.gym_id, gym_name: gymName },
      });
    }
    for (const [classId, userIds] of outcome.promoted) {
      await notifyPromoted(userIds, { id: classId, gym_id: existing.gym_id, title });
    }

    const row = await selectClass(caller.id, id);
    return json({ ...row, can_coach: true });
  }

  // ── DELETE /classes/:id[?series=true] ─────────────────────────────────────────
  // Cancels (sets cancelled_at); bookings are kept for history.
  if (req.method === "DELETE" && id && !action) {
    const existing = await db.selectFrom("gym_class").selectAll().where("id", "=", id).executeTakeFirst();
    if (!existing) return jsonError("Class not found", 404);
    if (!(await canCoachAtGym(caller, existing.gym_id))) return forbidden();
    if (
      !(await canStaffGym(caller, existing.gym_id)) &&
      existing.trainer_id !== caller.id && existing.created_by !== caller.id
    ) {
      return forbidden("Trainers can only cancel their own classes");
    }

    const seriesRow = await db.selectFrom("class_series").select("repeat")
      .where("id", "=", existing.series_id).executeTakeFirstOrThrow();
    const series = url.searchParams.get("series") === "true" && seriesRow.repeat !== "none";
    let query = db
      .updateTable("gym_class")
      .set({ cancelled_at: sql<string>`NOW()`, updated_at: sql<string>`NOW()` })
      .where("cancelled_at", "is", null);
    query = series
      ? query.where("series_id", "=", existing.series_id).where("starts_at", ">=", existing.starts_at)
      : query.where("id", "=", id);
    const cancelled = await query.returning(["id", "starts_at"]).execute();
    if (series || seriesRow.repeat === "none") {
      // The timetable ends the day before (or stops, from its first day on).
      await sql`
        UPDATE class_series SET
          active = active AND (${existing.starts_at}::timestamptz AT TIME ZONE timezone)::date > starts_on,
          ends_on = CASE WHEN (${existing.starts_at}::timestamptz AT TIME ZONE timezone)::date > starts_on
                         THEN (${existing.starts_at}::timestamptz AT TIME ZONE timezone)::date - 1 ELSE ends_on END,
          updated_at = NOW()
        WHERE id = ${existing.series_id}
      `.execute(db);
    }

    const now = Date.now();
    const upcoming = cancelled.filter((c) => new Date(c.starts_at).getTime() > now).map((c) => c.id);
    const affected = await attendeesByUser(upcoming, ["booked", "waitlisted"]);
    if (affected.size) {
      const gymName = await gymNameOf(existing.gym_id);
      const byClass = new Map<string, string[]>();
      for (const [userId, classId] of affected) {
        if (userId === caller.id) continue;
        byClass.set(classId, [...(byClass.get(classId) ?? []), userId]);
      }
      for (const [classId, userIds] of byClass) {
        await notify(userIds, {
          type: "events",
          title: `Class cancelled: ${existing.title}`,
          body: series
            ? `Upcoming ${existing.title} classes at ${gymName} have been cancelled.`
            : `${existing.title} at ${gymName} has been cancelled.`,
          metadata: { class_id: classId, gym_id: existing.gym_id, gym_name: gymName },
        });
      }
    }
    return json({ cancelled: cancelled.map((c) => c.id) });
  }

  // ── GET /classes/:id/addable?q= ───────────────────────────────────────────────
  // People a coach can add to the class: the gym's members plus the caller's
  // approved followers (instant for public accounts), minus blocks.
  // [{id, username, name, last_name, avatar_url, is_member, follows_you, booking_status}]
  if (req.method === "GET" && id && action === "addable") {
    const cls = await db.selectFrom("gym_class").select(["id", "gym_id"]).where("id", "=", id).executeTakeFirst();
    if (!cls) return jsonError("Class not found", 404);
    if (!(await canCoachAtGym(caller, cls.gym_id))) return forbidden();

    const q = (url.searchParams.get("q") ?? "").trim().slice(0, 100);
    const pattern = `%${q.replace(/[\\%_]/g, (c) => `\\${c}`)}%`;
    const { rows } = await sql<{
      id: string;
      username: string;
      name: string;
      last_name: string;
      avatar_url: string | null;
      is_member: boolean;
      follows_you: boolean;
      booking_status: BookingStatus | null;
    }>`
      SELECT u.id, u.username, u.name, u.last_name, u.avatar_url,
        EXISTS (SELECT 1 FROM member m WHERE m.user_id = u.id AND m.gym_id = ${cls.gym_id}) AS is_member,
        EXISTS (SELECT 1 FROM follow f WHERE f.follower_id = u.id AND f.followee_id = ${caller.id}
                AND f.status = 'accepted') AS follows_you,
        cb.status AS booking_status
      FROM users u
      LEFT JOIN class_booking cb ON cb.class_id = ${id} AND cb.user_id = u.id AND cb.status <> 'cancelled'
      WHERE u.id <> ${caller.id}
        AND (
          u.id IN (SELECT user_id FROM member WHERE gym_id = ${cls.gym_id})
          OR u.id IN (SELECT follower_id FROM follow WHERE followee_id = ${caller.id} AND status = 'accepted')
        )
        AND NOT is_blocked_between(u.id, ${caller.id})
        AND (${q} = '' OR CONCAT(u.name, ' ', u.last_name) ILIKE ${pattern} OR u.username ILIKE ${pattern})
      ORDER BY u.name, u.last_name
      LIMIT 50
    `.execute(db);
    return json(rows);
  }

  // ── POST /classes/:id/book [{user_id}] ────────────────────────────────────────
  // Coaches can add the gym's members or their own approved followers.
  if (req.method === "POST" && id && action === "book") {
    const body = await req.json().catch(() => ({}));
    const cls = await db.selectFrom("gym_class").selectAll().where("id", "=", id).executeTakeFirst();
    if (!cls) return jsonError("Class not found", 404);
    if (cls.cancelled_at) return jsonError("This class has been cancelled", 400);
    if (new Date(cls.starts_at).getTime() <= Date.now()) return jsonError("This class has already started", 400);

    const userId: string = body?.user_id ?? caller.id;
    if (typeof userId !== "string" || !UUID_RE.test(userId)) return jsonError("Invalid user_id", 400);
    if (userId !== caller.id) {
      if (!(await canCoachAtGym(caller, cls.gym_id))) return forbidden("Only staff can book for someone else");
      if (await isBlockedBetween(caller.id, userId)) return forbidden("You can't add this person");
      if (
        !(await isMember(userId, cls.gym_id)) && !(await isFollowing(userId, caller.id)) &&
        !(await isAcceptedCustomer(caller.id, userId))
      ) {
        return jsonError("Only members of this gym, your followers or your customers can be added", 400);
      }
    } else if (!isSuperUser(caller) && !(await isMember(caller.id, cls.gym_id))) {
      return forbidden("Only members of this gym can book its classes");
    }

    const result = await db.transaction().execute(async (trx) => {
      await sql`SELECT id FROM gym_class WHERE id = ${id} FOR UPDATE`.execute(trx);
      const existing = await trx
        .selectFrom("class_booking")
        .selectAll()
        .where("class_id", "=", id)
        .where("user_id", "=", userId)
        .executeTakeFirst();
      if (existing && existing.status !== "cancelled") return null;

      const { rows: [{ taken }] } = await sql<{ taken: number }>`
        SELECT COUNT(*)::int AS taken FROM class_booking
        WHERE class_id = ${id} AND status IN ('booked', 'attended', 'no_show')
      `.execute(trx);
      const status: BookingStatus = taken < cls.capacity ? "booked" : "waitlisted";

      if (existing) {
        // Rebooking reuses the row; created_at restarts so the waitlist stays fair.
        return await trx
          .updateTable("class_booking")
          .set({ status, created_at: sql<string>`NOW()`, updated_at: sql<string>`NOW()` })
          .where("id", "=", existing.id)
          .returningAll()
          .executeTakeFirstOrThrow();
      }
      return await trx
        .insertInto("class_booking")
        .values({ class_id: id, user_id: userId, status })
        .returningAll()
        .executeTakeFirstOrThrow();
    });
    if (!result) return jsonError("Already booked for this class", 409);

    let waitlistPosition: number | null = null;
    if (result.status === "waitlisted") {
      const { rows: [{ pos }] } = await sql<{ pos: number }>`
        SELECT COUNT(*)::int AS pos FROM class_booking
        WHERE class_id = ${id} AND status = 'waitlisted'
          AND (created_at, id) <= (SELECT created_at, id FROM class_booking WHERE id = ${result.id})
      `.execute(db);
      waitlistPosition = pos;
    }
    if (userId !== caller.id) {
      const [gymName, adder] = await Promise.all([
        gymNameOf(cls.gym_id),
        db.selectFrom("users").select(["name", "last_name"]).where("id", "=", caller.id).executeTakeFirstOrThrow(),
      ]);
      await notify([userId], {
        type: "events",
        title: result.status === "waitlisted" ? `Waitlisted: ${cls.title}` : `You're in: ${cls.title}`,
        body: `${displayName(adder)} added you to ${cls.title} at ${gymName}` +
          (result.status === "waitlisted" ? ` (waitlist #${waitlistPosition}).` : "."),
        metadata: { class_id: cls.id, gym_id: cls.gym_id, gym_name: gymName },
      });
    }
    return json({ ...result, waitlist_position: waitlistPosition }, 201);
  }

  // ── POST /classes/:id/cancel-booking [{user_id}] ──────────────────────────────
  if (req.method === "POST" && id && action === "cancel_booking") {
    const body = await req.json().catch(() => ({}));
    const cls = await db.selectFrom("gym_class").selectAll().where("id", "=", id).executeTakeFirst();
    if (!cls) return jsonError("Class not found", 404);

    const userId: string = body?.user_id ?? caller.id;
    if (typeof userId !== "string" || !UUID_RE.test(userId)) return jsonError("Invalid user_id", 400);
    const isCoach = await canCoachAtGym(caller, cls.gym_id);
    if (userId !== caller.id && !isCoach) return forbidden("Only staff can cancel someone else's booking");
    if (!isCoach && new Date(cls.starts_at).getTime() <= Date.now()) {
      return jsonError("This class has already started", 400);
    }

    const result = await db.transaction().execute(async (trx) => {
      await sql`SELECT id FROM gym_class WHERE id = ${id} FOR UPDATE`.execute(trx);
      const booking = await trx
        .selectFrom("class_booking")
        .selectAll()
        .where("class_id", "=", id)
        .where("user_id", "=", userId)
        .where("status", "in", ["booked", "waitlisted"])
        .executeTakeFirst();
      if (!booking) return null;

      const updated = await trx
        .updateTable("class_booking")
        .set({ status: "cancelled", updated_at: sql<string>`NOW()` })
        .where("id", "=", booking.id)
        .returningAll()
        .executeTakeFirstOrThrow();

      const freedSeat = booking.status === "booked" && !cls.cancelled_at &&
        new Date(cls.starts_at).getTime() > Date.now();
      const promoted = freedSeat ? await promoteWaitlist(trx, id, cls.capacity) : [];
      return { updated, promoted };
    });
    if (!result) return jsonError("No active booking for this class", 404);

    await notifyPromoted(result.promoted, cls);
    return json(result.updated);
  }

  // ── PUT /classes/:id/bookings/:bookingId {status} ─────────────────────────────
  if (req.method === "PUT" && id && action === "booking" && bookingId) {
    const body = await req.json().catch(() => null);
    const status = body?.status;
    if (!["attended", "no_show", "booked"].includes(status)) {
      return jsonError("status must be attended, no_show or booked", 400);
    }
    const cls = await db.selectFrom("gym_class").select(["id", "gym_id"]).where("id", "=", id).executeTakeFirst();
    if (!cls) return jsonError("Class not found", 404);
    if (!(await canCoachAtGym(caller, cls.gym_id))) return forbidden();

    // Only seat-holding bookings can be marked: moving a waitlisted or
    // cancelled booking here would bypass capacity and the waitlist order.
    const updated = await db
      .updateTable("class_booking")
      .set({ status, updated_at: sql<string>`NOW()` })
      .where("id", "=", bookingId)
      .where("class_id", "=", id)
      .where("status", "in", ["booked", "attended", "no_show"])
      .returningAll()
      .executeTakeFirst();
    if (!updated) {
      const exists = await db.selectFrom("class_booking").select("status")
        .where("id", "=", bookingId).where("class_id", "=", id).executeTakeFirst();
      if (!exists) return jsonError("Booking not found", 404);
      return jsonError(`A ${exists.status} booking can't be marked; only booked members can`, 409);
    }
    return json(updated);
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
