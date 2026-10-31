import type { Kysely } from "npm:kysely@^0.27";
import type { Database } from "../../types/schema/public.ts";
import { plainText } from "./mentions.ts";

// Hashtags in personal post captions. "#legday" anywhere in the caption
// (not inside a word, a URL fragment or an HTML entity) is a tag; tags are
// stored lowercased in post_hashtag and must contain a letter, so "#10" is
// just a number. Mention markup is flattened first so a name can't add tags.

export const MAX_HASHTAGS = 30;
const HASHTAG_RE = /(^|[^\p{L}\p{N}_&/#])#([\p{L}\p{N}_]{1,50})/gu;
const LETTER_RE = /\p{L}/u;

/** Unique lowercased hashtags in [text], in order of appearance (at most MAX_HASHTAGS). */
export function parseHashtags(text: string): string[] {
  const out: string[] = [];
  for (const m of plainText(text).matchAll(HASHTAG_RE)) {
    const tag = m[2].toLowerCase();
    if (!LETTER_RE.test(tag) || out.includes(tag)) continue;
    out.push(tag);
    if (out.length >= MAX_HASHTAGS) break;
  }
  return out;
}

/** A search term or path segment as a tag ("#LegDay" → "legday"); null when it can't be one. */
export function normalizeTag(raw: string): string | null {
  const tag = raw.trim().replace(/^#/, "").toLowerCase();
  return /^[\p{L}\p{N}_]{1,50}$/u.test(tag) ? tag : null;
}

/** Makes the post's hashtag rows match its caption. */
export async function syncHashtags(trx: Kysely<Database>, postId: string, caption: string): Promise<void> {
  const tags = parseHashtags(caption);
  await trx.deleteFrom("post_hashtag").where("post_id", "=", postId).execute();
  if (tags.length) await trx.insertInto("post_hashtag").values(tags.map((tag) => ({ post_id: postId, tag }))).execute();
}
