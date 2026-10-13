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
