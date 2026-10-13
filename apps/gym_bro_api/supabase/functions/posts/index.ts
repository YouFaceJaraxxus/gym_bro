import type { Kysely } from "npm:kysely@^0.27";
import { db } from "../_shared/config.ts";
import {
  canCoachAtGym,
  canEditAuthored,
  canStaffShop,
  forbidden,
  json,
  jsonError,
  requireCaller,
} from "../_shared/auth.ts";
import { notify } from "../_shared/notify.ts";
import type { Database, PostImageInsert, PostInsert, PostUpdate } from "../../types/schema/public.ts";

const POST_COLS = ["id", "business_id", "author_id", "content", "created_at", "updated_at"] as const;
const IMAGE_COLS = ["id", "post_id", "url", "position"] as const;

// ── Path parsing ──────────────────────────────────────────────────────────────

function parseId(pathname: string): string | null {
  const match = pathname.match(/^\/posts\/([^/]+)$/);
  return match ? match[1] : null;
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
  const id = parseId(url.pathname);

  // ── GET /posts — public, ?business_id= required, paginated newest-first ──────
  if (req.method === "GET" && !id) {
    const businessId = url.searchParams.get("business_id");
    if (!businessId) return jsonError("business_id is required", 400);

    const page = parseInt(url.searchParams.get("page") ?? "0");
    const pageSize = Math.min(parseInt(url.searchParams.get("page_size") ?? "20"), 100);

    const posts = await db
      .selectFrom("post")
      .select(POST_COLS)
      .where("business_id", "=", businessId)
      .orderBy("created_at", "desc")
      .limit(pageSize)
      .offset(page * pageSize)
      .execute();

    return json(await attachImages(posts));
  }

  // ── GET /posts/:id — public ───────────────────────────────────────────────────
  if (req.method === "GET" && id) {
    const post = await db.selectFrom("post").select(POST_COLS).where("id", "=", id).executeTakeFirst();
    if (!post) return jsonError("Post not found", 404);
    const [withImages] = await attachImages([post]);
    return json(withImages);
  }

  // ── Auth wall ─────────────────────────────────────────────────────────────────

  const { caller, response } = await requireCaller(req);
  if (!caller) return response;

  // ── POST /posts ────────────────────────────────────────────────────────────────
  // A post is an announcement from business staff, not open member-generated
  // content — gym staff/trainers, shop owners/vendors (or super_user) only.
  if (req.method === "POST" && !id) {
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
          metadata: { business_id, post_id: post.id },
        },
      );
    }

    const [withImages] = await attachImages([post]);
    return json(withImages, 201);
  }

  // ── PUT /posts/:id ────────────────────────────────────────────────────────────
  if (req.method === "PUT" && id) {
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
    const [withImages] = await attachImages([post]);
    return json(withImages);
  }

  // ── DELETE /posts/:id ─────────────────────────────────────────────────────────
  if (req.method === "DELETE" && id) {
    const existing = await db
      .selectFrom("post")
      .select(["author_id"])
      .where("id", "=", id)
      .executeTakeFirst();
    if (!existing) return jsonError("Post not found", 404);
    if (!canEditAuthored(caller, existing.author_id)) return forbidden();

    await db.deleteFrom("post").where("id", "=", id).execute();
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
