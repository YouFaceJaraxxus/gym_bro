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
import { displayName } from "../_shared/social.ts";
import {
  bookEnrollee,
  ensureCustomer,
  generateSessions,
  gymNameOf,
  inviteToSeries,
  isTimezone,
  notifyCancelled,
  notifyPromoted,
  promoteWaitlist,
  removeEnrollment,
  retireSessions,
  topUpSeries,
} from "../_shared/class_series.ts";
import type { ClassRepeat } from "../../types/schema/public.ts";

// Classes as trainers manage them: a timetable (one or more start times a day,
// once / daily / on chosen weekdays) whose sessions are generated 90 days
// ahead, plus per-class invites. See _shared/class_series.ts for the rules.
//
//   GET    /class-series[?gym_id=]               mine (trainer or creator), or a gym's (coaches)
//   POST   /class-series                         create {gym_id, title, description?, location?, capacity,
//                                                duration_minutes, repeat, weekdays?, times, timezone,
//                                                starts_on?, ends_on?, trainer_id?}
//   GET    /class-series/invites                 my pending invites
//   GET    /class-series/:id                     one, with enrollments for coaches
//   PUT    /class-series/:id                     any create field, plus active
//   POST   /class-series/:id/enrollments         invite {user_id}
//   DELETE /class-series/:id/enrollments/:userId remove (coach) or leave (that user)
//   POST   /class-series/:id/accept|decline      answer my invite

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const DATE_RE = /^\d{4}-\d{2}-\d{2}$/;
const TIME_RE = /^([01]\d|2[0-3]):[0-5]\d$/;
const REPEATS: readonly ClassRepeat[] = ["none", "daily", "weekly"];
const MAX_TIMES = 12;
const MAX_CAPACITY = 1000;

type Route =
  | { kind: "list" }
  | { kind: "invites" }
  | { kind: "one"; id: string }
  | { kind: "enrollments"; id: string; userId?: string }
  | { kind: "answer"; id: string; accept: boolean }
  | { kind: "unknown" };

function parsePath(pathname: string): Route {
  const p = pathname.replace(/\/+$/, "").split("/").filter(Boolean);
  // p[0] === "class-series"
  if (p[0] !== "class-series") return { kind: "unknown" };
  if (p.length === 1) return { kind: "list" };
  if (p.length === 2 && p[1] === "invites") return { kind: "invites" };
  if (!UUID_RE.test(p[1] ?? "")) return { kind: "unknown" };
  if (p.length === 2) return { kind: "one", id: p[1] };
  if (p[2] === "enrollments" && p.length === 3) return { kind: "enrollments", id: p[1] };
  if (p[2] === "enrollments" && p.length === 4 && UUID_RE.test(p[3])) {
    return { kind: "enrollments", id: p[1], userId: p[3] };
  }
  if (p.length === 3 && (p[2] === "accept" || p[2] === "decline")) {
    return { kind: "answer", id: p[1], accept: p[2] === "accept" };
  }
  return { kind: "unknown" };
}

// ── Rows ──────────────────────────────────────────────────────────────────────

type SeriesRow = {
  id: string;
  gym_id: string;
  gym_name: string;
  trainer_id: string | null;
  trainer_name: string | null;
  trainer_avatar_url: string | null;
  title: string;
  description: string | null;
  location: string | null;
  capacity: number;
  duration_minutes: number;
  repeat: ClassRepeat;
  weekdays: number[];
  times: string[];
  timezone: string;
  starts_on: string;
  ends_on: string | null;
  active: boolean;
  created_by: string | null;
  created_at: string;
  next_starts_at: string | null;
  upcoming_count: number;
  completed_count: number;
  enrolled_count: number;
  pending_count: number;
  state: "active" | "paused" | "ended";
  my_enrollment_status: string | null;
};

async function selectSeries(callerId: string, where: RawBuilder<unknown>[]): Promise<SeriesRow[]> {
  const { rows } = await sql<SeriesRow>`
    SELECT s.id, s.gym_id, b.name AS gym_name, s.trainer_id,
      NULLIF(TRIM(CONCAT(t.name, ' ', t.last_name)), '') AS trainer_name, t.avatar_url AS trainer_avatar_url,
      s.title, s.description, s.location, s.capacity, s.duration_minutes, s.repeat,
      ARRAY(SELECT d::int FROM unnest(s.weekdays) d ORDER BY d) AS weekdays,
      ARRAY(SELECT to_char(x, 'HH24:MI') FROM unnest(s.times) x ORDER BY x) AS times,
      s.timezone, to_char(s.starts_on, 'YYYY-MM-DD') AS starts_on, to_char(s.ends_on, 'YYYY-MM-DD') AS ends_on,
      s.active, s.created_by, s.created_at,
      nx.next_starts_at, nx.upcoming_count,
      (SELECT COUNT(*)::int FROM gym_class c
        WHERE c.series_id = s.id AND c.cancelled_at IS NULL AND c.ends_at <= NOW()) AS completed_count,
      (SELECT COUNT(*)::int FROM class_enrollment e WHERE e.series_id = s.id AND e.status = 'accepted') AS enrolled_count,
      (SELECT COUNT(*)::int FROM class_enrollment e WHERE e.series_id = s.id AND e.status = 'pending') AS pending_count,
      CASE WHEN NOT s.active THEN 'paused'
           WHEN nx.next_starts_at IS NULL AND (s.repeat = 'none' OR s.ends_on < (NOW() AT TIME ZONE s.timezone)::date)
             THEN 'ended'
           ELSE 'active' END AS state,
      me.status AS my_enrollment_status
    FROM class_series s
    JOIN business b ON b.id = s.gym_id
    LEFT JOIN users t ON t.id = s.trainer_id
    LEFT JOIN class_enrollment me ON me.series_id = s.id AND me.user_id = ${callerId}
    CROSS JOIN LATERAL (
      SELECT MIN(c.starts_at) AS next_starts_at, COUNT(*)::int AS upcoming_count
      FROM gym_class c WHERE c.series_id = s.id AND c.cancelled_at IS NULL AND c.starts_at > NOW()
    ) nx
    ${where.length ? sql`WHERE ${sql.join(where, sql` AND `)}` : sql``}
    ORDER BY (CASE WHEN NOT s.active THEN 2 WHEN nx.next_starts_at IS NULL THEN 1 ELSE 0 END),
      nx.next_starts_at NULLS LAST, s.title
    LIMIT 500
  `.execute(db);
  return rows;
}

/** Owner/staff of the gym, the series' trainer, or whoever created it. */
function canEditSeries(
  caller: Caller,
  s: { gym_id: string; trainer_id: string | null; created_by: string | null },
): Promise<boolean> {
  if (s.trainer_id === caller.id || s.created_by === caller.id) return canCoachAtGym(caller, s.gym_id);
  return canStaffGym(caller, s.gym_id);
}

async function withCanEdit(caller: Caller, rows: SeriesRow[]) {
  const out = [];
  for (const r of rows) out.push({ ...r, can_edit: await canEditSeries(caller, r) });
  return out;
}

async function enrollmentsOf(seriesId: string) {
  return await db.selectFrom("class_enrollment as e")
    .innerJoin("users as u", "u.id", "e.user_id")
    .select([
      "e.user_id",
      "u.username",
      "u.name",
      "u.last_name",
      "u.avatar_url",
      "e.status",
      "e.created_at",
      "e.responded_at",
    ])
    .where("e.series_id", "=", seriesId)
    .orderBy(sql`CASE e.status WHEN 'accepted' THEN 0 WHEN 'pending' THEN 1 ELSE 2 END`)
    .orderBy("u.name")
    .execute();
}

// ── Validation ────────────────────────────────────────────────────────────────

type SeriesFields = {
  title?: string;
  description?: string | null;
  location?: string | null;
  capacity?: number;
  duration_minutes?: number;
  repeat?: ClassRepeat;
  weekdays?: number[];
  times?: string[];
  timezone?: string;
  starts_on?: string;
  ends_on?: string | null;
  trainer_id?: string | null;
  active?: boolean;
};

const trimOrNull = (v: unknown) => (typeof v === "string" && v.trim() ? v.trim() : null);

/** Validates the fields present in `body`. */
async function readFields(body: Record<string, unknown>): Promise<{ fields: SeriesFields } | { error: string }> {
  const f: SeriesFields = {};
  if ("title" in body) {
    const t = trimOrNull(body.title);
    if (!t) return { error: "title is required" };
    if (t.length > 120) return { error: "title is limited to 120 characters" };
    f.title = t;
  }
  if ("description" in body) f.description = trimOrNull(body.description);
  if ("location" in body) f.location = trimOrNull(body.location);
  if ("capacity" in body) {
    const c = body.capacity;
    if (typeof c !== "number" || !Number.isInteger(c) || c < 1 || c > MAX_CAPACITY) {
      return { error: `capacity must be between 1 and ${MAX_CAPACITY}` };
    }
    f.capacity = c;
  }
  if ("duration_minutes" in body) {
    const d = body.duration_minutes;
    if (typeof d !== "number" || !Number.isInteger(d) || d < 5 || d > 1440) {
      return { error: "duration_minutes must be between 5 and 1440" };
    }
    f.duration_minutes = d;
  }
  if ("repeat" in body) {
    if (!REPEATS.includes(body.repeat as ClassRepeat)) return { error: "repeat must be none, daily or weekly" };
    f.repeat = body.repeat as ClassRepeat;
  }
  if ("weekdays" in body) {
    const w = body.weekdays;
    if (!Array.isArray(w) || w.some((d) => !Number.isInteger(d) || d < 1 || d > 7)) {
      return { error: "weekdays must be ISO weekday numbers (1 = Monday … 7 = Sunday)" };
    }
    f.weekdays = [...new Set(w as number[])].sort();
  }
  if ("times" in body) {
    const t = body.times;
    if (!Array.isArray(t) || t.length === 0 || t.some((x) => typeof x !== "string" || !TIME_RE.test(x))) {
      return { error: "times must be a non-empty list of HH:MM start times" };
    }
    const unique = [...new Set(t as string[])].sort();
    if (unique.length > MAX_TIMES) return { error: `Up to ${MAX_TIMES} start times a day` };
    f.times = unique;
  }
  if ("timezone" in body) {
    if (!(await isTimezone(body.timezone))) return { error: "timezone must be an IANA timezone name" };
    f.timezone = body.timezone as string;
  }
  if ("starts_on" in body) {
    if (typeof body.starts_on !== "string" || !DATE_RE.test(body.starts_on) || isNaN(Date.parse(body.starts_on))) {
      return { error: "starts_on must be a YYYY-MM-DD date" };
    }
    f.starts_on = body.starts_on;
  }
  if ("ends_on" in body) {
    if (body.ends_on === null || body.ends_on === "") f.ends_on = null;
    else if (typeof body.ends_on !== "string" || !DATE_RE.test(body.ends_on) || isNaN(Date.parse(body.ends_on))) {
      return { error: "ends_on must be a YYYY-MM-DD date or null" };
    } else f.ends_on = body.ends_on;
  }
  if ("trainer_id" in body) {
    if (body.trainer_id === null || body.trainer_id === "") f.trainer_id = null;
    else if (typeof body.trainer_id !== "string" || !UUID_RE.test(body.trainer_id)) {
      return { error: "Invalid trainer_id" };
    } else f.trainer_id = body.trainer_id;
  }
  if ("active" in body) {
    if (typeof body.active !== "boolean") return { error: "active must be a boolean" };
    f.active = body.active;
  }
  return { fields: f };
}

/** Checks the merged timetable (after applying an edit) hangs together. */
function checkTimetable(s: { repeat: ClassRepeat; weekdays: number[]; starts_on: string; ends_on: string | null }) {
  if (s.repeat === "weekly" && s.weekdays.length === 0) return "Pick at least one weekday";
  if (s.ends_on && s.ends_on < s.starts_on) return "ends_on can't be before starts_on";
  return null;
}

async function isTrainerAtGym(userId: string, gymId: string): Promise<boolean> {
  const { rows } = await sql<{ ok: number }>`
    SELECT 1 AS ok FROM trainer WHERE user_id = ${userId} AND gym_id = ${gymId}
    UNION SELECT 1 FROM employee_trainer WHERE user_id = ${userId} AND gym_id = ${gymId}
  `.execute(db);
  return rows.length > 0;
}

/** Resolves who teaches a new/edited series, or an error response. */
async function resolveTrainer(
  caller: Caller,
  gymId: string,
  requested: string | null | undefined,
): Promise<{ trainerId: string | null } | { response: Response }> {
  if (requested) {
    if (!(await isTrainerAtGym(requested, gymId))) {
      return { response: jsonError("The trainer must be a trainer or employee-trainer at this gym", 400) };
    }
    if (requested !== caller.id && !(await canStaffGym(caller, gymId))) {
      return { response: forbidden("Trainers can only schedule their own classes") };
    }
    return { trainerId: requested };
  }
  if (requested === null) return { trainerId: null };
  return { trainerId: (await isTrainerAtGym(caller.id, gymId)) ? caller.id : null };
}

// ── Handler ───────────────────────────────────────────────────────────────────

async function handler(req: Request): Promise<Response> {
  const { caller, response } = await requireCaller(req);
  if (response) return response;
  const url = new URL(req.url);
  const route = parsePath(url.pathname);

  // ── GET /class-series ────────────────────────────────────────────────────────
  if (req.method === "GET" && route.kind === "list") {
    await topUpSeries();
    const gymId = url.searchParams.get("gym_id");
    if (gymId) {
      if (!UUID_RE.test(gymId)) return jsonError("Invalid gym_id", 400);
      if (!(await canCoachAtGym(caller, gymId))) return forbidden();
      return json(await withCanEdit(caller, await selectSeries(caller.id, [sql`s.gym_id = ${gymId}`])));
    }
    return json(await withCanEdit(
      caller,
      await selectSeries(caller.id, [sql`(s.trainer_id = ${caller.id} OR s.created_by = ${caller.id})`]),
    ));
  }

  // ── GET /class-series/invites ────────────────────────────────────────────────
  if (req.method === "GET" && route.kind === "invites") {
    const rows = await selectSeries(caller.id, [sql`me.status = 'pending'`]);
    const inviters = await db.selectFrom("class_enrollment as e")
      .innerJoin("users as u", "u.id", "e.invited_by")
      .select(["e.series_id", "u.id", "u.username", "u.name", "u.last_name", "u.avatar_url", "e.created_at"])
      .where("e.user_id", "=", caller.id).where("e.status", "=", "pending")
      .execute();
    const byId = new Map(inviters.map((i) => [i.series_id, i]));
    return json(rows.map((r) => {
      const i = byId.get(r.id);
      return {
        ...r,
        invited_at: i?.created_at ?? null,
        invited_by: i
          ? { id: i.id, username: i.username, name: i.name, last_name: i.last_name, avatar_url: i.avatar_url }
          : null,
      };
    }));
  }

  // ── POST /class-series ───────────────────────────────────────────────────────
  if (req.method === "POST" && route.kind === "list") {
    const body = await req.json().catch(() => null);
    if (!body || typeof body !== "object" || Array.isArray(body)) return jsonError("Invalid JSON body", 400);
    const gymId = body.gym_id;
    if (typeof gymId !== "string" || !UUID_RE.test(gymId)) return jsonError("gym_id is required", 400);
    for (const key of ["title", "capacity", "duration_minutes", "repeat", "times", "timezone"]) {
      if (!(key in body)) return jsonError(`${key} is required`, 400);
    }
    const read = await readFields(body);
    if ("error" in read) return jsonError(read.error, 400);
    const f = read.fields;
    if (f.active !== undefined) delete f.active;
    if (!(await canCoachAtGym(caller, gymId))) return forbidden();
    const trainer = await resolveTrainer(caller, gymId, f.trainer_id);
    if ("response" in trainer) return trainer.response;

    const { rows: [{ today }] } = await sql<{ today: string }>`
      SELECT to_char((NOW() AT TIME ZONE ${f.timezone!})::date, 'YYYY-MM-DD') AS today
    `.execute(db);
    const startsOn = f.starts_on ?? today;
    const weekdays = f.repeat === "weekly" ? f.weekdays ?? [] : [];
    const problem = checkTimetable({ repeat: f.repeat!, weekdays, starts_on: startsOn, ends_on: f.ends_on ?? null });
    if (problem) return jsonError(problem, 400);

    const id = await db.transaction().execute(async (trx) => {
      const s = await trx.insertInto("class_series").values({
        gym_id: gymId,
        trainer_id: trainer.trainerId,
        title: f.title!,
        description: f.description ?? null,
        location: f.location ?? null,
        capacity: f.capacity!,
        duration_minutes: f.duration_minutes!,
        repeat: f.repeat!,
        weekdays,
        times: f.times!,
        timezone: f.timezone!,
        starts_on: startsOn,
        ends_on: f.repeat === "none" ? startsOn : f.ends_on ?? null,
        created_by: caller.id,
      }).returning("id").executeTakeFirstOrThrow();
      await generateSessions(trx, s.id);
      return s.id;
    });
    const [row] = await withCanEdit(caller, await selectSeries(caller.id, [sql`s.id = ${id}`]));
    return json({ ...row, enrollments: [] }, 201);
  }

  if (route.kind === "unknown") return jsonError("Not found", 404);
  if (route.kind === "list" || route.kind === "invites") return jsonError("Method not allowed", 405);

  // Dates as text: pg would hand DATE columns back as JS Dates.
  const series = await db.selectFrom("class_series")
    .select([
      "id",
      "gym_id",
      "trainer_id",
      "created_by",
      "title",
      "capacity",
      "repeat",
      "weekdays",
      "active",
      sql<string>`to_char(starts_on, 'YYYY-MM-DD')`.as("starts_on"),
      sql<string | null>`to_char(ends_on, 'YYYY-MM-DD')`.as("ends_on"),
    ])
    .where("id", "=", route.id).executeTakeFirst();
  if (!series) return jsonError("Class not found", 404);
  const canEdit = await canEditSeries(caller, series);

  // ── GET /class-series/:id ────────────────────────────────────────────────────
  if (req.method === "GET" && route.kind === "one") {
    const [row] = await selectSeries(caller.id, [sql`s.id = ${series.id}`]);
    const coach = isSuperUser(caller) || (await canCoachAtGym(caller, series.gym_id));
    if (!coach && !row.my_enrollment_status) return forbidden();
    return json({ ...row, can_edit: canEdit, enrollments: coach ? await enrollmentsOf(series.id) : null });
  }

  // ── PUT /class-series/:id ────────────────────────────────────────────────────
  if (req.method === "PUT" && route.kind === "one") {
    if (!canEdit) return forbidden("Only the class's trainer or the gym's staff can edit it");
    const body = await req.json().catch(() => null);
    if (!body || typeof body !== "object" || Array.isArray(body)) return jsonError("Invalid JSON body", 400);
    const read = await readFields(body);
    if ("error" in read) return jsonError(read.error, 400);
    const f = read.fields;
    if (Object.keys(f).length === 0) return jsonError("Nothing to update", 400);

    let trainerId = series.trainer_id;
    if (f.trainer_id !== undefined) {
      const trainer = await resolveTrainer(caller, series.gym_id, f.trainer_id);
      if ("response" in trainer) return trainer.response;
      trainerId = trainer.trainerId;
    }
    const merged = {
      repeat: f.repeat ?? series.repeat,
      weekdays: f.weekdays ?? series.weekdays.map(Number),
      starts_on: f.starts_on ?? series.starts_on,
      ends_on: f.ends_on !== undefined ? f.ends_on : series.ends_on,
    };
    if (merged.repeat !== "weekly") merged.weekdays = [];
    if (merged.repeat === "none") merged.ends_on = merged.starts_on;
    const problem = checkTimetable(merged);
    if (problem) return jsonError(problem, 400);

    if (f.capacity !== undefined && f.capacity < series.capacity) {
      const { rows: [{ most }] } = await sql<{ most: number }>`
        SELECT COALESCE(MAX(n), 0)::int AS most FROM (
          SELECT COUNT(*) AS n FROM class_booking b JOIN gym_class c ON c.id = b.class_id
          WHERE c.series_id = ${series.id} AND c.cancelled_at IS NULL AND c.starts_at > NOW()
            AND b.status IN ('booked', 'attended', 'no_show')
          GROUP BY c.id
        ) x
      `.execute(db);
      if (f.capacity < most) return jsonError(`Capacity can't be below the ${most} people booked in a session`, 400);
    }

    const timetableChanged = ["repeat", "weekdays", "times", "timezone", "starts_on", "ends_on", "active"]
      .some((k) => k in f);
    const outcome = await db.transaction().execute(async (trx) => {
      await trx.updateTable("class_series").set({
        ...(f.title !== undefined ? { title: f.title } : {}),
        ...(f.description !== undefined ? { description: f.description } : {}),
        ...(f.location !== undefined ? { location: f.location } : {}),
        ...(f.capacity !== undefined ? { capacity: f.capacity } : {}),
        ...(f.duration_minutes !== undefined ? { duration_minutes: f.duration_minutes } : {}),
        ...(f.times !== undefined ? { times: f.times } : {}),
        ...(f.timezone !== undefined ? { timezone: f.timezone } : {}),
        ...(f.active !== undefined ? { active: f.active } : {}),
        trainer_id: trainerId,
        repeat: merged.repeat,
        weekdays: merged.weekdays,
        starts_on: merged.starts_on,
        ends_on: merged.ends_on,
        updated_at: sql<string>`NOW()`,
      }).where("id", "=", series.id).execute();

      // Upcoming sessions take the new details (a single moved session keeps its time).
      await sql`
        UPDATE gym_class c SET
          title = s.title, description = s.description, location = s.location,
          capacity = s.capacity, trainer_id = s.trainer_id,
          ends_at = c.starts_at + make_interval(mins => s.duration_minutes),
          updated_at = NOW()
        FROM class_series s
        WHERE s.id = c.series_id AND c.series_id = ${series.id}
          AND c.cancelled_at IS NULL AND c.starts_at > NOW()
      `.execute(trx);

      const retired = timetableChanged ? await retireSessions(trx, series.id) : [];
      const created = await generateSessions(trx, series.id);

      const promoted = new Map<string, string[]>();
      if (f.capacity !== undefined && f.capacity > series.capacity) {
        const upcoming = await trx.selectFrom("gym_class").select(["id", "capacity"])
          .where("series_id", "=", series.id).where("cancelled_at", "is", null)
          .where("starts_at", ">", sql<string>`NOW()`).execute();
        for (const c of upcoming) {
          const ids = await promoteWaitlist(trx, c.id, c.capacity);
          if (ids.length) promoted.set(c.id, ids);
        }
      }
      return { retired, created, promoted };
    });

    const title = f.title ?? series.title;
    await notifyCancelled(outcome.retired, { gym_id: series.gym_id, title }, caller.id);
    for (const [classId, ids] of outcome.promoted) {
      await notifyPromoted(ids, { id: classId, gym_id: series.gym_id, title });
    }
    if (timetableChanged && (f.active ?? series.active)) {
      const enrolled = await db.selectFrom("class_enrollment").select("user_id")
        .where("series_id", "=", series.id).where("status", "=", "accepted").execute();
      const gymName = await gymNameOf(series.gym_id);
      await notify(enrolled.map((e) => e.user_id).filter((u) => u !== caller.id), {
        type: "events",
        title: `New times: ${title}`,
        body: `The timetable for ${title} at ${gymName} changed. Your schedule has the new sessions.`,
        metadata: { kind: "class_timetable", series_id: series.id, gym_id: series.gym_id, gym_name: gymName },
      });
    }
    const [row] = await withCanEdit(caller, await selectSeries(caller.id, [sql`s.id = ${series.id}`]));
    return json({ ...row, enrollments: await enrollmentsOf(series.id) });
  }

  // ── POST /class-series/:id/enrollments {user_id} ─────────────────────────────
  if (req.method === "POST" && route.kind === "enrollments" && !route.userId) {
    if (!canEdit) return forbidden("Only the class's trainer or the gym's staff can invite people");
    const body = await req.json().catch(() => null);
    const userId = body?.user_id;
    if (typeof userId !== "string" || !UUID_RE.test(userId)) return jsonError("user_id is required", 400);
    if (!series.active) return jsonError("This class is paused", 400);
    const result = await inviteToSeries(caller, series, userId);
    if (!result.ok) return jsonError(result.error, result.status);
    if (!result.created) return jsonError("Already invited to this class", 409);
    return json({ enrollments: await enrollmentsOf(series.id) }, 201);
  }

  // ── DELETE /class-series/:id/enrollments/:userId ─────────────────────────────
  if (req.method === "DELETE" && route.kind === "enrollments" && route.userId) {
    const self = route.userId === caller.id;
    if (!self && !canEdit) return forbidden();
    const wasAccepted = await removeEnrollment(series.id, route.userId);
    if (!self && wasAccepted) {
      const gymName = await gymNameOf(series.gym_id);
      await notify([route.userId], {
        type: "events",
        title: `Removed from ${series.title}`,
        body: `${displayName(caller)} took you off ${series.title} at ${gymName}; its sessions left your schedule.`,
        metadata: { kind: "class_removed", series_id: series.id, gym_id: series.gym_id, gym_name: gymName },
      });
    }
    return new Response(null, { status: 204 });
  }

  // ── POST /class-series/:id/accept|decline ────────────────────────────────────
  if (req.method === "POST" && route.kind === "answer") {
    const mine = await db.selectFrom("class_enrollment").selectAll()
      .where("series_id", "=", series.id).where("user_id", "=", caller.id).executeTakeFirst();
    if (!mine || mine.status !== "pending") return jsonError("No pending invite for this class", 404);
    const trainerId = series.trainer_id ?? mine.invited_by;

    await db.transaction().execute(async (trx) => {
      await trx.updateTable("class_enrollment")
        .set({ status: route.accept ? "accepted" : "declined", responded_at: sql<string>`NOW()` })
        .where("series_id", "=", series.id).where("user_id", "=", caller.id).execute();
      if (!route.accept) return;
      await bookEnrollee(trx, series.id, caller.id);
      // Accepting a class makes them the trainer's customer.
      if (trainerId && trainerId !== caller.id) {
        await ensureCustomer(trx, trainerId, caller.id);
        await trx.updateTable("trainer_customer")
          .set({ status: "accepted", accepted_at: sql<string>`COALESCE(accepted_at, NOW())` })
          .where("trainer_id", "=", trainerId).where("user_id", "=", caller.id).execute();
      }
    });

    if (route.accept && trainerId && trainerId !== caller.id) {
      await notify([trainerId], {
        type: "events",
        title: `${displayName(caller)} joined ${series.title}`,
        body: `${displayName(caller)} accepted your invite to ${series.title}.`,
        metadata: { kind: "class_joined", series_id: series.id, user_id: caller.id },
      });
    }
    const [row] = await selectSeries(caller.id, [sql`s.id = ${series.id}`]);
    return json({ ...row, can_edit: canEdit });
  }

  return jsonError("Not found", 404);
}

Deno.serve(async (req: Request) => {
  try {
    return await handler(req);
  } catch (e) {
    const err = e as { code?: string; message?: string } | null;
    if (err?.code === "23514" || err?.code === "22P02" || err?.code === "22007" || err?.code === "22008") {
      return jsonError(err.message ?? "Invalid value", 400);
    }
    throw e;
  }
});
