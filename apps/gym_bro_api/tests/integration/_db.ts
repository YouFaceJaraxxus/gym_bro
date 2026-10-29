// Direct database access for test cleanup only (rows that have no DELETE
// endpoint: classes, orders, check-ins, audit log entries, …).
//
// Uses DB_URL when set (`supabase status -o env` prints it). Without it, a
// local stack (API_URL on 127.0.0.1/localhost:54321) falls back to the
// Supabase CLI default postgres URL. When neither applies — or the database
// can't be reached — cleanup is skipped with a warning and `dbAvailable`
// reports false, so the suites still run (they just leave rows behind).
import pg from "npm:pg@^8";
import { API } from "./_client.ts";

function resolveDbUrl(): string | null {
  const explicit = Deno.env.get("DB_URL")?.trim();
  if (explicit) return explicit;
  if (/^https?:\/\/(127\.0\.0\.1|localhost):54321$/.test(API)) {
    return "postgresql://postgres:postgres@127.0.0.1:54322/postgres";
  }
  return null;
}

const DB_URL = resolveDbUrl();
let reachable: boolean | null = null;

/** Runs one statement; returns its rows, or null when no database is available. */
export async function sql<T = Record<string, unknown>>(text: string, params: unknown[] = []): Promise<T[] | null> {
  if (!DB_URL || reachable === false) return null;
  const client = new pg.Client({ connectionString: DB_URL });
  try {
    await client.connect();
    reachable = true;
  } catch (err) {
    reachable = false;
    console.warn(`DB cleanup unavailable (${(err as Error).message}); test rows may be left behind.`);
    return null;
  }
  try {
    const res = await client.query(text, params);
    return res.rows as T[];
  } finally {
    await client.end();
  }
}

/** True when cleanup SQL can run (connects once to find out). */
export async function dbAvailable(): Promise<boolean> {
  if (reachable === null) await sql("SELECT 1");
  return reachable === true;
}

/** Deletes notifications whose metadata->>key is one of `values`. */
export async function deleteNotificationsWhere(key: string, values: string[]): Promise<void> {
  const ids = values.filter(Boolean);
  if (!ids.length) return;
  await sql(`DELETE FROM notification WHERE metadata->>$1 = ANY($2::text[])`, [key, ids]);
}

/** Deletes notifications sent to `userIds` since `since` whose metadata->>key is one of `values`. */
export async function deleteNotificationsSince(userIds: string[], since: string, key: string, values: string[]): Promise<void> {
  if (!userIds.length || !values.length) return;
  await sql(
    `DELETE FROM notification WHERE user_id = ANY($1::uuid[]) AND created_at >= $2 AND metadata->>$3 = ANY($4::text[])`,
    [userIds, since, key, values],
  );
}

type Row = Record<string, unknown>;
export type PairSnapshot = { follows: Row[]; friendships: Row[]; blocks: Row[] };

/** Follow / friendship / block rows between two users, to put back after a test. */
export async function snapshotPair(a: string, b: string): Promise<PairSnapshot> {
  const pair = [a, b];
  return {
    follows: (await sql(`SELECT * FROM follow WHERE follower_id = ANY($1) AND followee_id = ANY($1)`, [pair])) ?? [],
    friendships: (await sql(`SELECT * FROM friendship WHERE requester_id = ANY($1) AND addressee_id = ANY($1)`, [pair])) ?? [],
    blocks: (await sql(`SELECT * FROM user_block WHERE blocker_id = ANY($1) AND blocked_id = ANY($1)`, [pair])) ?? [],
  };
}

/** Puts back the rows `snapshotPair` saw (and nothing else) between the two users. */
export async function restorePair(a: string, b: string, s: PairSnapshot): Promise<void> {
  const pair = [a, b];
  await sql(`DELETE FROM follow WHERE follower_id = ANY($1) AND followee_id = ANY($1)`, [pair]);
  await sql(`DELETE FROM friendship WHERE requester_id = ANY($1) AND addressee_id = ANY($1)`, [pair]);
  await sql(`DELETE FROM user_block WHERE blocker_id = ANY($1) AND blocked_id = ANY($1)`, [pair]);
  for (const f of s.follows) {
    await sql(`INSERT INTO follow VALUES ($1,$2,$3,$4,$5)`, [f.follower_id, f.followee_id, f.status, f.created_at, f.accepted_at]);
  }
  for (const f of s.friendships) {
    await sql(`INSERT INTO friendship VALUES ($1,$2,$3,$4,$5)`, [f.requester_id, f.addressee_id, f.status, f.created_at, f.accepted_at]);
  }
  for (const r of s.blocks) await sql(`INSERT INTO user_block VALUES ($1,$2,$3)`, [r.blocker_id, r.blocked_id, r.created_at]);
}
