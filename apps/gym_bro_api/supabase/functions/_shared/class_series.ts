import { type Kysely, sql } from "npm:kysely@^0.27";
import { db } from "./config.ts";
import { notify } from "./notify.ts";
import type { Database } from "../../types/schema/public.ts";

// Class timetables (class_series) and their sessions (gym_class), shared by
// the classes, class-series, customers and jobs functions.
//
// * Sessions exist from now through HORIZON_DAYS ahead (in the series'
//   timezone), one per (local date that matches the repeat rule × start time).
//   They're keyed by (series_id, slot_at), so generating again is a no-op and a
//   moved or cancelled session is never re-created.
// * Accepted enrollees are booked into every upcoming session, first come
//   first served by when they accepted; whoever doesn't fit is waitlisted.
// * When the timetable changes or is paused, upcoming sessions that no longer
//   fit are retired: cancelled with their bookings (people booked are told),
//   or deleted if nobody ever booked. A retired session comes back, with its
//   enrollees booked again, if the timetable fits it again.

export const HORIZON_DAYS = 90;

type Q = Kysely<Database>;

const SEAT_STATUSES = sql`('booked', 'attended', 'no_show')`;

/** Local "today" and the last date sessions should exist for, per series. */
const TARGET_SQL = sql`
  CASE WHEN s.repeat = 'none' THEN s.starts_on
       ELSE LEAST(COALESCE(s.ends_on, 'infinity'::date), (NOW() AT TIME ZONE s.timezone)::date + ${HORIZON_DAYS}::int)
  END`;

/** Upcoming slots (timestamptz) the series should have right now. */
function expectedSlotsSql(seriesId: string) {
  return sql`
    SELECT ((d::date + t) AT TIME ZONE s.timezone) AS slot_at
    FROM class_series s
    CROSS JOIN LATERAL generate_series(
      GREATEST(s.starts_on, (NOW() AT TIME ZONE s.timezone)::date)::timestamp,
      (${TARGET_SQL})::timestamp,
      INTERVAL '1 day'
    ) AS d
    CROSS JOIN LATERAL unnest(s.times) AS t
    WHERE s.id = ${seriesId} AND s.active
      AND (
        s.repeat = 'daily'
        OR (s.repeat = 'weekly' AND EXTRACT(ISODOW FROM d)::smallint = ANY(s.weekdays))
        OR (s.repeat = 'none' AND d::date = s.starts_on)
      )
      AND ((d::date + t) AT TIME ZONE s.timezone) > NOW()`;
}

/**
 * Creates the series' missing upcoming sessions and books its accepted
 * enrollees into them. Returns the new session ids.
 */
export async function generateSessions(q: Q, seriesId: string): Promise<string[]> {
  const { rows: revived } = await sql<{ id: string }>`
    UPDATE gym_class c SET
      cancelled_at = NULL, retired = FALSE, reminder_sent_at = NULL,
      title = s.title, description = s.description, location = s.location, capacity = s.capacity,
      trainer_id = s.trainer_id, starts_at = c.slot_at,
      ends_at = c.slot_at + make_interval(mins => s.duration_minutes), updated_at = NOW()
    FROM class_series s
    WHERE s.id = c.series_id AND c.series_id = ${seriesId} AND c.retired
      AND c.slot_at IN (${expectedSlotsSql(seriesId)})
    RETURNING c.id
  `.execute(q);
  const { rows } = await sql<{ id: string }>`
    INSERT INTO gym_class (gym_id, trainer_id, title, description, location, starts_at, ends_at, slot_at,
                           capacity, series_id, created_by)
    SELECT s.gym_id, s.trainer_id, s.title, s.description, s.location,
           e.slot_at, e.slot_at + make_interval(mins => s.duration_minutes), e.slot_at,
           s.capacity, s.id, s.created_by
    FROM class_series s CROSS JOIN (${expectedSlotsSql(seriesId)}) e
    WHERE s.id = ${seriesId}
    ON CONFLICT (series_id, slot_at) DO NOTHING
    RETURNING id
  `.execute(q);
  const ids = rows.map((r) => r.id);
  const booking = [...ids, ...revived.map((r) => r.id)];

  if (booking.length) {
    await sql`
      INSERT INTO class_booking (class_id, user_id, status)
      SELECT c.id, e.user_id,
        (CASE WHEN ROW_NUMBER() OVER (PARTITION BY c.id ORDER BY e.responded_at, e.user_id) <= c.capacity
              THEN 'booked' ELSE 'waitlisted' END)::booking_status
      FROM gym_class c
      JOIN class_enrollment e ON e.series_id = c.series_id AND e.status = 'accepted'
      WHERE c.id = ANY(${booking}::uuid[])
      ON CONFLICT (class_id, user_id) DO UPDATE
        SET status = EXCLUDED.status, created_at = NOW(), updated_at = NOW()
        WHERE class_booking.status = 'cancelled'
    `.execute(q);
  }
  await sql`
    UPDATE class_series s SET generated_until = ${TARGET_SQL} WHERE s.id = ${seriesId}
  `.execute(q);
  return ids;
}

/** Tops up active series running low on sessions. Returns how many sessions were created. */
export async function topUpSeries(limit = 25): Promise<number> {
  const { rows } = await sql<{ id: string }>`
    SELECT s.id FROM class_series s
    WHERE s.active
      AND (s.generated_until IS NULL
           OR s.generated_until < LEAST(${TARGET_SQL}, (NOW() AT TIME ZONE s.timezone)::date + ${HORIZON_DAYS - 1}::int))
    ORDER BY s.generated_until NULLS FIRST
    LIMIT ${limit}
  `.execute(db);
  let created = 0;
  for (const { id } of rows) {
    created += (await db.transaction().execute((trx) => generateSessions(trx, id))).length;
  }
  return created;
}

/**
 * Upcoming sessions that no longer fit the timetable (or all of them, when
 * the series is paused): cancelled if anyone is booked or waitlisted, else
 * deleted. Returns the cancelled ones with the people to tell.
 */
export async function retireSessions(
  q: Q,
  seriesId: string,
): Promise<{ id: string; userIds: string[] }[]> {
  const { rows } = await sql<{ id: string; user_ids: string[] | null }>`
    SELECT c.id,
      (SELECT array_agg(b.user_id) FROM class_booking b
        WHERE b.class_id = c.id AND b.status IN ('booked', 'waitlisted')) AS user_ids
    FROM gym_class c
    WHERE c.series_id = ${seriesId} AND c.cancelled_at IS NULL AND c.starts_at > NOW()
      AND c.slot_at NOT IN (${expectedSlotsSql(seriesId)})
    FOR UPDATE OF c
  `.execute(q);
  const cancel = rows.filter((r) => r.user_ids?.length);
  const drop = rows.filter((r) => !r.user_ids?.length).map((r) => r.id);
  if (cancel.length) {
    const ids = cancel.map((r) => r.id);
    await q.updateTable("gym_class")
      .set({ cancelled_at: sql<string>`NOW()`, retired: true, updated_at: sql<string>`NOW()` })
      .where("id", "in", ids)
      .execute();
    await q.updateTable("class_booking")
      .set({ status: "cancelled", updated_at: sql<string>`NOW()` })
      .where("class_id", "in", ids).where("status", "in", ["booked", "waitlisted"])
      .execute();
  }
  if (drop.length) {
    // Rows with only cancelled bookings go too; their history isn't worth a ghost session.
    await q.deleteFrom("gym_class").where("id", "in", drop).execute();
  }
  return cancel.map((r) => ({ id: r.id, userIds: r.user_ids! }));
}

/** Books an accepted enrollee into every upcoming session of the series. */
export async function bookEnrollee(q: Q, seriesId: string, userId: string): Promise<void> {
  await sql`
    SELECT id FROM gym_class
    WHERE series_id = ${seriesId} AND cancelled_at IS NULL AND starts_at > NOW()
    FOR UPDATE
  `.execute(q);
  await sql`
    INSERT INTO class_booking (class_id, user_id, status)
    SELECT c.id, ${userId},
      (CASE WHEN (SELECT COUNT(*) FROM class_booking x
                  WHERE x.class_id = c.id AND x.status IN ${SEAT_STATUSES}) < c.capacity
            THEN 'booked' ELSE 'waitlisted' END)::booking_status
    FROM gym_class c
    WHERE c.series_id = ${seriesId} AND c.cancelled_at IS NULL AND c.starts_at > NOW()
    ON CONFLICT (class_id, user_id) DO UPDATE
      SET status = EXCLUDED.status, created_at = NOW(), updated_at = NOW()
      WHERE class_booking.status = 'cancelled'
  `.execute(q);
}

/**
 * Cancels someone's upcoming bookings in the series and fills the freed seats
 * from the waitlist. Returns the promoted user ids per session.
 */
export async function unbookEnrollee(q: Q, seriesId: string, userId: string): Promise<Map<string, string[]>> {
  const { rows } = await sql<{ class_id: string; was: string; capacity: number }>`
    UPDATE class_booking b SET status = 'cancelled', updated_at = NOW()
    FROM gym_class c, class_booking old
    WHERE b.class_id = c.id AND old.id = b.id
      AND c.series_id = ${seriesId} AND c.cancelled_at IS NULL AND c.starts_at > NOW()
      AND b.user_id = ${userId} AND b.status IN ('booked', 'waitlisted')
    RETURNING b.class_id, old.status AS was, c.capacity
  `.execute(q);
  const promoted = new Map<string, string[]>();
  for (const r of rows) {
    if (r.was !== "booked") continue;
    const ids = await promoteWaitlist(q, r.class_id, r.capacity);
    if (ids.length) promoted.set(r.class_id, ids);
  }
  return promoted;
}

/**
 * Promotes the earliest waitlisted bookings while seats are free. Must run in
 * a transaction that already holds a lock on the class row (or is the only
 * writer). Returns the promoted user ids.
 */
export async function promoteWaitlist(q: Q, classId: string, capacity: number): Promise<string[]> {
  const { rows: [{ taken }] } = await sql<{ taken: number }>`
    SELECT COUNT(*)::int AS taken FROM class_booking
    WHERE class_id = ${classId} AND status IN ${SEAT_STATUSES}
  `.execute(q);
  const free = capacity - taken;
  if (free <= 0) return [];
  const { rows } = await sql<{ user_id: string }>`
    UPDATE class_booking SET status = 'booked', updated_at = NOW()
    WHERE id IN (
      SELECT id FROM class_booking
      WHERE class_id = ${classId} AND status = 'waitlisted'
      ORDER BY created_at, id
      LIMIT ${free}
    )
    RETURNING user_id
  `.execute(q);
  return rows.map((r) => r.user_id);
}

export async function gymNameOf(gymId: string): Promise<string> {
  const row = await db.selectFrom("business").select("name").where("id", "=", gymId).executeTakeFirst();
  return row?.name ?? "your gym";
}

export async function notifyPromoted(userIds: string[], cls: { id: string; gym_id: string; title: string }) {
  if (userIds.length === 0) return;
  const gymName = await gymNameOf(cls.gym_id);
  await notify(userIds, {
    type: "events",
    title: `You're in: ${cls.title}`,
    body: `A spot opened up and you've been moved off the waitlist for ${cls.title} at ${gymName}.`,
    metadata: { class_id: cls.id, gym_id: cls.gym_id, gym_name: gymName },
  });
}

/** Tells booked people their sessions were cancelled, one notification per session. */
export async function notifyCancelled(
  sessions: { id: string; userIds: string[] }[],
  series: { gym_id: string; title: string },
  skip?: string,
) {
  if (!sessions.length) return;
  const gymName = await gymNameOf(series.gym_id);
  for (const s of sessions) {
    const userIds = s.userIds.filter((u) => u !== skip);
    if (!userIds.length) continue;
    await notify(userIds, {
      type: "events",
      title: `Class cancelled: ${series.title}`,
      body: `A ${series.title} session at ${gymName} you were booked for has been cancelled.`,
      metadata: { class_id: s.id, gym_id: series.gym_id, gym_name: gymName },
    });
  }
}

/** True for a valid IANA timezone name Postgres knows. */
export async function isTimezone(name: unknown): Promise<boolean> {
  if (typeof name !== "string" || !name || name.length > 64) return false;
  const { rows } = await sql`SELECT 1 FROM pg_timezone_names WHERE name = ${name}`.execute(db);
  return rows.length > 0;
}

/** True when `userId` accepted `trainerId` as their trainer. */
export async function isAcceptedCustomer(trainerId: string, userId: string): Promise<boolean> {
  const row = await db.selectFrom("trainer_customer").select("user_id")
    .where("trainer_id", "=", trainerId).where("user_id", "=", userId).where("status", "=", "accepted")
    .executeTakeFirst();
  return !!row;
}

// ── Invites ───────────────────────────────────────────────────────────────────

/**
 * Whether `inviterId` may invite `userId` to classes or as a customer: not
 * blocked either way, and the person is one of the inviter's approved
 * followers, already their customer, or a member of `gymId` (or, without
 * one, of any gym where the inviter coaches).
 */
export async function canInvite(inviterId: string, userId: string, gymId?: string): Promise<boolean> {
  if (inviterId === userId) return false;
  const { rows } = await sql<{ ok: boolean }>`
    SELECT NOT is_blocked_between(${inviterId}, ${userId}) AND (
      EXISTS (SELECT 1 FROM follow WHERE follower_id = ${userId} AND followee_id = ${inviterId} AND status = 'accepted')
      OR EXISTS (SELECT 1 FROM trainer_customer WHERE trainer_id = ${inviterId} AND user_id = ${userId})
      OR EXISTS (
        SELECT 1 FROM member m WHERE m.user_id = ${userId} AND m.gym_id IN (
          ${
    gymId ? sql`SELECT ${gymId}::uuid` : sql`
            SELECT gym_id FROM trainer WHERE user_id = ${inviterId}
            UNION SELECT gym_id FROM employee_trainer WHERE user_id = ${inviterId}
            UNION SELECT gym_id FROM employee WHERE user_id = ${inviterId}
            UNION SELECT gym_id FROM gym_owner WHERE user_id = ${inviterId}`
  }
        )
      )
    ) AS ok
  `.execute(db);
  return rows[0]?.ok === true;
}

/** Adds `userId` to the trainer's customers (pending) unless they already are one. */
export async function ensureCustomer(q: Q, trainerId: string, userId: string): Promise<boolean> {
  if (trainerId === userId) return false;
  const res = await q.insertInto("trainer_customer").values({ trainer_id: trainerId, user_id: userId })
    .onConflict((oc) => oc.columns(["trainer_id", "user_id"]).doNothing())
    .executeTakeFirst();
  return Number(res.numInsertedOrUpdatedRows ?? 0) > 0;
}

export type InviteResult = { ok: true; created: boolean } | { ok: false; status: number; error: string };

/**
 * Invites `userId` to the series (a pending class_enrollment) and makes them
 * a customer of its trainer. A declined invite can be sent again; pending or
 * accepted ones are left alone. Notifies the person.
 */
export async function inviteToSeries(
  inviter: { id: string; name: string; last_name: string },
  series: { id: string; gym_id: string; title: string; trainer_id: string | null },
  userId: string,
  opts: { notify?: boolean } = {},
): Promise<InviteResult> {
  if (!(await canInvite(inviter.id, userId, series.gym_id))) {
    return {
      ok: false,
      status: 400,
      error: "Only members of this gym, your followers or your customers can be invited",
    };
  }
  const trainerId = series.trainer_id ?? inviter.id;
  const created = await db.transaction().execute(async (trx) => {
    const existing = await trx.selectFrom("class_enrollment").select("status")
      .where("series_id", "=", series.id).where("user_id", "=", userId).executeTakeFirst();
    if (existing && existing.status !== "declined") return false;
    await trx.insertInto("class_enrollment")
      .values({ series_id: series.id, user_id: userId, status: "pending", invited_by: inviter.id })
      .onConflict((oc) =>
        oc.columns(["series_id", "user_id"]).doUpdateSet({
          status: "pending",
          invited_by: inviter.id,
          created_at: sql<string>`NOW()`,
          responded_at: null,
        })
      )
      .execute();
    await ensureCustomer(trx, trainerId, userId);
    return true;
  });
  if (created && opts.notify !== false) {
    const gymName = await gymNameOf(series.gym_id);
    await notify([userId], {
      type: "events",
      title: `Class invite: ${series.title}`,
      body: `${`${inviter.name} ${inviter.last_name}`.trim() || "Your trainer"} invited you to ${series.title} at ${gymName}. ` +
        "Accept it to get every session in your schedule.",
      metadata: { kind: "class_invite", series_id: series.id, gym_id: series.gym_id, gym_name: gymName },
    });
  }
  return { ok: true, created };
}

/**
 * Removes someone's enrollment in the series (any status) and cancels their
 * upcoming bookings in it. Returns whether they had accepted.
 */
export async function removeEnrollment(seriesId: string, userId: string): Promise<boolean> {
  const { wasAccepted, promoted } = await db.transaction().execute(async (trx) => {
    const gone = await trx.deleteFrom("class_enrollment")
      .where("series_id", "=", seriesId).where("user_id", "=", userId)
      .returning("status").executeTakeFirst();
    const wasAccepted = gone?.status === "accepted";
    return { wasAccepted, promoted: wasAccepted ? await unbookEnrollee(trx, seriesId, userId) : new Map() };
  });
  if (promoted.size) {
    const s = await db.selectFrom("class_series").select(["gym_id", "title"]).where("id", "=", seriesId)
      .executeTakeFirstOrThrow();
    for (const [classId, ids] of promoted) await notifyPromoted(ids, { id: classId, gym_id: s.gym_id, title: s.title });
  }
  return wasAccepted;
}
