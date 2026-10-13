import { supabaseAdmin } from "../_shared/config.ts";
import { json, jsonError, requireAuth } from "../_shared/auth.ts";

// Uploads are proxied through this function using the service-role key — the
// Flutter app never talks to Supabase Storage directly, matching the rest of
// the backend's "all access control lives in the edge function" pattern.

const VALID_BUCKETS = ["avatars", "media"] as const;
type Bucket = (typeof VALID_BUCKETS)[number];

// Folder is a free-ish path segment used to group uploads within a bucket,
// e.g. "exercises", "recipes", "businesses", "shop-items", "posts". Keep it
// filesystem-safe.
const FOLDER_RE = /^[a-zA-Z0-9_-]{1,40}$/;

const EXT_BY_MIME: Record<string, string> = {
  "image/png": "png",
  "image/jpeg": "jpg",
  "image/webp": "webp",
};

// ── Handler ───────────────────────────────────────────────────────────────────

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") return jsonError("Not found", 404);

  const { user, error: authError } = await requireAuth(req);
  if (!user) return jsonError(authError ?? "Unauthorized", 401);

  const form = await req.formData().catch(() => null);
  if (!form) return jsonError("Expected multipart/form-data body", 400);

  const file = form.get("file");
  const bucket = form.get("bucket");
  const folder = form.get("folder");

  if (!(file instanceof File)) return jsonError("Missing file field", 400);
  if (typeof bucket !== "string" || !VALID_BUCKETS.includes(bucket as Bucket)) {
    return jsonError(`bucket must be one of: ${VALID_BUCKETS.join(", ")}`, 400);
  }
  if (folder !== null && (typeof folder !== "string" || !FOLDER_RE.test(folder))) {
    return jsonError("folder must be alphanumeric/-/_ and at most 40 chars", 400);
  }

  const ext = EXT_BY_MIME[file.type];
  if (!ext) return jsonError("Unsupported file type — use PNG, JPEG, or WEBP", 400);

  const maxBytes = bucket === "avatars" ? 5 * 1024 * 1024 : 10 * 1024 * 1024;
  if (file.size > maxBytes) return jsonError(`File too large — max ${maxBytes / 1024 / 1024}MB`, 400);

  const bytes = new Uint8Array(await file.arrayBuffer());
  const path = folder
    ? `${folder}/${crypto.randomUUID()}.${ext}`
    : `${crypto.randomUUID()}.${ext}`;

  const { error: uploadErr } = await supabaseAdmin.storage
    .from(bucket as Bucket)
    .upload(path, bytes, { contentType: file.type, upsert: false });

  if (uploadErr) return jsonError(uploadErr.message, 500);

  const { data: publicUrlData } = supabaseAdmin.storage
    .from(bucket as Bucket)
    .getPublicUrl(path);

  return json({ url: publicUrlData.publicUrl, bucket, path }, 201);
});
