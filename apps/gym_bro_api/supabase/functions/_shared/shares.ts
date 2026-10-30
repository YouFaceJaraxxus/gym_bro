import { sql } from "npm:kysely@^0.27";
import { db } from "./config.ts";
import { type Caller, isSuperUser, jsonError } from "./auth.ts";
import { buildAttachment } from "./post_attachments.ts";
import { signPaths } from "./media.ts";
import { plainText } from "./mentions.ts";
import { callerHasAssignedAccessToMealPlan, mealPlansUsingDailyPlan } from "./nutrition.ts";
import { isBlockedBetween, PUBLIC_USER_COLS } from "./social.ts";
import { postVisibleSql, storyVisibleSql } from "./visibility.ts";
import type { PostType, ShareKind } from "../../types/schema/public.ts";

// Sharing things in chat messages and stories.
//
// A share is stored as { kind, ref_id } — or, for a logged workout or meal,
// a snapshot built when sharing (only their owner can share them, and the
// snapshot is what they chose to show). Everything else is resolved for each
// viewer whenever it's read, so the preview always follows the current
// visibility rules: someone who can't see a private account's post gets
// { available: false, reason: "private" } instead of the post.
//
//   reason  "private"      exists, but this viewer isn't allowed to see it
//           "unavailable"  deleted, archived, or someone blocked someone
//           "expired"      a story past its 24 hours (its author still sees it)
//
// Stories share anything but people and businesses (accounts) and stories.

export const SHARE_KINDS: readonly ShareKind[] = [
  "post", "story", "user", "business", "shop_item", "workout", "meal", "exercise", "training",
  "routine", "recipe", "food_item", "daily_meal_plan", "meal_plan",
];
export type StoryShareKind = Exclude<ShareKind, "story" | "user" | "business">;
export const STORY_SHARE_KINDS = SHARE_KINDS.filter((k) => !["story", "user", "business"].includes(k)) as
  readonly StoryShareKind[];

const LIBRARY_KINDS = ["exercise", "training", "routine", "recipe", "food_item", "daily_meal_plan", "meal_plan"] as const;
export type LibraryKind = (typeof LIBRARY_KINDS)[number];
const isLibrary = (k: ShareKind): k is LibraryKind => (LIBRARY_KINDS as readonly string[]).includes(k);

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export type StoredShare = { kind: ShareKind; ref_id: string | null; snapshot: unknown | null };

export type Unavailable = "private" | "unavailable" | "expired";

export type SharePreview =
  | { kind: ShareKind; ref_id: string | null; available: true; preview: Record<string, unknown> }
  | { kind: ShareKind; ref_id: string | null; available: false; reason: Unavailable }
  // Not resolved for anyone in particular (realtime payloads go to every
  // participant at once): the app fetches the message to see it.
  | { kind: ShareKind; ref_id: string | null; available: null };

const label: Record<ShareKind, string> = {
  post: "Post",
  story: "Story",
  user: "Account",
  business: "Business",
  shop_item: "Product",
  workout: "Workout",
  meal: "Meal",
  exercise: "Exercise",
  training: "Workout",
  routine: "Routine",
  recipe: "Recipe",
  food_item: "Food item",
  daily_meal_plan: "Day plan",
  meal_plan: "Meal plan",
};

/**
 * Validates what [caller] wants to share ({ kind, ref_id } or, for a meal,
 * { kind: "meal", meal: { log_date, slot_type } }) and returns what to
 * store; a Response when it's invalid or the caller can't see it.
 */
export async function prepareShare(
  caller: Caller,
  raw: unknown,
  allowed: readonly ShareKind[] = SHARE_KINDS,
): Promise<StoredShare | Response> {
  const input = (raw ?? {}) as { kind?: unknown; ref_id?: unknown; meal?: unknown };
  const kind = input.kind as ShareKind;
  if (!allowed.includes(kind)) return jsonError(`share.kind must be one of: ${allowed.join(", ")}`, 400);
  if (kind === "workout" || kind === "meal") {
    const built = await buildAttachment(caller, kind, { ref_id: input.ref_id, meal: input.meal });
    if (built instanceof Response) return built;
    return { kind, ref_id: built.ref_id, snapshot: built.attachment };
  }
  if (typeof input.ref_id !== "string" || !UUID_RE.test(input.ref_id)) {
    return jsonError("share.ref_id must be the id of what you're sharing", 400);
  }
  const stored = { kind, ref_id: input.ref_id.toLowerCase(), snapshot: null };
  const [resolved] = await resolveShares(caller, [stored]);
  if (!resolved.available) return jsonError(`${label[kind]} not found`, 404, { code: "share_not_found" });
  return stored;
}

/** Previews of [shares] as [viewer] may see them, in order. */
export async function resolveShares(viewer: Caller, shares: StoredShare[]): Promise<SharePreview[]> {
  const cache = new Map<string, Promise<SharePreview>>();
  return await Promise.all(shares.map((s) => {
    if (s.kind === "workout" || s.kind === "meal") return Promise.resolve(fromSnapshot(s));
    const key = `${s.kind}:${s.ref_id}`;
    if (!cache.has(key)) cache.set(key, resolveOne(viewer, s).catch((e) => {
      if ((e as { code?: string })?.code === "22P02") return gone(s, "unavailable");
      throw e;
    }));
    return cache.get(key)!;
  }));
}

/** A share's shape before it's resolved for a viewer. */
export function unresolved(s: StoredShare): SharePreview {
  if (s.kind === "workout" || s.kind === "meal") return fromSnapshot(s);
  return { kind: s.kind, ref_id: s.ref_id, available: null };
}

/** Short text for inbox previews and pushes ("Shared a post"). */
export function shareSummary(kind: ShareKind): string {
  switch (kind) {
    case "user":
      return "Shared a profile";
    case "workout":
    case "training":
      return "Shared a workout";
    case "meal":
      return "Shared a meal";
    default:
      return `Shared ${/^[aeiou]/i.test(label[kind]) ? "an" : "a"} ${label[kind].toLowerCase()}`;
  }
}

const gone = (s: StoredShare, reason: Unavailable): SharePreview => ({
  kind: s.kind,
  ref_id: s.ref_id,
  available: false,
  reason,
});
const shown = (s: StoredShare, preview: Record<string, unknown>): SharePreview => ({
  kind: s.kind,
  ref_id: s.ref_id,
  available: true,
  preview,
});

function fromSnapshot(s: StoredShare): SharePreview {
  return s.snapshot && typeof s.snapshot === "object"
    ? shown(s, s.snapshot as Record<string, unknown>)
    : gone(s, "unavailable");
}

async function resolveOne(viewer: Caller, s: StoredShare): Promise<SharePreview> {
  const id = s.ref_id;
  if (!id || !UUID_RE.test(id)) return gone(s, "unavailable");
  switch (s.kind) {
    case "post":
      return await resolvePost(viewer, s, id);
    case "story":
      return await resolveStory(viewer, s, id);
    case "user": {
      const u = await db.selectFrom("users").select([...PUBLIC_USER_COLS, "is_private", "bio"]).where("id", "=", id)
        .executeTakeFirst();
      if (!u || (u.id !== viewer.id && (await isBlockedBetween(viewer.id, u.id)))) return gone(s, "unavailable");
      return shown(s, { ...u, bio: u.bio?.slice(0, 160) ?? null });
    }
    case "business": {
      const b = await db.selectFrom("business").select(["id", "name", "logo", "type", "location"]).where("id", "=", id)
        .executeTakeFirst();
      return b ? shown(s, b) : gone(s, "unavailable");
    }
    case "shop_item": {
      const i = await db.selectFrom("shop_item as i").innerJoin("business as b", "b.id", "i.shop_id")
        .select(["i.id", "i.name", "i.image_url", "i.price", "i.is_active", "i.shop_id", "b.name as shop_name"])
        .where("i.id", "=", id).executeTakeFirst();
      return i ? shown(s, { ...i, price: Number(i.price) }) : gone(s, "unavailable");
    }
    default:
      if (isLibrary(s.kind)) return await resolveLibrary(viewer, s, s.kind, id);
      return gone(s, "unavailable");
  }
}

async function resolvePost(viewer: Caller, s: StoredShare, id: string): Promise<SharePreview> {
  const row = await db.selectFrom("post")
    .select(["id", "author_id", "business_id", "content", "post_type", "attachment", "archived_at", "created_at",
      sql<boolean>`${postVisibleSql(viewer.id)}`.as("visible")])
    .where("id", "=", id).executeTakeFirst();
  if (!row) return gone(s, "unavailable");
  if (!row.visible) {
    const blocked = row.author_id ? await isBlockedBetween(viewer.id, row.author_id) : false;
    return gone(s, row.archived_at || blocked ? "unavailable" : "private");
  }
  const [media, author, business, count] = await Promise.all([
    db.selectFrom("post_image").select(["url", "storage_path", "media_type"]).where("post_id", "=", id)
      .orderBy("position").executeTakeFirst(),
    row.author_id
      ? db.selectFrom("users").select(PUBLIC_USER_COLS).where("id", "=", row.author_id).executeTakeFirst()
      : undefined,
    row.business_id
      ? db.selectFrom("business").select(["id", "name", "logo", "type"]).where("id", "=", row.business_id)
        .executeTakeFirst()
      : undefined,
    db.selectFrom("post_image").select(sql<number>`count(*)::int`.as("n")).where("post_id", "=", id)
      .executeTakeFirstOrThrow(),
  ]);
  const signed = media?.storage_path ? await signPaths("user-media", [media.storage_path]) : null;
  return shown(s, {
    id: row.id,
    author: author ?? null,
    business: business ?? null,
    caption: plainText(row.content).slice(0, 300),
    post_type: row.post_type,
    attachment: row.attachment,
    thumbnail_url: media ? (media.storage_path ? signed?.get(media.storage_path) ?? null : media.url) : null,
    media_type: media?.media_type ?? null,
    media_count: count.n,
    created_at: row.created_at,
  });
}

async function resolveStory(viewer: Caller, s: StoredShare, id: string): Promise<SharePreview> {
  const row = await db.selectFrom("story")
    .select(["id", "author_id", "storage_path", "media_type", "caption", "background", "share_kind", "created_at",
      "expires_at", sql<boolean>`${storyVisibleSql(viewer.id)}`.as("visible")])
    .where("id", "=", id).executeTakeFirst();
  if (!row) return gone(s, "unavailable");
  if (!row.visible) {
    if (await isBlockedBetween(viewer.id, row.author_id)) return gone(s, "unavailable");
    return gone(s, new Date(row.expires_at).getTime() <= Date.now() ? "expired" : "private");
  }
  const [author, signed] = await Promise.all([
    db.selectFrom("users").select(PUBLIC_USER_COLS).where("id", "=", row.author_id).executeTakeFirst(),
    row.storage_path ? signPaths("user-media", [row.storage_path]) : Promise.resolve(null),
  ]);
  return shown(s, {
    id: row.id,
    author: author ?? null,
    media_url: row.storage_path ? signed?.get(row.storage_path) ?? null : null,
    media_type: row.media_type,
    caption: row.caption,
    background: row.background,
    share_kind: row.share_kind,
    created_at: row.created_at,
    expires_at: row.expires_at,
  });
}

const LIBRARY_TABLE = {
  exercise: "exercise",
  training: "training",
  routine: "routine",
  recipe: "recipe",
  food_item: "food_item",
  daily_meal_plan: "daily_meal_plan",
  meal_plan: "meal_plan",
} as const;

async function resolveLibrary(viewer: Caller, s: StoredShare, kind: LibraryKind, id: string): Promise<SharePreview> {
  const { rows: [row] } = await sql<{ author_id: string | null }>`
    SELECT author_id FROM ${sql.table(LIBRARY_TABLE[kind])} WHERE id = ${id}`.execute(db);
  if (!row) return gone(s, "unavailable");
  const trusted = await assignedAccess(viewer, kind, id);
  const built = await buildAttachment(viewer, kind as PostType, { ref_id: id }, { trusted });
  if (built instanceof Response) return gone(s, "private");
  return shown(s, { id, author_id: row.author_id, ...built.attachment });
}

/**
 * Whether [viewer] can open a library item: "ok", "private" (it exists but
 * isn't public, theirs, or assigned to them) or "unavailable" (deleted). For
 * links that outlive their access, e.g. a plan entry of a routine they left.
 */
export async function libraryAccess(
  viewer: Caller,
  kind: LibraryKind,
  id: string,
): Promise<"ok" | "private" | "unavailable"> {
  const r = await resolveLibrary(viewer, { kind, ref_id: id, snapshot: null }, kind, id);
  if (r.available === true) return "ok";
  return r.available === false && r.reason === "private" ? "private" : "unavailable";
}

/**
 * Access a viewer has to a private plan beyond public/own: it's assigned to
 * them (or to someone they coach), or — for a workout — they've logged it.
 */
async function assignedAccess(viewer: Caller, kind: LibraryKind, id: string): Promise<boolean> {
  if (isSuperUser(viewer)) return true;
  switch (kind) {
    case "routine": {
      const r = await db.selectFrom("routine_assignment").select("id").where("routine_id", "=", id)
        .where("user_id", "=", viewer.id).where("left_at", "is", null).executeTakeFirst();
      return !!r;
    }
    case "training": {
      const { rows: [r] } = await sql<{ ok: boolean }>`
        SELECT EXISTS (SELECT 1 FROM training_session WHERE training_id = ${id} AND user_id = ${viewer.id})
            OR EXISTS (SELECT 1 FROM routine_training rt
                         JOIN routine_assignment ra ON ra.routine_id = rt.routine_id
                        WHERE rt.training_id = ${id} AND ra.user_id = ${viewer.id} AND ra.left_at IS NULL) AS ok`.execute(db);
      return r?.ok === true;
    }
    case "meal_plan":
      return await callerHasAssignedAccessToMealPlan(viewer, id);
    case "daily_meal_plan":
      return await callerHasAssignedAccessToMealPlan(viewer, await mealPlansUsingDailyPlan(id));
    default:
      // Recipes and food items already count assigned plans (canSeeRecipe / canSeeFoodItem).
      return false;
  }
}
