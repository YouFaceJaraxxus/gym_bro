import { db, supabaseAdmin } from "../_shared/config.ts";
import type { PostImageInsert, PostInsert, PostUpdate } from "../../types/schema/public.ts";

const POST_COLS = ["id", "business_id", "author_id", "content", "created_at", "updated_at"] as const;
const IMAGE_COLS = ["id", "post_id", "url", "position"] as const;

// ── Auth ──────────────────────────────────────────────────────────────────────

async function requireAuth(req: Request) {
  const token = req.headers.get("Authorization")?.replace(/^Bearer\s+/i, "");
  if (!token) return { user: null, error: "Missing Authorization header" };
  const { data: { user }, error } = await supabaseAdmin.auth.getUser(token);
  return { user: error ? null : user, error: error?.message ?? null };
}

// A post is an announcement from business staff, not open member-generated
// content — only people with a staff role at the business (or super_user) may
// create/edit/delete posts there.
async function isBusinessStaff(dbUserId: string, businessId: string): Promise<boolean> {
  const [gymOwner, shopOwner, employee, trainer, employeeTrainer, shopVendor] = await Promise.all([
    db.selectFrom("gym_owner").select("id").where("user_id", "=", dbUserId).where("gym_id", "=", businessId).executeTakeFirst(),
    db.selectFrom("shop_owner").select("id").where("user_id", "=", dbUserId).where("shop_id", "=", businessId).executeTakeFirst(),
    db.selectFrom("employee").select("id").where("user_id", "=", dbUserId).where("gym_id", "=", businessId).executeTakeFirst(),
    db.selectFrom("trainer").select("id").where("user_id", "=", dbUserId).where("gym_id", "=", businessId).executeTakeFirst(),
    db.selectFrom("employee_trainer").select("id").where("user_id", "=", dbUserId).where("gym_id", "=", businessId).executeTakeFirst(),
    db.selectFrom("shop_vendor").select("id").where("user_id", "=", dbUserId).where("shop_id", "=", businessId).executeTakeFirst(),
  ]);
  return !!(gymOwner || shopOwner || employee || trainer || employeeTrainer || shopVendor);
}

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

// ── Handler ───────────────────────────────────────────────────────────────────

Deno.serve(async (req: Request) => {
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

  const { user, error: authError } = await requireAuth(req);
  if (!user) return jsonError(authError ?? "Unauthorized", 401);

  const dbUser = await db
    .selectFrom("users")
    .select(["id", "role"])
    .where("auth_id", "=", user.id)
    .executeTakeFirst();
  if (!dbUser) return jsonError("User not found", 404);

  // ── POST /posts ────────────────────────────────────────────────────────────────
  if (req.method === "POST" && !id) {
    const body = await req.json().catch(() => null);
    const { business_id, content, images } = body ?? {};

    if (!business_id || !content) {
      return jsonError("Missing required fields: business_id, content", 400);
    }

    if (dbUser.role !== "super_user" && !(await isBusinessStaff(dbUser.id, business_id))) {
      return jsonError("Forbidden — only business staff can post", 403);
    }

    const insert: PostInsert = { business_id, author_id: dbUser.id, content };
    const post = await db.insertInto("post").values(insert).returning(POST_COLS).executeTakeFirstOrThrow();

    if (Array.isArray(images) && images.length) {
      const imageInserts: PostImageInsert[] = images.map(
        (img: { url: string; position?: number }, i: number) => ({
          post_id: post.id,
          url: img.url,
          position: img.position ?? i,
        }),
      );
      await db.insertInto("post_image").values(imageInserts).execute();
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

    if (dbUser.role !== "super_user" && existing.author_id !== dbUser.id) {
      return jsonError("Forbidden", 403);
    }

    const body = await req.json().catch(() => null);
    const { content, images } = body ?? {};

    const update: PostUpdate = {
      ...(content !== undefined && { content }),
      updated_at: new Date().toISOString(),
    };
    await db.updateTable("post").set(update).where("id", "=", id).execute();

    if (Array.isArray(images)) {
      await db.deleteFrom("post_image").where("post_id", "=", id).execute();
      if (images.length) {
        const imageInserts: PostImageInsert[] = images.map(
          (img: { url: string; position?: number }, i: number) => ({
            post_id: id,
            url: img.url,
            position: img.position ?? i,
          }),
        );
        await db.insertInto("post_image").values(imageInserts).execute();
      }
    }

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

    if (dbUser.role !== "super_user" && existing.author_id !== dbUser.id) {
      return jsonError("Forbidden", 403);
    }

    await db.deleteFrom("post").where("id", "=", id).execute();
    return new Response(null, { status: 204 });
  }

  return jsonError("Not found", 404);
});

function json(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

function jsonError(message: string, status: number): Response {
  return json({ error: message }, status);
}
