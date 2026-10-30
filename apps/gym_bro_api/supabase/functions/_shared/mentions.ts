import { type Kysely, sql } from "npm:kysely@^0.27";
import type { Database, PostTagKind } from "../../types/schema/public.ts";

// Mentions in captions and comments, Instagram-style. In stored text a
// mention is markup the app renders as a tappable "@Name":
//
//   @[Elena Vasquez](user:<uuid>)   @[Ironclad Fitness](business:<uuid>)
//   @[Whey Isolate](shop_item:<uuid>)
//
// The app inserts markup when a suggestion is picked; a plain "@username"
// typed by hand is turned into markup on save when that user exists. Each
// mention is mirrored as a post_tag row (comment_id set for comments) so it
// can notify once and make the post visible to the person mentioned.

export const MAX_MENTIONS = 20;
const KINDS: readonly PostTagKind[] = ["user", "business", "shop_item"];
const MARKUP_RE = /@\[([^\]\n]{1,100})\]\((user|business|shop_item):([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})\)/gi;
// "@name" not preceded by a word character, @ or ] (so emails and markup are left alone).
const HANDLE_RE = /(^|[^\w@\]])@([A-Za-z0-9_.]{2,30})(?![\w])/g;

export type MentionRef = { kind: PostTagKind; id: string; label: string };

/** Unique mentions in [text], in order of appearance (at most MAX_MENTIONS). */
export function parseMentions(text: string): MentionRef[] {
  const seen = new Set<string>();
  const out: MentionRef[] = [];
  for (const m of text.matchAll(MARKUP_RE)) {
    const kind = m[2].toLowerCase() as PostTagKind;
    const id = m[3].toLowerCase();
    if (!KINDS.includes(kind) || seen.has(`${kind}:${id}`)) continue;
    seen.add(`${kind}:${id}`);
    out.push({ kind, id, label: m[1] });
    if (out.length >= MAX_MENTIONS) break;
  }
  return out;
}

/** [text] with mentions as "@Name", for notifications and previews. */
export function plainText(text: string): string {
  return text.replace(MARKUP_RE, (_, label: string) => `@${label}`);
}

/** Usernames typed as plain "@handle" (outside markup), lower-cased. */
export function plainHandles(text: string): string[] {
  const withoutMarkup = text.replace(MARKUP_RE, " ");
  return [...new Set([...withoutMarkup.matchAll(HANDLE_RE)].map((m) => m[2].replace(/\.+$/, "").toLowerCase()))];
}

/** Rewrites plain "@handle" mentions of existing users into markup. */
export async function normalizeMentions(executor: Kysely<Database>, text: string): Promise<string> {
  const handles = plainHandles(text);
  if (!handles.length) return text;
  const users = await executor.selectFrom("users").select(["id", "username", "name", "last_name"])
    .where(sql<string>`lower(username)`, "in", handles).execute();
  if (!users.length) return text;
  const byHandle = new Map(users.map((u) => [u.username.toLowerCase(), u]));
  // Split around existing markup so only plain text is rewritten.
  const parts = text.split(new RegExp(`(${MARKUP_RE.source})`, "gi"));
  let out = "";
  for (let i = 0; i < parts.length; i++) {
    const part = parts[i];
    if (part === undefined) continue;
    if (new RegExp(`^${MARKUP_RE.source}$`, "i").test(part)) {
      out += part;
      i += 3; // skip the capture groups split() inserted
      continue;
    }
    out += part.replace(HANDLE_RE, (whole, lead: string, handle: string) => {
      const trailingDots = handle.match(/\.+$/)?.[0] ?? "";
      const u = byHandle.get(handle.slice(0, handle.length - trailingDots.length).toLowerCase());
      if (!u) return whole;
      const label = `${u.name} ${u.last_name}`.trim() || u.username;
      return `${lead}@[${label.replace(/[\]\n]/g, "")}](user:${u.id})${trailingDots}`;
    });
  }
  return out;
}

/**
 * The mentions in [text] that point at something real and, for people, at
 * someone who hasn't blocked (or been blocked by) [authorId].
 */
export async function validMentions(executor: Kysely<Database>, text: string, authorId: string): Promise<MentionRef[]> {
  const refs = parseMentions(text);
  if (!refs.length) return [];
  const ids = (kind: PostTagKind) => refs.filter((r) => r.kind === kind).map((r) => r.id);
  const [users, businesses, items] = await Promise.all([
    ids("user").length
      ? executor.selectFrom("users").select("id").where("id", "in", ids("user"))
        .where(sql<boolean>`NOT is_blocked_between(id, ${authorId})`).execute()
      : [],
    ids("business").length ? executor.selectFrom("business").select("id").where("id", "in", ids("business")).execute() : [],
    ids("shop_item").length ? executor.selectFrom("shop_item").select("id").where("id", "in", ids("shop_item")).execute() : [],
  ]);
  const ok = new Set([
    ...users.map((u) => `user:${u.id}`),
    ...businesses.map((b) => `business:${b.id}`),
    ...items.map((i) => `shop_item:${i.id}`),
  ]);
  return refs.filter((r) => ok.has(`${r.kind}:${r.id}`));
}

const targetColumn = { user: "user_id", business: "business_id", shop_item: "shop_item_id" } as const;

/**
 * Makes the mention rows of a caption (commentId null) or a comment match
 * [refs]. Returns the ones that are new, to notify.
 */
export async function syncMentionRows(
  trx: Kysely<Database>,
  where: { postId: string; commentId: string | null; authorId: string },
  refs: MentionRef[],
): Promise<MentionRef[]> {
  let q = trx.selectFrom("post_tag").select(["id", "kind", "user_id", "business_id", "shop_item_id"])
    .where("post_id", "=", where.postId).where("post_image_id", "is", null);
  q = where.commentId ? q.where("comment_id", "=", where.commentId) : q.where("comment_id", "is", null);
  const existing = await q.execute();
  const keyOf = (r: (typeof existing)[number]) => `${r.kind}:${r.user_id ?? r.business_id ?? r.shop_item_id}`;
  const wanted = new Set(refs.map((r) => `${r.kind}:${r.id}`));
  const stale = existing.filter((r) => !wanted.has(keyOf(r))).map((r) => r.id);
  if (stale.length) await trx.deleteFrom("post_tag").where("id", "in", stale).execute();
  const have = new Set(existing.map(keyOf));
  const added = refs.filter((r) => !have.has(`${r.kind}:${r.id}`));
  if (added.length) {
    await trx.insertInto("post_tag").values(added.map((r) => ({
      post_id: where.postId,
      comment_id: where.commentId,
      kind: r.kind,
      [targetColumn[r.kind]]: r.id,
      created_by: where.authorId,
    }))).execute();
  }
  return added;
}

/**
 * Who to notify for these mentions: the people themselves, a business's
 * owners, a product's shop owners. Never the author.
 */
export async function mentionRecipients(executor: Kysely<Database>, refs: MentionRef[], authorId: string) {
  const users = refs.filter((r) => r.kind === "user").map((r) => r.id);
  const businesses = refs.filter((r) => r.kind === "business").map((r) => r.id);
  const items = refs.filter((r) => r.kind === "shop_item").map((r) => r.id);
  const owners = businesses.length || items.length
    ? (await sql<{ user_id: string }>`
        SELECT user_id FROM gym_owner WHERE gym_id = ANY(${businesses}::uuid[])
        UNION SELECT user_id FROM shop_owner WHERE shop_id = ANY(${businesses}::uuid[])
        UNION SELECT so.user_id FROM shop_owner so JOIN shop_item si ON si.shop_id = so.shop_id
               WHERE si.id = ANY(${items}::uuid[])
      `.execute(executor)).rows.map((r) => r.user_id)
    : [];
  return {
    people: users.filter((id) => id !== authorId),
    owners: [...new Set(owners)].filter((id) => id !== authorId && !users.includes(id)),
  };
}
