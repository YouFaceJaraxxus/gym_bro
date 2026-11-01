import { sql } from "npm:kysely@^0.27";
import { db } from "./config.ts";
import { notify } from "./notify.ts";
import { type Caller, canCoachAtGym, canManageGym, isSuperUser } from "./auth.ts";
import { isTimezone } from "./plans.ts";
import { addDays, localDate } from "./streaks.ts";
import type { ChallengeMetric } from "../../types/schema/public.ts";

// Challenges (see sql/schemas/000028_challenges_wrapped.sql).
//
// Progress is computed from real data inside [starts_on, ends_on], local to
// each participant (their saved zone, else their streak's, else UTC), with
// the streak engine's rules:
// * workouts / active_days / minutes / volume_kg count finished workouts
//   (ended, started in the past, at least one logged set) that were logged by
//   the end of the day after they happened;
// * minutes caps one workout at SESSION_MINUTES_CAP (a session left running
//   doesn't count for hours);
// * volume_kg is kg × reps over counted sets with a weight;
// * check_ins counts days with a check-in at the challenge's gym.
// Workouts before joining count too: it's the window that matters.
//
// The cached progress is recomputed while a challenge is live (from the day
// before it starts until SETTLE_DAYS after it ends, so a late-logged workout
// from its last day still counts) — on read, after a workout changes and from
// the jobs step. Reaching the target sets completed_at once and notifies;
// a completion is never taken back.

export const METRICS: readonly ChallengeMetric[] = ["workouts", "active_days", "minutes", "volume_kg", "check_ins"];
export const SESSION_MINUTES_CAP = 240;
/** Days after ends_on a challenge's progress can still move (late logging + zones). */
export const SETTLE_DAYS = 3;
export const MAX_CHALLENGE_DAYS = 366;
export const TITLE_MAX = 80;
export const DESCRIPTION_MAX = 1000;
export const TARGET_MAX = 10_000_000;

export type ChallengeStatus = "upcoming" | "active" | "past";

export type ChallengeRow = {
  id: string;
  business_id: string | null;
  created_by: string | null;
  title: string;
  description: string | null;
  metric: ChallengeMetric;
  target: number;
  starts_on: string;
  ends_on: string;
  auto_key: string | null;
  created_at: string;
};

/** Every challenge column, with the dates as 'YYYY-MM-DD'. */
export const CHALLENGE_COLS = sql<ChallengeRow>`
  c.id, c.business_id, c.created_by, c.title, c.description, c.metric, c.target,
  to_char(c.starts_on, 'YYYY-MM-DD') AS starts_on, to_char(c.ends_on, 'YYYY-MM-DD') AS ends_on,
  c.auto_key, c.created_at`;

// ── Pure helpers ──────────────────────────────────────────────────────────────

const DAY_RE = /^\d{4}-\d{2}-\d{2}$/;

export function isDay(v: unknown): v is string {
  if (typeof v !== "string" || !DAY_RE.test(v)) return false;
  const d = new Date(`${v}T00:00:00Z`);
  return !Number.isNaN(d.getTime()) && d.toISOString().slice(0, 10) === v;
}

export function daysBetween(from: string, to: string): number {
  return Math.round((Date.parse(`${to}T00:00:00Z`) - Date.parse(`${from}T00:00:00Z`)) / 86_400_000);
}

export function statusOf(c: { starts_on: string; ends_on: string }, today: string): ChallengeStatus {
  if (today < c.starts_on) return "upcoming";
  if (today > c.ends_on) return "past";
  return "active";
}

/** Active: days left including today. Upcoming: days until it starts. Past: 0. */
export function daysLeft(c: { starts_on: string; ends_on: string }, today: string): number {
  const s = statusOf(c, today);
  if (s === "active") return daysBetween(today, c.ends_on) + 1;
  if (s === "upcoming") return daysBetween(today, c.starts_on);
  return 0;
}

/** Whether progress may still move (see SETTLE_DAYS); [today] is a UTC date. */
export function isLive(c: { starts_on: string; ends_on: string }, today: string): boolean {
  return c.starts_on <= addDays(today, 1) && c.ends_on >= addDays(today, -SETTLE_DAYS);
}

/** "12 workouts", "20 active days", … (notifications are English, like the rest). */
export function goalText(metric: ChallengeMetric, target: number): string {
  const n = target.toLocaleString("en-US");
  const plural = (one: string, many: string) => (target === 1 ? `${n} ${one}` : `${n} ${many}`);
  switch (metric) {
    case "workouts":
      return plural("workout", "workouts");
    case "active_days":
      return plural("active day", "active days");
    case "minutes":
      return plural("minute", "minutes");
    case "volume_kg":
      return `${n} kg lifted`;
    case "check_ins":
      return plural("check-in", "check-ins");
  }
}

const MONTHS = [
  "January",
  "February",
  "March",
  "April",
  "May",
  "June",
  "July",
  "August",
  "September",
  "October",
  "November",
  "December",
];

export const MONTHLY_WORKOUTS = 12;
export const MONTHLY_ACTIVE_DAYS = 20;

export type MonthlyChallenge = {
  auto_key: string;
  title: string;
  description: string;
  metric: ChallengeMetric;
  target: number;
  starts_on: string;
  ends_on: string;
};

/** The automatic platform challenges of a month ([month] 1–12). */
export function monthlyChallenges(year: number, month: number): MonthlyChallenge[] {
  const ym = `${year}-${String(month).padStart(2, "0")}`;
  const starts_on = `${ym}-01`;
  const ends_on = new Date(Date.UTC(year, month, 0)).toISOString().slice(0, 10);
  const name = MONTHS[month - 1];
  return [
    {
      auto_key: `monthly:${ym}:workouts`,
      title: `${name} Grind: ${MONTHLY_WORKOUTS} workouts`,
      description: `Finish ${MONTHLY_WORKOUTS} workouts in ${name}. Any workout counts, at the gym or at home.`,
      metric: "workouts",
      target: MONTHLY_WORKOUTS,
      starts_on,
      ends_on,
    },
    {
      auto_key: `monthly:${ym}:active_days`,
      title: `Active ${name}: ${MONTHLY_ACTIVE_DAYS} days`,
      description: `Train on ${MONTHLY_ACTIVE_DAYS} different days in ${name}.`,
      metric: "active_days",
      target: MONTHLY_ACTIVE_DAYS,
      starts_on,
      ends_on,
    },
  ];
}

export type ChallengeInput = {
  business_id?: string | null;
  title?: string;
  description?: string | null;
  metric?: ChallengeMetric;
  target?: number;
  starts_on?: string;
  ends_on?: string;
};

/**
 * Validates a create (all fields but description/business_id required) or
 * edit body ([existing] given: only what's present). Returns the clean values
 * or an error message.
 */
export function readChallengeInput(
  body: unknown,
  opts: { today: string; existing?: ChallengeRow },
): { values: ChallengeInput } | { error: string } {
  if (!body || typeof body !== "object" || Array.isArray(body)) return { error: "Body must be a JSON object" };
  const b = body as Record<string, unknown>;
  const ex = opts.existing;
  const out: ChallengeInput = {};
  const has = (k: string) => k in b && b[k] !== undefined;

  if (!ex && has("business_id") && b.business_id !== null) {
    if (typeof b.business_id !== "string") return { error: "business_id must be a gym id or null" };
    out.business_id = b.business_id;
  }
  if (!ex || has("title")) {
    const t = typeof b.title === "string" ? b.title.trim() : "";
    if (!t || t.length > TITLE_MAX) return { error: `title is required (at most ${TITLE_MAX} characters)` };
    out.title = t;
  }
  if (has("description")) {
    if (b.description !== null && typeof b.description !== "string") return { error: "description must be text" };
    const d = typeof b.description === "string" ? b.description.trim() : "";
    if (d.length > DESCRIPTION_MAX) return { error: `description is at most ${DESCRIPTION_MAX} characters` };
    out.description = d || null;
  }
  if (!ex || has("metric")) {
    if (!METRICS.includes(b.metric as ChallengeMetric)) return { error: `metric must be one of: ${METRICS.join(", ")}` };
    out.metric = b.metric as ChallengeMetric;
  }
  if (!ex || has("target")) {
    const n = typeof b.target === "number" ? b.target : Number.NaN;
    if (!Number.isInteger(n) || n < 1 || n > TARGET_MAX) return { error: `target must be a whole number from 1 to ${TARGET_MAX}` };
    out.target = n;
  }
  for (const k of ["starts_on", "ends_on"] as const) {
    if (!ex || has(k)) {
      if (!isDay(b[k])) return { error: `${k} must be a date (YYYY-MM-DD)` };
      out[k] = b[k] as string;
    }
  }

  const startsOn = out.starts_on ?? ex!.starts_on;
  const endsOn = out.ends_on ?? ex!.ends_on;
  const metric = out.metric ?? ex!.metric;
  const businessId = ex ? ex.business_id : out.business_id ?? null;
  if (endsOn < startsOn) return { error: "ends_on must be on or after starts_on" };
  if (daysBetween(startsOn, endsOn) > MAX_CHALLENGE_DAYS) return { error: `A challenge lasts at most ${MAX_CHALLENGE_DAYS} days` };
  if (metric === "check_ins" && !businessId) return { error: "check_ins challenges belong to a gym" };
  if ((out.ends_on || !ex) && endsOn < opts.today) return { error: "ends_on can't be in the past" };
  if (ex && statusOf(ex, opts.today) !== "upcoming") {
    // Once it started, what counts and since when is fixed for everyone.
    if (out.metric && out.metric !== ex.metric) return { error: "The metric can't change once the challenge started" };
    if (out.starts_on && out.starts_on !== ex.starts_on) return { error: "starts_on can't change once the challenge started" };
  }
  return { values: out };
}

// ── Time zones ────────────────────────────────────────────────────────────────

/** [userId]'s zone: [hint] when valid, else saved settings, else their streak's, else UTC. */
export async function zoneOf(userId: string, hint?: string | null): Promise<string> {
  if (hint && isTimezone(hint)) return hint;
  const row = await sql<{ tz: string | null }>`
    SELECT COALESCE(
      (SELECT timezone FROM user_settings WHERE user_id = ${userId}),
      (SELECT timezone FROM workout_streak WHERE user_id = ${userId})
    ) AS tz
  `.execute(db);
  const tz = row.rows[0]?.tz;
  return tz && isTimezone(tz) ? tz : "UTC";
}

export async function todayFor(userId: string, hint?: string | null): Promise<string> {
  return localDate(new Date(), await zoneOf(userId, hint));
}

export const utcToday = () => new Date().toISOString().slice(0, 10);

// ── Access ────────────────────────────────────────────────────────────────────

/** SQL: gyms where [userId] has an active membership today. */
export function memberGymIdsSql(userId: string) {
  return sql`
    SELECT t.gym_id FROM membership m JOIN gym_membership_type t ON t.id = m.current_membership_type_id
     WHERE m.user_id = ${userId} AND m.is_active AND CURRENT_DATE BETWEEN m.from_date AND m.to_date`;
}

/** Platform challenges: everyone. Gym ones: the approved gym's active members, its team and super users. */
export async function canSeeChallenge(caller: Caller, c: { business_id: string | null }): Promise<boolean> {
  if (!c.business_id) return true;
  if (isSuperUser(caller)) return true;
  const row = await sql<{ ok: boolean }>`
    SELECT EXISTS (
      SELECT 1 FROM business b
       WHERE b.id = ${c.business_id} AND b.status = 'approved' AND b.has_gym
         AND b.id IN (${memberGymIdsSql(caller.id)})
    ) AS ok
  `.execute(db);
  if (row.rows[0]?.ok) return true;
  return await canCoachAtGym(caller, c.business_id);
}

/**
 * The creator (while still allowed to create it), the gym's owners, or a super
 * user. Automatic monthly challenges: super users only.
 */
export async function canEditChallenge(caller: Caller, c: ChallengeRow): Promise<boolean> {
  if (isSuperUser(caller)) return true;
  if (c.business_id) {
    if (c.created_by === caller.id && (await canCoachAtGym(caller, c.business_id))) return true;
    return await canManageGym(caller, c.business_id);
  }
  return false;
}

// ── Progress ──────────────────────────────────────────────────────────────────

type Challengeish = Pick<ChallengeRow, "id" | "business_id" | "metric" | "starts_on" | "ends_on">;

/** Each participant's (or [userIds]') progress, computed from the data. */
export async function computeProgress(c: Challengeish, userIds?: string[]): Promise<{ user_id: string; value: number }[]> {
  const value = c.metric === "workouts"
    ? sql`(SELECT COUNT(*) FROM w WHERE w.user_id = p.user_id)`
    : c.metric === "active_days"
    ? sql`(SELECT COUNT(DISTINCT w.day) FROM w WHERE w.user_id = p.user_id)`
    : c.metric === "minutes"
    ? sql`(SELECT COALESCE(FLOOR(SUM(LEAST(GREATEST(EXTRACT(EPOCH FROM (w.ended_at - w.started_at)), 0) / 60,
                                             ${SESSION_MINUTES_CAP}))), 0)
             FROM w WHERE w.user_id = p.user_id)`
    : c.metric === "volume_kg"
    ? sql`(SELECT COALESCE(FLOOR(SUM(dl.weight_kg_actual * dl.rep_count_actual)), 0)
             FROM w
             JOIN session_set_log l   ON l.session_id = w.id
             JOIN session_drop_log dl ON dl.session_set_log_id = l.id
            WHERE w.user_id = p.user_id
              AND dl.rep_type_actual = 'count' AND dl.rep_count_actual > 0 AND dl.weight_kg_actual > 0)`
    : sql`(SELECT COUNT(DISTINCT (ci.checked_in_at AT TIME ZONE p.tz)::date)
             FROM check_in ci
            WHERE ci.user_id = p.user_id AND ci.gym_id = ${c.business_id}
              AND ci.checked_in_at <= now()
              AND ci.checked_in_at >= (${c.starts_on}::date::timestamp AT TIME ZONE p.tz)
              AND ci.checked_in_at <  ((${c.ends_on}::date + 1)::timestamp AT TIME ZONE p.tz))`;

  const rows = await sql<{ user_id: string; value: number }>`
    WITH p AS (
      SELECT cp.user_id,
             COALESCE(us.timezone, ws.timezone, 'UTC') AS tz
        FROM challenge_participant cp
        LEFT JOIN user_settings us  ON us.user_id = cp.user_id
        LEFT JOIN workout_streak ws ON ws.user_id = cp.user_id
       WHERE cp.challenge_id = ${c.id}
         ${userIds ? sql`AND cp.user_id = ANY(${userIds}::uuid[])` : sql``}
    ),
    w AS (
      SELECT s.id, s.user_id, s.started_at, s.ended_at, (s.started_at AT TIME ZONE p.tz)::date AS day
        FROM p JOIN training_session s ON s.user_id = p.user_id
       WHERE s.ended_at IS NOT NULL
         AND s.started_at <= now()
         AND s.started_at >= (${c.starts_on}::date::timestamp AT TIME ZONE p.tz)
         AND s.started_at <  ((${c.ends_on}::date + 1)::timestamp AT TIME ZONE p.tz)
         -- logged by the end of the next day
         AND s.created_at < (((s.started_at AT TIME ZONE p.tz)::date + 2)::timestamp AT TIME ZONE p.tz)
         AND EXISTS (SELECT 1 FROM session_set_log l WHERE l.session_id = s.id)
    )
    SELECT p.user_id, LEAST(${value}, 2147483647)::int AS value FROM p
  `.execute(db);
  return rows.rows;
}

/**
 * Brings the cached progress of [c]'s participants (or just [userIds]) up to
 * date while it's live, marks who reached the target and notifies them.
 * Returns the users who completed it just now.
 */
export async function syncChallenge(
  c: Challengeish & { title: string },
  userIds?: string[],
): Promise<string[]> {
  if (!isLive(c, utcToday())) return [];
  if (userIds && userIds.length === 0) return [];
  const progress = await computeProgress(c, userIds);
  if (progress.length) {
    await sql`
      UPDATE challenge_participant cp
         SET progress = v.value
        FROM unnest(${progress.map((p) => p.user_id)}::uuid[], ${progress.map((p) => p.value)}::int[])
             AS v(user_id, value)
       WHERE cp.challenge_id = ${c.id} AND cp.user_id = v.user_id AND cp.progress <> v.value
    `.execute(db);
  }
  // A separate statement, so concurrent syncs can't both claim a completion.
  const done = await sql<{ user_id: string }>`
    UPDATE challenge_participant cp
       SET completed_at = now()
      FROM challenge c
     WHERE c.id = cp.challenge_id AND cp.challenge_id = ${c.id}
       AND cp.completed_at IS NULL AND cp.progress >= c.target
       ${userIds ? sql`AND cp.user_id = ANY(${userIds}::uuid[])` : sql``}
    RETURNING cp.user_id
  `.execute(db);
  const ids = done.rows.map((r) => r.user_id);
  if (ids.length) {
    await notify(ids, {
      type: "challenge",
      title: "Challenge complete! 🏅",
      body: `You finished “${c.title}”. That medal is yours.`,
      metadata: { kind: "completed", challenge_id: c.id, title: c.title },
    });
  }
  return ids;
}

/** Live challenges [userId] joined, brought up to date for them. */
export async function syncChallengesOf(userId: string): Promise<void> {
  const today = utcToday();
  const rows = await sql<ChallengeRow>`
    SELECT ${CHALLENGE_COLS}
      FROM challenge c JOIN challenge_participant cp ON cp.challenge_id = c.id
     WHERE cp.user_id = ${userId}
       AND c.starts_on <= ${addDays(today, 1)}::date AND c.ends_on >= ${addDays(today, -SETTLE_DAYS)}::date
  `.execute(db);
  for (const c of rows.rows) await syncChallenge(c, [userId]);
}

/**
 * After a workout was logged, changed or deleted: brings the athlete's
 * challenges up to date after the response, so finishing a workout isn't
 * slower. Failures are logged, never thrown.
 */
export function syncChallengesLater(userId: string): void {
  const task = syncChallengesOf(userId).catch((err) => console.error("challenge sync failed", userId, err));
  const runtime = (globalThis as unknown as { EdgeRuntime?: { waitUntil?: (p: Promise<unknown>) => void } })
    .EdgeRuntime;
  if (typeof runtime?.waitUntil === "function") runtime.waitUntil(task);
}

// ── Jobs ──────────────────────────────────────────────────────────────────────

/**
 * Creates this month's automatic challenges (and next month's during the last
 * week of this one, so they show as upcoming). Idempotent by auto_key.
 */
export async function ensureMonthlyChallenges(now = new Date()): Promise<number> {
  const y = now.getUTCFullYear();
  const m = now.getUTCMonth() + 1;
  const months = [[y, m]];
  const lastDay = new Date(Date.UTC(y, m, 0)).getUTCDate();
  if (now.getUTCDate() > lastDay - 7) months.push(m === 12 ? [y + 1, 1] : [y, m + 1]);
  const rows = months.flatMap(([yy, mm]) => monthlyChallenges(yy, mm));
  const res = await db.insertInto("challenge")
    .values(rows.map((r) => ({ ...r, business_id: null, created_by: null })))
    .onConflict((oc) => oc.column("auto_key").doNothing())
    .executeTakeFirst();
  return Number(res.numInsertedOrUpdatedRows ?? 0);
}

/** Recomputes every live challenge (oldest-synced first is unnecessary: they're few). */
export async function syncLiveChallenges(limit = 200): Promise<{ challenges: number; completed: number }> {
  const today = utcToday();
  const rows = await sql<ChallengeRow>`
    SELECT ${CHALLENGE_COLS}
      FROM challenge c
     WHERE c.starts_on <= ${addDays(today, 1)}::date AND c.ends_on >= ${addDays(today, -SETTLE_DAYS)}::date
       AND EXISTS (SELECT 1 FROM challenge_participant cp WHERE cp.challenge_id = c.id AND cp.completed_at IS NULL)
     ORDER BY c.ends_on
     LIMIT ${limit}
  `.execute(db);
  let completed = 0;
  for (const c of rows.rows) completed += (await syncChallenge(c)).length;
  return { challenges: rows.rows.length, completed };
}
