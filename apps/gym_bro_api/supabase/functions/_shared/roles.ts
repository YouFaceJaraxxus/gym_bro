import { type Kysely, sql } from "npm:kysely@^0.27";
import type { Database } from "../../types/schema/public.ts";

/** Postgres error code (e.g. "23505" unique violation) from a pg error, if any. */
export function pgCode(err: unknown): string | undefined {
  return typeof err === "object" && err !== null && "code" in err
    ? String((err as { code: unknown }).code)
    : undefined;
}

/**
 * Recomputes users.role for `userIds` from the role rows they still hold
 * anywhere, highest first: owner (gym or shop) > employee_trainer > employee >
 * trainer > shop_vendor > member. Call it after adding or removing any of
 * those rows. super_user is never touched.
 */
export async function reconcileRoles(q: Kysely<Database>, userIds: string[]): Promise<void> {
  const ids = [...new Set(userIds)];
  if (ids.length === 0) return;
  await sql`
    UPDATE users u SET role = CASE
      WHEN EXISTS (SELECT 1 FROM gym_owner        x WHERE x.user_id = u.id)
        OR EXISTS (SELECT 1 FROM shop_owner       x WHERE x.user_id = u.id) THEN 'owner'
      WHEN EXISTS (SELECT 1 FROM employee_trainer x WHERE x.user_id = u.id) THEN 'employee_trainer'
      WHEN EXISTS (SELECT 1 FROM employee         x WHERE x.user_id = u.id) THEN 'employee'
      WHEN EXISTS (SELECT 1 FROM trainer          x WHERE x.user_id = u.id) THEN 'trainer'
      WHEN EXISTS (SELECT 1 FROM shop_vendor      x WHERE x.user_id = u.id) THEN 'shop_vendor'
      ELSE 'member'
    END::user_role
    WHERE u.id = ANY(${ids}::uuid[])
      AND u.role <> 'super_user'
  `.execute(q);
}
