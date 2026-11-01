// Water goal and validation rules (no database access, so unit tests can
// import this directly). The app mirrors waterGoalFor in
// gym_bro_mobile/lib/models/user_settings.dart.

/** Extra water on a day with a finished workout. */
export const WORKOUT_BONUS_ML = 500;
/** The goal without a chosen one or a body weight. */
export const DEFAULT_GOAL_ML = 2500;
export const MIN_AUTO_GOAL_ML = 1500;
export const MAX_AUTO_GOAL_ML = 5000;
export const ML_PER_KG = 35;

/** One drink: 1 ml to 3 l (matches the table's check). */
export const MAX_ENTRY_ML = 3000;
/** How far back a drink may be logged. */
export const MAX_BACKDATE_DAYS = 30;
/** Clock skew allowed for a logged_at in the future. */
export const FUTURE_SKEW_MS = 5 * 60_000;

export const DEFAULT_HISTORY_DAYS = 30;
export const MAX_HISTORY_DAYS = 90;

/**
 * The daily goal before the workout bonus: the chosen one, else ~35 ml per kg
 * of body weight rounded to 50 ml and clamped to 1.5–5 l, else 2.5 l.
 */
export function baseGoalMl(chosenMl: number | null | undefined, weightKg: number | null | undefined): number {
  if (chosenMl != null) return chosenMl;
  if (weightKg == null || !Number.isFinite(weightKg) || weightKg <= 0) return DEFAULT_GOAL_ML;
  const ml = Math.round((weightKg * ML_PER_KG) / 50) * 50;
  return Math.min(MAX_AUTO_GOAL_ML, Math.max(MIN_AUTO_GOAL_ML, ml));
}

/** A day's goal: the base, plus the bonus when a workout was finished that day. */
export function dayGoalMl(base: number, workedOut: boolean): number {
  return base + (workedOut ? WORKOUT_BONUS_ML : 0);
}

/** `ml` from a request body: a whole number of ml, or an error message. */
export function readMl(v: unknown): number | string {
  if (typeof v !== "number" || !Number.isInteger(v)) return "ml must be a whole number";
  if (v < 1 || v > MAX_ENTRY_ML) return `ml must be between 1 and ${MAX_ENTRY_ML}`;
  return v;
}

/**
 * Optional `logged_at` from a request body: an ISO timestamp, not in the
 * future and at most MAX_BACKDATE_DAYS back. Undefined means now.
 */
export function readLoggedAt(v: unknown, now = Date.now()): Date | undefined | string {
  if (v === undefined || v === null) return undefined;
  if (typeof v !== "string") return "logged_at must be an ISO timestamp";
  const t = Date.parse(v);
  if (Number.isNaN(t)) return "logged_at must be an ISO timestamp";
  if (t > now + FUTURE_SKEW_MS) return "logged_at can't be in the future";
  if (t < now - MAX_BACKDATE_DAYS * 86_400_000) return `logged_at can be at most ${MAX_BACKDATE_DAYS} days ago`;
  return new Date(t);
}

/** `days` from the query string: 1..MAX_HISTORY_DAYS, default 30. */
export function readDays(v: string | null): number | string {
  if (v === null || v === "") return DEFAULT_HISTORY_DAYS;
  const n = Number(v);
  if (!Number.isInteger(n) || n < 1 || n > MAX_HISTORY_DAYS) return `days must be between 1 and ${MAX_HISTORY_DAYS}`;
  return n;
}
