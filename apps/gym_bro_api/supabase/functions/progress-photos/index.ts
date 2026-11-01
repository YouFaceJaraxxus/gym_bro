import { sql } from "npm:kysely@^0.27";
import { db } from "../_shared/config.ts";
import { forbidden, json, jsonError, requireCaller } from "../_shared/auth.ts";
import { createUploadSlot, markClaimed, normalizeMime, removeObjects, signPaths, verifyUploads } from "../_shared/media.ts";
import type { ProgressPhotoPose } from "../../types/schema/public.ts";

// Private progress photos (before/after). Strictly owner-only: there is no
// ?user_id= read path for coaches or super users, and the photos never reach
// feeds. Files live in the private `progress-photos` bucket under <user_id>/;
// list responses carry short-lived signed URLs (relative to the Supabase
// origin, see _shared/media.ts).
//
//   GET    /progress-photos?pose=&from=&to=   mine, newest first, with `url`
//   POST   /progress-photos/uploads           {mime_type, size_bytes, file_name?} → upload slot
//   POST   /progress-photos                   {path, pose?, taken_on?, weight_kg?, note?}
//                                             weight_kg omitted → nearest weigh-in within 7 days
//   PUT    /progress-photos/:id               {pose?, taken_on?, weight_kg?, note?}
//   DELETE /progress-photos/:id               also deletes the stored file
//
// Row shape: { id, user_id, pose, taken_on: 'YYYY-MM-DD', weight_kg: number|null,
//              note, created_at, url: string|null }

const BUCKET = "progress-photos" as const;
const POSES: ProgressPhotoPose[] = ["front", "side", "back", "other"];
const MAX_PHOTO_BYTES = 20 * 1024 * 1024;
const NOTE_MAX = 500;
/** How far from taken_on a weigh-in may be to become the photo's weight. */
const SNAPSHOT_DAYS = 7;
const LIST_LIMIT = 500;

const DATE_RE = /^\d{4}-\d{2}-\d{2}$/;
const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

const COLS = [
  "id",
  "user_id",
  "path",
  "pose",
  sql<string>`to_char(taken_on, 'YYYY-MM-DD')`.as("taken_on"),
  sql<number | null>`weight_kg::float8`.as("weight_kg"),
  "note",
  "created_at",
] as const;

type Row = {
  id: string;
  user_id: string;
  path: string;
  pose: ProgressPhotoPose;
  taken_on: string;
  weight_kg: number | null;
  note: string | null;
  created_at: string;
};

/** Adds signed URLs and drops the storage path. */
async function decorate(rows: Row[]) {
  const urls = await signPaths(BUCKET, rows.map((r) => r.path));
  return rows.map(({ path, ...r }) => ({ ...r, url: urls.get(path) ?? null }));
}

// ── Validation ────────────────────────────────────────────────────────────────

type Fields = { pose?: ProgressPhotoPose; taken_on?: string; weight_kg?: number | null; note?: string | null };

function readFields(body: Record<string, unknown>): { fields: Fields; error?: string } {
  const fields: Fields = {};
  if (body.pose !== undefined) {
    if (!POSES.includes(body.pose as ProgressPhotoPose)) return { fields, error: `pose must be one of: ${POSES.join(", ")}` };
    fields.pose = body.pose as ProgressPhotoPose;
  }
  if (body.taken_on !== undefined) {
    if (typeof body.taken_on !== "string" || !DATE_RE.test(body.taken_on)) {
      return { fields, error: "taken_on must be YYYY-MM-DD" };
    }
    fields.taken_on = body.taken_on;
  }
  if (body.weight_kg !== undefined) {
    const v = body.weight_kg;
    if (v === null || v === "") fields.weight_kg = null;
    else {
      const n = typeof v === "number" ? v : Number(v);
      if (!Number.isFinite(n) || n <= 0 || n >= 1000) return { fields, error: "weight_kg must be a positive number" };
      fields.weight_kg = Math.round(n * 100) / 100;
    }
  }
  if (body.note !== undefined) {
    const note = typeof body.note === "string" ? body.note.trim() : "";
    if (note.length > NOTE_MAX) return { fields, error: `note is limited to ${NOTE_MAX} characters` };
    fields.note = note || null;
  }
  return { fields };
}

function pgErrorResponse(e: unknown): Response {
  const err = e as { code?: string; message?: string; detail?: string } | null;
  switch (err?.code) {
    case "23505":
      return jsonError("That upload is already a photo", 409);
    case "23514":
    case "23502":
    case "22P02":
    case "22003":
    case "22007":
    case "22008":
      return jsonError(err.message ?? "Invalid value", 400);
  }
  throw e;
}

/** My photo by id, or null (someone else's photo is "not found" too). */
async function ownPhoto(id: string, me: string): Promise<Row | null> {
  if (!UUID_RE.test(id)) return null;
  const row = await db.selectFrom("progress_photo").select(COLS)
    .where("id", "=", id).where("user_id", "=", me).executeTakeFirst();
  return (row as Row | undefined) ?? null;
}

// ── Handler ───────────────────────────────────────────────────────────────────

async function handler(req: Request): Promise<Response> {
  const { caller, response } = await requireCaller(req);
  if (!caller) return response;
  const me = caller.id;
  const url = new URL(req.url);
  const parts = url.pathname.replace(/^\/progress-photos\/?/, "").split("/").filter(Boolean);

  // ── GET /progress-photos ─────────────────────────────────────────────────────
  if (req.method === "GET" && parts.length === 0) {
    const userId = url.searchParams.get("user_id");
    // Nobody else — coaches and super users included — reads these.
    if (userId && userId !== me) return forbidden();
    const pose = url.searchParams.get("pose");
    if (pose && !POSES.includes(pose as ProgressPhotoPose)) {
      return jsonError(`pose must be one of: ${POSES.join(", ")}`, 400);
    }
    const from = url.searchParams.get("from");
    const to = url.searchParams.get("to");
    if ((from && !DATE_RE.test(from)) || (to && !DATE_RE.test(to))) {
      return jsonError("from/to must be YYYY-MM-DD", 400);
    }
    const rows = await db.selectFrom("progress_photo").select(COLS)
      .where("user_id", "=", me)
      .$if(!!pose, (q) => q.where("pose", "=", pose as ProgressPhotoPose))
      .$if(!!from, (q) => q.where("taken_on", ">=", from!))
      .$if(!!to, (q) => q.where("taken_on", "<=", to!))
      .orderBy("taken_on", "desc").orderBy("created_at", "desc")
      .limit(LIST_LIMIT)
      .execute();
    return json(await decorate(rows as Row[]));
  }

  // ── POST /progress-photos/uploads ────────────────────────────────────────────
  if (req.method === "POST" && parts.length === 1 && parts[0] === "uploads") {
    const body = await req.json().catch(() => null);
    const mime = normalizeMime(body?.mime_type);
    if (!mime || !mime.startsWith("image/")) return jsonError("Progress photos must be images (image/*)", 400);
    const size = Number(body?.size_bytes);
    if (!Number.isFinite(size) || size <= 0) return jsonError("size_bytes is required", 400);
    if (size > MAX_PHOTO_BYTES) return jsonError(`Photos are limited to ${MAX_PHOTO_BYTES / 1024 / 1024} MB`, 413);
    const slot = await createUploadSlot({
      bucket: BUCKET,
      prefix: me,
      uploaderId: me,
      mime,
      fileName: typeof body?.file_name === "string" ? body.file_name : null,
    });
    return json(slot, 201);
  }

  // ── POST /progress-photos ────────────────────────────────────────────────────
  if (req.method === "POST" && parts.length === 0) {
    const body = await req.json().catch(() => null);
    if (!body || typeof body !== "object" || Array.isArray(body)) return jsonError("Body must be an object", 400);
    if (typeof body.path !== "string" || !body.path) return jsonError("path is required", 400);
    const { fields, error } = readFields(body);
    if (error) return jsonError(error, 400);

    const verified = await verifyUploads({ bucket: BUCKET, paths: [body.path], uploaderId: me });
    if ("error" in verified) return jsonError(verified.error, 400);

    let weight = fields.weight_kg;
    if (weight === undefined) {
      const day = fields.taken_on ?? null;
      const near = await db.selectFrom("body_measurement")
        .select(sql<number>`weight_kg::float8`.as("w"))
        .where("user_id", "=", me)
        .where("weight_kg", "is not", null)
        .where(sql<boolean>`abs(measured_on - COALESCE(${day}::date, CURRENT_DATE)) <= ${SNAPSHOT_DAYS}`)
        .orderBy(sql`abs(measured_on - COALESCE(${day}::date, CURRENT_DATE))`)
        .orderBy("measured_on", "desc")
        .limit(1)
        .executeTakeFirst();
      weight = near?.w ?? null;
    }

    const row = await db.insertInto("progress_photo").values({
      user_id: me,
      path: body.path,
      pose: fields.pose ?? "front",
      weight_kg: weight,
      note: fields.note ?? null,
      ...(fields.taken_on && { taken_on: fields.taken_on }),
    }).returning(COLS).executeTakeFirstOrThrow();
    await markClaimed(BUCKET, [body.path]);
    const [out] = await decorate([row as Row]);
    return json(out, 201);
  }

  // ── PUT /progress-photos/:id ─────────────────────────────────────────────────
  if (req.method === "PUT" && parts.length === 1) {
    const existing = await ownPhoto(parts[0], me);
    if (!existing) return jsonError("Photo not found", 404);
    const body = await req.json().catch(() => null);
    if (!body || typeof body !== "object" || Array.isArray(body)) return jsonError("Body must be an object", 400);
    const { fields, error } = readFields(body);
    if (error) return jsonError(error, 400);
    if (!Object.keys(fields).length) return jsonError("Nothing to update", 400);
    const row = await db.updateTable("progress_photo").set(fields)
      .where("id", "=", existing.id).returning(COLS).executeTakeFirstOrThrow();
    const [out] = await decorate([row as Row]);
    return json(out);
  }

  // ── DELETE /progress-photos/:id ──────────────────────────────────────────────
  if (req.method === "DELETE" && parts.length === 1) {
    const existing = await ownPhoto(parts[0], me);
    if (!existing) return jsonError("Photo not found", 404);
    await db.deleteFrom("progress_photo").where("id", "=", existing.id).execute();
    await db.deleteFrom("media_upload").where("bucket", "=", BUCKET).where("storage_path", "=", existing.path).execute();
    await removeObjects(BUCKET, [existing.path]);
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
