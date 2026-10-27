import { sql } from "npm:kysely@^0.27";
import { db } from "./config.ts";
import type { ReactionType, WhoCanMessage } from "../../types/schema/public.ts";

// Social graph rules shared by the social, chat and posts functions.
//
// * Follow: me → them. Auto-accepted for public accounts; a request
//   (status 'pending') for private ones until they accept.
// * Friendship: mutual, one row per pair, request → accepted.
// * Block: either direction hides the users from each other everywhere
//   (profiles answer 404, search/suggestions skip them, no messages).
// * A private account is still findable and its comments/reactions are
//   visible; only its own posts (photos/videos) need an accepted follow.

export const REACTIONS: readonly ReactionType[] = [
  "like",
  "love",
  "haha",
  "wow",
  "sad",
  "angry",
  "fire",
  "strong",
  "clap",
  "celebrate",
];

export function isReaction(value: unknown): value is ReactionType {
  return typeof value === "string" && (REACTIONS as readonly string[]).includes(value);
}

export const REACTION_EMOJI: Record<ReactionType, string> = {
  like: "👍",
  love: "❤️",
  haha: "😂",
  wow: "😮",
  sad: "😢",
  angry: "😡",
  fire: "🔥",
  strong: "💪",
  clap: "👏",
  celebrate: "🎉",
};

/** Columns of another user that anyone may see. */
export const PUBLIC_USER_COLS = ["id", "username", "name", "last_name", "avatar_url"] as const;

export type UserSummary = {
  id: string;
  username: string;
  name: string;
  last_name: string;
  avatar_url: string | null;
};

export async function userSummaries(ids: (string | null | undefined)[]): Promise<Record<string, UserSummary>> {
  const unique = [...new Set(ids.filter((x): x is string => !!x))];
  if (!unique.length) return {};
  const rows = await db.selectFrom("users").select(PUBLIC_USER_COLS).where("id", "in", unique).execute();
  return Object.fromEntries(rows.map((r) => [r.id, r]));
}

export async function isBlockedBetween(a: string, b: string): Promise<boolean> {
  const row = await db
    .selectFrom("user_block")
    .select("blocker_id")
    .where((eb) =>
      eb.or([
        eb.and([eb("blocker_id", "=", a), eb("blocked_id", "=", b)]),
        eb.and([eb("blocker_id", "=", b), eb("blocked_id", "=", a)]),
      ])
    )
    .executeTakeFirst();
  return !!row;
}

/** Ids of everyone who blocked `userId` or was blocked by them. */
export async function blockedIds(userId: string): Promise<Set<string>> {
  const rows = await db
    .selectFrom("user_block")
    .select(["blocker_id", "blocked_id"])
    .where((eb) => eb.or([eb("blocker_id", "=", userId), eb("blocked_id", "=", userId)]))
    .execute();
  return new Set(rows.map((r) => (r.blocker_id === userId ? r.blocked_id : r.blocker_id)));
}

export async function isFollowing(followerId: string, followeeId: string): Promise<boolean> {
  if (followerId === followeeId) return true;
  const row = await db
    .selectFrom("follow")
    .select("status")
    .where("follower_id", "=", followerId)
    .where("followee_id", "=", followeeId)
    .where("status", "=", "accepted")
    .executeTakeFirst();
  return !!row;
}

export async function areFriends(a: string, b: string): Promise<boolean> {
  const row = await db
    .selectFrom("friendship")
    .select("status")
    .where("status", "=", "accepted")
    .where((eb) =>
      eb.or([
        eb.and([eb("requester_id", "=", a), eb("addressee_id", "=", b)]),
        eb.and([eb("requester_id", "=", b), eb("addressee_id", "=", a)]),
      ])
    )
    .executeTakeFirst();
  return !!row;
}

export type Relationship = {
  /** Me → them. */
  following: "none" | "pending" | "accepted";
  /** Them → me. */
  followed_by: "none" | "pending" | "accepted";
  friendship: "none" | "outgoing" | "incoming" | "friends";
  /** I blocked them (if they blocked me, they're invisible instead). */
  blocked: boolean;
};

const NO_RELATIONSHIP: Relationship = { following: "none", followed_by: "none", friendship: "none", blocked: false };

/** My relationship to each of `otherIds`, in a constant number of queries. */
export async function relationships(meId: string, otherIds: string[]): Promise<Map<string, Relationship>> {
  const ids = [...new Set(otherIds)].filter((id) => id !== meId);
  const out = new Map<string, Relationship>();
  for (const id of ids) out.set(id, { ...NO_RELATIONSHIP });
  if (!ids.length) return out;

  const [follows, friendships, blocks] = await Promise.all([
    db.selectFrom("follow")
      .select(["follower_id", "followee_id", "status"])
      .where((eb) =>
        eb.or([
          eb.and([eb("follower_id", "=", meId), eb("followee_id", "in", ids)]),
          eb.and([eb("followee_id", "=", meId), eb("follower_id", "in", ids)]),
        ])
      )
      .execute(),
    db.selectFrom("friendship")
      .select(["requester_id", "addressee_id", "status"])
      .where((eb) =>
        eb.or([
          eb.and([eb("requester_id", "=", meId), eb("addressee_id", "in", ids)]),
          eb.and([eb("addressee_id", "=", meId), eb("requester_id", "in", ids)]),
        ])
      )
      .execute(),
    db.selectFrom("user_block").select("blocked_id").where("blocker_id", "=", meId).where("blocked_id", "in", ids)
      .execute(),
  ]);

  for (const f of follows) {
    if (f.follower_id === meId) out.get(f.followee_id)!.following = f.status;
    else out.get(f.follower_id)!.followed_by = f.status;
  }
  for (const f of friendships) {
    const other = f.requester_id === meId ? f.addressee_id : f.requester_id;
    out.get(other)!.friendship = f.status === "accepted"
      ? "friends"
      : f.requester_id === meId
      ? "outgoing"
      : "incoming";
  }
  for (const b of blocks) out.get(b.blocked_id)!.blocked = true;
  return out;
}

export async function relationship(meId: string, otherId: string): Promise<Relationship> {
  return (await relationships(meId, [otherId])).get(otherId) ?? { ...NO_RELATIONSHIP };
}

/** Whether `viewerId` may see the posts (photos/videos) of `owner`. */
export async function canSeeContentOf(
  viewerId: string | null,
  owner: { id: string; is_private: boolean },
): Promise<boolean> {
  if (viewerId === owner.id) return true;
  if (viewerId && (await isBlockedBetween(viewerId, owner.id))) return false;
  if (!owner.is_private) return true;
  return viewerId ? await isFollowing(viewerId, owner.id) : false;
}

/**
 * Whether a direct message from `senderId` lands in `recipient`'s inbox
 * ('active') or in their message requests ('request'). Blocked → null.
 */
export async function directMessageStatus(
  senderId: string,
  recipient: { id: string; who_can_message: WhoCanMessage },
): Promise<"active" | "request" | null> {
  if (await isBlockedBetween(senderId, recipient.id)) return null;
  if (recipient.who_can_message === "everyone") return "active";
  if (await areFriends(senderId, recipient.id)) return "active";
  if (recipient.who_can_message === "following" && (await isFollowing(recipient.id, senderId))) return "active";
  return "request";
}

/** Marks the user active now (at most one write per minute). */
export async function touchActivity(userId: string): Promise<void> {
  try {
    await sql`
      UPDATE users SET last_active_at = NOW()
      WHERE id = ${userId} AND (last_active_at IS NULL OR last_active_at < NOW() - INTERVAL '1 minute')
    `.execute(db);
  } catch (err) {
    console.error("touchActivity failed", err);
  }
}

export function parsePaging(url: URL, defaultSize: number, max = 100): { page: number; pageSize: number } {
  const page = Math.max(0, parseInt(url.searchParams.get("page") ?? "0") || 0);
  const pageSize = Math.min(max, Math.max(1, parseInt(url.searchParams.get("page_size") ?? "") || defaultSize));
  return { page, pageSize };
}

export const displayName = (u: { name: string; last_name: string }) => `${u.name} ${u.last_name}`.trim() || "Someone";
