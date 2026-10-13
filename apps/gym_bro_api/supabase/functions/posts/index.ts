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
import type { Database, PostImageInsert, PostInsert, PostUpdate } from "../../types/schema/public.ts";

const POST_COLS = ["id", "business_id", "author_id", "content", "created_at", "updated_at"] as const;
const IMAGE_COLS = ["id", "post_id", "url", "position"] as const;
const COMMENT_MAX_LENGTH = 2000;

// ── Path parsing ──────────────────────────────────────────────────────────────
// /posts/comments/:commentId must be matched before /posts/:id.

type Route =
  | { kind: "collection" }
  | { kind: "post"; id: string }
  | { kind: "like"; id: string }
  | { kind: "comments"; id: string }
  | { kind: "comment"; commentId: string }
  | { kind: "unknown" };

function parsePath(pathname: string): Route {
  if (/^\/posts\/?$/.test(pathname)) return { kind: "collection" };
  let m = pathname.match(/^\/posts\/comments\/([^/]+)$/);
  if (m) return { kind: "comment", commentId: m[1] };
  m = pathname.match(/^\/posts\/([^/]+)\/like$/);
  if (m) return { kind: "like", id: m[1] };
  m = pathname.match(/^\/posts\/([^/]+)\/comments$/);
  if (m) return { kind: "comments", id: m[1] };
  m = pathname.match(/^\/posts\/([^/]+)$/);
  if (m) return { kind: "post", id: m[1] };
  return { kind: "unknown" };
}

function parsePaging(url: URL, defaultSize: number): { page: number; pageSize: number } {
  const page = Math.max(0, parseInt(url.searchParams.get("page") ?? "0") || 0);
  const pageSize = Math.min(100, Math.max(1, parseInt(url.searchParams.get("page_size") ?? "") || defaultSize));
  return { page, pageSize };
}

// ── Optional caller ───────────────────────────────────────────────────────────
// GET routes are public; resolve the caller only when a valid user token is
// sent (the anon key or an expired token just means "anonymous").

async function optionalCaller(req: Request): Promise<Caller | null> {
  if (!req.headers.get("Authorization")) return null;
  try {
    const { caller } = await requireCaller(req);
    return caller ?? null;
  } catch {
    return null;
  }
}

// ── Nested fetch ──────────────────────────────────────────────────────────────

async function attachImages<T extends { id: string }>(posts: T[]) {
  const ids = posts.map((p) => p.id);
  const images = ids.length
    ? await db.selectFrom("post_image").select(IMAGE_COLS).where("post_id", "in", ids).orderBy("position", "asc").execute()
    : [];
  const byPost: Record<string, typeof images> = {};
  for (const img of images) (byPost[img.post_id] ??= []).push(img);
  return posts.map((p) => ({ ...p, images: byPost[p.id] ?? [] }));
}

type Author = { id: string; name: string; last_name: string; avatar_url: string | null };

async function authorsById(ids: (string | null)[]): Promise<Record<string, Author>> {
  const unique = [...new Set(ids.filter((x): x is string => !!x))];
  if (!unique.length) return {};
  const rows = await db
    .selectFrom("users")
    .select(["id", "name", "last_name", "avatar_url"])
    .where("id", "in", unique)
    .execute();
  return Object.fromEntries(rows.map((r) => [r.id, r]));
}

/** Adds images, author, like_count, comment_count and liked_by_me to each post. */
async function decoratePosts<T extends { id: string; author_id: string | null }>(
  posts: T[],
  caller: Caller | null,
) {
  if (!posts.length) return [];
  const ids = posts.map((p) => p.id);
  const [withImages, likeRows, commentRows, mine, authors] = await Promise.all([
    attachImages(posts),
    db
      .selectFrom("post_like")
      .select(["post_id", sql<number>`count(*)::int`.as("n")])
      .where("post_id", "in", ids)
      .groupBy("post_id")
      .execute(),
    db
      .selectFrom("post_comment")
      .select(["post_id", sql<number>`count(*)::int`.as("n")])
      .where("post_id", "in", ids)
      .groupBy("post_id")
      .execute(),
    caller
      ? db
        .selectFrom("post_like")
        .select("post_id")
        .where("post_id", "in", ids)
        .where("user_id", "=", caller.id)
        .execute()
      : Promise.resolve([] as { post_id: string }[]),
    authorsById(posts.map((p) => p.author_id)),
  ]);
  const likes = Object.fromEntries(likeRows.map((r) => [r.post_id, r.n]));
  const comments = Object.fromEntries(commentRows.map((r) => [r.post_id, r.n]));
  const liked = new Set(mine.map((r) => r.post_id));
  return withImages.map((p) => ({
    ...p,
    author: p.author_id ? authors[p.author_id] ?? null : null,
    like_count: likes[p.id] ?? 0,
    comment_count: comments[p.id] ?? 0,
    liked_by_me: liked.has(p.id),
  }));
}

async function likeCount(postId: string): Promise<number> {
  const row = await db
    .selectFrom("post_like")
    .select(sql<number>`count(*)::int`.as("n"))
    .where("post_id", "=", postId)
    .executeTakeFirstOrThrow();
  return row.n;
}

/** Gym post: members plus coaches/staff of that gym. Shop post: any signed-in user. */
async function canCommentOn(caller: Caller, business: { id: string; type: string }): Promise<boolean> {
  if (business.type !== "gym") return true;
  if (await canCoachAtGym(caller, business.id)) return true;
  const member = await db
    .selectFrom("member")
    .select("id")
    .where("user_id", "=", caller.id)
    .where("gym_id", "=", business.id)
    .executeTakeFirst();
  return !!member;
}

const COMMENT_COLS = ["id", "post_id", "author_id", "body", "created_at", "updated_at"] as const;

// Always call inside a transaction.
async function replacePostImages(
  trx: Kysely<Database>,
  postId: string,
  images: { url: string; position?: number }[],
) {
  await trx.deleteFrom("post_image").where("post_id", "=", postId).execute();
  if (!images.length) return;
  const imageInserts: PostImageInsert[] = images.map((img, i) => ({
    post_id: postId,
    url: img.url,
    position: img.position ?? i,
  }));
  await trx.insertInto("post_image").values(imageInserts).execute();
}

// ── Postgres error mapping ────────────────────────────────────────────────────

function pgErrorResponse(e: unknown): Response {
  const err = e as { code?: string; message?: string; detail?: string } | null;
  switch (err?.code) {
    case "23505":
      return jsonError("Already exists", 409, { detail: err.detail });
    case "23503":
      return jsonError("Referenced business does not exist", 400, { detail: err.detail });
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

  // ── GET /posts — public, ?business_id= required, paginated newest-first ──────
  if (req.method === "GET" && route.kind === "collection") {
    const businessId = url.searchParams.get("business_id");
    if (!businessId) return jsonError("business_id is required", 400);
    const { page, pageSize } = parsePaging(url, 20);

    const caller = await optionalCaller(req);
    const posts = await db
      .selectFrom("post")
      .select(POST_COLS)
      .where("business_id", "=", businessId)
      .orderBy("created_at", "desc")
      .limit(pageSize)
      .offset(page * pageSize)
      .execute();

    return json(await decoratePosts(posts, caller));
  }

  // ── GET /posts/:id — public ───────────────────────────────────────────────────
  if (req.method === "GET" && route.kind === "post") {
    const caller = await optionalCaller(req);
    const post = await db.selectFrom("post").select(POST_COLS).where("id", "=", route.id).executeTakeFirst();
    if (!post) return jsonError("Post not found", 404);
    const [decorated] = await decoratePosts([post], caller);
    return json(decorated);
  }

  // ── GET /posts/:id/comments — public, oldest first ───────────────────────────
  // can_edit / can_delete are computed for the caller (false when anonymous).
  if (req.method === "GET" && route.kind === "comments") {
    const post = await db
      .selectFrom("post")
      .select(["id", "business_id"])
      .where("id", "=", route.id)
      .executeTakeFirst();
    if (!post) return jsonError("Post not found", 404);
    const { page, pageSize } = parsePaging(url, 50);
    const caller = await optionalCaller(req);

    const rows = await db
      .selectFrom("post_comment")
      .select(COMMENT_COLS)
      .where("post_id", "=", route.id)
      .orderBy("created_at", "asc")
      .orderBy("id", "asc")
      .limit(pageSize)
      .offset(page * pageSize)
      .execute();

    const authors = await authorsById(rows.map((r) => r.author_id));
    const moderator = caller ? await canManageBusiness(caller, post.business_id) : false;
    return json(rows.map((c) => {
      const own = !!caller && c.author_id === caller.id;
      return {
        ...c,
        author: c.author_id ? authors[c.author_id] ?? null : null,
        can_edit: own,
        can_delete: own || moderator,
      };
    }));
  }

  // ── Auth wall ─────────────────────────────────────────────────────────────────

  const { caller, response } = await requireCaller(req);
  if (!caller) return response;

  // ── POST /posts ────────────────────────────────────────────────────────────────
  // A post is an announcement from business staff, not open member-generated
  // content — gym staff/trainers, shop owners/vendors (or super_user) only.
  if (req.method === "POST" && route.kind === "collection") {
    const body = await req.json().catch(() => null);
    const { business_id, content, images } = body ?? {};

    if (!business_id || !content) {
      return jsonError("Missing required fields: business_id, content", 400);
    }

    const business = await db
      .selectFrom("business")
      .select(["id", "name", "type"])
      .where("id", "=", business_id)
      .executeTakeFirst();
    if (!business) return jsonError("Business not found", 404);

    const allowed = business.type === "gym"
      ? await canCoachAtGym(caller, business_id)
      : await canStaffShop(caller, business_id);
    if (!allowed) return forbidden("Only business staff can post");

    const insert: PostInsert = { business_id, author_id: caller.id, content };
    const post = await db.transaction().execute(async (trx) => {
      const created = await trx.insertInto("post").values(insert).returning(POST_COLS).executeTakeFirstOrThrow();
      if (Array.isArray(images) && images.length) await replacePostImages(trx, created.id, images);
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

  // ── PUT /posts/:id ────────────────────────────────────────────────────────────
  if (req.method === "PUT" && route.kind === "post") {
    const id = route.id;
    const existing = await db
      .selectFrom("post")
      .select(["id", "business_id", "author_id"])
      .where("id", "=", id)
      .executeTakeFirst();
    if (!existing) return jsonError("Post not found", 404);
    if (!canEditAuthored(caller, existing.author_id)) return forbidden();

    const body = await req.json().catch(() => null);
    const { content, images } = body ?? {};

    const update: PostUpdate = {
      ...(content !== undefined && { content }),
      updated_at: new Date().toISOString(),
    };
    await db.transaction().execute(async (trx) => {
      await trx.updateTable("post").set(update).where("id", "=", id).execute();
      if (Array.isArray(images)) await replacePostImages(trx, id, images);
    });

    const post = await db.selectFrom("post").select(POST_COLS).where("id", "=", id).executeTakeFirstOrThrow();
    const [decorated] = await decoratePosts([post], caller);
    return json(decorated);
  }

  // ── DELETE /posts/:id ─────────────────────────────────────────────────────────
  if (req.method === "DELETE" && route.kind === "post") {
    const existing = await db
      .selectFrom("post")
      .select(["author_id"])
      .where("id", "=", route.id)
      .executeTakeFirst();
    if (!existing) return jsonError("Post not found", 404);
    if (!canEditAuthored(caller, existing.author_id)) return forbidden();

    await db.deleteFrom("post").where("id", "=", route.id).execute();
    return new Response(null, { status: 204 });
  }

  // ── POST|DELETE /posts/:id/like — idempotent, returns the new count ──────────
  if ((req.method === "POST" || req.method === "DELETE") && route.kind === "like") {
    const post = await db.selectFrom("post").select("id").where("id", "=", route.id).executeTakeFirst();
    if (!post) return jsonError("Post not found", 404);

    if (req.method === "POST") {
      await db
        .insertInto("post_like")
        .values({ post_id: route.id, user_id: caller.id })
        .onConflict((oc) => oc.columns(["post_id", "user_id"]).doNothing())
        .execute();
    } else {
      await db
        .deleteFrom("post_like")
        .where("post_id", "=", route.id)
        .where("user_id", "=", caller.id)
        .execute();
    }
    return json({ post_id: route.id, liked: req.method === "POST", like_count: await likeCount(route.id) });
  }

  // ── POST /posts/:id/comments {body} ──────────────────────────────────────────
  if (req.method === "POST" && route.kind === "comments") {
    const payload = await req.json().catch(() => null);
    const text = typeof payload?.body === "string" ? payload.body.trim() : "";
    if (!text) return jsonError("body is required", 400);
    if (text.length > COMMENT_MAX_LENGTH) {
      return jsonError(`Comments are limited to ${COMMENT_MAX_LENGTH} characters`, 400);
    }

    const post = await db
      .selectFrom("post")
      .innerJoin("business", "business.id", "post.business_id")
      .select(["post.id", "post.author_id", "post.business_id", "business.name as business_name", "business.type"])
      .where("post.id", "=", route.id)
      .executeTakeFirst();
    if (!post) return jsonError("Post not found", 404);
    if (!(await canCommentOn(caller, { id: post.business_id, type: post.type }))) {
      return forbidden("Only members and staff of this gym can comment");
    }

    const comment = await db
      .insertInto("post_comment")
      .values({ post_id: post.id, author_id: caller.id, body: text })
      .returning(COMMENT_COLS)
      .executeTakeFirstOrThrow();

    if (post.author_id && post.author_id !== caller.id) {
      const who = `${caller.name} ${caller.last_name}`.trim() || "Someone";
      await notify([post.author_id], {
        type: "post_comment",
        title: `${who} commented on your post`,
        body: text.slice(0, 120),
        metadata: {
          post_id: post.id,
          business_id: post.business_id,
          business_name: post.business_name,
          comment_id: comment.id,
        },
      });
    }

    const authors = await authorsById([caller.id]);
    return json({ ...comment, author: authors[caller.id] ?? null, can_edit: true, can_delete: true }, 201);
  }

  // ── PUT /posts/comments/:commentId {body} — author only ─────────────────────
  if (req.method === "PUT" && route.kind === "comment") {
    const existing = await db
      .selectFrom("post_comment")
      .select(["id", "author_id"])
      .where("id", "=", route.commentId)
      .executeTakeFirst();
    if (!existing) return jsonError("Comment not found", 404);
    if (!existing.author_id || existing.author_id !== caller.id) return forbidden();

    const payload = await req.json().catch(() => null);
    const text = typeof payload?.body === "string" ? payload.body.trim() : "";
    if (!text) return jsonError("body is required", 400);
    if (text.length > COMMENT_MAX_LENGTH) {
      return jsonError(`Comments are limited to ${COMMENT_MAX_LENGTH} characters`, 400);
    }

    const comment = await db
      .updateTable("post_comment")
      .set({ body: text, updated_at: new Date().toISOString() })
      .where("id", "=", route.commentId)
      .returning(COMMENT_COLS)
      .executeTakeFirstOrThrow();
    const authors = await authorsById([caller.id]);
    return json({ ...comment, author: authors[caller.id] ?? null, can_edit: true, can_delete: true });
  }

  // ── DELETE /posts/comments/:commentId — author, super user or business owner ─
  if (req.method === "DELETE" && route.kind === "comment") {
    const existing = await db
      .selectFrom("post_comment")
      .innerJoin("post", "post.id", "post_comment.post_id")
      .select(["post_comment.id", "post_comment.author_id", "post.business_id"])
      .where("post_comment.id", "=", route.commentId)
      .executeTakeFirst();
    if (!existing) return jsonError("Comment not found", 404);
    const allowed = (existing.author_id !== null && existing.author_id === caller.id) ||
      isSuperUser(caller) ||
      (await canManageBusiness(caller, existing.business_id));
    if (!allowed) return forbidden();

    await db.deleteFrom("post_comment").where("id", "=", route.commentId).execute();
    return new Response(null, { status: 204 });
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
