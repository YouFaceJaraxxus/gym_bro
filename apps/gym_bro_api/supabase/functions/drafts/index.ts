import { sql } from "npm:kysely@^0.27";
import { db } from "../_shared/config.ts";
import { json, jsonError, requireCaller } from "../_shared/auth.ts";
import { removeObjects, signPaths } from "../_shared/media.ts";
import type { DraftKind, DraftTable } from "../../types/schema/public.ts";

// Drafts: unfinished posts, exercises, trainings, … saved when their author
// leaves a create screen. A draft is private to its author — every route only
// ever touches the caller's own rows. The app publishes a draft through the
// kind's usual create endpoint, then deletes it.
//
// Photos/videos on a draft were uploaded through POST /posts/uploads. Saving
// a draft holds those slots (media_upload.draft_id) so the daily sweep leaves
// them be while they stay unclaimed — a post published from the draft can
// still claim them. Media dropped from a draft, or left on a deleted draft,
// is removed unless a post claimed it.
//
//   GET    /drafts?kind=&scope_id=     the caller's drafts of a kind, newest first
//   GET    /drafts/:id                 one draft, media with signed URLs
//   POST   /drafts {kind, scope_id?, title?, thumbnail_url?, data, media?}
//   PUT    /drafts/:id {title?, thumbnail_url?, data, media?}
//   DELETE /drafts/:id

const KINDS: readonly DraftKind[] = [
  "post", "business_post", "exercise", "training", "routine",
  "recipe", "food_item", "daily_meal_plan", "meal_plan",
];
const BUCKET = "user-media" as const;
const MAX_DRAFTS_PER_KIND = 50;
const MAX_DATA_CHARS = 200_000;
const MAX_MEDIA = 10;
const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

const COLS = ["id", "kind", "scope_id", "title", "thumbnail_url", "data", "media", "created_at", "updated_at"] as const;

type DraftRow = Pick<DraftTable, "kind" | "scope_id" | "title" | "thumbnail_url"> & {
  id: string;
  data: unknown;
  media: unknown;
  created_at: string;
  updated_at: string;
};

type DraftMedia = {
  path: string;
  mime_type: string;
  file_name: string | null;
  size_bytes: number | null;
  width: number | null;
  height: number | null;
  duration_ms: number | null;
  edit: Record<string, unknown> | null;
};

function parseRoute(pathname: string): { kind: "collection" } | { kind: "item"; id: string } | null {
  if (/^\/drafts\/?$/.test(pathname)) return { kind: "collection" };
  const m = pathname.match(/^\/drafts\/([^/]+)\/?$/);
  return m ? { kind: "item", id: m[1] } : null;
}

const int = (v: unknown) => (Number.isFinite(Number(v)) && Number(v) >= 0 ? Math.round(Number(v)) : null);

function optionalText(value: unknown, max: number): string | null | { error: string } {
  if (value === undefined || value === null) return null;
  if (typeof value !== "string") return { error: "must be a string" };
  const t = value.trim();
  if (t.length > max) return { error: `is limited to ${max} characters` };
  return t || null;
}

/** Validates the media list shape (MIME types are filled in by verifyDraftMedia). */
function parseMedia(value: unknown): DraftMedia[] | { error: string } {
  if (value === undefined || value === null) return [];
  if (!Array.isArray(value)) return { error: "media must be an array" };
  if (value.length > MAX_MEDIA) return { error: `Up to ${MAX_MEDIA} photos/videos per draft` };
  const out: DraftMedia[] = [];
  for (const m of value) {
    if (typeof m?.path !== "string" || !m.path) return { error: "Each media item needs a path" };
    const edit = m.edit && typeof m.edit === "object" && !Array.isArray(m.edit) ? m.edit : null;
    out.push({
      path: m.path,
      mime_type: "",
      file_name: typeof m.file_name === "string" ? m.file_name.slice(0, 255) : null,
      size_bytes: int(m.size_bytes),
      width: int(m.width),
      height: int(m.height),
      duration_ms: int(m.duration_ms),
      edit,
    });
  }
  if (new Set(out.map((m) => m.path)).size !== out.length) return { error: "Duplicate media path" };
  return out;
}

/**
 * Checks the paths are the caller's own unclaimed uploads, free or already
 * held by this draft, and fills in their MIME types.
 */
async function verifyDraftMedia(callerId: string, media: DraftMedia[], draftId: string | null): Promise<string | null> {
  if (media.length === 0) return null;
  const rows = await db.selectFrom("media_upload")
    .select(["storage_path", "mime_type", "claimed_at", "draft_id"])
    .where("bucket", "=", BUCKET)
    .where("uploader_id", "=", callerId)
    .where("storage_path", "in", media.map((m) => m.path))
    .execute();
  const byPath = new Map(rows.map((r) => [r.storage_path, r]));
  for (const m of media) {
    const row = byPath.get(m.path);
    if (!row) return "Unknown upload — request an upload URL first";
    if (row.claimed_at) return "Upload already used";
    if (row.draft_id && row.draft_id !== draftId) return "Upload belongs to another draft";
    m.mime_type = row.mime_type;
  }
  return null;
}

/** Deletes a draft's unclaimed uploads that aren't in `keep` (files and slots). */
async function releaseMedia(draftId: string, keep: string[]): Promise<void> {
  let q = db.deleteFrom("media_upload")
    .where("bucket", "=", BUCKET)
    .where("draft_id", "=", draftId)
    .where("claimed_at", "is", null);
  if (keep.length) q = q.where("storage_path", "not in", keep);
  const removed = await q.returning("storage_path").execute();
  await removeObjects(BUCKET, removed.map((r) => r.storage_path));
}

/** Summary for lists: no data, a signed thumbnail for the first photo. */
async function summarize(rows: DraftRow[]) {
  const firstImage = (r: DraftRow) =>
    (r.media as DraftMedia[]).find((m) => m.mime_type.startsWith("image/"))?.path ?? null;
  const signed = await signPaths(BUCKET, rows.map(firstImage).filter((p): p is string => !!p));
  return rows.map((r) => {
    const media = r.media as DraftMedia[];
    const path = firstImage(r);
    return {
      id: r.id,
      kind: r.kind,
      scope_id: r.scope_id,
      title: r.title,
      thumbnail_url: (path ? signed.get(path) : null) ?? r.thumbnail_url,
      media_count: media.length,
      has_video: media.some((m) => m.mime_type.startsWith("video/")),
      created_at: r.created_at,
      updated_at: r.updated_at,
    };
  });
}

async function full(row: DraftRow) {
  const media = row.media as DraftMedia[];
  const signed = await signPaths(BUCKET, media.map((m) => m.path));
  const [summary] = await summarize([row]);
  return { ...summary, data: row.data, media: media.map((m) => ({ ...m, url: signed.get(m.path) ?? null })) };
}

Deno.serve(async (req: Request) => {
  const url = new URL(req.url);
  const route = parseRoute(url.pathname);
  if (!route) return jsonError("Not found", 404);

  const { caller, response } = await requireCaller(req);
  if (!caller) return response;

  // ── GET /drafts?kind=&scope_id= ─────────────────────────────────────────────
  if (req.method === "GET" && route.kind === "collection") {
    const kind = url.searchParams.get("kind") as DraftKind | null;
    if (kind && !KINDS.includes(kind)) return jsonError(`kind must be one of: ${KINDS.join(", ")}`, 400);
    const scope = url.searchParams.get("scope_id");
    if (scope && !UUID_RE.test(scope)) return jsonError("scope_id must be a UUID", 400);
    let q = db.selectFrom("draft").select(COLS).where("user_id", "=", caller.id);
    if (kind) q = q.where("kind", "=", kind);
    if (scope) q = q.where("scope_id", "=", scope);
    const rows = await q.orderBy("updated_at", "desc").limit(200).execute();
    return json(await summarize(rows as DraftRow[]));
  }

  // ── POST /drafts ────────────────────────────────────────────────────────────
  if (req.method === "POST" && route.kind === "collection") {
    const body = await req.json().catch(() => null);
    const kind = body?.kind as DraftKind;
    if (!KINDS.includes(kind)) return jsonError(`kind must be one of: ${KINDS.join(", ")}`, 400);
    const scopeId = body?.scope_id ?? null;
    if (scopeId !== null && (typeof scopeId !== "string" || !UUID_RE.test(scopeId))) {
      return jsonError("scope_id must be a UUID", 400);
    }
    const fields = parseFields(body);
    if ("error" in fields) return jsonError(fields.error, 400);
    const media = parseMedia(body?.media);
    if ("error" in media) return jsonError(media.error, 400);
    const mediaError = await verifyDraftMedia(caller.id, media, null);
    if (mediaError) return jsonError(mediaError, 400);

    const { count } = await db.selectFrom("draft").select(db.fn.countAll<number>().as("count"))
      .where("user_id", "=", caller.id).where("kind", "=", kind).executeTakeFirstOrThrow();
    if (Number(count) >= MAX_DRAFTS_PER_KIND) {
      return jsonError(`You can keep up to ${MAX_DRAFTS_PER_KIND} drafts of each kind — delete some first`, 409);
    }

    const row = await db.transaction().execute(async (trx) => {
      const created = await trx.insertInto("draft").values({
        user_id: caller.id,
        kind,
        scope_id: scopeId,
        title: fields.title,
        thumbnail_url: fields.thumbnail_url,
        data: sql`${JSON.stringify(fields.data)}::jsonb`,
        media: sql`${JSON.stringify(media)}::jsonb`,
      }).returning(COLS).executeTakeFirstOrThrow();
      if (media.length) {
        await trx.updateTable("media_upload").set({ draft_id: created.id })
          .where("bucket", "=", BUCKET).where("storage_path", "in", media.map((m) => m.path)).execute();
      }
      return created;
    });
    return json(await full(row as DraftRow), 201);
  }

  if (route.kind !== "item") return jsonError("Not found", 404);
  if (!UUID_RE.test(route.id)) return jsonError("Draft not found", 404);
  const existing = await db.selectFrom("draft").select(COLS)
    .where("id", "=", route.id).where("user_id", "=", caller.id).executeTakeFirst() as DraftRow | undefined;
  if (!existing) return jsonError("Draft not found", 404);

  // ── GET /drafts/:id ─────────────────────────────────────────────────────────
  if (req.method === "GET") return json(await full(existing));

  // ── PUT /drafts/:id ─────────────────────────────────────────────────────────
  // Replaces data and media; uploads dropped from the draft are deleted.
  if (req.method === "PUT") {
    const body = await req.json().catch(() => null);
    const fields = parseFields(body);
    if ("error" in fields) return jsonError(fields.error, 400);
    const media = parseMedia(body?.media);
    if ("error" in media) return jsonError(media.error, 400);
    const mediaError = await verifyDraftMedia(caller.id, media, existing.id);
    if (mediaError) return jsonError(mediaError, 400);

    const row = await db.transaction().execute(async (trx) => {
      const updated = await trx.updateTable("draft").set({
        title: fields.title,
        thumbnail_url: fields.thumbnail_url,
        data: sql`${JSON.stringify(fields.data)}::jsonb`,
        media: sql`${JSON.stringify(media)}::jsonb`,
        updated_at: new Date().toISOString(),
      }).where("id", "=", existing.id).returning(COLS).executeTakeFirstOrThrow();
      if (media.length) {
        await trx.updateTable("media_upload").set({ draft_id: existing.id })
          .where("bucket", "=", BUCKET).where("storage_path", "in", media.map((m) => m.path)).execute();
      }
      return updated;
    });
    await releaseMedia(existing.id, media.map((m) => m.path));
    return json(await full(row as DraftRow));
  }

  // ── DELETE /drafts/:id ──────────────────────────────────────────────────────
  // Media a post published from the draft claimed stays; the rest goes.
  if (req.method === "DELETE") {
    await releaseMedia(existing.id, []);
    await db.deleteFrom("draft").where("id", "=", existing.id).execute();
    return new Response(null, { status: 204 });
  }

  return jsonError("Not found", 404);
});

function parseFields(body: unknown):
  | { title: string | null; thumbnail_url: string | null; data: Record<string, unknown> }
  | { error: string } {
  const b = (body ?? {}) as Record<string, unknown>;
  const title = optionalText(b.title, 200);
  if (title && typeof title === "object") return { error: `title ${title.error}` };
  const thumb = optionalText(b.thumbnail_url, 2048);
  if (thumb && typeof thumb === "object") return { error: `thumbnail_url ${thumb.error}` };
  if (typeof thumb === "string" && !/^https?:\/\//.test(thumb)) return { error: "thumbnail_url must be an http(s) URL" };
  const data = b.data ?? {};
  if (typeof data !== "object" || Array.isArray(data)) return { error: "data must be an object" };
  if (JSON.stringify(data).length > MAX_DATA_CHARS) return { error: "Draft is too large" };
  return { title, thumbnail_url: thumb, data: data as Record<string, unknown> };
}
