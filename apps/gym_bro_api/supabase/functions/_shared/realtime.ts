import { type Kysely, sql } from "npm:kysely@^0.27";
import { db } from "./config.ts";
import type { Database } from "../../types/schema/public.ts";

// Server → client events over Supabase Realtime private channels. Each event is
// written with realtime.send(), so when called with a transaction it is only
// delivered if that transaction commits. Topics (authorized by the RLS
// policies in 000014):
//   user:<users.id>        one user's inbox / social events
//   chat:<conversation id> everything that changes a conversation
// Clients use chat-live:<id> among themselves for typing and presence; the
// server never writes there.

export const userTopic = (userId: string) => `user:${userId}`;
export const chatTopic = (conversationId: string) => `chat:${conversationId}`;

type Executor = Kysely<Database>;

/** Sends one broadcast event. Failures are logged, never thrown. */
export async function broadcast(
  topic: string,
  event: string,
  payload: unknown,
  executor: Executor = db,
): Promise<void> {
  try {
    await sql`SELECT realtime.send(${JSON.stringify(payload)}::jsonb, ${event}, ${topic}, TRUE)`.execute(executor);
  } catch (err) {
    console.error("realtime broadcast failed", topic, event, err);
  }
}

/** Sends the same event to several users' inbox topics. */
export async function broadcastToUsers(
  userIds: string[],
  event: string,
  payload: unknown,
  executor: Executor = db,
): Promise<void> {
  const unique = [...new Set(userIds)].filter(Boolean);
  if (unique.length === 0) return;
  try {
    await sql`
      SELECT realtime.send(${JSON.stringify(payload)}::jsonb, ${event}, 'user:' || uid::text, TRUE)
      FROM unnest(${unique}::uuid[]) AS uid
    `.execute(executor);
  } catch (err) {
    console.error("realtime broadcast failed", event, err);
  }
}
