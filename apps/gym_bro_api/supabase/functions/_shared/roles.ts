import { type Kysely, sql } from "npm:kysely@^0.27";
import type { Database, UserRole } from "../../types/schema/public.ts";

/** Postgres error code (e.g. "23505" unique violation) from a pg error, if any. */
export function pgCode(err: unknown): string | undefined {
  return typeof err === "object" && err !== null && "code" in err
    ? String((err as { code: unknown }).code)
    : undefined;
}

/** Sets users.role for a newly added role row, never demoting super users or owners. */
export async function assignRole(q: Kysely<Database>, userId: string, role: UserRole): Promise<void> {
  await q
    .updateTable("users")
    .set({ role })
    .where("id", "=", userId)
    .where("role", "not in", ["super_user", "owner"])
    .execute();
}

/**
 * Resets users.role to 'member' for any of `userIds` whose role points at a
 * kind of row they no longer have anywhere. super_user is never touched.
 */
export async function reconcileRoles(q: Kysely<Database>, userIds: string[]): Promise<void> {
  const ids = [...new Set(userIds)];
  if (ids.length === 0) return;
  await sql`
    UPDATE users u SET role = 'member'
    WHERE u.id = ANY(${ids}::uuid[])
      AND (
        (u.role = 'employee'         AND NOT EXISTS (SELECT 1 FROM employee         x WHERE x.user_id = u.id)) OR
        (u.role = 'employee_trainer' AND NOT EXISTS (SELECT 1 FROM employee_trainer x WHERE x.user_id = u.id)) OR
        (u.role = 'trainer'          AND NOT EXISTS (SELECT 1 FROM trainer          x WHERE x.user_id = u.id)) OR
        (u.role = 'shop_vendor'      AND NOT EXISTS (SELECT 1 FROM shop_vendor      x WHERE x.user_id = u.id)) OR
        (u.role = 'owner'            AND NOT EXISTS (SELECT 1 FROM gym_owner  x WHERE x.user_id = u.id)
                                     AND NOT EXISTS (SELECT 1 FROM shop_owner y WHERE y.user_id = u.id))
      )
  `.execute(q);
}
