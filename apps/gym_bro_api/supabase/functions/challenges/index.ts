import { sql } from "npm:kysely@^0.27";
import { db } from "../_shared/config.ts";
import { type Caller, canCoachAtGym, forbidden, isSuperUser, json, jsonError, requireCaller } from "../_shared/auth.ts";
import { teamBusinessIdsSql } from "../_shared/business.ts";
import { notify } from "../_shared/notify.ts";
import { isTimezone } from "../_shared/plans.ts";
import { canSeeContentOf, isBlockedBetween, userSummaries } from "../_shared/social.ts";
import {
  canEditChallenge,
  canSeeChallenge,
  CHALLENGE_COLS,
  type ChallengeRow,
  daysLeft,
  goalText,
  memberGymIdsSql,
  readChallengeInput,
  statusOf,
  syncChallenge,
  syncChallengesOf,
  todayFor,
} from "../_shared/challenges.ts";
import type { BusinessRole } from "../../types/schema/public.ts";

// Challenges: time-boxed goals people join together (rules in _shared/challenges.ts).
//
//   GET    /challenges?status=current|past&gym_id=&joined=1&tz=
//                                   visible challenges (current = active and
//                                   upcoming, the default), with my progress;
//                                   plus what I may create
//   GET    /challenges/completed?user_id=
//                                   someone's completed challenges (medals)
//   GET    /challenges/:id?tz=      one, with my progress and the leaderboard
//   POST   /challenges              create {business_id?, title, description?,
//                                   metric, target, starts_on, ends_on}
//   PATCH  /challenges/:id          edit (creator, the gym's owners, super users)
//   DELETE /challenges/:id          delete (same)
//   POST   /challenges/:id/join     join (until it ends)
//   DELETE /challenges/:id/join     leave (until it ends)
//
// Platform challenges (no business_id) are for everyone and made by super
// users (plus the automatic monthly ones). Gym challenges are made by the
// gym's owners, staff and trainers, for its active members and team.

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const LIST_LIMIT = 100;
const BOARD_LIMIT = 50;
const COMPLETED_LIMIT = 100;

type ListRow = ChallengeRow & {
  business_name: string | null;
  business_logo: string | null;
  participants: number;
  joined_at: string | null;
  progress: number | null;
  completed_at: string | null;
};

/** The gyms where [caller] is on the team, with their roles there. */
async function myGymRoles(caller: Caller): Promise<Map<string, { name: string; logo: string | null; roles: BusinessRole[] }>> {
  const rows = await sql<{ id: string; name: string; logo: string | null; roles: BusinessRole[] }>`
    SELECT b.id, b.name, b.logo, array_agg(m.role::text ORDER BY m.role) AS roles
      FROM business_member m JOIN business b ON b.id = m.business_id
     WHERE m.user_id = ${caller.id} AND m.status = 'active' AND b.status = 'approved' AND b.has_gym
     GROUP BY b.id
     ORDER BY b.name
  `.execute(db);
  return new Map(rows.rows.map((r) => [r.id, { name: r.name, logo: r.logo, roles: r.roles }]));
}

/** canEditChallenge without a query per row. */
function canEditWith(caller: Caller, roles: Awaited<ReturnType<typeof myGymRoles>>, c: ChallengeRow): boolean {
  if (isSuperUser(caller)) return true;
  if (!c.business_id) return false;
  const mine = roles.get(c.business_id)?.roles ?? [];
  return mine.includes("owner") || (c.created_by === caller.id && mine.length > 0);
}

function shape(r: ListRow, today: string, canEdit: boolean) {
  return {
    id: r.id,
    title: r.title,
    description: r.description,
    metric: r.metric,
    target: r.target,
    starts_on: r.starts_on,
    ends_on: r.ends_on,
    auto_key: r.auto_key,
    created_by: r.created_by,
    created_at: r.created_at,
    business: r.business_id ? { id: r.business_id, name: r.business_name, logo: r.business_logo } : null,
    status: statusOf(r, today),
    days_left: daysLeft(r, today),
    participants: r.participants,
    me: r.joined_at
      ? { joined: true, joined_at: r.joined_at, progress: r.progress ?? 0, completed_at: r.completed_at }
      : { joined: false, joined_at: null, progress: 0, completed_at: null },
    can_edit: canEdit,
  };
}

const LIST_SELECT = (callerId: string) =>
  sql`
    SELECT ${CHALLENGE_COLS},
           b.name AS business_name, b.logo AS business_logo,
           (SELECT COUNT(*) FROM challenge_participant x WHERE x.challenge_id = c.id)::int AS participants,
           me.joined_at, me.progress, me.completed_at
      FROM challenge c
      LEFT JOIN business b ON b.id = c.business_id
      LEFT JOIN challenge_participant me ON me.challenge_id = c.id AND me.user_id = ${callerId}`;

async function loadOne(callerId: string, id: string): Promise<ListRow | null> {
  const rows = await sql<ListRow>`${LIST_SELECT(callerId)} WHERE c.id = ${id}`.execute(db);
  return rows.rows[0] ?? null;
}

/** The challenge as GET /challenges/:id returns it: mine, plus the leaderboard. */
async function detail(caller: Caller, id: string, today: string) {
  const row = await loadOne(caller.id, id);
  if (!row) return null;
  const board = await sql<{ user_id: string; progress: number; completed_at: string | null; rank: number }>`
    SELECT cp.user_id, cp.progress, cp.completed_at,
           RANK() OVER (ORDER BY cp.progress DESC)::int AS rank
      FROM challenge_participant cp
      LEFT JOIN user_settings us ON us.user_id = cp.user_id
     WHERE cp.challenge_id = ${id}
       AND (cp.user_id = ${caller.id} OR (
            COALESCE(us.show_on_gym_boards, TRUE)
        AND NOT EXISTS (
              SELECT 1 FROM user_block ub
               WHERE (ub.blocker_id = ${caller.id} AND ub.blocked_id = cp.user_id)
                  OR (ub.blocker_id = cp.user_id AND ub.blocked_id = ${caller.id}))))
     ORDER BY cp.progress DESC, cp.completed_at ASC NULLS LAST, cp.joined_at ASC, cp.user_id
  `.execute(db);
  const top = board.rows.slice(0, BOARD_LIMIT);
  const mine = board.rows.find((r) => r.user_id === caller.id) ?? null;
  const people = await userSummaries([...top.map((r) => r.user_id), row.created_by, mine?.user_id]);
  const entry = (r: (typeof board.rows)[number]) => ({
    rank: r.rank,
    progress: r.progress,
    completed_at: r.completed_at,
    user: people[r.user_id] ?? null,
  });
  const roles = await myGymRoles(caller);
  return {
    ...shape(row, today, canEditWith(caller, roles, row)),
    creator: row.created_by ? people[row.created_by] ?? null : null,
    leaderboard: top.map(entry),
    my_rank: mine?.rank ?? null,
  };
}

async function notifyGymOfNewChallenge(c: ChallengeRow, creatorId: string) {
  const gym = await db.selectFrom("business").select("name").where("id", "=", c.business_id!).executeTakeFirst();
  const members = await sql<{ user_id: string }>`
    SELECT DISTINCT m.user_id
      FROM membership m JOIN gym_membership_type t ON t.id = m.current_membership_type_id
     WHERE t.gym_id = ${c.business_id} AND m.is_active AND CURRENT_DATE BETWEEN m.from_date AND m.to_date
       AND m.user_id <> ${creatorId}
  `.execute(db);
  if (!members.rows.length) return;
  await notify(members.rows.map((r) => r.user_id), {
    type: "challenge",
    title: `New challenge at ${gym?.name ?? "your gym"}`,
    body: `${c.title}: ${goalText(c.metric, c.target)} by ${c.ends_on}. Join in!`,
    metadata: {
      kind: "new",
      challenge_id: c.id,
      title: c.title,
      business_id: c.business_id,
      gym_name: gym?.name ?? null,
    },
  });
}

async function handler(req: Request): Promise<Response> {
  const { caller, response } = await requireCaller(req);
  if (!caller) return response;
  const url = new URL(req.url);
  const parts = url.pathname.replace(/^\/challenges\/?/, "").split("/").filter(Boolean);
  const tzParam = url.searchParams.get("tz");
  if (tzParam && !isTimezone(tzParam)) return jsonError("tz must be an IANA zone", 400);
  const today = await todayFor(caller.id, tzParam);

  // ── GET /challenges ───────────────────────────────────────────────────────────
  if (req.method === "GET" && parts.length === 0) {
    const status = url.searchParams.get("status") ?? "current";
    if (status !== "current" && status !== "past") return jsonError("status must be current or past", 400);
    const gymId = url.searchParams.get("gym_id");
    if (gymId !== null && !UUID_RE.test(gymId)) return jsonError("gym_id must be a UUID", 400);
    const joinedOnly = url.searchParams.get("joined") === "1";

    if (gymId && !(await canSeeChallenge(caller, { business_id: gymId }))) {
      return jsonError("Gym challenges are for the gym's members", 403);
    }
    // My progress, fresh.
    await syncChallengesOf(caller.id);

    const visible = gymId ? sql`c.business_id = ${gymId}` : sql`(
      c.business_id IS NULL
      OR me.user_id IS NOT NULL
      OR (b.status = 'approved' AND b.has_gym AND (
            c.business_id IN (${memberGymIdsSql(caller.id)})
         OR c.business_id IN (${teamBusinessIdsSql(caller.id)}))))`;
    const window = status === "current"
      ? sql`c.ends_on >= ${today}::date ORDER BY (c.starts_on > ${today}::date), c.ends_on, c.starts_on, c.created_at`
      : sql`c.ends_on < ${today}::date ORDER BY c.ends_on DESC, c.created_at DESC`;
    const rows = await sql<ListRow>`
      ${LIST_SELECT(caller.id)}
       WHERE ${visible}
         ${joinedOnly ? sql`AND me.user_id IS NOT NULL` : sql``}
         AND ${window}
       LIMIT ${LIST_LIMIT}
    `.execute(db);

    const roles = await myGymRoles(caller);
    return json({
      today,
      items: rows.rows.map((r) => shape(r, today, canEditWith(caller, roles, r))),
      can_create_platform: isSuperUser(caller),
      creatable_gyms: [...roles].map(([id, g]) => ({ id, name: g.name, logo: g.logo })),
    });
  }

  // ── GET /challenges/completed?user_id= ────────────────────────────────────────
  if (req.method === "GET" && parts.length === 1 && parts[0] === "completed") {
    const userId = url.searchParams.get("user_id") ?? caller.id;
    if (!UUID_RE.test(userId)) return jsonError("user_id must be a UUID", 400);
    let showItems = true;
    if (userId !== caller.id) {
      if (await isBlockedBetween(caller.id, userId)) return jsonError("User not found", 404);
      const owner = await db.selectFrom("users").select(["id", "is_private"]).where("id", "=", userId)
        .executeTakeFirst();
      if (!owner) return jsonError("User not found", 404);
      // Like posts: a private account's list is for its followers; the count is public.
      showItems = await canSeeContentOf(caller.id, owner);
    } else {
      await syncChallengesOf(caller.id);
    }
    const rows = await sql<ChallengeRow & { business_name: string | null; business_logo: string | null; completed_at: string }>`
      SELECT ${CHALLENGE_COLS}, b.name AS business_name, b.logo AS business_logo, cp.completed_at
        FROM challenge_participant cp
        JOIN challenge c ON c.id = cp.challenge_id
        LEFT JOIN business b ON b.id = c.business_id
       WHERE cp.user_id = ${userId} AND cp.completed_at IS NOT NULL
       ORDER BY cp.completed_at DESC
    `.execute(db);
    return json({
      user_id: userId,
      count: rows.rows.length,
      items: showItems
        ? rows.rows.slice(0, COMPLETED_LIMIT).map((r) => ({
          id: r.id,
          title: r.title,
          metric: r.metric,
          target: r.target,
          starts_on: r.starts_on,
          ends_on: r.ends_on,
          auto_key: r.auto_key,
          business: r.business_id ? { id: r.business_id, name: r.business_name, logo: r.business_logo } : null,
          completed_at: r.completed_at,
        }))
        : [],
      private: !showItems,
    });
  }

  // ── POST /challenges ──────────────────────────────────────────────────────────
  if (req.method === "POST" && parts.length === 0) {
    const body = await req.json().catch(() => null);
    const read = readChallengeInput(body, { today });
    if ("error" in read) return jsonError(read.error, 400);
    const v = read.values;
    if (v.business_id) {
      if (!UUID_RE.test(v.business_id)) return jsonError("Gym not found", 404);
      const gym = await db.selectFrom("business").select(["id"]).where("id", "=", v.business_id)
        .where("has_gym", "=", true).executeTakeFirst();
      if (!gym) return jsonError("Gym not found", 404);
      if (!(await canCoachAtGym(caller, v.business_id))) {
        return forbidden("Only the gym's owners, staff and trainers can create its challenges");
      }
    } else if (!isSuperUser(caller)) {
      return forbidden("Only super users can create platform challenges");
    }
    const created = await db.insertInto("challenge").values({
      business_id: v.business_id ?? null,
      created_by: caller.id,
      title: v.title!,
      description: v.description ?? null,
      metric: v.metric!,
      target: v.target!,
      starts_on: v.starts_on!,
      ends_on: v.ends_on!,
    }).returning("id").executeTakeFirstOrThrow();
    const row = (await loadOne(caller.id, created.id))!;
    if (row.business_id) await notifyGymOfNewChallenge(row, caller.id);
    return json(await detail(caller, created.id, today), 201);
  }

  const id = parts[0];
  if (!id || !UUID_RE.test(id)) return jsonError("Not found", 404);
  const c = await loadOne(caller.id, id);
  if (!c || !(await canSeeChallenge(caller, c))) return jsonError("Challenge not found", 404);

  // ── GET /challenges/:id ───────────────────────────────────────────────────────
  if (req.method === "GET" && parts.length === 1) {
    await syncChallenge(c);
    return json(await detail(caller, id, today));
  }

  // ── PATCH /challenges/:id ─────────────────────────────────────────────────────
  if (req.method === "PATCH" && parts.length === 1) {
    if (!(await canEditChallenge(caller, c))) return forbidden("Only its creator or the gym's owners can edit it");
    const body = await req.json().catch(() => null);
    const read = readChallengeInput(body, { today, existing: c });
    if ("error" in read) return jsonError(read.error, 400);
    const { business_id: _ignored, ...v } = read.values;
    if (Object.keys(v).length) {
      await db.updateTable("challenge").set({ ...v, updated_at: sql<string>`now()` }).where("id", "=", id).execute();
      const updated = (await loadOne(caller.id, id))!;
      // A lower target can complete people; a new window changes everyone's progress.
      await syncChallenge(updated);
    }
    return json(await detail(caller, id, today));
  }

  // ── DELETE /challenges/:id ────────────────────────────────────────────────────
  if (req.method === "DELETE" && parts.length === 1) {
    if (!(await canEditChallenge(caller, c))) return forbidden("Only its creator or the gym's owners can delete it");
    await db.deleteFrom("challenge").where("id", "=", id).execute();
    return new Response(null, { status: 204 });
  }

  // ── POST|DELETE /challenges/:id/join ──────────────────────────────────────────
  if (parts.length === 2 && parts[1] === "join" && (req.method === "POST" || req.method === "DELETE")) {
    if (statusOf(c, today) === "past") return jsonError("This challenge is over", 400, { code: "challenge_over" });
    if (req.method === "DELETE") {
      await db.deleteFrom("challenge_participant").where("challenge_id", "=", id).where("user_id", "=", caller.id)
        .execute();
      return new Response(null, { status: 204 });
    }
    await db.insertInto("challenge_participant").values({ challenge_id: id, user_id: caller.id })
      .onConflict((oc) => oc.columns(["challenge_id", "user_id"]).doNothing()).execute();
    // Workouts earlier in the window count, so joining can complete it at once.
    await syncChallenge(c, [caller.id]);
    return json(await detail(caller, id, today));
  }

  return jsonError("Not found", 404);
}

Deno.serve(async (req: Request) => {
  try {
    return await handler(req);
  } catch (e) {
    console.error("challenges", e);
    return jsonError("Something went wrong", 500);
  }
});
