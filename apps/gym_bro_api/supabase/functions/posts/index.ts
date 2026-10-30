import { type Kysely, sql } from "npm:kysely@^0.27";
import { db } from "../_shared/config.ts";
import {
  type Caller,
  canCoachAtGym,
  canEditAuthored,
  canManageBusiness,
  canStaffShop,
  forbidden,
  isSuperUser,
  json,
  jsonError,
  requireCaller,
} from "../_shared/auth.ts";
import { notify } from "../_shared/notify.ts";
import {
  createUploadSlot,
  markClaimed,
  MAX_UPLOAD_BYTES,
  normalizeMime,
  removeObjects,
  signPaths,
  verifyUploads,
} from "../_shared/media.ts";
import {
  blockedIds,
  canSeeContentOf,
  displayName,
  isReaction,
  parsePaging,
  REACTION_EMOJI,
  REACTIONS,
  userSummaries,
} from "../_shared/social.ts";
import {
  mentionRecipients,
  type MentionRef,
  normalizeMentions,
  plainText,
  syncMentionRows,
  validMentions,
} from "../_shared/mentions.ts";
import { buildAttachment, POST_TYPES } from "../_shared/post_attachments.ts";
import { postVisibleSql } from "../_shared/visibility.ts";
import type {
  Database,
  PostImageInsert,
  PostType,
  PostVisibility,
  ReactionType,
} from "../../types/schema/public.ts";

// Posts come in two kinds:
//   * business posts — announcements from gym/shop staff (business_id set),
//     public, with public image URLs;
//   * personal posts — a user's own photos/videos/text (business_id null),
//     shown on their profile grid and in feeds. Media is in the private
//     user-media bucket and URLs are signed per viewer. Visibility: the
//     author and accepted followers always; everyone else only for a
//     'public' post on a public account.
//
// Reactions (10 types, one per person) on posts and comments; comments are
// threads up to 10 levels deep (depth 0–9), soft-deleted when they have replies.
//
//   GET    /posts?business_id= | ?author_id=          a business's or person's posts
//   GET    /posts/feed?mode=home|explore              ranked feed
//   GET    /posts/:id
//   POST   /posts                                     business post, or personal post when no business_id
//   POST   /posts/uploads {mime_type, size_bytes}      signed upload URL for personal media
//   PUT    /posts/:id, DELETE /posts/:id
//   PUT    /posts/:id/reaction {reaction}, DELETE     (POST|DELETE /posts/:id/like = 'like')
//   GET    /posts/:id/reactions?reaction=             who reacted
//   GET    /posts/:id/comments?sort=top|new|old       top-level page + every reply under it
//   POST   /posts/:id/comments {body, parent_id?}
//   PUT    /posts/comments/:id, DELETE /posts/comments/:id
//   PUT    /posts/comments/:id/reaction {reaction}, DELETE
//   GET    /posts?tagged_user_id=                     posts someone is tagged in (photo or caption)
//   GET    /posts/mention-search?q=                   people, gyms/shops and products for "@"
//   DELETE /posts/:id/tags/me                         remove myself from a post's photo tags
//   PUT    /posts/:id/archive, DELETE                 archive my post (hidden from everyone else) / show it again
//   GET    /posts/archive?from=&to=                   my archived posts (created in [from, to)), newest first
//
// Personal posts have a type: generic, or sharing a logged workout / meal or
// a library item ({type, ref_id} or {type: 'meal', meal: {log_date,
// slot_type}}); see _shared/post_attachments.ts. Captions and comments carry
// mentions as markup (_shared/mentions.ts); photos carry people pinned at
// (x, y). Mentioned and tagged people are notified and can see the post.

const POST_COLS = [
  "id",
  "business_id",
  "author_id",
  "content",
  "visibility",
  "post_type",
  "ref_id",
  "attachment",
  "archived_at",
  "created_at",
  "updated_at",
] as const;
const MEDIA_COLS = [
  "id",
  "post_id",
  "url",
  "storage_path",
  "position",
  "media_type",
  "mime_type",
  "width",
  "height",
  "duration_ms",
] as const;
const COMMENT_COLS = [
  "id",
  "post_id",
  "parent_id",
  "depth",
  "author_id",
  "body",
  "created_at",
  "updated_at",
  "deleted_at",
] as const;
const COMMENT_MAX_LENGTH = 2000;
const CAPTION_MAX_LENGTH = 2200;
const MAX_DEPTH = 9;
const MEDIA_MAX = 10;
const VISIBILITIES: readonly PostVisibility[] = ["public", "followers"];
const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const BUCKET = "user-media" as const;

type PostRow = {
  id: string;
  business_id: string | null;
  author_id: string | null;
  content: string;
  visibility: PostVisibility;
  post_type: PostType;
  ref_id: string | null;
  attachment: unknown;
  archived_at: string | null;
  created_at: string;
  updated_at: string;
};

type PinInput = { user_id?: unknown; x?: unknown; y?: unknown };

// ── Path parsing ──────────────────────────────────────────────────────────────

type Route =
  | { kind: "collection" }
  | { kind: "feed" }
  | { kind: "uploads" }
  | { kind: "archive_list" }
  | { kind: "archive"; id: string }
  | { kind: "mention_search" }
  | { kind: "untag"; id: string }
  | { kind: "post"; id: string }
  | { kind: "like"; id: string }
  | { kind: "reaction"; id: string }
  | { kind: "reactions"; id: string }
  | { kind: "comments"; id: string }
  | { kind: "comment"; commentId: string }
  | { kind: "comment_reaction"; commentId: string }
  | { kind: "unknown" };

function parsePath(pathname: string): Route {
  if (/^\/posts\/?$/.test(pathname)) return { kind: "collection" };
  if (/^\/posts\/feed\/?$/.test(pathname)) return { kind: "feed" };
  if (/^\/posts\/uploads\/?$/.test(pathname)) return { kind: "uploads" };
  if (/^\/posts\/mention-search\/?$/.test(pathname)) return { kind: "mention_search" };
  if (/^\/posts\/archive\/?$/.test(pathname)) return { kind: "archive_list" };
  const a = pathname.match(/^\/posts\/([^/]+)\/archive$/);
  if (a) return { kind: "archive", id: a[1] };
  const t = pathname.match(/^\/posts\/([^/]+)\/tags\/me$/);
  if (t) return { kind: "untag", id: t[1] };
  let m = pathname.match(/^\/posts\/comments\/([^/]+)\/reaction$/);
  if (m) return { kind: "comment_reaction", commentId: m[1] };
  m = pathname.match(/^\/posts\/comments\/([^/]+)$/);
  if (m) return { kind: "comment", commentId: m[1] };
  m = pathname.match(/^\/posts\/([^/]+)\/like$/);
  if (m) return { kind: "like", id: m[1] };
  m = pathname.match(/^\/posts\/([^/]+)\/reaction$/);
  if (m) return { kind: "reaction", id: m[1] };
  m = pathname.match(/^\/posts\/([^/]+)\/reactions$/);
  if (m) return { kind: "reactions", id: m[1] };
  m = pathname.match(/^\/posts\/([^/]+)\/comments$/);
  if (m) return { kind: "comments", id: m[1] };
  m = pathname.match(/^\/posts\/([^/]+)$/);
  if (m) return { kind: "post", id: m[1] };
  return { kind: "unknown" };
}

// ── Optional caller ───────────────────────────────────────────────────────────
// Business feeds and public posts are readable anonymously; resolve the
// caller only when a valid user token is sent.

async function optionalCaller(req: Request): Promise<Caller | null> {
  if (!req.headers.get("Authorization")) return null;
  try {
    const { caller } = await requireCaller(req);
    return caller ?? null;
  } catch {
    return null;
  }
}

// ── Visibility ────────────────────────────────────────────────────────────────

/** SQL condition: `post` (alias) is visible to the viewer (see _shared/visibility.ts). */
const visibleTo = postVisibleSql;

async function loadVisiblePost(id: string, viewer: Caller | null): Promise<PostRow | null> {
  if (!UUID_RE.test(id)) return null;
  const row = await db.selectFrom("post").select(POST_COLS).where("id", "=", id)
    .where(visibleTo(viewer?.id ?? null)).executeTakeFirst();
  return row ?? null;
}

// ── Decoration ────────────────────────────────────────────────────────────────

async function attachMedia<T extends { id: string }>(posts: T[]) {
  const ids = posts.map((p) => p.id);
  const media = ids.length
    ? await db.selectFrom("post_image").select(MEDIA_COLS).where("post_id", "in", ids).orderBy("position", "asc").execute()
    : [];
  const [signed, pins] = await Promise.all([
    signPaths(BUCKET, media.flatMap((m) => (m.storage_path ? [m.storage_path] : []))),
    media.length
      ? db.selectFrom("post_tag as t").innerJoin("users as u", "u.id", "t.user_id")
        .select(["t.post_image_id", "t.x", "t.y", "u.id as user_id", "u.username", "u.name", "u.last_name", "u.avatar_url"])
        .where("t.post_image_id", "in", media.map((m) => m.id))
        .orderBy("t.created_at").execute()
      : Promise.resolve([]),
  ]);
  const pinsByMedia = new Map<string, unknown[]>();
  for (const { post_image_id, ...pin } of pins) {
    (pinsByMedia.get(post_image_id!) ?? pinsByMedia.set(post_image_id!, []).get(post_image_id!)!).push(pin);
  }
  const byPost: Record<string, unknown[]> = {};
  for (const m of media) {
    const { storage_path, ...rest } = m;
    (byPost[m.post_id] ??= []).push({
      ...rest,
      url: storage_path ? signed.get(storage_path) ?? null : m.url,
      tags: pinsByMedia.get(m.id) ?? [],
    });
  }
  return posts.map((p) => ({ ...p, images: byPost[p.id] ?? [] }));
}

type ReactionSummary = { counts: Partial<Record<ReactionType, number>>; total: number; top: ReactionType[] };

function summarize(rows: { reaction: ReactionType; n: number }[]): ReactionSummary {
  const counts: Partial<Record<ReactionType, number>> = {};
  let total = 0;
  for (const r of rows) {
    counts[r.reaction] = r.n;
    total += r.n;
  }
  const top = (Object.entries(counts) as [ReactionType, number][])
    .sort((a, b) => b[1] - a[1] || REACTIONS.indexOf(a[0]) - REACTIONS.indexOf(b[0]))
    .slice(0, 3)
    .map(([k]) => k);
  return { counts, total, top };
}

/**
 * Adds media, author, business, reaction summary, my_reaction and
 * comment_count. like_count / liked_by_me mirror the reaction total and
 * "I reacted" for older clients.
 */
async function decoratePosts(posts: PostRow[], caller: Caller | null) {
  if (!posts.length) return [];
  const ids = posts.map((p) => p.id);
  const businessIds = [...new Set(posts.map((p) => p.business_id).filter((x): x is string => !!x))];
  const [withMedia, reactionRows, commentRows, mine, authors, businesses] = await Promise.all([
    attachMedia(posts),
    db.selectFrom("post_reaction")
      .select(["post_id", "reaction", sql<number>`count(*)::int`.as("n")])
      .where("post_id", "in", ids)
      .groupBy(["post_id", "reaction"])
      .execute(),
    db.selectFrom("post_comment")
      .select(["post_id", sql<number>`count(*)::int`.as("n")])
      .where("post_id", "in", ids)
      .where("deleted_at", "is", null)
      .groupBy("post_id")
      .execute(),
    caller
      ? db.selectFrom("post_reaction").select(["post_id", "reaction"]).where("post_id", "in", ids)
        .where("user_id", "=", caller.id).execute()
      : Promise.resolve([] as { post_id: string; reaction: ReactionType }[]),
    userSummaries(posts.map((p) => p.author_id)),
    businessIds.length
      ? db.selectFrom("business").select(["id", "name", "logo", "type"]).where("id", "in", businessIds).execute()
      : Promise.resolve([]),
  ]);
  const reactionsByPost = new Map<string, { reaction: ReactionType; n: number }[]>();
  for (const r of reactionRows) {
    (reactionsByPost.get(r.post_id) ?? reactionsByPost.set(r.post_id, []).get(r.post_id)!).push(r);
  }
  const comments = Object.fromEntries(commentRows.map((r) => [r.post_id, r.n]));
  const myReaction = new Map(mine.map((r) => [r.post_id, r.reaction]));
  const businessById = new Map(businesses.map((b) => [b.id, b]));
  return withMedia.map((p) => {
    const reactions = summarize(reactionsByPost.get(p.id) ?? []);
    const my = myReaction.get(p.id) ?? null;
    return {
      ...p,
      kind: p.business_id ? "business" : "personal",
      author: p.author_id ? authors[p.author_id] ?? null : null,
      business: p.business_id ? businessById.get(p.business_id) ?? null : null,
      reactions,
      my_reaction: my,
      comment_count: comments[p.id] ?? 0,
      like_count: reactions.total,
      liked_by_me: my !== null,
      can_edit: !!caller && canEditAuthored(caller, p.author_id),
    };
  });
}

async function postReactionResult(postId: string, caller: Caller) {
  const [rows, mine] = await Promise.all([
    db.selectFrom("post_reaction").select(["reaction", sql<number>`count(*)::int`.as("n")])
      .where("post_id", "=", postId).groupBy("reaction").execute(),
    db.selectFrom("post_reaction").select("reaction").where("post_id", "=", postId).where("user_id", "=", caller.id)
      .executeTakeFirst(),
  ]);
  const reactions = summarize(rows);
  return {
    post_id: postId,
    reactions,
    my_reaction: mine?.reaction ?? null,
    // Older clients:
    liked: !!mine,
    like_count: reactions.total,
  };
}

// ── Comments ─────────────────────────────────────────────────────────────────

type CommentRow = {
  id: string;
  post_id: string;
  parent_id: string | null;
  depth: number;
  author_id: string | null;
  body: string;
  created_at: string;
  updated_at: string;
  deleted_at: string | null;
};

/** Who may comment: business gym posts → members & staff; anything else → whoever can see it. */
async function canCommentOn(caller: Caller, post: PostRow): Promise<boolean> {
  if (!post.business_id) return true; // visibility was already checked
  const business = await db.selectFrom("business").select(["id", "type"]).where("id", "=", post.business_id)
    .executeTakeFirst();
  if (!business || business.type !== "gym") return true;
  if (await canCoachAtGym(caller, business.id)) return true;
  const member = await db.selectFrom("member").select("id").where("user_id", "=", caller.id)
    .where("gym_id", "=", business.id).executeTakeFirst();
  return !!member;
}

/** Can delete others' comments: the business owner, or the personal post's author. */
async function moderates(caller: Caller | null, post: { business_id: string | null; author_id: string | null }) {
  if (!caller) return false;
  if (isSuperUser(caller)) return true;
  if (post.business_id) return await canManageBusiness(caller, post.business_id);
  return post.author_id === caller.id;
}

async function decorateComments(rows: CommentRow[], caller: Caller | null, moderator: boolean) {
  if (!rows.length) return [];
  const ids = rows.map((r) => r.id);
  const [reactionRows, mine, replyRows, authors, hidden] = await Promise.all([
    db.selectFrom("comment_reaction").select(["comment_id", "reaction", sql<number>`count(*)::int`.as("n")])
      .where("comment_id", "in", ids).groupBy(["comment_id", "reaction"]).execute(),
    caller
      ? db.selectFrom("comment_reaction").select(["comment_id", "reaction"]).where("comment_id", "in", ids)
        .where("user_id", "=", caller.id).execute()
      : Promise.resolve([] as { comment_id: string; reaction: ReactionType }[]),
    db.selectFrom("post_comment").select(["parent_id", sql<number>`count(*)::int`.as("n")])
      .where("parent_id", "in", ids).groupBy("parent_id").execute(),
    userSummaries(rows.map((r) => r.author_id)),
    caller ? blockedIds(caller.id) : Promise.resolve(new Set<string>()),
  ]);
  const reactionsBy = new Map<string, { reaction: ReactionType; n: number }[]>();
  for (const r of reactionRows) {
    (reactionsBy.get(r.comment_id) ?? reactionsBy.set(r.comment_id, []).get(r.comment_id)!).push(r);
  }
  const myBy = new Map(mine.map((r) => [r.comment_id, r.reaction]));
  const repliesBy = new Map(replyRows.map((r) => [r.parent_id!, r.n]));
  return rows.map((c) => {
    const deleted = !!c.deleted_at;
    const blocked = !!c.author_id && hidden.has(c.author_id);
    const own = !!caller && c.author_id === caller.id;
    const reactions = summarize(reactionsBy.get(c.id) ?? []);
    return {
      ...c,
      body: deleted || blocked ? null : c.body,
      deleted,
      hidden: blocked,
      author: deleted || blocked || !c.author_id ? null : authors[c.author_id] ?? null,
      reply_count: repliesBy.get(c.id) ?? 0,
      reactions,
      my_reaction: myBy.get(c.id) ?? null,
      // Reddit-ish "points" used for sorting siblings by top.
      score: reactions.total + 2 * (repliesBy.get(c.id) ?? 0),
      can_edit: own && !deleted,
      can_delete: !deleted && (own || moderator),
      can_reply: !!caller && !deleted && c.depth < MAX_DEPTH,
    };
  });
}

async function commentResponse(id: string, caller: Caller) {
  const row = await db.selectFrom("post_comment").select(COMMENT_COLS).where("id", "=", id).executeTakeFirstOrThrow();
  const post = await db.selectFrom("post").select(["business_id", "author_id"]).where("id", "=", row.post_id)
    .executeTakeFirstOrThrow();
  const [decorated] = await decorateComments([row], caller, await moderates(caller, post));
  return decorated;
}

// ── Media ─────────────────────────────────────────────────────────────────────

// Always call inside a transaction. Business posts: public image URLs.
async function replaceBusinessImages(
  trx: Kysely<Database>,
  postId: string,
  images: { url: string; position?: number }[],
) {
  await trx.deleteFrom("post_image").where("post_id", "=", postId).execute();
  if (!images.length) return;
  const inserts: PostImageInsert[] = images.map((img, i) => ({
    post_id: postId,
    url: img.url,
    position: img.position ?? i,
  }));
  await trx.insertInto("post_image").values(inserts).execute();
}

// ── Tags & mentions ───────────────────────────────────────────────────────────

const MAX_PINS_PER_MEDIA = 20;

/** Pins from a body ([{user_id, x, y}]); a Response when malformed. */
function readPins(raw: unknown): { user_id: string; x: number; y: number }[] | Response {
  if (raw === undefined || raw === null) return [];
  if (!Array.isArray(raw)) return jsonError("tags must be an array", 400);
  if (raw.length > MAX_PINS_PER_MEDIA) return jsonError(`Up to ${MAX_PINS_PER_MEDIA} people per photo`, 400);
  const out: { user_id: string; x: number; y: number }[] = [];
  for (const t of raw as PinInput[]) {
    const x = Number(t?.x), y = Number(t?.y);
    if (typeof t?.user_id !== "string" || !UUID_RE.test(t.user_id) || !(x >= 0 && x <= 1) || !(y >= 0 && y <= 1)) {
      return jsonError("Each tag needs a user_id and x, y between 0 and 1", 400);
    }
    if (!out.some((o) => o.user_id === t.user_id)) out.push({ user_id: t.user_id as string, x, y });
  }
  return out;
}

/**
 * Makes the pins of [mediaId] exactly [pins] (people blocked either way with
 * the author are dropped). Returns the user ids newly pinned.
 */
async function replacePins(
  trx: Kysely<Database>,
  postId: string,
  mediaId: string,
  authorId: string,
  pins: { user_id: string; x: number; y: number }[],
): Promise<string[]> {
  const allowed = pins.length
    ? new Set((await trx.selectFrom("users").select("id").where("id", "in", pins.map((p) => p.user_id))
      .where(sql<boolean>`NOT is_blocked_between(id, ${authorId})`).execute()).map((u) => u.id))
    : new Set<string>();
  const keep = pins.filter((p) => allowed.has(p.user_id));
  const before = new Set((await trx.selectFrom("post_tag").select("user_id").where("post_image_id", "=", mediaId)
    .execute()).map((r) => r.user_id!));
  await trx.deleteFrom("post_tag").where("post_image_id", "=", mediaId).execute();
  if (keep.length) {
    await trx.insertInto("post_tag").values(keep.map((p) => ({
      post_id: postId,
      post_image_id: mediaId,
      kind: "user" as const,
      user_id: p.user_id,
      x: p.x,
      y: p.y,
      created_by: authorId,
    }))).execute();
  }
  return keep.map((p) => p.user_id).filter((id) => !before.has(id));
}

/** Notifies people newly mentioned / pinned, and owners of mentioned businesses and products. */
async function notifyTags(
  caller: Caller,
  post: { id: string; business_id: string | null },
  t: { mentions: MentionRef[]; pinned: string[]; commentId?: string | null; text: string },
) {
  const who = displayName(caller);
  const where = t.commentId ? "a comment" : "a post";
  const body = plainText(t.text).slice(0, 120);
  const metadata = { post_id: post.id, business_id: post.business_id, comment_id: t.commentId ?? null, user_id: caller.id };
  const { people, owners } = await mentionRecipients(db, t.mentions, caller.id);
  const pinned = t.pinned.filter((id) => id !== caller.id);
  await notify(pinned, { type: "photo_tag", title: `${who} tagged you in a photo`, body, metadata });
  await notify(people.filter((id) => !pinned.includes(id)), {
    type: "mention",
    title: `${who} mentioned you in ${where}`,
    body,
    metadata,
  });
  const named = t.mentions.filter((m) => m.kind !== "user").map((m) => m.label);
  if (owners.length && named.length) {
    await notify(owners, {
      type: "mention",
      title: `${who} mentioned ${named.slice(0, 2).join(", ")} in ${where}`,
      body,
      metadata,
    });
  }
}

/** [text] with typed @handles turned into mentions, and the mentions that are valid. */
async function prepareText(text: string, authorId: string) {
  const normalized = await normalizeMentions(db, text);
  return { text: normalized, mentions: await validMentions(db, normalized, authorId) };
}

// ── Feed ──────────────────────────────────────────────────────────────────────
// Candidates from the last 30 days that the viewer can see, from:
//   me · people I follow · businesses I belong to · (explore) public posts of
//   public, discoverable accounts I don't follow.
// score = affinity × engagement × freshness
//   affinity   friend 2.0 · following 1.5 · my business 1.3 · me 1.2 · other 0.5,
//              + 0.5·ln(1 + my recent interactions with the author: reactions,
//              comments, direct messages)
//   engagement 1 + ln(1 + reactions + 2·comments)
//   freshness  (1 + age_hours / 6) ^ -1.3
// and ×0.6 once I've reacted (already seen), so new things float up.
// mode=explore keeps only the "other" bucket and drops the affinity term.

async function feed(caller: Caller, mode: "home" | "explore", limit: number, offset: number): Promise<PostRow[]> {
  const me = caller.id;
  const { rows } = await sql<PostRow>`
    WITH following AS (
      SELECT followee_id AS id FROM follow WHERE follower_id = ${me} AND status = 'accepted'
    ),
    friends AS (
      SELECT CASE WHEN requester_id = ${me} THEN addressee_id ELSE requester_id END AS id
      FROM friendship WHERE (requester_id = ${me} OR addressee_id = ${me}) AND status = 'accepted'
    ),
    my_businesses AS (
      SELECT gym_id AS id FROM member WHERE user_id = ${me}
      UNION SELECT gym_id FROM trainer WHERE user_id = ${me}
      UNION SELECT gym_id FROM employee WHERE user_id = ${me}
      UNION SELECT gym_id FROM employee_trainer WHERE user_id = ${me}
      UNION SELECT gym_id FROM gym_owner WHERE user_id = ${me}
      UNION SELECT shop_id FROM shop_owner WHERE user_id = ${me}
      UNION SELECT shop_id FROM shop_vendor WHERE user_id = ${me}
    ),
    interactions AS (
      SELECT p.author_id AS id, count(*) AS n FROM post_reaction r JOIN post p ON p.id = r.post_id
        WHERE r.user_id = ${me} AND r.created_at > NOW() - INTERVAL '60 days' GROUP BY p.author_id
      UNION ALL
      SELECT p.author_id, count(*) FROM post_comment c JOIN post p ON p.id = c.post_id
        WHERE c.author_id = ${me} AND c.created_at > NOW() - INTERVAL '60 days' GROUP BY p.author_id
      UNION ALL
      SELECT other.user_id, count(*) FROM message m
        JOIN conversation cv ON cv.id = m.conversation_id AND cv.kind = 'direct'
        JOIN conversation_participant other ON other.conversation_id = cv.id AND other.user_id <> ${me}
        WHERE m.sender_id = ${me} AND m.created_at > NOW() - INTERVAL '30 days' GROUP BY other.user_id
    ),
    affinity AS (SELECT id, sum(n) AS n FROM interactions WHERE id IS NOT NULL GROUP BY id),
    candidates AS (
      SELECT post.*,
        CASE
          WHEN post.author_id = ${me} AND post.business_id IS NULL THEN 'me'
          WHEN post.business_id IS NULL AND post.author_id IN (SELECT id FROM friends) THEN 'friend'
          WHEN post.business_id IS NULL AND post.author_id IN (SELECT id FROM following) THEN 'following'
          WHEN post.business_id IN (SELECT id FROM my_businesses) THEN 'business'
          ELSE 'other'
        END AS bucket
      FROM post
      LEFT JOIN users a ON a.id = post.author_id
      WHERE post.created_at > NOW() - INTERVAL '30 days'
        AND post.archived_at IS NULL
        AND ${visibleTo(me)}
        AND (
          (post.business_id IS NULL AND (post.author_id = ${me} OR post.author_id IN (SELECT id FROM following)))
          OR post.business_id IN (SELECT id FROM my_businesses)
          OR (post.business_id IS NULL AND post.visibility = 'public' AND NOT a.is_private AND a.discoverable)
        )
    ),
    scored AS (
      SELECT c.*,
        (
          CASE WHEN ${mode} = 'explore' THEN 1.0 ELSE
            CASE c.bucket WHEN 'friend' THEN 2.0 WHEN 'following' THEN 1.5 WHEN 'business' THEN 1.3
                          WHEN 'me' THEN 1.2 ELSE 0.5 END
            + 0.5 * ln(1 + COALESCE((SELECT n FROM affinity WHERE affinity.id = c.author_id), 0))
          END
        )
        * (1 + ln(1
            + (SELECT count(*) FROM post_reaction r WHERE r.post_id = c.id)
            + 2 * (SELECT count(*) FROM post_comment pc WHERE pc.post_id = c.id AND pc.deleted_at IS NULL)))
        * power(1 + extract(epoch FROM NOW() - c.created_at) / 3600 / 6, -1.3)
        * CASE WHEN EXISTS (SELECT 1 FROM post_reaction r WHERE r.post_id = c.id AND r.user_id = ${me}) THEN 0.6 ELSE 1 END
        AS score
      FROM candidates c
      WHERE ${mode} = 'home' OR (c.bucket = 'other' AND c.business_id IS NULL)
    )
    SELECT id, business_id, author_id, content, visibility, post_type, ref_id, attachment, archived_at,
           created_at, updated_at
    FROM scored
    ORDER BY score DESC, created_at DESC, id
    LIMIT ${limit} OFFSET ${offset}
  `.execute(db);
  return rows;
}

/** ?from= & ?to= as ISO timestamps (each optional); a 400 when malformed. */
function parseRange(url: URL): { from: string | null; to: string | null } | Response {
  const read = (name: string) => {
    const v = url.searchParams.get(name);
    if (!v) return null;
    const t = Date.parse(v);
    return Number.isNaN(t) ? undefined : new Date(t).toISOString();
  };
  const from = read("from"), to = read("to");
  if (from === undefined || to === undefined) return jsonError("from and to must be ISO dates", 400);
  return { from, to };
}

// ── Postgres error mapping ────────────────────────────────────────────────────

function pgErrorResponse(e: unknown): Response {
  const err = e as { code?: string; message?: string; detail?: string } | null;
  switch (err?.code) {
    case "23505":
      return jsonError("Already exists", 409, { detail: err.detail });
    case "23503":
      return jsonError("Referenced row does not exist", 400, { detail: err.detail });
    case "23502":
    case "23514":
    case "22P02":
      return jsonError(err.message ?? "Invalid value", 400);
  }
  throw e;
}

// ── Handler ───────────────────────────────────────────────────────────────────

async function handler(req: Request): Promise<Response> {
  const url = new URL(req.url);
  const route = parsePath(url.pathname);
  if (route.kind === "unknown") return jsonError("Not found", 404);

  // ── GET /posts?business_id= | ?author_id= — newest first ────────────────────
  if (req.method === "GET" && route.kind === "collection") {
    const businessId = url.searchParams.get("business_id");
    const authorId = url.searchParams.get("author_id");
    const taggedId = url.searchParams.get("tagged_user_id");
    if (!businessId && !authorId && !taggedId) {
      return jsonError("business_id, author_id or tagged_user_id is required", 400);
    }
    const { page, pageSize } = parsePaging(url, 20);
    const caller = await optionalCaller(req);

    let q = db.selectFrom("post").select(POST_COLS);
    if (taggedId && !businessId && !authorId) {
      // Posts the person is pinned in or mentioned in the caption of.
      if (!UUID_RE.test(taggedId)) return jsonError("User not found", 404);
      const person = await db.selectFrom("users").select(["id", "is_private"]).where("id", "=", taggedId)
        .executeTakeFirst();
      if (!person) return jsonError("User not found", 404);
      if (!(await canSeeContentOf(caller?.id ?? null, person))) {
        return jsonError("This account is private", 403, { code: "private_account" });
      }
      q = q.where(({ exists, selectFrom }) =>
        exists(selectFrom("post_tag").select("post_tag.id").whereRef("post_tag.post_id", "=", "post.id")
          .where("post_tag.user_id", "=", taggedId).where("post_tag.comment_id", "is", null))
      ).where(visibleTo(caller?.id ?? null)).where("archived_at", "is", null);
    } else if (businessId) {
      q = q.where("business_id", "=", businessId);
    } else {
      if (!UUID_RE.test(authorId!)) return jsonError("User not found", 404);
      const author = await db.selectFrom("users").select(["id", "is_private"]).where("id", "=", authorId!)
        .executeTakeFirst();
      if (!author) return jsonError("User not found", 404);
      if (!(await canSeeContentOf(caller?.id ?? null, author))) {
        return jsonError("This account is private", 403, { code: "private_account" });
      }
      // Archived posts are left out for the author too: they live in the archive.
      q = q.where("author_id", "=", authorId!).where("business_id", "is", null).where("archived_at", "is", null)
        .where(visibleTo(caller?.id ?? null));
      const type = url.searchParams.get("media"); // only posts with photos/videos (profile grid)
      if (type === "only") {
        q = q.where(({ exists, selectFrom }) =>
          exists(selectFrom("post_image").select("post_image.id").whereRef("post_image.post_id", "=", "post.id"))
        );
      }
    }
    const posts = await q.orderBy("created_at", "desc").orderBy("id", "desc").limit(pageSize).offset(page * pageSize)
      .execute();
    return json(await decoratePosts(posts, caller));
  }

  // ── GET /posts/:id ───────────────────────────────────────────────────────────
  if (req.method === "GET" && route.kind === "post") {
    const caller = await optionalCaller(req);
    const post = await loadVisiblePost(route.id, caller);
    if (!post) return jsonError("Post not found", 404);
    const [decorated] = await decoratePosts([post], caller);
    return json(decorated);
  }

  // ── GET /posts/:id/comments — threads ────────────────────────────────────────
  // Pages over top-level comments (sorted), and returns every reply beneath
  // each of them in the same flat list (parent_id + depth); the app builds the
  // tree and collapses deep or long branches.
  if (req.method === "GET" && route.kind === "comments") {
    const caller = await optionalCaller(req);
    const post = await loadVisiblePost(route.id, caller);
    if (!post) return jsonError("Post not found", 404);
    const { page, pageSize } = parsePaging(url, 20, 50);
    const sort = url.searchParams.get("sort") ?? "top";
    if (!["top", "new", "old"].includes(sort)) return jsonError("sort must be top, new or old", 400);
    const order = sort === "new"
      ? sql`c.created_at DESC, c.id DESC`
      : sort === "old"
      ? sql`c.created_at ASC, c.id ASC`
      : sql`((SELECT count(*) FROM comment_reaction r WHERE r.comment_id = c.id)
             + 2 * (SELECT count(*) FROM post_comment k WHERE k.parent_id = c.id)) DESC, c.created_at ASC, c.id ASC`;
    const { rows } = await sql<CommentRow>`
      WITH RECURSIVE roots AS (
        SELECT c.id FROM post_comment c
        WHERE c.post_id = ${post.id} AND c.parent_id IS NULL
          -- a deleted comment with no replies left is just gone
          AND (c.deleted_at IS NULL OR EXISTS (SELECT 1 FROM post_comment k WHERE k.parent_id = c.id))
        ORDER BY ${order}
        LIMIT ${pageSize} OFFSET ${page * pageSize}
      ),
      tree AS (
        SELECT c.* FROM post_comment c JOIN roots r ON r.id = c.id
        UNION ALL
        SELECT c.* FROM post_comment c JOIN tree t ON c.parent_id = t.id
      )
      SELECT id, post_id, parent_id, depth, author_id, body, created_at, updated_at, deleted_at
      FROM tree
      ORDER BY depth, created_at
      LIMIT 2000
    `.execute(db);
    return json(await decorateComments(rows, caller, await moderates(caller, post)));
  }

  // ── Auth wall ─────────────────────────────────────────────────────────────────

  const { caller, response } = await requireCaller(req);
  if (!caller) return response;

  // ── GET /posts/feed ──────────────────────────────────────────────────────────
  if (req.method === "GET" && route.kind === "feed") {
    const mode = url.searchParams.get("mode") === "explore" ? "explore" : "home";
    const { page, pageSize } = parsePaging(url, 20, 50);
    return json(await decoratePosts(await feed(caller, mode, pageSize, page * pageSize), caller));
  }

  // ── POST /posts/uploads — signed upload URL for a personal post's media ─────
  if (req.method === "POST" && route.kind === "uploads") {
    const body = await req.json().catch(() => null);
    const mime = normalizeMime(body?.mime_type);
    if (!mime || !(mime.startsWith("image/") || mime.startsWith("video/"))) {
      return jsonError("Posts take photos and videos (image/* or video/*)", 400);
    }
    const size = Number(body?.size_bytes);
    if (!Number.isFinite(size) || size <= 0) return jsonError("size_bytes is required", 400);
    if (size > MAX_UPLOAD_BYTES) return jsonError(`Files are limited to ${MAX_UPLOAD_BYTES / 1024 / 1024} MB`, 413);
    const slot = await createUploadSlot({
      bucket: BUCKET,
      prefix: caller.id,
      uploaderId: caller.id,
      mime,
      fileName: typeof body?.file_name === "string" ? body.file_name : null,
    });
    return json(slot, 201);
  }

  // ── GET /posts/mention-search?q= ─────────────────────────────────────────────
  // Suggestions for "@": [{kind: user|business|shop_item, id, label, subtitle,
  // image_url, username}] — people first (ones I follow first), then gyms and
  // shops, then products.
  if (req.method === "GET" && route.kind === "mention_search") {
    const q = (url.searchParams.get("q") ?? "").trim().replace(/^@/, "").slice(0, 50);
    const prefix = `${q.replace(/[\\%_]/g, (c) => `\\${c}`)}%`;
    const wordPrefix = `% ${prefix}`; // a later word of a name
    const kinds = (url.searchParams.get("kinds") ?? "user,business,shop_item").split(",");
    const [people, businesses, products] = await Promise.all([
      kinds.includes("user")
        ? db.selectFrom("users as u")
          .select(["u.id", "u.username", "u.name", "u.last_name", "u.avatar_url",
            sql<boolean>`EXISTS (SELECT 1 FROM follow f WHERE f.follower_id = ${caller.id}
              AND f.followee_id = u.id AND f.status = 'accepted')`.as("followed")])
          .where("u.id", "<>", caller.id)
          .where(sql<boolean>`NOT is_blocked_between(u.id, ${caller.id})`)
          .$if(q.length > 0, (b) =>
            b.where((eb) =>
              eb.or([
                eb("u.username", "ilike", prefix),
                eb("u.name", "ilike", prefix),
                eb("u.last_name", "ilike", prefix),
                eb(sql<string>`u.name || ' ' || u.last_name`, "ilike", prefix),
              ])
            ))
          .$if(q.length === 0, (b) =>
            b.where(sql<boolean>`EXISTS (SELECT 1 FROM follow f WHERE f.follower_id = ${caller.id}
              AND f.followee_id = u.id AND f.status = 'accepted')`))
          .orderBy(sql`EXISTS (SELECT 1 FROM follow f WHERE f.follower_id = ${caller.id}
              AND f.followee_id = u.id AND f.status = 'accepted')`, "desc")
          .orderBy("u.username").limit(6).execute()
        : Promise.resolve([]),
      kinds.includes("business") && q.length > 0
        ? db.selectFrom("business").select(["id", "name", "location", "logo", "type"])
          .where((eb) => eb.or([eb("name", "ilike", prefix), eb("name", "ilike", wordPrefix)]))
          .orderBy("name").limit(4).execute()
        : Promise.resolve([]),
      kinds.includes("shop_item") && q.length > 0
        ? db.selectFrom("shop_item as i").innerJoin("business as b", "b.id", "i.shop_id")
          .select(["i.id", "i.name", "i.image_url", "b.name as shop_name"])
          .where((eb) => eb.or([eb("i.name", "ilike", prefix), eb("i.name", "ilike", wordPrefix)]))
          .where("i.is_active", "=", true)
          .orderBy("i.name").limit(4).execute()
        : Promise.resolve([]),
    ]);
    return json([
      ...people.map((u) => ({
        kind: "user",
        id: u.id,
        label: `${u.name} ${u.last_name}`.trim() || u.username,
        subtitle: `@${u.username}`,
        username: u.username,
        image_url: u.avatar_url,
      })),
      ...businesses.map((b) => ({
        kind: "business",
        id: b.id,
        label: b.name,
        subtitle: b.location,
        business_type: b.type,
        image_url: b.logo,
      })),
      ...products.map((i) => ({ kind: "shop_item", id: i.id, label: i.name, subtitle: i.shop_name, image_url: i.image_url })),
    ]);
  }

  // ── DELETE /posts/:id/tags/me — take myself off a post's photos ─────────────
  if (req.method === "DELETE" && route.kind === "untag") {
    if (!UUID_RE.test(route.id)) return jsonError("Post not found", 404);
    await db.deleteFrom("post_tag").where("post_id", "=", route.id).where("user_id", "=", caller.id)
      .where("post_image_id", "is not", null).execute();
    return new Response(null, { status: 204 });
  }

  // ── GET /posts/archive?from=&to= — my archived posts ─────────────────────────
  // [from, to) are ISO timestamps on created_at (the app asks a month at a
  // time for its calendar); both optional.
  if (req.method === "GET" && route.kind === "archive_list") {
    const range = parseRange(url);
    if (range instanceof Response) return range;
    const { page, pageSize } = parsePaging(url, 60, 500);
    const posts = await db.selectFrom("post").select(POST_COLS)
      .where("author_id", "=", caller.id).where("business_id", "is", null).where("archived_at", "is not", null)
      .$if(!!range.from, (q) => q.where("created_at", ">=", range.from!))
      .$if(!!range.to, (q) => q.where("created_at", "<", range.to!))
      .orderBy("created_at", "desc").orderBy("id", "desc").limit(pageSize).offset(page * pageSize).execute();
    return json(await decoratePosts(posts, caller));
  }

  // ── PUT|DELETE /posts/:id/archive — hide my post / show it again ─────────────
  if (route.kind === "archive" && (req.method === "PUT" || req.method === "DELETE")) {
    if (!UUID_RE.test(route.id)) return jsonError("Post not found", 404);
    const existing = await db.selectFrom("post").select(["author_id", "business_id"]).where("id", "=", route.id)
      .executeTakeFirst();
    if (!existing) return jsonError("Post not found", 404);
    if (existing.business_id) return jsonError("Only personal posts can be archived", 400);
    if (existing.author_id !== caller.id) return forbidden("Only the author can archive a post");
    await db.updateTable("post")
      .set({ archived_at: req.method === "PUT" ? sql<string>`COALESCE(archived_at, NOW())` : null })
      .where("id", "=", route.id).execute();
    const post = await db.selectFrom("post").select(POST_COLS).where("id", "=", route.id).executeTakeFirstOrThrow();
    const [decorated] = await decoratePosts([post], caller);
    return json(decorated);
  }

  // ── POST /posts ──────────────────────────────────────────────────────────────
  if (req.method === "POST" && route.kind === "collection") {
    const body = await req.json().catch(() => null);
    const { business_id, content, images } = body ?? {};

    // Personal post: any signed-in user.
    if (!business_id) {
      const { text: caption, mentions } = await prepareText(typeof content === "string" ? content.trim() : "", caller.id);
      if (caption.length > CAPTION_MAX_LENGTH) return jsonError(`Captions are limited to ${CAPTION_MAX_LENGTH} characters`, 400);
      const visibility = body?.visibility ?? "public";
      if (!VISIBILITIES.includes(visibility)) return jsonError("visibility must be public or followers", 400);
      const media: { path: string; width?: number; height?: number; duration_ms?: number; tags?: unknown }[] =
        Array.isArray(body?.media) ? body.media : [];
      if (media.length > MEDIA_MAX) return jsonError(`Up to ${MEDIA_MAX} photos/videos per post`, 400);
      if (media.some((m) => typeof m?.path !== "string")) return jsonError("Each media item needs a path", 400);
      const pinsPerMedia = media.map((m) => readPins(m.tags));
      const badPins = pinsPerMedia.find((p) => p instanceof Response);
      if (badPins) return badPins as Response;

      const type: PostType = body?.type ?? "generic";
      if (!POST_TYPES.includes(type)) return jsonError(`type must be one of: ${POST_TYPES.join(", ")}`, 400);
      let shared: { ref_id: string | null; attachment: Record<string, unknown> } | null = null;
      if (type !== "generic") {
        const built = await buildAttachment(caller, type, { ref_id: body?.ref_id, meal: body?.meal });
        if (built instanceof Response) return built;
        shared = built;
      }
      if (!caption && media.length === 0 && !shared) return jsonError("A post needs a caption or media", 400);

      const verified = await verifyUploads({ bucket: BUCKET, paths: media.map((m) => m.path), uploaderId: caller.id });
      if ("error" in verified) return jsonError(verified.error, 400);
      const int = (v: unknown) => (Number.isFinite(Number(v)) && Number(v) >= 0 ? Math.round(Number(v)) : null);

      const { post, pinned } = await db.transaction().execute(async (trx) => {
        const created = await trx.insertInto("post")
          .values({
            business_id: null,
            author_id: caller.id,
            content: caption,
            visibility,
            post_type: type,
            ref_id: shared?.ref_id ?? null,
            attachment: shared ? JSON.stringify(shared.attachment) : null,
          })
          .returning(POST_COLS).executeTakeFirstOrThrow();
        const pinned: string[] = [];
        if (media.length) {
          const rows = await trx.insertInto("post_image").values(media.map((m, i) => {
            const mime = verified.mimeByPath.get(m.path)!;
            return {
              post_id: created.id,
              url: null,
              storage_path: m.path,
              position: i,
              media_type: mime.startsWith("video/") ? "video" as const : "image" as const,
              mime_type: mime,
              width: int(m.width),
              height: int(m.height),
              duration_ms: int(m.duration_ms),
            };
          })).returning(["id", "position"]).execute();
          for (const row of rows) {
            const pins = pinsPerMedia[row.position] as { user_id: string; x: number; y: number }[];
            if (pins.length) pinned.push(...(await replacePins(trx, created.id, row.id, caller.id, pins)));
          }
        }
        await syncMentionRows(trx, { postId: created.id, commentId: null, authorId: caller.id }, mentions);
        return { post: created, pinned: [...new Set(pinned)] };
      });
      await markClaimed(BUCKET, media.map((m) => m.path));
      await notifyTags(caller, post, { mentions, pinned, text: caption });
      const [decorated] = await decoratePosts([post], caller);
      return json(decorated, 201);
    }

    // Business post: an announcement from staff.
    if (!content) return jsonError("Missing required fields: business_id, content", 400);
    const business = await db.selectFrom("business").select(["id", "name", "type"]).where("id", "=", business_id)
      .executeTakeFirst();
    if (!business) return jsonError("Business not found", 404);
    const allowed = business.type === "gym"
      ? await canCoachAtGym(caller, business_id)
      : await canStaffShop(caller, business_id);
    if (!allowed) return forbidden("Only business staff can post");

    const { text, mentions } = await prepareText(String(content), caller.id);
    const post = await db.transaction().execute(async (trx) => {
      const created = await trx.insertInto("post").values({ business_id, author_id: caller.id, content: text })
        .returning(POST_COLS).executeTakeFirstOrThrow();
      if (Array.isArray(images) && images.length) await replaceBusinessImages(trx, created.id, images);
      await syncMentionRows(trx, { postId: created.id, commentId: null, authorId: caller.id }, mentions);
      return created;
    });
    await notifyTags(caller, post, { mentions, pinned: [], text });

    if (business.type === "gym") {
      const members = await db.selectFrom("member").select("user_id").where("gym_id", "=", business_id).execute();
      await notify(
        members.map((m) => m.user_id).filter((uid) => uid !== caller.id),
        {
          type: "news",
          title: `${business.name}: new post`,
          body: plainText(text).slice(0, 120),
          metadata: { business_id, business_name: business.name, post_id: post.id },
        },
      );
    }

    const [decorated] = await decoratePosts([post], caller);
    return json(decorated, 201);
  }

  // ── PUT /posts/:id ───────────────────────────────────────────────────────────
  // Business posts: content + images. Personal posts: caption + visibility +
  // photo tags (photo_tags: [{post_image_id, tags: [{user_id, x, y}]}] replaces
  // the people on those photos); the media itself is fixed once posted.
  if (req.method === "PUT" && route.kind === "post") {
    const existing = await db.selectFrom("post").select(POST_COLS).where("id", "=", route.id).executeTakeFirst();
    if (!existing) return jsonError("Post not found", 404);
    if (!canEditAuthored(caller, existing.author_id)) return forbidden();

    const body = await req.json().catch(() => null);
    const { content, images, visibility } = body ?? {};
    if (visibility !== undefined && (existing.business_id || !VISIBILITIES.includes(visibility))) {
      return jsonError("visibility must be public or followers (personal posts only)", 400);
    }
    const photoTags: { post_image_id: string; tags: { user_id: string; x: number; y: number }[] }[] = [];
    if (body?.photo_tags !== undefined) {
      if (existing.business_id || !Array.isArray(body.photo_tags)) {
        return jsonError("photo_tags must be an array (personal posts only)", 400);
      }
      const ownMedia = new Set((await db.selectFrom("post_image").select("id").where("post_id", "=", route.id)
        .execute()).map((m) => m.id));
      for (const entry of body.photo_tags) {
        if (!ownMedia.has(entry?.post_image_id)) return jsonError("post_image_id must be a photo of this post", 400);
        const pins = readPins(entry.tags);
        if (pins instanceof Response) return pins;
        photoTags.push({ post_image_id: entry.post_image_id, tags: pins });
      }
    }
    // Same rules as POST: a personal caption is trimmed and the post keeps a
    // caption or media; a business post always needs content.
    const prepared = typeof content === "string"
      ? await prepareText(existing.business_id ? content : content.trim(), existing.author_id ?? caller.id)
      : null;
    const text = prepared ? prepared.text : content;
    if (typeof text === "string" && text.length > CAPTION_MAX_LENGTH) {
      return jsonError(`Captions are limited to ${CAPTION_MAX_LENGTH} characters`, 400);
    }
    if (content !== undefined && !text) {
      if (existing.business_id) return jsonError("content is required", 400);
      const media = await db.selectFrom("post_image").select("id").where("post_id", "=", route.id).executeTakeFirst();
      if (!media && !existing.attachment) return jsonError("A post needs a caption or media", 400);
    }
    const authorId = existing.author_id ?? caller.id;
    const { mentioned, pinned } = await db.transaction().execute(async (trx) => {
      await trx.updateTable("post").set({
        ...(content !== undefined && { content: text }),
        ...(visibility !== undefined && { visibility }),
        updated_at: new Date().toISOString(),
      }).where("id", "=", route.id).execute();
      if (existing.business_id && Array.isArray(images)) await replaceBusinessImages(trx, route.id, images);
      const mentioned = prepared
        ? await syncMentionRows(trx, { postId: route.id, commentId: null, authorId }, prepared.mentions)
        : [];
      const pinned: string[] = [];
      for (const t of photoTags) pinned.push(...(await replacePins(trx, route.id, t.post_image_id, authorId, t.tags)));
      return { mentioned, pinned: [...new Set(pinned)] };
    });
    await notifyTags(caller, existing, { mentions: mentioned, pinned, text: prepared?.text ?? existing.content });

    const post = await db.selectFrom("post").select(POST_COLS).where("id", "=", route.id).executeTakeFirstOrThrow();
    const [decorated] = await decoratePosts([post], caller);
    return json(decorated);
  }

  // ── DELETE /posts/:id ────────────────────────────────────────────────────────
  if (req.method === "DELETE" && route.kind === "post") {
    const existing = await db.selectFrom("post").select(["author_id"]).where("id", "=", route.id).executeTakeFirst();
    if (!existing) return jsonError("Post not found", 404);
    if (!canEditAuthored(caller, existing.author_id)) return forbidden();
    const files = await db.selectFrom("post_image").select("storage_path").where("post_id", "=", route.id)
      .where("storage_path", "is not", null).execute();
    await db.deleteFrom("post").where("id", "=", route.id).execute();
    await removeObjects(BUCKET, files.map((f) => f.storage_path!));
    return new Response(null, { status: 204 });
  }

  // ── Post reactions ───────────────────────────────────────────────────────────
  // PUT /posts/:id/reaction {reaction} sets or switches mine; DELETE removes.
  // POST|DELETE /posts/:id/like are the same with 'like' (older clients).
  if ((route.kind === "reaction" && (req.method === "PUT" || req.method === "DELETE")) ||
    (route.kind === "like" && (req.method === "POST" || req.method === "DELETE"))) {
    const post = await loadVisiblePost(route.id, caller);
    if (!post) return jsonError("Post not found", 404);

    if (req.method === "DELETE") {
      await db.deleteFrom("post_reaction").where("post_id", "=", post.id).where("user_id", "=", caller.id).execute();
    } else {
      const reaction: unknown = route.kind === "like" ? "like" : (await req.json().catch(() => null))?.reaction;
      if (!isReaction(reaction)) return jsonError(`reaction must be one of: ${REACTIONS.join(", ")}`, 400);
      const { rows: [r] } = await sql<{ inserted: boolean }>`
        INSERT INTO post_reaction (post_id, user_id, reaction) VALUES (${post.id}, ${caller.id}, ${reaction})
        ON CONFLICT (post_id, user_id) DO UPDATE SET reaction = EXCLUDED.reaction
        RETURNING (xmax = 0) AS inserted
      `.execute(db);
      // Only a first reaction notifies; switching emoji doesn't.
      if (r.inserted && post.author_id && post.author_id !== caller.id) {
        await notify([post.author_id], {
          type: "post_reaction",
          title: `${displayName(caller)} reacted ${REACTION_EMOJI[reaction]} to your post`,
          body: plainText(post.content).slice(0, 120),
          metadata: { post_id: post.id, business_id: post.business_id, user_id: caller.id, reaction },
        });
      }
    }
    return json(await postReactionResult(post.id, caller));
  }

  // ── GET /posts/:id/reactions?reaction= — who reacted ────────────────────────
  if (req.method === "GET" && route.kind === "reactions") {
    const post = await loadVisiblePost(route.id, caller);
    if (!post) return jsonError("Post not found", 404);
    const filter = url.searchParams.get("reaction");
    if (filter && !isReaction(filter)) return jsonError("Unknown reaction", 400);
    const { page, pageSize } = parsePaging(url, 50);
    const hidden = [...(await blockedIds(caller.id))];
    const rows = await db.selectFrom("post_reaction as r")
      .innerJoin("users as u", "u.id", "r.user_id")
      .select(["u.id", "u.username", "u.name", "u.last_name", "u.avatar_url", "r.reaction", "r.created_at"])
      .where("r.post_id", "=", post.id)
      .$if(!!filter, (q) => q.where("r.reaction", "=", filter as ReactionType))
      .$if(hidden.length > 0, (q) => q.where("u.id", "not in", hidden))
      .orderBy("r.created_at", "desc")
      .limit(pageSize).offset(page * pageSize)
      .execute();
    return json(rows);
  }

  // ── POST /posts/:id/comments {body, parent_id?} ──────────────────────────────
  if (req.method === "POST" && route.kind === "comments") {
    const payload = await req.json().catch(() => null);
    const { text, mentions } = await prepareText(typeof payload?.body === "string" ? payload.body.trim() : "", caller.id);
    if (!text) return jsonError("body is required", 400);
    if (text.length > COMMENT_MAX_LENGTH) {
      return jsonError(`Comments are limited to ${COMMENT_MAX_LENGTH} characters`, 400);
    }
    const post = await loadVisiblePost(route.id, caller);
    if (!post) return jsonError("Post not found", 404);
    if (!(await canCommentOn(caller, post))) return forbidden("Only members and staff of this gym can comment");

    const parentId = typeof payload?.parent_id === "string" ? payload.parent_id : null;
    let parent: { id: string; author_id: string | null; depth: number; deleted_at: string | null } | undefined;
    if (parentId) {
      if (!UUID_RE.test(parentId)) return jsonError("parent comment not found", 404);
      parent = await db.selectFrom("post_comment").select(["id", "author_id", "depth", "deleted_at"])
        .where("id", "=", parentId).where("post_id", "=", post.id).executeTakeFirst();
      if (!parent) return jsonError("parent comment not found", 404);
      if (parent.deleted_at) return jsonError("Can't reply to a deleted comment", 400);
      if (parent.depth >= MAX_DEPTH) return jsonError("This thread is as deep as it goes — reply higher up", 400);
    }

    const comment = await db.transaction().execute(async (trx) => {
      const row = await trx.insertInto("post_comment")
        .values({ post_id: post.id, author_id: caller.id, body: text, parent_id: parentId })
        .returning("id")
        .executeTakeFirstOrThrow();
      await syncMentionRows(trx, { postId: post.id, commentId: row.id, authorId: caller.id }, mentions);
      return row;
    });

    const who = displayName(caller);
    const business = post.business_id
      ? await db.selectFrom("business").select("name").where("id", "=", post.business_id).executeTakeFirst()
      : undefined;
    const metadata = {
      post_id: post.id,
      business_id: post.business_id,
      business_name: business?.name ?? null,
      comment_id: comment.id,
      parent_id: parentId,
    };
    const preview = plainText(text).slice(0, 120);
    const notified = new Set<string>([caller.id]);
    if (parent?.author_id && !notified.has(parent.author_id)) {
      notified.add(parent.author_id);
      await notify([parent.author_id], {
        type: "comment_reply",
        title: `${who} replied to your comment`,
        body: preview,
        metadata,
      });
    }
    if (post.author_id && !notified.has(post.author_id)) {
      notified.add(post.author_id);
      await notify([post.author_id], {
        type: "post_comment",
        title: `${who} commented on your post`,
        body: preview,
        metadata,
      });
    }
    // Mentioned people who weren't already told about this comment.
    await notifyTags(caller, post, {
      mentions: mentions.filter((m) => m.kind !== "user" || !notified.has(m.id)),
      pinned: [],
      commentId: comment.id,
      text,
    });
    return json(await commentResponse(comment.id, caller), 201);
  }

  // ── PUT /posts/comments/:id {body} — author only ─────────────────────────────
  if (req.method === "PUT" && route.kind === "comment") {
    if (!UUID_RE.test(route.commentId)) return jsonError("Comment not found", 404);
    const existing = await db.selectFrom("post_comment").select(["id", "post_id", "author_id", "deleted_at"])
      .where("id", "=", route.commentId).executeTakeFirst();
    if (!existing || existing.deleted_at) return jsonError("Comment not found", 404);
    if (!existing.author_id || existing.author_id !== caller.id) return forbidden();

    const payload = await req.json().catch(() => null);
    const { text, mentions } = await prepareText(typeof payload?.body === "string" ? payload.body.trim() : "", caller.id);
    if (!text) return jsonError("body is required", 400);
    if (text.length > COMMENT_MAX_LENGTH) {
      return jsonError(`Comments are limited to ${COMMENT_MAX_LENGTH} characters`, 400);
    }
    const added = await db.transaction().execute(async (trx) => {
      await trx.updateTable("post_comment").set({ body: text, updated_at: new Date().toISOString() })
        .where("id", "=", route.commentId).execute();
      return await syncMentionRows(trx, { postId: existing.post_id, commentId: route.commentId, authorId: caller.id }, mentions);
    });
    const post = await db.selectFrom("post").select(["id", "business_id"]).where("id", "=", existing.post_id)
      .executeTakeFirstOrThrow();
    await notifyTags(caller, post, { mentions: added, pinned: [], commentId: route.commentId, text });
    return json(await commentResponse(route.commentId, caller));
  }

  // ── DELETE /posts/comments/:id — author, moderator or super user ─────────────
  // With replies it becomes a "[deleted]" placeholder so the thread survives.
  if (req.method === "DELETE" && route.kind === "comment") {
    if (!UUID_RE.test(route.commentId)) return jsonError("Comment not found", 404);
    const existing = await db.selectFrom("post_comment")
      .innerJoin("post", "post.id", "post_comment.post_id")
      .select(["post_comment.id", "post_comment.author_id", "post_comment.deleted_at", "post.business_id", "post.author_id as post_author_id"])
      .where("post_comment.id", "=", route.commentId)
      .executeTakeFirst();
    if (!existing || existing.deleted_at) return jsonError("Comment not found", 404);
    const allowed = (existing.author_id !== null && existing.author_id === caller.id) ||
      (await moderates(caller, { business_id: existing.business_id, author_id: existing.post_author_id }));
    if (!allowed) return forbidden();

    const hasReplies = await db.selectFrom("post_comment").select("id").where("parent_id", "=", route.commentId)
      .executeTakeFirst();
    if (hasReplies) {
      await db.transaction().execute(async (trx) => {
        await trx.updateTable("post_comment").set({ deleted_at: new Date().toISOString(), body: "" })
          .where("id", "=", route.commentId).execute();
        await trx.deleteFrom("comment_reaction").where("comment_id", "=", route.commentId).execute();
        await trx.deleteFrom("post_tag").where("comment_id", "=", route.commentId).execute();
      });
    } else {
      await db.deleteFrom("post_comment").where("id", "=", route.commentId).execute();
    }
    return new Response(null, { status: 204 });
  }

  // ── PUT|DELETE /posts/comments/:id/reaction ──────────────────────────────────
  if (route.kind === "comment_reaction" && (req.method === "PUT" || req.method === "DELETE")) {
    if (!UUID_RE.test(route.commentId)) return jsonError("Comment not found", 404);
    const c = await db.selectFrom("post_comment").select(["id", "post_id", "deleted_at"])
      .where("id", "=", route.commentId).executeTakeFirst();
    if (!c || c.deleted_at || !(await loadVisiblePost(c.post_id, caller))) return jsonError("Comment not found", 404);
    if (req.method === "DELETE") {
      await db.deleteFrom("comment_reaction").where("comment_id", "=", c.id).where("user_id", "=", caller.id).execute();
    } else {
      const reaction = (await req.json().catch(() => null))?.reaction;
      if (!isReaction(reaction)) return jsonError(`reaction must be one of: ${REACTIONS.join(", ")}`, 400);
      await db.insertInto("comment_reaction").values({ comment_id: c.id, user_id: caller.id, reaction })
        .onConflict((oc) => oc.columns(["comment_id", "user_id"]).doUpdateSet({ reaction })).execute();
    }
    return json(await commentResponse(c.id, caller));
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
