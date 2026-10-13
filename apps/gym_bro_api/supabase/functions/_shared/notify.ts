import { db } from "./config.ts";
import type { NotificationType } from "../../types/schema/public.ts";

/**
 * Inserts the same in-app notification for each user. Notifications are only
 * ever created by the server; clients can read, mark read and delete their own.
 * Failures are logged, never thrown, so a notification can't break the action
 * that triggered it.
 */
export async function notify(
  userIds: string[],
  n: { type: NotificationType; title: string; body: string; metadata?: Record<string, unknown> },
): Promise<void> {
  const unique = [...new Set(userIds)].filter(Boolean);
  if (unique.length === 0) return;
  try {
    await db
      .insertInto("notification")
      .values(unique.map((user_id) => ({
        user_id,
        type: n.type,
        title: n.title,
        body: n.body,
        // pg serializes plain objects to JSON for the jsonb column.
        metadata: n.metadata ?? {},
      })))
      .execute();
  } catch (err) {
    console.error("notify failed", n.type, err);
  }
}

/** User ids of everyone who owns the gym. */
export async function gymOwnerIds(gymId: string): Promise<string[]> {
  const rows = await db.selectFrom("gym_owner").select("user_id").where("gym_id", "=", gymId).execute();
  return rows.map((r) => r.user_id);
}

/** User ids of everyone who owns the shop. */
export async function shopOwnerIds(shopId: string): Promise<string[]> {
  const rows = await db.selectFrom("shop_owner").select("user_id").where("shop_id", "=", shopId).execute();
  return rows.map((r) => r.user_id);
}

export async function businessName(businessId: string): Promise<string> {
  const row = await db.selectFrom("business").select("name").where("id", "=", businessId).executeTakeFirst();
  return row?.name ?? "the business";
}
