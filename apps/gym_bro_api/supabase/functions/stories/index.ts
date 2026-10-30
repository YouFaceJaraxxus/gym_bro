import { sql } from "npm:kysely@^0.27";
import { db } from "../_shared/config.ts";
import { type Caller, forbidden, isSuperUser, json, jsonError, requireCaller } from "../_shared/auth.ts";
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
  displayName,
  isReaction,
  parsePaging,
  REACTION_EMOJI,
  REACTIONS,
  userSummaries,
} from "../_shared/social.ts";
import { prepareShare, resolveShares, type StoredShare, STORY_SHARE_KINDS, type StoryShareKind } from "../_shared/shares.ts";
import { storyVisibleSql } from "../_shared/visibility.ts";
import type { ReactionType } from "../../types/schema/public.ts";

// Stories, Instagram-style. A story is a photo/video, a text card on a
// background colour, or something shared (a post, a logged workout or meal,
// a library item, a product — never a person). It's live for 24 hours for
// the author's audience (see storyVisibleSql), then stays in the author's
// archive. Viewers are recorded; the author sees who watched and who liked
// it. Likes/reactions (10 types, one per person) notify the author. Replies
// and quick emoji reactions go to the author's DMs — POST /chat/story-replies.
//
//   GET    /stories/feed                        tray: me first, then people I follow with live stories (unseen first)
//   GET    /stories?user_id=                    someone's live stories I can see, oldest first
//   GET    /stories/archive?from=&to=           my stories, live and expired (created in [from, to)), newest first
//   GET    /stories/:id                         one story (its author: always)
//   POST   /stories/uploads {mime_type, size_bytes}   signed upload URL for a photo/video
//   POST   /stories {media?: {path, width?, height?, duration_ms?}, caption?, background?, share?: {kind, ref_id | meal}}
//   DELETE /stories/:id
//   POST   /stories/:id/view                    I watched it
//   PUT    /stories/:id/reaction {reaction}, DELETE   (POST|DELETE /stories/:id/like = 'like')
//   GET    /stories/:id/viewers                 the author: who watched, with their reactions

const BUCKET = "user-media" as const;
const CAPTION_MAX = 500;
const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const HEX_RE = /^#[0-9a-fA-F]{6}$/;

const STORY_COLS = [
  "id",
  "author_id",
  "storage_path",
  "media_type",
  "mime_type",
  "width",
  "height",
  "duration_ms",
  "caption",
  "background",
  "share_kind",
  "share_ref_id",
  "share_snapshot",
  "created_at",
  "expires_at",
] as const;

type StoryRow = {
  id: string;
  author_id: string;
  storage_path: string | null;
  media_type: "image" | "video" | null;
  mime_type: string | null;
  width: number | null;
  height: number | null;
  duration_ms: number | null;
  caption: string | null;
  background: string | null;
  share_kind: StoryShareKind | null;
  share_ref_id: string | null;
  share_snapshot: unknown;
  created_at: string;
  expires_at: string;
};

// ── Path parsing ──────────────────────────────────────────────────────────────

type Route =
  | { kind: "collection" }
  | { kind: "feed" }
  | { kind: "archive" }
  | { kind: "uploads" }
  | { kind: "story"; id: string }
  | { kind: "view"; id: string }
  | { kind: "reaction"; id: string }
  | { kind: "like"; id: string }
  | { kind: "viewers"; id: string }
  | { kind: "unknown" };

function parsePath(pathname: string): Route {
  const p = pathname.replace(/\/+$/, "");
  if (p === "/stories") return { kind: "collection" };
  if (p === "/stories/feed") return { kind: "feed" };
  if (p === "/stories/archive") return { kind: "archive" };
  if (p === "/stories/uploads") return { kind: "uploads" };
  const m = p.match(/^\/stories\/([^/]+)(?:\/(view|reaction|like|viewers))?$/);
  if (!m) return { kind: "unknown" };
  return m[2] ? { kind: m[2] as "view", id: m[1] } : { kind: "story", id: m[1] };
}

// ── Loading & decoration ──────────────────────────────────────────────────────

async function loadVisibleStory(id: string, viewer: Caller): Promise<StoryRow | null> {
  if (!UUID_RE.test(id)) return null;
  const row = await db.selectFrom("story").select(STORY_COLS).where("id", "=", id)
    .where(storyVisibleSql(viewer.id)).executeTakeFirst();
  return row ?? null;
}

const isLive = (s: { expires_at: string }) => new Date(s.expires_at).getTime() > Date.now();

/**
 * Signed media, author, the shared thing as the viewer may see it, whether
 * I've seen it and my reaction; for the author also view and reaction counts.
 */
async function decorateStories(rows: StoryRow[], viewer: Caller) {
  if (!rows.length) return [];
  const ids = rows.map((r) => r.id);
  const own = rows.filter((r) => r.author_id === viewer.id).map((r) => r.id);
  const shared = rows.filter((r) => r.share_kind);
  const [signed, authors, seen, mine, views, reactions, previews] = await Promise.all([
    signPaths(BUCKET, rows.flatMap((r) => (r.storage_path ? [r.storage_path] : []))),
    userSummaries(rows.map((r) => r.author_id)),
    db.selectFrom("story_view").select("story_id").where("story_id", "in", ids).where("viewer_id", "=", viewer.id)
      .execute(),
    db.selectFrom("story_reaction").select(["story_id", "reaction"]).where("story_id", "in", ids)
      .where("user_id", "=", viewer.id).execute(),
    own.length
      ? db.selectFrom("story_view").select(["story_id", sql<number>`count(*)::int`.as("n")])
        .where("story_id", "in", own).groupBy("story_id").execute()
      : Promise.resolve([]),
    own.length
      ? db.selectFrom("story_reaction").select(["story_id", sql<number>`count(*)::int`.as("n")])
        .where("story_id", "in", own).groupBy("story_id").execute()
      : Promise.resolve([]),
    resolveShares(viewer, shared.map((r): StoredShare => ({
      kind: r.share_kind!,
      ref_id: r.share_ref_id,
      snapshot: r.share_snapshot,
    }))),
  ]);
  const seenSet = new Set(seen.map((s) => s.story_id));
  const myReaction = new Map(mine.map((r) => [r.story_id, r.reaction]));
  const viewCount = new Map(views.map((v) => [v.story_id, v.n]));
  const reactionCount = new Map(reactions.map((v) => [v.story_id, v.n]));
  const previewById = new Map(shared.map((r, i) => [r.id, previews[i]]));
  return rows.map((r) => {
    const { storage_path, share_snapshot: _snapshot, ...rest } = r;
    const mineStory = r.author_id === viewer.id;
    return {
      ...rest,
      media_url: storage_path ? signed.get(storage_path) ?? null : null,
      author: authors[r.author_id] ?? null,
      share: previewById.get(r.id) ?? null,
      is_live: isLive(r),
      seen: mineStory || seenSet.has(r.id),
      my_reaction: myReaction.get(r.id) ?? null,
      liked: myReaction.has(r.id),
      is_mine: mineStory,
      view_count: mineStory ? viewCount.get(r.id) ?? 0 : null,
      reaction_count: mineStory ? reactionCount.get(r.id) ?? 0 : null,
    };
  });
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

// ── Handler ───────────────────────────────────────────────────────────────────

async function handler(req: Request): Promise<Response> {
  const url = new URL(req.url);
  const route = parsePath(url.pathname);
  if (route.kind === "unknown") return jsonError("Not found", 404);

  const { caller, response } = await requireCaller(req);
  if (!caller) return response;
  const me = caller.id;

  // ── GET /stories/feed — the tray ─────────────────────────────────────────────
  // One entry per person: me first (when I have live stories), then the people
  // I follow — those with stories I haven't seen first, newest first.
  if (req.method === "GET" && route.kind === "feed") {
    const { rows } = await sql<{
      author_id: string;
      story_count: number;
      unseen_count: number;
      latest_at: string;
    }>`
      SELECT story.author_id,
             count(*)::int AS story_count,
             count(*) FILTER (WHERE story.author_id <> ${me} AND NOT EXISTS (
               SELECT 1 FROM story_view v WHERE v.story_id = story.id AND v.viewer_id = ${me}))::int AS unseen_count,
             max(story.created_at) AS latest_at
        FROM story
       WHERE story.expires_at > NOW()
         AND (story.author_id = ${me} OR story.author_id IN (
               SELECT followee_id FROM follow WHERE follower_id = ${me} AND status = 'accepted'))
         AND ${storyVisibleSql(me)}
       GROUP BY story.author_id
       ORDER BY (story.author_id = ${me}) DESC, (count(*) FILTER (WHERE NOT EXISTS (
               SELECT 1 FROM story_view v WHERE v.story_id = story.id AND v.viewer_id = ${me})) > 0) DESC,
                max(story.created_at) DESC
       LIMIT 150
    `.execute(db);
    const people = await userSummaries(rows.map((r) => r.author_id));
    return json(rows.filter((r) => people[r.author_id]).map((r) => ({
      user: people[r.author_id],
      is_me: r.author_id === me,
      story_count: r.story_count,
      unseen_count: r.unseen_count,
      has_unseen: r.unseen_count > 0,
      latest_at: r.latest_at,
    })));
  }

  // ── GET /stories?user_id= — someone's live stories ───────────────────────────
  if (req.method === "GET" && route.kind === "collection") {
    const userId = url.searchParams.get("user_id") ?? me;
    if (!UUID_RE.test(userId)) return jsonError("User not found", 404);
    const rows = await db.selectFrom("story").select(STORY_COLS)
      .where("author_id", "=", userId).where("expires_at", ">", sql<string>`NOW()`)
      .where(storyVisibleSql(me))
      .orderBy("created_at", "asc").orderBy("id", "asc").limit(100).execute();
    return json(await decorateStories(rows, caller));
  }

  // ── GET /stories/archive?from=&to= — all my stories ──────────────────────────
  if (req.method === "GET" && route.kind === "archive") {
    const range = parseRange(url);
    if (range instanceof Response) return range;
    const { page, pageSize } = parsePaging(url, 100, 500);
    const rows = await db.selectFrom("story").select(STORY_COLS).where("author_id", "=", me)
      .$if(!!range.from, (q) => q.where("created_at", ">=", range.from!))
      .$if(!!range.to, (q) => q.where("created_at", "<", range.to!))
      .orderBy("created_at", "desc").orderBy("id", "desc").limit(pageSize).offset(page * pageSize).execute();
    return json(await decorateStories(rows, caller));
  }

  // ── POST /stories/uploads ────────────────────────────────────────────────────
  if (req.method === "POST" && route.kind === "uploads") {
    const body = await req.json().catch(() => null);
    const mime = normalizeMime(body?.mime_type);
    if (!mime || !(mime.startsWith("image/") || mime.startsWith("video/"))) {
      return jsonError("Stories take photos and videos (image/* or video/*)", 400);
    }
    const size = Number(body?.size_bytes);
    if (!Number.isFinite(size) || size <= 0) return jsonError("size_bytes is required", 400);
    if (size > MAX_UPLOAD_BYTES) return jsonError(`Files are limited to ${MAX_UPLOAD_BYTES / 1024 / 1024} MB`, 413);
    const slot = await createUploadSlot({
      bucket: BUCKET,
      prefix: me,
      uploaderId: me,
      mime,
      fileName: typeof body?.file_name === "string" ? body.file_name : null,
    });
    return json(slot, 201);
  }

  // ── POST /stories ────────────────────────────────────────────────────────────
  if (req.method === "POST" && route.kind === "collection") {
    const body = await req.json().catch(() => null);
    const caption = typeof body?.caption === "string" ? body.caption.trim() : "";
    if (caption.length > CAPTION_MAX) return jsonError(`Story text is limited to ${CAPTION_MAX} characters`, 400);
    const background = body?.background ?? null;
    if (background !== null && (typeof background !== "string" || !HEX_RE.test(background))) {
      return jsonError("background must be a #rrggbb colour", 400);
    }
    const media = body?.media ?? null;
    if (media !== null && typeof media?.path !== "string") return jsonError("media.path is required", 400);

    let share: StoredShare | null = null;
    if (body?.share != null) {
      const prepared = await prepareShare(caller, body.share, STORY_SHARE_KINDS);
      if (prepared instanceof Response) return prepared;
      share = prepared;
    }
    if (!media && !share && !caption) return jsonError("A story needs a photo, a video, text or something shared", 400);

    let mime: string | null = null;
    if (media) {
      const verified = await verifyUploads({ bucket: BUCKET, paths: [media.path], uploaderId: me });
      if ("error" in verified) return jsonError(verified.error, 400);
      mime = verified.mimeByPath.get(media.path)!;
    }
    const int = (v: unknown) => (Number.isFinite(Number(v)) && Number(v) >= 0 ? Math.round(Number(v)) : null);
    const row = await db.insertInto("story").values({
      author_id: me,
      storage_path: media?.path ?? null,
      media_type: mime ? (mime.startsWith("video/") ? "video" : "image") : null,
      mime_type: mime,
      width: media ? int(media.width) : null,
      height: media ? int(media.height) : null,
      duration_ms: media ? int(media.duration_ms) : null,
      caption: caption || null,
      background,
      share_kind: (share?.kind as StoryShareKind | undefined) ?? null,
      share_ref_id: share?.ref_id ?? null,
      share_snapshot: share?.snapshot ? JSON.stringify(share.snapshot) : null,
    }).returning(STORY_COLS).executeTakeFirstOrThrow();
    if (media) await markClaimed(BUCKET, [media.path]);
    const [decorated] = await decorateStories([row], caller);
    return json(decorated, 201);
  }

  if (!("id" in route)) return jsonError("Method not allowed", 405);

  // ── GET /stories/:id ─────────────────────────────────────────────────────────
  if (req.method === "GET" && route.kind === "story") {
    const story = await loadVisibleStory(route.id, caller);
    if (!story) return jsonError("Story not found", 404);
    const [decorated] = await decorateStories([story], caller);
    return json(decorated);
  }

  // ── DELETE /stories/:id ──────────────────────────────────────────────────────
  if (req.method === "DELETE" && route.kind === "story") {
    if (!UUID_RE.test(route.id)) return jsonError("Story not found", 404);
    const story = await db.selectFrom("story").select(["author_id", "storage_path"]).where("id", "=", route.id)
      .executeTakeFirst();
    if (!story) return jsonError("Story not found", 404);
    if (story.author_id !== me && !isSuperUser(caller)) return forbidden();
    await db.deleteFrom("story").where("id", "=", route.id).execute();
    if (story.storage_path) await removeObjects(BUCKET, [story.storage_path]);
    return new Response(null, { status: 204 });
  }

  // ── POST /stories/:id/view ───────────────────────────────────────────────────
  if (req.method === "POST" && route.kind === "view") {
    const story = await loadVisibleStory(route.id, caller);
    if (!story) return jsonError("Story not found", 404);
    if (story.author_id !== me) {
      await db.insertInto("story_view").values({ story_id: story.id, viewer_id: me })
        .onConflict((oc) => oc.columns(["story_id", "viewer_id"]).doNothing()).execute();
    }
    return new Response(null, { status: 204 });
  }

  // ── Reactions / likes ────────────────────────────────────────────────────────
  if ((route.kind === "reaction" && (req.method === "PUT" || req.method === "DELETE")) ||
    (route.kind === "like" && (req.method === "POST" || req.method === "DELETE"))) {
    const story = await loadVisibleStory(route.id, caller);
    if (!story) return jsonError("Story not found", 404);
    if (req.method === "DELETE") {
      await db.deleteFrom("story_reaction").where("story_id", "=", story.id).where("user_id", "=", me).execute();
    } else {
      const reaction: unknown = route.kind === "like" ? "like" : (await req.json().catch(() => null))?.reaction;
      if (!isReaction(reaction)) return jsonError(`reaction must be one of: ${REACTIONS.join(", ")}`, 400);
      if (story.author_id !== me && !isLive(story)) return jsonError("This story has expired", 410);
      const { rows: [r] } = await sql<{ inserted: boolean }>`
        INSERT INTO story_reaction (story_id, user_id, reaction) VALUES (${story.id}, ${me}, ${reaction})
        ON CONFLICT (story_id, user_id) DO UPDATE SET reaction = EXCLUDED.reaction
        RETURNING (xmax = 0) AS inserted
      `.execute(db);
      // Liking counts as watching it; only a first reaction notifies.
      if (story.author_id !== me) {
        await db.insertInto("story_view").values({ story_id: story.id, viewer_id: me })
          .onConflict((oc) => oc.columns(["story_id", "viewer_id"]).doNothing()).execute();
      }
      if (r.inserted && story.author_id !== me) {
        await notify([story.author_id], {
          type: "story_reaction",
          title: reaction === "like"
            ? `${displayName(caller)} liked your story`
            : `${displayName(caller)} reacted ${REACTION_EMOJI[reaction]} to your story`,
          body: story.caption?.slice(0, 120) ?? "",
          metadata: { story_id: story.id, user_id: me, reaction },
        });
      }
    }
    const [mine, count] = await Promise.all([
      db.selectFrom("story_reaction").select("reaction").where("story_id", "=", story.id).where("user_id", "=", me)
        .executeTakeFirst(),
      db.selectFrom("story_reaction").select(sql<number>`count(*)::int`.as("n")).where("story_id", "=", story.id)
        .executeTakeFirstOrThrow(),
    ]);
    return json({
      story_id: story.id,
      my_reaction: mine?.reaction ?? null,
      liked: !!mine,
      reaction_count: story.author_id === me ? count.n : null,
    });
  }

  // ── GET /stories/:id/viewers — the author only ───────────────────────────────
  // Everyone who watched it (people who reacted without a recorded view too),
  // those who reacted first, then most recent.
  if (req.method === "GET" && route.kind === "viewers") {
    if (!UUID_RE.test(route.id)) return jsonError("Story not found", 404);
    const story = await db.selectFrom("story").select(["id", "author_id"]).where("id", "=", route.id)
      .executeTakeFirst();
    if (!story) return jsonError("Story not found", 404);
    if (story.author_id !== me && !isSuperUser(caller)) return forbidden("Only the author sees who watched");
    const { page, pageSize } = parsePaging(url, 50, 200);
    const hidden = [...(await blockedIds(story.author_id))];
    const { rows } = await sql<{ user_id: string; viewed_at: string; reaction: ReactionType | null }>`
      SELECT u.id AS user_id,
             COALESCE(v.viewed_at, r.created_at) AS viewed_at,
             r.reaction
        FROM (SELECT viewer_id AS id FROM story_view WHERE story_id = ${story.id}
              UNION SELECT user_id FROM story_reaction WHERE story_id = ${story.id}) w
        JOIN users u ON u.id = w.id
        LEFT JOIN story_view v ON v.story_id = ${story.id} AND v.viewer_id = u.id
        LEFT JOIN story_reaction r ON r.story_id = ${story.id} AND r.user_id = u.id
       WHERE u.id <> ${story.author_id} AND NOT (u.id = ANY(${hidden}::uuid[]))
       ORDER BY (r.reaction IS NOT NULL) DESC, COALESCE(v.viewed_at, r.created_at) DESC, u.id
       LIMIT ${pageSize} OFFSET ${page * pageSize}
    `.execute(db);
    const people = await userSummaries(rows.map((r) => r.user_id));
    return json(rows.filter((r) => people[r.user_id]).map((r) => ({
      user: people[r.user_id],
      viewed_at: r.viewed_at,
      reaction: r.reaction,
    })));
  }

  return jsonError("Not found", 404);
}

Deno.serve(async (req: Request) => {
  try {
    return await handler(req);
  } catch (e) {
    const err = e as { code?: string; message?: string };
    if (err?.code === "22P02") return jsonError("Invalid id", 400);
    if (err?.code === "23514") return jsonError(err.message ?? "Invalid value", 400);
    throw e;
  }
});
