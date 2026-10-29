import { sql } from "npm:kysely@^0.27";
import { db } from "../_shared/config.ts";
import { type Caller, isSuperUser, json, jsonError, requireCaller } from "../_shared/auth.ts";
import { notify } from "../_shared/notify.ts";
import { broadcastToUsers } from "../_shared/realtime.ts";
import {
  blockedIds,
  canSeeContentOf,
  directMessageStatus,
  displayName,
  isBlockedBetween,
  parsePaging,
  PUBLIC_USER_COLS,
  relationship,
  relationships,
  touchActivity,
  unreadMessageSql,
  type UserSummary,
} from "../_shared/social.ts";
import type { ReportReason, WhoCanMessage } from "../../types/schema/public.ts";

// People: profiles, follows, friends, blocks, reports, search and discovery.
//
//   GET    /social/me                              own profile + privacy settings
//   PUT    /social/me                              edit profile / settings
//   PUT    /social/me/location {lat,lng}           coarse location for discovery
//   DELETE /social/me/location
//   GET    /social/badges                          counts for nav badges
//   GET    /social/users/:id | /social/users/by-username/:username
//   GET    /social/users/:id/followers|following|friends|mutual-friends
//   POST   /social/users/:id/follow                follow / request
//   DELETE /social/users/:id/follow                unfollow / cancel request
//   DELETE /social/users/:id/follower              remove them as my follower
//   POST   /social/users/:id/friend                request / accept theirs
//   DELETE /social/users/:id/friend                unfriend / cancel / decline
//   POST   /social/users/:id/block, DELETE …/block
//   GET    /social/blocks
//   GET    /social/follow-requests                 incoming, pending
//   POST   /social/follow-requests/:userId/accept, DELETE /social/follow-requests/:userId
//   GET    /social/friend-requests?direction=incoming|outgoing
//   POST   /social/reports {user_id, message_id?, reason, details?}
//   GET    /social/reports                         super user: open reports
//   POST   /social/reports/:id/resolve             super user
//   GET    /social/search?q=                       people search
//   GET    /social/suggestions                     people you may know
//   GET    /social/nearby?radius_km=               discoverable people near me

const BIO_MAX = 300;
const INTEREST_MAX = 30;
const INTERESTS_MAX = 10;
const WHO_CAN_MESSAGE: readonly WhoCanMessage[] = ["everyone", "following", "friends"];
const REPORT_REASONS: readonly ReportReason[] = ["spam", "harassment", "inappropriate", "impersonation", "other"];
const USERNAME_RE = /^[a-zA-Z0-9._]{3,30}$/;

type Route =
  | { kind: "me" }
  | { kind: "me_location" }
  | { kind: "badges" }
  | { kind: "user"; id?: string; username?: string }
  | { kind: "user_list"; id: string; list: "followers" | "following" | "friends" | "mutual-friends" }
  | { kind: "user_action"; id: string; action: "follow" | "follower" | "friend" | "block" }
  | { kind: "blocks" }
  | { kind: "follow_requests" }
  | { kind: "follow_request"; userId: string; accept: boolean }
  | { kind: "friend_requests" }
  | { kind: "reports" }
  | { kind: "report_resolve"; id: string }
  | { kind: "search" }
  | { kind: "suggestions" }
  | { kind: "nearby" }
  | { kind: "unknown" };

function parsePath(pathname: string): Route {
  const p = pathname.replace(/\/+$/, "");
  if (p === "/social/me") return { kind: "me" };
  if (p === "/social/me/location") return { kind: "me_location" };
  if (p === "/social/badges") return { kind: "badges" };
  if (p === "/social/blocks") return { kind: "blocks" };
  if (p === "/social/follow-requests") return { kind: "follow_requests" };
  if (p === "/social/friend-requests") return { kind: "friend_requests" };
  if (p === "/social/reports") return { kind: "reports" };
  if (p === "/social/search") return { kind: "search" };
  if (p === "/social/suggestions") return { kind: "suggestions" };
  if (p === "/social/nearby") return { kind: "nearby" };
  let m = p.match(/^\/social\/reports\/([^/]+)\/resolve$/);
  if (m) return { kind: "report_resolve", id: m[1] };
  m = p.match(/^\/social\/follow-requests\/([^/]+)(\/accept)?$/);
  if (m) return { kind: "follow_request", userId: m[1], accept: !!m[2] };
  m = p.match(/^\/social\/users\/by-username\/([^/]+)$/);
  if (m) return { kind: "user", username: decodeURIComponent(m[1]) };
  m = p.match(/^\/social\/users\/([^/]+)\/(followers|following|friends|mutual-friends)$/);
  if (m) return { kind: "user_list", id: m[1], list: m[2] as "followers" };
  m = p.match(/^\/social\/users\/([^/]+)\/(follow|follower|friend|block)$/);
  if (m) return { kind: "user_action", id: m[1], action: m[2] as "follow" };
  m = p.match(/^\/social\/users\/([^/]+)$/);
  if (m) return { kind: "user", id: m[1] };
  return { kind: "unknown" };
}

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

// ── Profile building ─────────────────────────────────────────────────────────

const PROFILE_COLS = [
  ...PUBLIC_USER_COLS,
  "role",
  "bio",
  "interests",
  "is_private",
  "who_can_message",
  "show_activity_status",
  "last_active_at",
  "created_at",
] as const;

type ProfileRow = {
  id: string;
  username: string;
  name: string;
  last_name: string;
  avatar_url: string | null;
  role: string;
  bio: string | null;
  interests: string[];
  is_private: boolean;
  who_can_message: WhoCanMessage;
  show_activity_status: boolean;
  last_active_at: string | null;
  created_at: string;
};

async function counts(userId: string) {
  const { rows: [c] } = await sql<{ posts: number; followers: number; following: number; friends: number }>`
    SELECT
      (SELECT count(*)::int FROM post WHERE author_id = ${userId} AND business_id IS NULL) AS posts,
      (SELECT count(*)::int FROM follow WHERE followee_id = ${userId} AND status = 'accepted') AS followers,
      (SELECT count(*)::int FROM follow WHERE follower_id = ${userId} AND status = 'accepted') AS following,
      (SELECT count(*)::int FROM friendship
        WHERE (requester_id = ${userId} OR addressee_id = ${userId}) AND status = 'accepted') AS friends
  `.execute(db);
  return c;
}

/** Ids of the accepted friends of `userId`. */
function friendIdsQuery(userId: string) {
  return sql<{ id: string }>`
    SELECT CASE WHEN requester_id = ${userId} THEN addressee_id ELSE requester_id END AS id
    FROM friendship
    WHERE (requester_id = ${userId} OR addressee_id = ${userId}) AND status = 'accepted'
  `;
}

async function mutualFriends(meId: string, otherId: string, limit: number, offset = 0) {
  const { rows } = await sql<UserSummary & { total: number }>`
    WITH mine AS (${friendIdsQuery(meId)}), theirs AS (${friendIdsQuery(otherId)})
    SELECT u.id, u.username, u.name, u.last_name, u.avatar_url, count(*) OVER ()::int AS total
    FROM mine JOIN theirs USING (id) JOIN users u ON u.id = mine.id
    ORDER BY u.name, u.last_name
    LIMIT ${limit} OFFSET ${offset}
  `.execute(db);
  return { total: rows[0]?.total ?? 0, users: rows.map(({ total: _t, ...u }) => u) };
}

async function gymsOf(userId: string) {
  const { rows } = await sql<{ id: string; name: string; logo: string | null }>`
    SELECT DISTINCT b.id, b.name, b.logo FROM business b
    JOIN (
      SELECT gym_id FROM member WHERE user_id = ${userId}
      UNION SELECT gym_id FROM trainer WHERE user_id = ${userId}
      UNION SELECT gym_id FROM employee WHERE user_id = ${userId}
      UNION SELECT gym_id FROM employee_trainer WHERE user_id = ${userId}
      UNION SELECT gym_id FROM gym_owner WHERE user_id = ${userId}
    ) g ON g.gym_id = b.id
    ORDER BY b.name
  `.execute(db);
  return rows;
}

async function buildProfile(caller: Caller, u: ProfileRow) {
  const isMe = u.id === caller.id;
  const [c, rel, canView, gyms, mutual] = await Promise.all([
    counts(u.id),
    isMe ? Promise.resolve(null) : relationship(caller.id, u.id),
    canSeeContentOf(caller.id, u),
    gymsOf(u.id),
    isMe ? Promise.resolve({ total: 0, users: [] }) : mutualFriends(caller.id, u.id, 3),
  ]);
  const connected = !!rel && (rel.friendship === "friends" || (rel.following === "accepted" && rel.followed_by === "accepted"));
  const showActivity = u.show_activity_status && (isMe || connected);
  return {
    id: u.id,
    username: u.username,
    name: u.name,
    last_name: u.last_name,
    avatar_url: u.avatar_url,
    role: u.role,
    bio: u.bio,
    interests: u.interests,
    is_private: u.is_private,
    created_at: u.created_at,
    is_me: isMe,
    counts: c,
    relationship: rel,
    can_view_content: canView,
    message_status: isMe ? null : await directMessageStatus(caller.id, u),
    mutual_friends: { count: mutual.total, preview: mutual.users },
    gyms: canView ? gyms : [],
    last_active_at: showActivity ? u.last_active_at : null,
  };
}

/** Adds relationship + is_private + bio to a list of user rows. */
async function decorateUsers<T extends { id: string }>(caller: Caller, users: T[]) {
  const rels = await relationships(caller.id, users.map((u) => u.id));
  const extra = users.length
    ? await db.selectFrom("users").select(["id", "bio", "is_private"]).where("id", "in", users.map((u) => u.id)).execute()
    : [];
  const byId = new Map(extra.map((e) => [e.id, e]));
  return users.map((u) => ({
    ...u,
    bio: byId.get(u.id)?.bio ?? null,
    is_private: byId.get(u.id)?.is_private ?? false,
    relationship: u.id === caller.id ? null : rels.get(u.id) ?? null,
  }));
}

// ── Mutations ─────────────────────────────────────────────────────────────────

async function follow(caller: Caller, target: { id: string; is_private: boolean }) {
  const status = target.is_private ? "pending" : "accepted";
  const inserted = await db
    .insertInto("follow")
    .values({
      follower_id: caller.id,
      followee_id: target.id,
      status,
      accepted_at: status === "accepted" ? new Date().toISOString() : null,
    })
    .onConflict((oc) => oc.columns(["follower_id", "followee_id"]).doNothing())
    .returning("status")
    .executeTakeFirst();
  if (inserted) {
    const who = displayName(caller);
    await notify([target.id], status === "accepted"
      ? { type: "follow", title: `${who} started following you`, body: "", metadata: { user_id: caller.id } }
      : { type: "follow_request", title: `${who} wants to follow you`, body: "", metadata: { user_id: caller.id } });
  }
}

async function removeFollow(followerId: string, followeeId: string) {
  await db.deleteFrom("follow").where("follower_id", "=", followerId).where("followee_id", "=", followeeId).execute();
}

async function deleteFriendship(a: string, b: string) {
  await db.deleteFrom("friendship")
    .where((eb) =>
      eb.or([
        eb.and([eb("requester_id", "=", a), eb("addressee_id", "=", b)]),
        eb.and([eb("requester_id", "=", b), eb("addressee_id", "=", a)]),
      ])
    )
    .execute();
}

// ── Discovery ─────────────────────────────────────────────────────────────────
// "People you may know": every candidate gets points for each signal and the
// signals come back as `reasons` the app turns into copy:
//   same_gym       member/staff of one of my gyms                     +40
//   same_time      checked in at the same gym within 90 min of me      +3/day, max 30
//   same_class     booked the same class                               +4 each, max 20
//   mutual         connected (friend or accepted follow) to my people  +8 each, max 40
//   follows_you    follows me and I don't follow back                  +25
//   nearby         within 50 km (coarse locations)                     up to +25
//   interests      shared interests                                    +5 each, max 20
//   active         active in the last week                             +5
// Excluded: me, people I follow/requested, friends/pending friendships,
// blocks either way, and non-discoverable accounts.

type Suggestion = UserSummary & {
  score: number;
  same_gyms: string[] | null;
  co_visit_days: number;
  co_classes: number;
  mutual_count: number;
  follows_me: boolean;
  distance_km: number | null;
  shared_interests: string[];
};

async function suggestions(meId: string, limit: number, offset: number): Promise<Suggestion[]> {
  const { rows } = await sql<Suggestion>`
    WITH me AS (
      SELECT id, location_lat, location_lng, interests FROM users WHERE id = ${meId}
    ),
    my_gyms AS (
      SELECT gym_id FROM member WHERE user_id = ${meId}
      UNION SELECT gym_id FROM trainer WHERE user_id = ${meId}
      UNION SELECT gym_id FROM employee WHERE user_id = ${meId}
      UNION SELECT gym_id FROM employee_trainer WHERE user_id = ${meId}
      UNION SELECT gym_id FROM gym_owner WHERE user_id = ${meId}
    ),
    excluded AS (
      SELECT ${meId}::uuid AS id
      UNION SELECT followee_id FROM follow WHERE follower_id = ${meId}
      UNION SELECT CASE WHEN requester_id = ${meId} THEN addressee_id ELSE requester_id END
            FROM friendship WHERE requester_id = ${meId} OR addressee_id = ${meId}
      UNION SELECT blocked_id FROM user_block WHERE blocker_id = ${meId}
      UNION SELECT blocker_id FROM user_block WHERE blocked_id = ${meId}
    ),
    my_conn AS (
      SELECT followee_id AS id FROM follow WHERE follower_id = ${meId} AND status = 'accepted'
      UNION SELECT CASE WHEN requester_id = ${meId} THEN addressee_id ELSE requester_id END
            FROM friendship WHERE (requester_id = ${meId} OR addressee_id = ${meId}) AND status = 'accepted'
    ),
    gym_people AS (
      SELECT user_id, gym_id FROM member
      UNION SELECT user_id, gym_id FROM trainer
      UNION SELECT user_id, gym_id FROM employee
      UNION SELECT user_id, gym_id FROM employee_trainer
      UNION SELECT user_id, gym_id FROM gym_owner
    ),
    same_gym AS (
      SELECT gp.user_id, array_agg(DISTINCT b.name ORDER BY b.name) AS gyms
      FROM gym_people gp JOIN my_gyms USING (gym_id) JOIN business b ON b.id = gp.gym_id
      GROUP BY gp.user_id
    ),
    co_visits AS (
      SELECT o.user_id, count(DISTINCT date_trunc('day', mine.checked_in_at))::int AS days
      FROM check_in mine
      JOIN check_in o ON o.gym_id = mine.gym_id AND o.user_id <> mine.user_id
        AND o.checked_in_at BETWEEN mine.checked_in_at - INTERVAL '90 minutes' AND mine.checked_in_at + INTERVAL '90 minutes'
      WHERE mine.user_id = ${meId} AND mine.checked_in_at > NOW() - INTERVAL '60 days'
      GROUP BY o.user_id
    ),
    co_classes AS (
      SELECT o.user_id, count(*)::int AS n
      FROM class_booking mine
      JOIN class_booking o ON o.class_id = mine.class_id AND o.user_id <> mine.user_id
      WHERE mine.user_id = ${meId}
        AND mine.status IN ('booked', 'attended') AND o.status IN ('booked', 'attended')
      GROUP BY o.user_id
    ),
    mutuals AS (
      SELECT x.id AS user_id, count(DISTINCT c.id)::int AS n
      FROM my_conn c
      JOIN LATERAL (
        SELECT followee_id AS id FROM follow WHERE follower_id = c.id AND status = 'accepted'
        UNION SELECT follower_id FROM follow WHERE followee_id = c.id AND status = 'accepted'
        UNION SELECT CASE WHEN requester_id = c.id THEN addressee_id ELSE requester_id END
              FROM friendship WHERE (requester_id = c.id OR addressee_id = c.id) AND status = 'accepted'
      ) x ON TRUE
      GROUP BY x.id
    ),
    follows_me AS (
      SELECT follower_id AS user_id FROM follow WHERE followee_id = ${meId} AND status = 'accepted'
    ),
    near AS (
      SELECT u.id AS user_id, haversine_km(me.location_lat, me.location_lng, u.location_lat, u.location_lng) AS km
      FROM users u, me
      WHERE me.location_lat IS NOT NULL AND u.location_lat IS NOT NULL
        AND haversine_km(me.location_lat, me.location_lng, u.location_lat, u.location_lng) <= 50
    ),
    candidates AS (
      SELECT user_id FROM same_gym
      UNION SELECT user_id FROM co_visits
      UNION SELECT user_id FROM co_classes
      UNION SELECT user_id FROM mutuals
      UNION SELECT user_id FROM follows_me
      UNION SELECT user_id FROM near
      UNION SELECT u.id FROM users u, me WHERE cardinality(me.interests) > 0 AND u.interests && me.interests
    ),
    scored AS (
      SELECT
        u.id, u.username, u.name, u.last_name, u.avatar_url,
        sg.gyms AS same_gyms,
        COALESCE(cv.days, 0) AS co_visit_days,
        COALESCE(cc.n, 0) AS co_classes,
        COALESCE(mu.n, 0) AS mutual_count,
        (fm.user_id IS NOT NULL) AS follows_me,
        CASE WHEN nr.km IS NULL THEN NULL ELSE round(nr.km)::int END AS distance_km,
        ARRAY(SELECT unnest(u.interests) INTERSECT SELECT unnest(me.interests)) AS shared_interests,
        u.last_active_at
      FROM candidates c
      JOIN users u ON u.id = c.user_id
      CROSS JOIN me
      LEFT JOIN same_gym sg ON sg.user_id = u.id
      LEFT JOIN co_visits cv ON cv.user_id = u.id
      LEFT JOIN co_classes cc ON cc.user_id = u.id
      LEFT JOIN mutuals mu ON mu.user_id = u.id
      LEFT JOIN follows_me fm ON fm.user_id = u.id
      LEFT JOIN near nr ON nr.user_id = u.id
      WHERE u.discoverable AND u.id NOT IN (SELECT id FROM excluded)
    )
    SELECT
      id, username, name, last_name, avatar_url, same_gyms, co_visit_days, co_classes,
      mutual_count, follows_me, distance_km, shared_interests,
      (
        CASE WHEN same_gyms IS NOT NULL THEN 40 ELSE 0 END
        + LEAST(30, 3 * co_visit_days)
        + LEAST(20, 4 * co_classes)
        + LEAST(40, 8 * mutual_count)
        + CASE WHEN follows_me THEN 25 ELSE 0 END
        + CASE WHEN distance_km IS NULL THEN 0 ELSE 25 * (1 - LEAST(distance_km, 50) / 50.0) END
        + LEAST(20, 5 * cardinality(shared_interests))
        + CASE WHEN last_active_at > NOW() - INTERVAL '7 days' THEN 5 ELSE 0 END
      )::float AS score
    FROM scored
    ORDER BY score DESC, name, id
    LIMIT ${limit} OFFSET ${offset}
  `.execute(db);
  return rows;
}

function suggestionReasons(s: Suggestion) {
  const reasons: Record<string, unknown>[] = [];
  if (s.follows_me) reasons.push({ type: "follows_you" });
  if (s.mutual_count > 0) reasons.push({ type: "mutual", count: s.mutual_count });
  if (s.same_gyms?.length) reasons.push({ type: "same_gym", gyms: s.same_gyms });
  if (s.co_visit_days >= 2) reasons.push({ type: "same_time", days: s.co_visit_days });
  if (s.co_classes > 0) reasons.push({ type: "same_class", count: s.co_classes });
  if (s.distance_km !== null) reasons.push({ type: "nearby", km: s.distance_km });
  if (s.shared_interests.length) reasons.push({ type: "interests", interests: s.shared_interests });
  return reasons;
}

// ── Handler ───────────────────────────────────────────────────────────────────

async function handler(req: Request): Promise<Response> {
  const url = new URL(req.url);
  const route = parsePath(url.pathname);
  if (route.kind === "unknown") return jsonError("Not found", 404);

  const { caller, response } = await requireCaller(req);
  if (!caller) return response;
  await touchActivity(caller.id);

  // ── GET /social/me ───────────────────────────────────────────────────────────
  if (req.method === "GET" && route.kind === "me") {
    const u = await db.selectFrom("users")
      .select([...PROFILE_COLS, "discoverable", "location_updated_at", "location_lat"])
      .where("id", "=", caller.id)
      .executeTakeFirstOrThrow();
    const { location_lat, ...rest } = u;
    return json({
      ...(await buildProfile(caller, rest)),
      settings: {
        is_private: u.is_private,
        discoverable: u.discoverable,
        who_can_message: u.who_can_message,
        show_activity_status: u.show_activity_status,
        has_location: location_lat !== null,
        location_updated_at: u.location_updated_at,
      },
    });
  }

  // ── PUT /social/me ───────────────────────────────────────────────────────────
  // Going public auto-accepts every pending follow request.
  if (req.method === "PUT" && route.kind === "me") {
    const body = await req.json().catch(() => null);
    if (!body || typeof body !== "object") return jsonError("Expected a JSON object", 400);
    const update: Record<string, unknown> = {};

    if ("bio" in body) {
      if (body.bio !== null && typeof body.bio !== "string") return jsonError("bio must be a string", 400);
      const bio = body.bio?.trim() || null;
      if (bio && bio.length > BIO_MAX) return jsonError(`bio is limited to ${BIO_MAX} characters`, 400);
      update.bio = bio;
    }
    for (const key of ["is_private", "discoverable", "show_activity_status"] as const) {
      if (key in body) {
        if (typeof body[key] !== "boolean") return jsonError(`${key} must be a boolean`, 400);
        update[key] = body[key];
      }
    }
    if ("who_can_message" in body) {
      if (!WHO_CAN_MESSAGE.includes(body.who_can_message)) {
        return jsonError(`who_can_message must be one of: ${WHO_CAN_MESSAGE.join(", ")}`, 400);
      }
      update.who_can_message = body.who_can_message;
    }
    if ("interests" in body) {
      if (!Array.isArray(body.interests) || body.interests.some((i: unknown) => typeof i !== "string")) {
        return jsonError("interests must be a list of strings", 400);
      }
      const interests = [...new Set((body.interests as string[]).map((i) => i.trim().toLowerCase()).filter(Boolean))];
      if (interests.length > INTERESTS_MAX || interests.some((i) => i.length > INTEREST_MAX)) {
        return jsonError(`Up to ${INTERESTS_MAX} interests of at most ${INTEREST_MAX} characters`, 400);
      }
      update.interests = interests;
    }
    for (const key of ["name", "last_name"] as const) {
      if (key in body) {
        const v = typeof body[key] === "string" ? body[key].trim() : "";
        if (!v || v.length > 100) return jsonError(`${key} must be 1–100 characters`, 400);
        update[key] = v;
      }
    }
    if ("username" in body) {
      if (typeof body.username !== "string" || !USERNAME_RE.test(body.username)) {
        return jsonError("username must be 3–30 letters, digits, dots or underscores", 400);
      }
      update.username = body.username;
    }
    if ("avatar_url" in body) {
      if (body.avatar_url !== null && typeof body.avatar_url !== "string") {
        return jsonError("avatar_url must be a string", 400);
      }
      update.avatar_url = body.avatar_url;
    }
    if (Object.keys(update).length === 0) return jsonError("Nothing to update", 400);

    try {
      await db.transaction().execute(async (trx) => {
        await trx.updateTable("users").set(update).where("id", "=", caller.id).execute();
        if (update.is_private === false) {
          await trx.updateTable("follow")
            .set({ status: "accepted", accepted_at: new Date().toISOString() })
            .where("followee_id", "=", caller.id)
            .where("status", "=", "pending")
            .execute();
        }
      });
    } catch (e) {
      if ((e as { code?: string }).code === "23505") return jsonError("That username is taken", 409);
      throw e;
    }
    const u = await db.selectFrom("users").select(PROFILE_COLS).where("id", "=", caller.id).executeTakeFirstOrThrow();
    return json(await buildProfile(caller, u));
  }

  // ── PUT|DELETE /social/me/location ───────────────────────────────────────────
  // Stored rounded to two decimals (~1 km); never shown to anyone else.
  if (route.kind === "me_location" && (req.method === "PUT" || req.method === "DELETE")) {
    if (req.method === "DELETE") {
      await db.updateTable("users")
        .set({ location_lat: null, location_lng: null, location_updated_at: null })
        .where("id", "=", caller.id).execute();
      return new Response(null, { status: 204 });
    }
    const body = await req.json().catch(() => null);
    const lat = Number(body?.lat);
    const lng = Number(body?.lng);
    if (!Number.isFinite(lat) || !Number.isFinite(lng) || Math.abs(lat) > 90 || Math.abs(lng) > 180) {
      return jsonError("lat and lng must be valid coordinates", 400);
    }
    const round = (v: number) => Math.round(v * 100) / 100;
    await db.updateTable("users")
      .set({ location_lat: round(lat), location_lng: round(lng), location_updated_at: new Date().toISOString() })
      .where("id", "=", caller.id).execute();
    return json({ has_location: true });
  }

  // ── GET /social/badges ───────────────────────────────────────────────────────
  if (req.method === "GET" && route.kind === "badges") {
    const { rows: [b] } = await sql<Record<string, number>>`
      SELECT
        (SELECT count(*)::int FROM follow WHERE followee_id = ${caller.id} AND status = 'pending') AS follow_requests,
        (SELECT count(*)::int FROM friendship WHERE addressee_id = ${caller.id} AND status = 'pending') AS friend_requests,
        (SELECT count(*)::int FROM conversation_participant p JOIN conversation c ON c.id = p.conversation_id
          WHERE p.user_id = ${caller.id} AND p.status = 'active' AND p.archived_at IS NULL
            AND EXISTS (SELECT 1 FROM message m
              WHERE m.conversation_id = c.id AND ${unreadMessageSql(caller.id)})) AS unread_conversations,
        (SELECT count(*)::int FROM conversation_participant
          WHERE user_id = ${caller.id} AND status = 'request') AS message_requests,
        (SELECT count(*)::int FROM notification WHERE user_id = ${caller.id} AND NOT is_read) AS unread_notifications
    `.execute(db);
    return json(b);
  }

  // ── GET /social/users/:id | by-username ──────────────────────────────────────
  if (req.method === "GET" && route.kind === "user") {
    if (route.id && !UUID_RE.test(route.id)) return jsonError("User not found", 404);
    let q = db.selectFrom("users").select(PROFILE_COLS);
    q = route.id ? q.where("id", "=", route.id) : q.where(sql`lower(username)`, "=", route.username!.toLowerCase());
    const u = await q.executeTakeFirst();
    if (!u) return jsonError("User not found", 404);
    // Someone who blocked me doesn't exist for me. Someone I blocked is
    // shown (so I can unblock) but with no content.
    if (u.id !== caller.id) {
      const theyBlockedMe = await db.selectFrom("user_block").select("blocker_id")
        .where("blocker_id", "=", u.id).where("blocked_id", "=", caller.id).executeTakeFirst();
      if (theyBlockedMe) return jsonError("User not found", 404);
    }
    return json(await buildProfile(caller, u));
  }

  // ── GET /social/users/:id/followers|following|friends|mutual-friends ─────────
  if (req.method === "GET" && route.kind === "user_list") {
    if (!UUID_RE.test(route.id)) return jsonError("User not found", 404);
    const owner = await db.selectFrom("users").select(["id", "is_private"]).where("id", "=", route.id)
      .executeTakeFirst();
    if (!owner || (owner.id !== caller.id && (await isBlockedBetween(caller.id, owner.id)))) {
      return jsonError("User not found", 404);
    }
    if (route.list !== "mutual-friends" && !(await canSeeContentOf(caller.id, owner))) {
      return jsonError("This account is private", 403, { code: "private_account" });
    }
    const { page, pageSize } = parsePaging(url, 30);
    const q = (url.searchParams.get("q") ?? "").trim();
    const like = `%${q}%`;
    const hidden = [...(await blockedIds(caller.id))];

    let users: UserSummary[];
    if (route.list === "mutual-friends") {
      users = (await mutualFriends(caller.id, owner.id, pageSize, page * pageSize)).users;
    } else {
      const ids = route.list === "followers"
        ? sql`SELECT follower_id AS id, created_at FROM follow WHERE followee_id = ${owner.id} AND status = 'accepted'`
        : route.list === "following"
        ? sql`SELECT followee_id AS id, created_at FROM follow WHERE follower_id = ${owner.id} AND status = 'accepted'`
        : sql`SELECT CASE WHEN requester_id = ${owner.id} THEN addressee_id ELSE requester_id END AS id,
                     COALESCE(accepted_at, created_at) AS created_at
              FROM friendship WHERE (requester_id = ${owner.id} OR addressee_id = ${owner.id}) AND status = 'accepted'`;
      const { rows } = await sql<UserSummary>`
        SELECT u.id, u.username, u.name, u.last_name, u.avatar_url
        FROM (${ids}) x JOIN users u ON u.id = x.id
        WHERE (${q} = '' OR u.username ILIKE ${like} OR (u.name || ' ' || u.last_name) ILIKE ${like})
          AND NOT (u.id = ANY(${hidden}::uuid[]))
        ORDER BY x.created_at DESC, u.id
        LIMIT ${pageSize} OFFSET ${page * pageSize}
      `.execute(db);
      users = rows;
    }
    return json(await decorateUsers(caller, users));
  }

  // ── Follow / follower / friend / block actions ───────────────────────────────
  if (route.kind === "user_action" && (req.method === "POST" || req.method === "DELETE")) {
    if (!UUID_RE.test(route.id)) return jsonError("User not found", 404);
    if (route.id === caller.id) return jsonError("That's you", 400);
    const target = await db.selectFrom("users").select(["id", "name", "last_name", "is_private"])
      .where("id", "=", route.id).executeTakeFirst();
    if (!target) return jsonError("User not found", 404);
    const blocked = await isBlockedBetween(caller.id, target.id);

    switch (route.action) {
      case "follow":
        if (req.method === "POST") {
          if (blocked) return jsonError("User not found", 404);
          await follow(caller, target);
        } else {
          await removeFollow(caller.id, target.id);
        }
        break;
      case "follower":
        if (req.method !== "DELETE") return jsonError("Method not allowed", 405);
        await removeFollow(target.id, caller.id);
        break;
      case "friend":
        if (req.method === "POST") {
          if (blocked) return jsonError("User not found", 404);
          const existing = await db.selectFrom("friendship").select(["requester_id", "status"])
            .where((eb) =>
              eb.or([
                eb.and([eb("requester_id", "=", caller.id), eb("addressee_id", "=", target.id)]),
                eb.and([eb("requester_id", "=", target.id), eb("addressee_id", "=", caller.id)]),
              ])
            )
            .executeTakeFirst();
          const who = displayName(caller);
          if (!existing) {
            await db.insertInto("friendship").values({ requester_id: caller.id, addressee_id: target.id })
              .onConflict((oc) => oc.doNothing()).execute();
            await notify([target.id], {
              type: "friend_request",
              title: `${who} sent you a friend request`,
              body: "",
              metadata: { user_id: caller.id },
            });
          } else if (existing.status === "pending" && existing.requester_id === target.id) {
            // They asked first: this accepts. Friends also follow each other.
            await acceptFriendship(caller, target.id);
          }
        } else {
          await deleteFriendship(caller.id, target.id);
        }
        break;
      case "block":
        if (req.method === "POST") {
          await db.transaction().execute(async (trx) => {
            await trx.insertInto("user_block").values({ blocker_id: caller.id, blocked_id: target.id })
              .onConflict((oc) => oc.doNothing()).execute();
            await trx.deleteFrom("follow")
              .where((eb) =>
                eb.or([
                  eb.and([eb("follower_id", "=", caller.id), eb("followee_id", "=", target.id)]),
                  eb.and([eb("follower_id", "=", target.id), eb("followee_id", "=", caller.id)]),
                ])
              ).execute();
          });
          await deleteFriendship(caller.id, target.id);
        } else {
          await db.deleteFrom("user_block").where("blocker_id", "=", caller.id).where("blocked_id", "=", target.id)
            .execute();
        }
        break;
    }
    await broadcastToUsers([caller.id, target.id], "relationship", { users: [caller.id, target.id] });
    const theyBlockedMe = (await db.selectFrom("user_block").select("blocker_id")
      .where("blocker_id", "=", target.id).where("blocked_id", "=", caller.id).executeTakeFirst()) !== undefined;
    return json({ user_id: target.id, relationship: theyBlockedMe ? null : await relationship(caller.id, target.id) });
  }

  // ── GET /social/blocks ───────────────────────────────────────────────────────
  if (req.method === "GET" && route.kind === "blocks") {
    const rows = await db.selectFrom("user_block")
      .innerJoin("users", "users.id", "user_block.blocked_id")
      .select(["users.id", "users.username", "users.name", "users.last_name", "users.avatar_url", "user_block.created_at"])
      .where("user_block.blocker_id", "=", caller.id)
      .orderBy("user_block.created_at", "desc")
      .execute();
    return json(rows);
  }

  // ── Follow requests (incoming) ───────────────────────────────────────────────
  if (req.method === "GET" && route.kind === "follow_requests") {
    const rows = await db.selectFrom("follow")
      .innerJoin("users", "users.id", "follow.follower_id")
      .select(["users.id", "users.username", "users.name", "users.last_name", "users.avatar_url", "follow.created_at"])
      .where("follow.followee_id", "=", caller.id)
      .where("follow.status", "=", "pending")
      .orderBy("follow.created_at", "desc")
      .execute();
    return json(await decorateUsers(caller, rows));
  }

  if (route.kind === "follow_request" && (req.method === "POST" || req.method === "DELETE")) {
    if (req.method === "POST" && !route.accept) return jsonError("Not found", 404);
    if (req.method === "DELETE" && route.accept) return jsonError("Not found", 404);
    if (!UUID_RE.test(route.userId)) return jsonError("Request not found", 404);
    const pending = await db.selectFrom("follow").select("follower_id")
      .where("follower_id", "=", route.userId).where("followee_id", "=", caller.id).where("status", "=", "pending")
      .executeTakeFirst();
    if (!pending) return jsonError("Request not found", 404);
    if (req.method === "POST") {
      await db.updateTable("follow")
        .set({ status: "accepted", accepted_at: new Date().toISOString() })
        .where("follower_id", "=", route.userId).where("followee_id", "=", caller.id).execute();
      await notify([route.userId], {
        type: "follow_accepted",
        title: `${displayName(caller)} accepted your follow request`,
        body: "",
        metadata: { user_id: caller.id },
      });
    } else {
      await removeFollow(route.userId, caller.id);
    }
    await broadcastToUsers([caller.id, route.userId], "relationship", { users: [caller.id, route.userId] });
    return json({ user_id: route.userId, relationship: await relationship(caller.id, route.userId) });
  }

  // ── GET /social/friend-requests ──────────────────────────────────────────────
  if (req.method === "GET" && route.kind === "friend_requests") {
    const outgoing = url.searchParams.get("direction") === "outgoing";
    const rows = await db.selectFrom("friendship")
      .innerJoin("users", "users.id", outgoing ? "friendship.addressee_id" : "friendship.requester_id")
      .select(["users.id", "users.username", "users.name", "users.last_name", "users.avatar_url", "friendship.created_at"])
      .where(outgoing ? "friendship.requester_id" : "friendship.addressee_id", "=", caller.id)
      .where("friendship.status", "=", "pending")
      .orderBy("friendship.created_at", "desc")
      .execute();
    const decorated = await decorateUsers(caller, rows);
    const mutualCounts = await Promise.all(decorated.map((u) => mutualFriends(caller.id, u.id, 0)));
    return json(decorated.map((u, i) => ({ ...u, mutual_count: mutualCounts[i].total })));
  }

  // ── Reports ──────────────────────────────────────────────────────────────────
  if (req.method === "POST" && route.kind === "reports") {
    const body = await req.json().catch(() => null);
    const { user_id, message_id, reason, details } = body ?? {};
    if (!REPORT_REASONS.includes(reason)) return jsonError(`reason must be one of: ${REPORT_REASONS.join(", ")}`, 400);
    if (!user_id && !message_id) return jsonError("user_id or message_id is required", 400);
    if (details !== undefined && details !== null && (typeof details !== "string" || details.length > 1000)) {
      return jsonError("details must be at most 1000 characters", 400);
    }
    let targetUserId: string | null = user_id ?? null;
    if (message_id) {
      // Only messages from a conversation you're in can be reported.
      const msg = await db.selectFrom("message")
        .innerJoin("conversation_participant as p", "p.conversation_id", "message.conversation_id")
        .select(["message.sender_id"])
        .where("message.id", "=", message_id)
        .where("p.user_id", "=", caller.id)
        .executeTakeFirst();
      if (!msg) return jsonError("Message not found", 404);
      targetUserId = msg.sender_id;
    }
    if (targetUserId) {
      if (!UUID_RE.test(targetUserId)) return jsonError("User not found", 404);
      const target = await db.selectFrom("users").select("id").where("id", "=", targetUserId).executeTakeFirst();
      if (!target) return jsonError("User not found", 404);
    }
    const report = await db.insertInto("user_report").values({
      reporter_id: caller.id,
      target_user_id: targetUserId,
      message_id: message_id ?? null,
      reason,
      details: details?.trim() || null,
    }).returning(["id", "created_at"]).executeTakeFirstOrThrow();
    return json(report, 201);
  }

  if (req.method === "GET" && route.kind === "reports") {
    if (!isSuperUser(caller)) return jsonError("Only super users can review reports", 403);
    const rows = await db.selectFrom("user_report")
      .leftJoin("users as target", "target.id", "user_report.target_user_id")
      .leftJoin("users as reporter", "reporter.id", "user_report.reporter_id")
      .leftJoin("message", "message.id", "user_report.message_id")
      .select([
        "user_report.id",
        "user_report.reason",
        "user_report.details",
        "user_report.created_at",
        "user_report.message_id",
        "message.body as message_body",
        "target.id as target_id",
        "target.username as target_username",
        "reporter.id as reporter_id",
        "reporter.username as reporter_username",
      ])
      .where("user_report.resolved_at", "is", null)
      .orderBy("user_report.created_at", "desc")
      .limit(200)
      .execute();
    return json(rows);
  }

  if (req.method === "POST" && route.kind === "report_resolve") {
    if (!isSuperUser(caller)) return jsonError("Only super users can review reports", 403);
    if (!UUID_RE.test(route.id)) return jsonError("Report not found", 404);
    const done = await db.updateTable("user_report")
      .set({ resolved_at: new Date().toISOString(), resolved_by: caller.id })
      .where("id", "=", route.id)
      .returning("id")
      .executeTakeFirst();
    if (!done) return jsonError("Report not found", 404);
    return json({ id: done.id, resolved: true });
  }

  // ── GET /social/search?q= ────────────────────────────────────────────────────
  // Everyone is findable (private accounts too) except across blocks. Ties in
  // text relevance go to people closer to me: friends, follows, same gym.
  if (req.method === "GET" && route.kind === "search") {
    const q = (url.searchParams.get("q") ?? "").trim().replace(/^@/, "");
    if (!q) return json([]);
    const { page, pageSize } = parsePaging(url, 20, 50);
    const like = `%${q}%`;
    const starts = `${q}%`;
    const { rows } = await sql<UserSummary>`
      WITH my_gyms AS (
        SELECT gym_id FROM member WHERE user_id = ${caller.id}
        UNION SELECT gym_id FROM trainer WHERE user_id = ${caller.id}
        UNION SELECT gym_id FROM employee WHERE user_id = ${caller.id}
        UNION SELECT gym_id FROM employee_trainer WHERE user_id = ${caller.id}
        UNION SELECT gym_id FROM gym_owner WHERE user_id = ${caller.id}
      )
      SELECT u.id, u.username, u.name, u.last_name, u.avatar_url
      FROM users u
      WHERE u.id <> ${caller.id}
        AND NOT is_blocked_between(u.id, ${caller.id})
        AND (u.username ILIKE ${like} OR u.name ILIKE ${like} OR u.last_name ILIKE ${like}
             OR (u.name || ' ' || u.last_name) ILIKE ${like})
      ORDER BY
        CASE
          WHEN lower(u.username) = lower(${q}) THEN 0
          WHEN lower(u.name || ' ' || u.last_name) = lower(${q}) THEN 1
          WHEN u.username ILIKE ${starts} OR u.name ILIKE ${starts} OR u.last_name ILIKE ${starts} THEN 2
          ELSE 3
        END,
        (
          CASE WHEN EXISTS (SELECT 1 FROM friendship f WHERE f.status = 'accepted'
            AND ((f.requester_id = u.id AND f.addressee_id = ${caller.id})
              OR (f.addressee_id = u.id AND f.requester_id = ${caller.id}))) THEN 3 ELSE 0 END
          + CASE WHEN EXISTS (SELECT 1 FROM follow WHERE follower_id = ${caller.id} AND followee_id = u.id) THEN 2 ELSE 0 END
          + CASE WHEN EXISTS (SELECT 1 FROM follow WHERE followee_id = ${caller.id} AND follower_id = u.id) THEN 1 ELSE 0 END
          + CASE WHEN EXISTS (SELECT 1 FROM member m JOIN my_gyms g USING (gym_id) WHERE m.user_id = u.id) THEN 1 ELSE 0 END
        ) DESC,
        u.name, u.last_name, u.id
      LIMIT ${pageSize} OFFSET ${page * pageSize}
    `.execute(db);
    return json(await decorateUsers(caller, rows));
  }

  // ── GET /social/suggestions ──────────────────────────────────────────────────
  if (req.method === "GET" && route.kind === "suggestions") {
    const { page, pageSize } = parsePaging(url, 20, 50);
    const rows = await suggestions(caller.id, pageSize, page * pageSize);
    const decorated = await decorateUsers(caller, rows.map((s) => ({
      id: s.id,
      username: s.username,
      name: s.name,
      last_name: s.last_name,
      avatar_url: s.avatar_url,
    })));
    return json(decorated.map((u, i) => ({
      ...u,
      score: Math.round(rows[i].score * 10) / 10,
      reasons: suggestionReasons(rows[i]),
    })));
  }

  // ── GET /social/nearby?radius_km= ────────────────────────────────────────────
  if (req.method === "GET" && route.kind === "nearby") {
    const me = await db.selectFrom("users").select(["location_lat", "location_lng"]).where("id", "=", caller.id)
      .executeTakeFirstOrThrow();
    if (me.location_lat === null || me.location_lng === null) {
      return jsonError("Share your location to see people nearby", 409, { code: "location_required" });
    }
    const radius = Math.min(200, Math.max(1, Number(url.searchParams.get("radius_km")) || 25));
    const { page, pageSize } = parsePaging(url, 30, 50);
    const { rows } = await sql<UserSummary & { distance_km: number }>`
      SELECT u.id, u.username, u.name, u.last_name, u.avatar_url,
             round(haversine_km(${me.location_lat}, ${me.location_lng}, u.location_lat, u.location_lng))::int AS distance_km
      FROM users u
      WHERE u.id <> ${caller.id} AND u.discoverable AND u.location_lat IS NOT NULL
        AND NOT is_blocked_between(u.id, ${caller.id})
        AND haversine_km(${me.location_lat}, ${me.location_lng}, u.location_lat, u.location_lng) <= ${radius}
      ORDER BY distance_km, u.last_active_at DESC NULLS LAST, u.id
      LIMIT ${pageSize} OFFSET ${page * pageSize}
    `.execute(db);
    const decorated = await decorateUsers(caller, rows.map(({ distance_km: _d, ...u }) => u));
    return json(decorated.map((u, i) => ({ ...u, distance_km: rows[i].distance_km })));
  }

  return jsonError("Not found", 404);
}

async function acceptFriendship(caller: Caller, requesterId: string) {
  const now = new Date().toISOString();
  await db.transaction().execute(async (trx) => {
    await trx.updateTable("friendship")
      .set({ status: "accepted", accepted_at: now })
      .where("requester_id", "=", requesterId)
      .where("addressee_id", "=", caller.id)
      .execute();
    // Friends follow each other (upgrading any pending request).
    for (const [a, b] of [[caller.id, requesterId], [requesterId, caller.id]]) {
      await trx.insertInto("follow")
        .values({ follower_id: a, followee_id: b, status: "accepted", accepted_at: now })
        .onConflict((oc) => oc.columns(["follower_id", "followee_id"]).doUpdateSet({ status: "accepted", accepted_at: now }))
        .execute();
    }
  });
  await notify([requesterId], {
    type: "friend_accepted",
    title: `${displayName(caller)} accepted your friend request`,
    body: "",
    metadata: { user_id: caller.id },
  });
}

Deno.serve(async (req: Request) => {
  try {
    return await handler(req);
  } catch (e) {
    const err = e as { code?: string; message?: string };
    if (err?.code === "22P02") return jsonError("Invalid id", 400);
    throw e;
  }
});
