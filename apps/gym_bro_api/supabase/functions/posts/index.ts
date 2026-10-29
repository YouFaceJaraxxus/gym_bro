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
import type { Database, PostImageInsert, PostVisibility, ReactionType } from "../../types/schema/public.ts";

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

const POST_COLS = ["id", "business_id", "author_id", "content", "visibility", "created_at", "updated_at"] as const;
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
  created_at: string;
  updated_at: string;
};

// ── Path parsing ──────────────────────────────────────────────────────────────

type Route =
  | { kind: "collection" }
  | { kind: "feed" }
  | { kind: "uploads" }
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

/** SQL condition: `post` (alias) is visible to the viewer. */
function visibleTo(viewerId: string | null) {
  if (!viewerId) {
    return sql<boolean>`(post.business_id IS NOT NULL OR (post.visibility = 'public'
      AND NOT (SELECT is_private FROM users WHERE id = post.author_id)))`;
  }
  return sql<boolean>`(
    post.business_id IS NOT NULL
    OR post.author_id = ${viewerId}
    OR (
      NOT is_blocked_between(post.author_id, ${viewerId})
      AND (
        EXISTS (SELECT 1 FROM follow f WHERE f.follower_id = ${viewerId} AND f.followee_id = post.author_id AND f.status = 'accepted')
        OR (post.visibility = 'public' AND NOT (SELECT is_private FROM users WHERE id = post.author_id))
      )
    )
  )`;
}

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
  const signed = await signPaths(BUCKET, media.flatMap((m) => (m.storage_path ? [m.storage_path] : [])));
  const byPost: Record<string, unknown[]> = {};
  for (const m of media) {
    const { storage_path, ...rest } = m;
    (byPost[m.post_id] ??= []).push({ ...rest, url: storage_path ? signed.get(storage_path) ?? null : m.url });
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
    SELECT id, business_id, author_id, content, visibility, created_at, updated_at
    FROM scored
    ORDER BY score DESC, created_at DESC, id
    LIMIT ${limit} OFFSET ${offset}
  `.execute(db);
  return rows;
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
    if (!businessId && !authorId) return jsonError("business_id or author_id is required", 400);
    const { page, pageSize } = parsePaging(url, 20);
    const caller = await optionalCaller(req);

    let q = db.selectFrom("post").select(POST_COLS);
    if (businessId) {
      q = q.where("business_id", "=", businessId);
    } else {
      if (!UUID_RE.test(authorId!)) return jsonError("User not found", 404);
      const author = await db.selectFrom("users").select(["id", "is_private"]).where("id", "=", authorId!)
        .executeTakeFirst();
      if (!author) return jsonError("User not found", 404);
      if (!(await canSeeContentOf(caller?.id ?? null, author))) {
        return jsonError("This account is private", 403, { code: "private_account" });
      }
      q = q.where("author_id", "=", authorId!).where("business_id", "is", null)
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

  // ── POST /posts ──────────────────────────────────────────────────────────────
  if (req.method === "POST" && route.kind === "collection") {
    const body = await req.json().catch(() => null);
    const { business_id, content, images } = body ?? {};

    // Personal post: any signed-in user.
    if (!business_id) {
      const caption = typeof content === "string" ? content.trim() : "";
      if (caption.length > CAPTION_MAX_LENGTH) return jsonError(`Captions are limited to ${CAPTION_MAX_LENGTH} characters`, 400);
      const visibility = body?.visibility ?? "public";
      if (!VISIBILITIES.includes(visibility)) return jsonError("visibility must be public or followers", 400);
      const media: { path: string; width?: number; height?: number; duration_ms?: number }[] =
        Array.isArray(body?.media) ? body.media : [];
      if (media.length > MEDIA_MAX) return jsonError(`Up to ${MEDIA_MAX} photos/videos per post`, 400);
      if (media.some((m) => typeof m?.path !== "string")) return jsonError("Each media item needs a path", 400);
      if (!caption && media.length === 0) return jsonError("A post needs a caption or media", 400);

      const verified = await verifyUploads({ bucket: BUCKET, paths: media.map((m) => m.path), uploaderId: caller.id });
      if ("error" in verified) return jsonError(verified.error, 400);
      const int = (v: unknown) => (Number.isFinite(Number(v)) && Number(v) >= 0 ? Math.round(Number(v)) : null);

      const post = await db.transaction().execute(async (trx) => {
        const created = await trx.insertInto("post")
          .values({ business_id: null, author_id: caller.id, content: caption, visibility })
          .returning(POST_COLS).executeTakeFirstOrThrow();
        if (media.length) {
          await trx.insertInto("post_image").values(media.map((m, i) => {
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
          })).execute();
        }
        return created;
      });
      await markClaimed(BUCKET, media.map((m) => m.path));
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

    const post = await db.transaction().execute(async (trx) => {
      const created = await trx.insertInto("post").values({ business_id, author_id: caller.id, content })
        .returning(POST_COLS).executeTakeFirstOrThrow();
      if (Array.isArray(images) && images.length) await replaceBusinessImages(trx, created.id, images);
      return created;
    });

    if (business.type === "gym") {
      const members = await db.selectFrom("member").select("user_id").where("gym_id", "=", business_id).execute();
      await notify(
        members.map((m) => m.user_id).filter((uid) => uid !== caller.id),
        {
          type: "news",
          title: `${business.name}: new post`,
          body: String(content).slice(0, 120),
          metadata: { business_id, business_name: business.name, post_id: post.id },
        },
      );
    }

    const [decorated] = await decoratePosts([post], caller);
    return json(decorated, 201);
  }

  // ── PUT /posts/:id ───────────────────────────────────────────────────────────
  // Business posts: content + images. Personal posts: caption + visibility
  // (the media itself is fixed once posted).
  if (req.method === "PUT" && route.kind === "post") {
    const existing = await db.selectFrom("post").select(POST_COLS).where("id", "=", route.id).executeTakeFirst();
    if (!existing) return jsonError("Post not found", 404);
    if (!canEditAuthored(caller, existing.author_id)) return forbidden();

    const body = await req.json().catch(() => null);
    const { content, images, visibility } = body ?? {};
    if (visibility !== undefined && (existing.business_id || !VISIBILITIES.includes(visibility))) {
      return jsonError("visibility must be public or followers (personal posts only)", 400);
    }
    // Same rules as POST: a personal caption is trimmed and the post keeps a
    // caption or media; a business post always needs content.
    const text = typeof content === "string" && !existing.business_id ? content.trim() : content;
    if (typeof text === "string" && text.length > CAPTION_MAX_LENGTH) {
      return jsonError(`Captions are limited to ${CAPTION_MAX_LENGTH} characters`, 400);
    }
    if (content !== undefined && !text) {
      if (existing.business_id) return jsonError("content is required", 400);
      const media = await db.selectFrom("post_image").select("id").where("post_id", "=", route.id).executeTakeFirst();
      if (!media) return jsonError("A post needs a caption or media", 400);
    }
    await db.transaction().execute(async (trx) => {
      await trx.updateTable("post").set({
        ...(content !== undefined && { content: text }),
        ...(visibility !== undefined && { visibility }),
        updated_at: new Date().toISOString(),
      }).where("id", "=", route.id).execute();
      if (existing.business_id && Array.isArray(images)) await replaceBusinessImages(trx, route.id, images);
    });

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
          body: post.content.slice(0, 120),
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
    const text = typeof payload?.body === "string" ? payload.body.trim() : "";
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

    const comment = await db.insertInto("post_comment")
      .values({ post_id: post.id, author_id: caller.id, body: text, parent_id: parentId })
      .returning("id")
      .executeTakeFirstOrThrow();

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
    const notified = new Set<string>([caller.id]);
    if (parent?.author_id && !notified.has(parent.author_id)) {
      notified.add(parent.author_id);
      await notify([parent.author_id], {
        type: "comment_reply",
        title: `${who} replied to your comment`,
        body: text.slice(0, 120),
        metadata,
      });
    }
    if (post.author_id && !notified.has(post.author_id)) {
      await notify([post.author_id], {
        type: "post_comment",
        title: `${who} commented on your post`,
        body: text.slice(0, 120),
        metadata,
      });
    }
    return json(await commentResponse(comment.id, caller), 201);
  }

  // ── PUT /posts/comments/:id {body} — author only ─────────────────────────────
  if (req.method === "PUT" && route.kind === "comment") {
    if (!UUID_RE.test(route.commentId)) return jsonError("Comment not found", 404);
    const existing = await db.selectFrom("post_comment").select(["id", "author_id", "deleted_at"])
      .where("id", "=", route.commentId).executeTakeFirst();
    if (!existing || existing.deleted_at) return jsonError("Comment not found", 404);
    if (!existing.author_id || existing.author_id !== caller.id) return forbidden();

    const payload = await req.json().catch(() => null);
    const text = typeof payload?.body === "string" ? payload.body.trim() : "";
    if (!text) return jsonError("body is required", 400);
    if (text.length > COMMENT_MAX_LENGTH) {
      return jsonError(`Comments are limited to ${COMMENT_MAX_LENGTH} characters`, 400);
    }
    await db.updateTable("post_comment").set({ body: text, updated_at: new Date().toISOString() })
      .where("id", "=", route.commentId).execute();
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
