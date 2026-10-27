import { db, supabaseAdmin } from "./config.ts";
import type { MediaBucket } from "../../types/schema/public.ts";

// Private media (chat attachments, personal post photos/videos).
//
// Upload: the API reserves a path (a media_upload row) and returns a signed
// upload URL; the client PUTs the bytes straight to Storage, so large videos
// never pass through a function. Only a path the caller reserved can then be
// attached to a message or post (claimUploads).
//
// Download: the buckets are private. The API signs short-lived URLs for
// people allowed to see the file.
//
// Signed URLs are returned *relative to the Supabase origin*
// (`/storage/v1/object/...`): inside the local edge runtime SUPABASE_URL is
// the Docker-internal Kong address, which phones can't reach. Clients
// prefix their own Supabase origin.

export const SIGNED_URL_TTL_SECONDS = 60 * 60 * 6;
export const MAX_UPLOAD_BYTES = 50 * 1024 * 1024;

const EXT_BY_MIME: Record<string, string> = {
  "image/jpeg": "jpg",
  "image/png": "png",
  "image/webp": "webp",
  "image/gif": "gif",
  "image/heic": "heic",
  "image/heif": "heif",
  "video/mp4": "mp4",
  "video/quicktime": "mov",
  "video/webm": "webm",
  "video/3gpp": "3gp",
  "audio/mpeg": "mp3",
  "audio/mp4": "m4a",
  "audio/aac": "aac",
  "audio/ogg": "ogg",
  "audio/wav": "wav",
  "application/pdf": "pdf",
  "application/zip": "zip",
  "text/plain": "txt",
  "text/csv": "csv",
};

const MIME_RE = /^[a-z0-9][a-z0-9!#$&^_.+-]{0,126}\/[a-z0-9][a-z0-9!#$&^_.+-]{0,126}$/;

/** Normalizes a client-sent MIME type; null when it isn't one. */
export function normalizeMime(value: unknown): string | null {
  if (typeof value !== "string") return null;
  const mime = value.split(";")[0].trim().toLowerCase();
  return MIME_RE.test(mime) ? mime : null;
}

export function mediaTypeOf(mime: string): "image" | "video" | "audio" | "file" {
  if (mime.startsWith("image/")) return "image";
  if (mime.startsWith("video/")) return "video";
  if (mime.startsWith("audio/")) return "audio";
  return "file";
}

/** File extension for a stored object: from the MIME type, else the file name. */
function extensionFor(mime: string, fileName: string | null): string {
  const known = EXT_BY_MIME[mime];
  if (known) return known;
  const fromName = fileName?.match(/\.([a-zA-Z0-9]{1,8})$/)?.[1]?.toLowerCase();
  return fromName ?? "bin";
}

function relativeUrl(absolute: string): string {
  const u = new URL(absolute);
  return `${u.pathname}${u.search}`;
}

export type UploadSlot = { path: string; upload_url: string; token: string; mime_type: string; expires_in: number };

/**
 * Reserves a path under `prefix` in `bucket` and returns a signed upload URL
 * (valid two hours, single object). `conversationId` is required for chat-media.
 */
export async function createUploadSlot(opts: {
  bucket: MediaBucket;
  prefix: string;
  uploaderId: string;
  mime: string;
  fileName: string | null;
  conversationId?: string;
}): Promise<UploadSlot> {
  const path = `${opts.prefix}/${crypto.randomUUID()}.${extensionFor(opts.mime, opts.fileName)}`;
  const { data, error } = await supabaseAdmin.storage.from(opts.bucket).createSignedUploadUrl(path);
  if (error || !data) throw new Error(`Could not create upload URL: ${error?.message ?? "unknown error"}`);
  await db.insertInto("media_upload").values({
    storage_path: path,
    bucket: opts.bucket,
    uploader_id: opts.uploaderId,
    conversation_id: opts.conversationId ?? null,
    mime_type: opts.mime,
  }).execute();
  return { path, upload_url: relativeUrl(data.signedUrl), token: data.token, mime_type: opts.mime, expires_in: 7200 };
}

/**
 * Checks that every path was reserved by `uploaderId` (for `conversationId`,
 * in chat), is unclaimed and was actually uploaded. Returns an error message,
 * or null when all are fine. Call markClaimed() once the row using them exists.
 */
export async function verifyUploads(opts: {
  bucket: MediaBucket;
  paths: string[];
  uploaderId: string;
  conversationId?: string;
}): Promise<{ error: string } | { mimeByPath: Map<string, string> }> {
  if (opts.paths.length === 0) return { mimeByPath: new Map() };
  if (new Set(opts.paths).size !== opts.paths.length) return { error: "Duplicate attachment path" };
  let q = db.selectFrom("media_upload")
    .select(["storage_path", "mime_type", "claimed_at", "conversation_id"])
    .where("bucket", "=", opts.bucket)
    .where("uploader_id", "=", opts.uploaderId)
    .where("storage_path", "in", opts.paths);
  if (opts.conversationId) q = q.where("conversation_id", "=", opts.conversationId);
  const rows = await q.execute();
  if (rows.length !== opts.paths.length) return { error: "Unknown upload — request an upload URL first" };
  if (rows.some((r) => r.claimed_at)) return { error: "Upload already used" };

  for (const path of opts.paths) {
    const slash = path.lastIndexOf("/");
    const { data, error } = await supabaseAdmin.storage.from(opts.bucket).list(path.slice(0, slash), {
      search: path.slice(slash + 1),
      limit: 1,
    });
    if (error || !data?.some((o) => o.name === path.slice(slash + 1))) {
      return { error: "Upload not finished — the file isn't in storage yet" };
    }
  }
  return { mimeByPath: new Map(rows.map((r) => [r.storage_path, r.mime_type])) };
}

export async function markClaimed(bucket: MediaBucket, paths: string[]): Promise<void> {
  if (paths.length === 0) return;
  await db.updateTable("media_upload")
    .set({ claimed_at: new Date().toISOString() })
    .where("bucket", "=", bucket)
    .where("storage_path", "in", paths)
    .execute();
}

/** Signs many paths at once; missing ones map to null. */
export async function signPaths(bucket: MediaBucket, paths: string[]): Promise<Map<string, string | null>> {
  const out = new Map<string, string | null>();
  const unique = [...new Set(paths)];
  if (unique.length === 0) return out;
  const { data, error } = await supabaseAdmin.storage.from(bucket).createSignedUrls(unique, SIGNED_URL_TTL_SECONDS);
  if (error) {
    console.error("signing failed", bucket, error.message);
    for (const p of unique) out.set(p, null);
    return out;
  }
  for (const row of data ?? []) {
    if (row.path) out.set(row.path, row.signedUrl ? relativeUrl(row.signedUrl) : null);
  }
  return out;
}

/** Deletes objects; errors are logged, not thrown. */
export async function removeObjects(bucket: MediaBucket, paths: string[]): Promise<void> {
  if (paths.length === 0) return;
  const { error } = await supabaseAdmin.storage.from(bucket).remove(paths);
  if (error) console.error("storage remove failed", bucket, error.message);
}
