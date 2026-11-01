import { sql, type Transaction } from "npm:kysely@^0.27";
import { db } from "./config.ts";
import { generateEntries, isTimezone, MAX_WINDOW_DAYS } from "./plans.ts";
import { notify } from "./notify.ts";
import type { Database, StreakEventKind, StreakTier } from "../../types/schema/public.ts";

// Workout streaks (see sql/schemas/000024_streaks_boards.sql).
//
// A streak is a count of finished workouts (sessions with at least one logged
// set, logged by the end of the day after they happened). Days are local to
// the user's timezone and weeks are ISO weeks (Monday–Sunday). It ends on a
// miss, unless a banked freeze absorbs it:
// * a day with a planned workout that wasn't done (no session linked to the
//   entry and no other workout that day), skipped entries included — one miss
//   per day however many entries it had;
// * a week without planned workouts that ended under the weekly target
//   (prorated in the week the streak started).
// A perfect week (every planned workout done, or the target met, and at least
// one workout) earns a freeze; at most MAX_FREEZES are banked. A miss while
// the streak is 0 changes nothing.
//
// A day is settled (its misses applied) once the next day is over, so a
// workout can still be logged the day after. Until then it is "open": its
// workouts already count, its misses don't yet.

export const STREAK_TIERS: readonly { tier: StreakTier; at: number }[] = [
  { tier: "bronze", at: 10 },
  { tier: "silver", at: 50 },
  { tier: "gold", at: 100 },
  { tier: "ruby", at: 200 },
  { tier: "emerald", at: 365 },
  { tier: "sapphire", at: 500 },
  { tier: "diamond", at: 1000 },
];

export const MAX_FREEZES = 2;

/** How far back the first computation of someone's streak looks. */
const FIRST_RUN_DAYS = 365;

/** The badge for a streak of [n] workouts. */
export function tierFor(n: number): StreakTier | null {
  let tier: StreakTier | null = null;
  for (const t of STREAK_TIERS) if (n >= t.at) tier = t.tier;
  return tier;
}

/** The next badge above a streak of [n], or null past the last one. */
export function nextTier(n: number): { tier: StreakTier; at: number } | null {
  return STREAK_TIERS.find((t) => t.at > n) ?? null;
}

// ── Local dates ('YYYY-MM-DD') ────────────────────────────────────────────────

/** The calendar date of [at] in [tz]. */
export function localDate(at: Date, tz: string): string {
  return new Intl.DateTimeFormat("en-CA", { timeZone: tz, year: "numeric", month: "2-digit", day: "2-digit" })
    .format(at);
}

/** The hour (0–23) of [at] in [tz]. */
export function localHour(at: Date, tz: string): number {
  return Number(new Intl.DateTimeFormat("en-GB", { timeZone: tz, hour: "2-digit", hourCycle: "h23" }).format(at));
}

export function addDays(day: string, n: number): string {
  const d = new Date(`${day}T00:00:00Z`);
  d.setUTCDate(d.getUTCDate() + n);
  return d.toISOString().slice(0, 10);
}

/** 1 = Monday … 7 = Sunday. */
export function isoDow(day: string): number {
  return new Date(`${day}T00:00:00Z`).getUTCDay() || 7;
}

/** The Monday of [day]'s week. */
export function weekStart(day: string): string {
  return addDays(day, 1 - isoDow(day));
}

function daysBetween(from: string, to: string): number {
  return Math.round((Date.parse(`${to}T00:00:00Z`) - Date.parse(`${from}T00:00:00Z`)) / 86_400_000);
}

const minDay = (a: string, b: string) => (a < b ? a : b);
const maxDay = (a: string, b: string) => (a > b ? a : b);

// ── Simulation (pure) ─────────────────────────────────────────────────────────

export type SimWorkout = { day: string; planEntryId: string | null };
export type SimEntry = { id: string; day: string; skipped: boolean };
export type SimState = { current: number; since: string | null; best: number; freezes: number };
export type SimEvent = {
  kind: StreakEventKind;
  day: string;
  streak: number;
  tier?: StreakTier;
  planEntryId?: string | null;
};

/** Workouts a week needs to stay on track when nothing is planned in it. */
export function weekRequirement(target: number, week: string, since: string | null): number {
  if (!since || since <= week) return target;
  // The streak started mid-week: only the days left count.
  const daysLeft = 7 - daysBetween(week, since);
  return Math.max(1, Math.round((target * daysLeft) / 7));
}

/**
 * Which of [entries] are done: a session linked to the entry, or else a
 * workout that day not linked to another entry (one workout per entry).
 */
export function doneEntryIds(entries: SimEntry[], workouts: SimWorkout[]): Set<string> {
  const done = new Set<string>();
  const ids = new Set(entries.map((e) => e.id));
  for (const w of workouts) if (w.planEntryId && ids.has(w.planEntryId)) done.add(w.planEntryId);
  const freeByDay = new Map<string, number>();
  for (const w of workouts) {
    if (!w.planEntryId || !ids.has(w.planEntryId)) freeByDay.set(w.day, (freeByDay.get(w.day) ?? 0) + 1);
  }
  for (const e of [...entries].sort((a, b) => a.day.localeCompare(b.day) || a.id.localeCompare(b.id))) {
    if (done.has(e.id)) continue;
    const free = freeByDay.get(e.day) ?? 0;
    if (free > 0) {
      done.add(e.id);
      freeByDay.set(e.day, free - 1);
    }
  }
  return done;
}

/**
 * Settles the days [from, through] on top of [state]. [workouts] and
 * [entries] must cover at least weekStart(from) … through; later ones only
 * count as having done an earlier entry they're linked to.
 */
export function settle(
  state: SimState,
  input: { from: string; through: string; workouts: SimWorkout[]; entries: SimEntry[]; target: number },
): { state: SimState; events: SimEvent[] } {
  const s = { ...state };
  const events: SimEvent[] = [];
  const done = doneEntryIds(input.entries, input.workouts);

  const miss = (day: string, planEntryId: string | null) => {
    if (s.current === 0) return;
    if (s.freezes > 0) {
      s.freezes--;
      events.push({ kind: "freeze_used", day, streak: s.current, planEntryId });
    } else {
      events.push({ kind: "broken", day, streak: s.current, planEntryId });
      s.current = 0;
      s.since = null;
    }
  };

  for (let day = input.from; day <= input.through; day = addDays(day, 1)) {
    // A missed plan ends the streak before that day's workouts start a new one.
    const missed = input.entries.filter((e) => e.day === day && !done.has(e.id));
    if (missed.length) miss(day, missed[0].id);

    for (const _ of input.workouts.filter((w) => w.day === day)) {
      s.current++;
      if (s.current === 1) s.since = day;
      events.push(...raiseBest(s, day));
    }

    if (isoDow(day) === 7) {
      const week = weekStart(day);
      const inWeek = <T extends { day: string }>(xs: T[]) => xs.filter((x) => x.day >= week && x.day <= day);
      const planned = inWeek(input.entries);
      const count = inWeek(input.workouts).length;
      let perfect: boolean;
      if (planned.length) {
        perfect = count > 0 && planned.every((e) => done.has(e.id));
      } else {
        perfect = count > 0 && count >= weekRequirement(input.target, week, s.since);
        if (!perfect) miss(day, null);
      }
      if (perfect && s.current > 0 && s.freezes < MAX_FREEZES) {
        s.freezes++;
        events.push({ kind: "freeze_earned", day, streak: s.current });
      }
    }
  }
  return { state: s, events };
}

/** Bumps the best streak; a 'tier' event for each badge reached for the first time. */
function raiseBest(s: SimState, day: string): SimEvent[] {
  if (s.current <= s.best) return [];
  const events: SimEvent[] = [];
  for (const t of STREAK_TIERS) {
    if (s.best < t.at && s.current >= t.at) events.push({ kind: "tier", day, streak: s.current, tier: t.tier });
  }
  s.best = s.current;
  return events;
}

/** The live streak: [settled] plus the workouts of the still-open days after [through]. */
export function live(
  settled: SimState,
  through: string | null,
  workouts: SimWorkout[],
): { state: SimState; events: SimEvent[] } {
  const s = { ...settled };
  const events: SimEvent[] = [];
  for (const w of [...workouts].sort((a, b) => a.day.localeCompare(b.day))) {
    if (through && w.day <= through) continue;
    s.current++;
    if (s.current === 1) s.since = w.day;
    events.push(...raiseBest(s, w.day));
  }
  return { state: s, events };
}

// ── Database ──────────────────────────────────────────────────────────────────

export type StreakRow = {
  user_id: string;
  current: number;
  since: string | null;
  best: number;
  freezes: number;
  tier: StreakTier | null;
  best_tier: StreakTier | null;
  timezone: string;
};

export type WeekStatus = {
  start: string;
  planned: boolean;
  target: number;
  required: number;
  done: number;
  entries: { id: string; day: string; name: string | null; done: boolean; skipped: boolean }[];
};

export type StreakStatus = StreakRow & {
  today: string;
  next_tier: { tier: StreakTier; at: number } | null;
  week: WeekStatus;
  /** Planned workouts on open days that still need doing. */
  at_risk: { id: string; day: string; name: string | null }[];
  /** Workouts still needed this week when nothing is planned (0 when on track). */
  week_remaining: number;
};

type Tx = Transaction<Database>;

/** A DATE column as 'YYYY-MM-DD' (pg would parse it into a Date at local midnight). */
export function dayCol<C extends "settled_since" | "settled_through" | "since" | "on_date" | "reminded_on">(col: C) {
  return sql<string | null>`to_char(${sql.ref(col)}, 'YYYY-MM-DD')`.as(col);
}

async function userTimezone(userId: string, hint: string | null | undefined): Promise<string> {
  const settings = await db.selectFrom("user_settings").select(["timezone"]).where("user_id", "=", userId)
    .executeTakeFirst();
  if (hint && isTimezone(hint)) {
    if (settings?.timezone !== hint) {
      await db.insertInto("user_settings").values({ user_id: userId, timezone: hint })
        .onConflict((oc) => oc.column("user_id").doUpdateSet({ timezone: hint })).execute();
    }
    return hint;
  }
  if (settings?.timezone && isTimezone(settings.timezone)) return settings.timezone;
  const row = await db.selectFrom("workout_streak").select("timezone").where("user_id", "=", userId)
    .executeTakeFirst();
  return row?.timezone ?? "UTC";
}

/** Counted workouts of [userId] on local days [from, to]. */
async function loadWorkouts(trx: Tx, userId: string, tz: string, from: string, to: string) {
  const rows = await sql<{ day: string; plan_entry_id: string | null }>`
    SELECT to_char((s.started_at AT TIME ZONE ${tz})::date, 'YYYY-MM-DD') AS day, s.plan_entry_id
      FROM training_session s
     WHERE s.user_id = ${userId}
       AND s.ended_at IS NOT NULL
       AND s.started_at <= now()
       AND s.started_at >= (${from}::date::timestamp AT TIME ZONE ${tz})
       AND s.started_at <  ((${to}::date + 1)::timestamp AT TIME ZONE ${tz})
       -- logged by the end of the next day
       AND s.created_at < (((s.started_at AT TIME ZONE ${tz})::date + 2)::timestamp AT TIME ZONE ${tz})
       AND EXISTS (SELECT 1 FROM session_set_log l WHERE l.session_id = s.id)
     ORDER BY s.started_at
  `.execute(trx);
  return rows.rows.map((r): SimWorkout => ({ day: r.day, planEntryId: r.plan_entry_id }));
}

/** Planned workouts of [userId] on [from, to], from the day each plan was assigned on. */
async function loadEntries(trx: Tx, userId: string, tz: string, from: string, to: string) {
  const rows = await sql<{ id: string; day: string; skipped: boolean; name: string | null }>`
    SELECT e.id, to_char(e.plan_date, 'YYYY-MM-DD') AS day, e.skipped, e.training_name AS name
      FROM plan_entry e
      JOIN routine_assignment a ON a.id = e.routine_assignment_id
     WHERE e.user_id = ${userId}
       AND e.kind = 'workout'
       AND e.plan_date BETWEEN ${from}::date AND ${to}::date
       AND e.plan_date >= (a.created_at AT TIME ZONE COALESCE(a.timezone, ${tz}))::date
  `.execute(trx);
  return rows.rows;
}

/**
 * Brings [userId]'s streak up to date: settles every day that has closed
 * since the last run, stores the live view (and the avatar badge) and
 * pushes what happened. [tz] is the app's current zone, when it sent one.
 */
export async function refreshStreak(userId: string, opts: { tz?: string | null } = {}): Promise<StreakStatus> {
  const tz = await userTimezone(userId, opts.tz);
  const today = localDate(new Date(), tz);
  const yesterday = addDays(today, -1);
  const finalThrough = addDays(today, -2);
  const weekEnd = addDays(weekStart(today), 6);

  const existing = await db.selectFrom("workout_streak").select(dayCol("settled_through"))
    .where("user_id", "=", userId).executeTakeFirst();
  const firstRun = !existing?.settled_through;
  const earliest = existing?.settled_through ? addDays(existing.settled_through, 1) : addDays(today, -FIRST_RUN_DAYS);
  const loadFrom = weekStart(minDay(earliest, yesterday));
  for (let from = loadFrom; from <= weekEnd; from = addDays(from, MAX_WINDOW_DAYS)) {
    await generateEntries(userId, from, minDay(addDays(from, MAX_WINDOW_DAYS - 1), weekEnd), tz);
  }

  const target = (await db.selectFrom("user_settings").select("weekly_workout_target").where("user_id", "=", userId)
    .executeTakeFirst())?.weekly_workout_target ?? 3;

  const { status, events } = await db.transaction().execute(async (trx) => {
    await trx.insertInto("workout_streak").values({ user_id: userId, timezone: tz })
      .onConflict((oc) => oc.column("user_id").doNothing()).execute();
    const row = await trx.selectFrom("workout_streak")
      .select(["settled_current", "best", "freezes", dayCol("settled_since"), dayCol("settled_through")])
      .where("user_id", "=", userId).forUpdate().executeTakeFirstOrThrow();

    const workouts = await loadWorkouts(trx, userId, tz, loadFrom, today);
    const entryRows = await loadEntries(trx, userId, tz, loadFrom, weekEnd);
    const entries = entryRows.map((e): SimEntry => ({ id: e.id, day: e.day, skipped: e.skipped }));

    let settled: SimState = {
      current: row.settled_current,
      since: row.settled_since,
      best: row.best,
      freezes: row.freezes,
    };
    const events: SimEvent[] = [];
    // First run: start at the first workout, nothing before it can be missed.
    const from = row.settled_through ? addDays(row.settled_through, 1) : (workouts[0]?.day ?? null);
    if (from && from <= finalThrough) {
      const r = settle(settled, { from, through: finalThrough, workouts, entries, target });
      settled = r.state;
      events.push(...r.events);
    }
    // Late logging can't reach a closed day, so a first run without workouts
    // closes everything up to here too.
    const settledThrough = maxDay(row.settled_through ?? finalThrough, finalThrough);

    const lv = live(settled, settledThrough, workouts);
    events.push(...lv.events);
    const state = lv.state;

    await trx.updateTable("workout_streak").set({
      settled_current: settled.current,
      settled_since: settled.since,
      settled_through: settledThrough,
      current: state.current,
      since: state.since,
      best: state.best,
      freezes: state.freezes,
      timezone: tz,
      updated_at: sql<string>`now()`,
    }).where("user_id", "=", userId).execute();

    const tier = tierFor(state.current);
    await trx.updateTable("users").set({ streak_tier: tier }).where("id", "=", userId)
      .where(sql<boolean>`streak_tier IS DISTINCT FROM ${tier}`).execute();

    if (events.length) {
      await trx.insertInto("streak_event").values(events.map((e) => ({
        user_id: userId,
        kind: e.kind,
        on_date: e.day,
        streak: e.streak,
        tier: e.tier ?? null,
        plan_entry_id: e.planEntryId ?? null,
      }))).onConflict((oc) => oc.doNothing()).execute();
    }

    // This week, for the streak screen.
    const week = weekStart(today);
    const weekWorkouts = workouts.filter((w) => w.day >= week);
    const weekEntries = entryRows.filter((e) => e.day >= week && e.day <= weekEnd)
      .sort((a, b) => a.day.localeCompare(b.day));
    const done = doneEntryIds(entries, workouts);
    const required = weekRequirement(target, week, state.since);
    const openDays = [yesterday, today].filter((d) => d > settledThrough);
    const status: StreakStatus = {
      user_id: userId,
      current: state.current,
      since: state.since,
      best: state.best,
      freezes: state.freezes,
      tier,
      best_tier: tierFor(state.best),
      timezone: tz,
      today,
      next_tier: nextTier(state.current),
      week: {
        start: week,
        planned: weekEntries.length > 0,
        target,
        required,
        done: weekWorkouts.length,
        entries: weekEntries.map((e) => ({
          id: e.id,
          day: e.day,
          name: e.name,
          done: done.has(e.id),
          skipped: e.skipped,
        })),
      },
      at_risk: entryRows
        .filter((e) => openDays.includes(e.day) && e.day <= today && !done.has(e.id))
        .map((e) => ({ id: e.id, day: e.day, name: e.name })),
      week_remaining: weekEntries.length ? 0 : Math.max(0, required - weekWorkouts.length),
    };
    return { status, events };
  });

  // History replayed on the first run isn't news.
  if (!firstRun) await pushStreakEvents(userId, events);
  return status;
}

const TIER_NAMES: Record<StreakTier, string> = {
  bronze: "Bronze",
  silver: "Silver",
  gold: "Gold",
  ruby: "Ruby",
  emerald: "Emerald",
  sapphire: "Sapphire",
  diamond: "Diamond",
};

async function pushStreakEvents(userId: string, events: SimEvent[]) {
  for (const e of events) {
    const n = e.kind === "freeze_used"
      ? {
        title: "A streak freeze saved you 🧊",
        body: `You missed a workout, so a freeze kept your ${e.streak}-workout streak alive.`,
      }
      : e.kind === "broken"
      ? { title: "Your streak ended", body: `Your ${e.streak}-workout streak is over. Start a new one today!` }
      : e.kind === "tier" && e.tier
      ? { title: `${TIER_NAMES[e.tier]} streak unlocked!`, body: `${e.streak} workouts in a row. Keep it going!` }
      : null;
    if (!n) continue;
    await notify([userId], {
      type: "streak",
      ...n,
      metadata: { kind: e.kind, streak: e.streak, tier: e.tier ?? null, on_date: e.day },
    });
  }
}

// ── Gym boards ────────────────────────────────────────────────────────────────

export const BOARDS = ["streak", "workouts", "check_ins"] as const;
export type Board = (typeof BOARDS)[number];

/** Active members of [gymId] who show on its boards (a SQL fragment of user ids). */
function boardMembers(gymId: string) {
  return sql`
    SELECT DISTINCT m.user_id
      FROM membership m
      JOIN gym_membership_type t ON t.id = m.current_membership_type_id
      LEFT JOIN user_settings us ON us.user_id = m.user_id
     WHERE t.gym_id = ${gymId}
       AND m.is_active AND CURRENT_DATE BETWEEN m.from_date AND m.to_date
       AND COALESCE(us.show_on_gym_boards, TRUE)
  `;
}

/** Whether [userId] has an active membership at [gymId]. */
export async function isActiveMember(userId: string, gymId: string): Promise<boolean> {
  const row = await sql<{ ok: boolean }>`
    SELECT EXISTS (
      SELECT 1 FROM membership m JOIN gym_membership_type t ON t.id = m.current_membership_type_id
       WHERE m.user_id = ${userId} AND t.gym_id = ${gymId}
         AND m.is_active AND CURRENT_DATE BETWEEN m.from_date AND m.to_date
    ) AS ok
  `.execute(db);
  return row.rows[0]?.ok ?? false;
}

export type BoardRow = { user_id: string; value: number; rank: number };

/**
 * [gymId]'s board, best first: streak = current streak, workouts = counted
 * workouts since [since], check_ins = check-ins at the gym since then.
 */
export async function boardRows(gymId: string, board: Board, since: string): Promise<BoardRow[]> {
  const members = boardMembers(gymId);
  const query = board === "streak"
    ? sql<BoardRow>`
      SELECT ws.user_id, ws.current AS value,
             RANK() OVER (ORDER BY ws.current DESC)::int AS rank
        FROM workout_streak ws
       WHERE ws.user_id IN (${members}) AND ws.current > 0
       ORDER BY ws.current DESC, ws.best DESC, ws.since ASC NULLS LAST, ws.user_id`
    : board === "workouts"
    ? sql<BoardRow>`
      SELECT s.user_id, COUNT(*)::int AS value,
             RANK() OVER (ORDER BY COUNT(*) DESC)::int AS rank
        FROM training_session s
       WHERE s.user_id IN (${members})
         AND s.ended_at IS NOT NULL AND s.started_at <= now() AND s.started_at >= ${since}::timestamptz
         AND EXISTS (SELECT 1 FROM session_set_log l WHERE l.session_id = s.id)
       GROUP BY s.user_id
       ORDER BY value DESC, MAX(s.started_at) ASC, s.user_id`
    : sql<BoardRow>`
      SELECT c.user_id, COUNT(*)::int AS value,
             RANK() OVER (ORDER BY COUNT(*) DESC)::int AS rank
        FROM check_in c
       WHERE c.gym_id = ${gymId} AND c.user_id IN (${members}) AND c.checked_in_at >= ${since}::timestamptz
       GROUP BY c.user_id
       ORDER BY value DESC, MAX(c.checked_in_at) ASC, c.user_id`;
  return (await query.execute(db)).rows;
}

export type GymRank = { gym_id: string; gym_name: string; rank: number; total: number; value: number };

/** Where [userId] stands on the streak board of each gym they're an active member of, best first. */
export async function gymStreakRanks(userId: string): Promise<GymRank[]> {
  const rows = await sql<GymRank>`
    WITH g AS (
      SELECT DISTINCT t.gym_id
        FROM membership m JOIN gym_membership_type t ON t.id = m.current_membership_type_id
       WHERE m.user_id = ${userId} AND m.is_active AND CURRENT_DATE BETWEEN m.from_date AND m.to_date
    ),
    mem AS (
      SELECT DISTINCT t.gym_id, m.user_id
        FROM membership m
        JOIN gym_membership_type t ON t.id = m.current_membership_type_id
        LEFT JOIN user_settings us ON us.user_id = m.user_id
       WHERE t.gym_id IN (SELECT gym_id FROM g)
         AND m.is_active AND CURRENT_DATE BETWEEN m.from_date AND m.to_date
         AND COALESCE(us.show_on_gym_boards, TRUE)
    ),
    board AS (
      SELECT mem.gym_id, mem.user_id, ws.current,
             RANK() OVER (PARTITION BY mem.gym_id ORDER BY ws.current DESC)::int AS rank,
             COUNT(*) OVER (PARTITION BY mem.gym_id)::int AS total
        FROM mem JOIN workout_streak ws ON ws.user_id = mem.user_id AND ws.current > 0
    )
    SELECT b.gym_id, biz.name AS gym_name, b.rank, b.total, b.current AS value
      FROM board b JOIN business biz ON biz.id = b.gym_id
     WHERE b.user_id = ${userId}
     ORDER BY b.rank, b.total DESC, biz.name
  `.execute(db);
  return rows.rows;
}

/**
 * Refreshes [userId]'s streak after a workout was logged or removed, and
 * returns it with how it moved (for the "workout complete" screen).
 */
export async function streakAfterWorkout(userId: string) {
  const before = await db.selectFrom("workout_streak").select(["current", "freezes"]).where("user_id", "=", userId)
    .executeTakeFirst();
  const ranksBefore = await gymStreakRanks(userId);
  const status = await refreshStreak(userId);
  const ranks = await gymStreakRanks(userId);
  const previous = before?.current ?? 0;
  return {
    previous,
    current: status.current,
    best: status.best,
    freezes: status.freezes,
    tier: status.tier,
    previous_tier: tierFor(previous),
    next_tier: status.next_tier,
    week: status.week,
    ranks: ranks.map((r) => ({
      ...r,
      previous_rank: ranksBefore.find((b) => b.gym_id === r.gym_id)?.rank ?? null,
    })),
  };
}
