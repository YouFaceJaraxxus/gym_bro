import { db } from "../_shared/config.ts";
import { canCoachAtGym, isSuperUser, json, jsonError, requireCaller } from "../_shared/auth.ts";
import { isTimezone } from "../_shared/plans.ts";
import { isBlockedBetween, userSummaries } from "../_shared/social.ts";
import {
  type Board,
  BOARDS,
  boardRows,
  dayCol,
  gymStreakRanks,
  isActiveMember,
  MAX_FREEZES,
  refreshStreak,
  STREAK_TIERS,
} from "../_shared/streaks.ts";

// Workout streaks and gym boards (rules in _shared/streaks.ts).
//
//   GET /streaks?tz=                    my streak, brought up to date: status,
//                                       this week, recent events, gym ranks
//   GET /streaks?user_id=               someone's public streak (current, best,
//                                       badges, best gym rank)
//   GET /streaks/boards/:gymId?board=streak|workouts|check_ins&tz=
//                                       the gym's board (top 50 + me; workouts
//                                       and check-ins over the last 30 days);
//                                       for its active members, team and super users

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const BOARD_LIMIT = 50;
const EVENT_LIMIT = 30;
/** The workouts and check-ins boards count this many days back. */
const BOARD_DAYS = 30;

async function handler(req: Request): Promise<Response> {
  const { caller, response } = await requireCaller(req);
  if (!caller) return response;
  const url = new URL(req.url);
  const parts = url.pathname.replace(/^\/streaks\/?/, "").split("/").filter(Boolean);
  const tzParam = url.searchParams.get("tz");
  if (tzParam && !isTimezone(tzParam)) return jsonError("tz must be an IANA zone", 400);

  if (req.method !== "GET") return jsonError("Not found", 404);

  // ── GET /streaks ──────────────────────────────────────────────────────────────
  if (parts.length === 0) {
    const userId = url.searchParams.get("user_id") ?? caller.id;
    if (!UUID_RE.test(userId)) return jsonError("user_id must be a UUID", 400);

    if (userId !== caller.id) {
      if (await isBlockedBetween(caller.id, userId)) return jsonError("User not found", 404);
      const exists = await db.selectFrom("users").select("id").where("id", "=", userId).executeTakeFirst();
      if (!exists) return jsonError("User not found", 404);
      const s = await refreshStreak(userId);
      const ranks = await gymStreakRanks(userId);
      return json({
        user_id: userId,
        current: s.current,
        best: s.best,
        tier: s.tier,
        best_tier: s.best_tier,
        gym_rank: ranks[0] ?? null,
      });
    }

    const status = await refreshStreak(caller.id, { tz: tzParam });
    const [events, ranks] = await Promise.all([
      db.selectFrom("streak_event")
        .select(["kind", dayCol("on_date"), "streak", "tier", "created_at"])
        .where("user_id", "=", caller.id)
        .orderBy("on_date", "desc")
        .orderBy("created_at", "desc")
        .limit(EVENT_LIMIT)
        .execute(),
      gymStreakRanks(caller.id),
    ]);
    return json({
      ...status,
      max_freezes: MAX_FREEZES,
      tiers: STREAK_TIERS,
      events,
      ranks,
    });
  }

  // ── GET /streaks/boards/:gymId ────────────────────────────────────────────────
  if (parts[0] === "boards" && parts.length === 2) {
    const gymId = parts[1];
    if (!UUID_RE.test(gymId)) return jsonError("Gym not found", 404);
    const board = (url.searchParams.get("board") ?? "streak") as Board;
    if (!BOARDS.includes(board)) return jsonError(`board must be one of: ${BOARDS.join(", ")}`, 400);

    const gym = await db.selectFrom("business").select(["id", "name", "logo"]).where("id", "=", gymId)
      .where("has_gym", "=", true).executeTakeFirst();
    if (!gym) return jsonError("Gym not found", 404);
    const member = await isActiveMember(caller.id, gymId);
    if (!member && !isSuperUser(caller) && !(await canCoachAtGym(caller, gymId))) {
      return jsonError("Gym boards are for the gym's members", 403);
    }

    // My own number is always current.
    if (member) await refreshStreak(caller.id, { tz: tzParam });
    const since = new Date(Date.now() - BOARD_DAYS * 86_400_000).toISOString();
    const rows = await boardRows(gymId, board, since);
    const top = rows.slice(0, BOARD_LIMIT);
    const mineIndex = rows.findIndex((r) => r.user_id === caller.id);
    const mine = mineIndex >= 0 ? rows[mineIndex] : null;
    // How much more it takes to pass the next person up.
    const ahead = mine ? rows.slice(0, mineIndex).findLast((r) => r.value > mine.value) : undefined;

    const people = await userSummaries([...top.map((r) => r.user_id), ...(mine ? [mine.user_id] : [])]);
    const entry = (r: (typeof rows)[number]) => ({ rank: r.rank, value: r.value, user: people[r.user_id] ?? null });
    return json({
      gym,
      board,
      since: board === "streak" ? null : since,
      total: rows.length,
      entries: top.map(entry),
      me: mine ? { ...entry(mine), gap: ahead ? ahead.value - mine.value + 1 : 0 } : null,
    });
  }

  return jsonError("Not found", 404);
}

Deno.serve(async (req: Request) => {
  try {
    return await handler(req);
  } catch (e) {
    console.error("streaks", e);
    return jsonError("Something went wrong", 500);
  }
});
