import type { User } from "jsr:@supabase/supabase-js@2";
import { db, supabaseAdmin } from "./config.ts";

// ── Responses ─────────────────────────────────────────────────────────────────

export function json(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

export function jsonError(message: string, status: number, extra?: Record<string, unknown>): Response {
  return json({ error: message, ...extra }, status);
}

// ── Authentication ────────────────────────────────────────────────────────────

export async function requireAuth(req: Request): Promise<{ user: User | null; error: string | null }> {
  const token = req.headers.get("Authorization")?.replace(/^Bearer\s+/i, "");
  if (!token) return { user: null, error: "Missing Authorization header" };
  const { data: { user }, error } = await supabaseAdmin.auth.getUser(token);
  return { user: error ? null : user, error: error?.message ?? null };
}

export type Caller = {
  authUser: User;
  id: string; // public.users.id
  role: string;
  name: string;
  last_name: string;
  email: string;
};

/**
 * Resolves the signed-in caller's public profile.
 * Returns either `{ caller }` or `{ response }` (401/404) to return as-is.
 */
export async function requireCaller(
  req: Request,
): Promise<{ caller: Caller; response?: never } | { caller?: never; response: Response }> {
  const { user, error } = await requireAuth(req);
  if (!user) return { response: jsonError(error ?? "Unauthorized", 401) };
  const profile = await db
    .selectFrom("users")
    .select(["id", "role", "name", "last_name", "email"])
    .where("auth_id", "=", user.id)
    .executeTakeFirst();
  if (!profile) return { response: jsonError("Profile not found", 404) };
  return { caller: { authUser: user, ...profile } };
}

export function isSuperUser(caller: Pick<Caller, "role">): boolean {
  return caller.role === "super_user";
}

export const forbidden = (message = "You don't have permission to do this") => jsonError(message, 403);

// ── Business permissions ──────────────────────────────────────────────────────
// Per-business roles live in the join tables; users.role is only trusted for
// super_user. gym.id and shop.id are the same UUID as business.id.

async function hasRow(
  table: "gym_owner" | "employee" | "employee_trainer" | "trainer" | "member",
  userId: string,
  gymId: string,
): Promise<boolean> {
  const row = await db
    .selectFrom(table)
    .select("id")
    .where("user_id", "=", userId)
    .where("gym_id", "=", gymId)
    .executeTakeFirst();
  return !!row;
}

/** Owner of the gym, or super user. Can manage staff, pricing and the business itself. */
export async function canManageGym(caller: Caller, gymId: string): Promise<boolean> {
  if (isSuperUser(caller)) return true;
  return await hasRow("gym_owner", caller.id, gymId);
}

/** Owner, employee or employee-trainer at the gym. Front-desk work: members, memberships, invoices. */
export async function canStaffGym(caller: Caller, gymId: string): Promise<boolean> {
  if (await canManageGym(caller, gymId)) return true;
  return (await hasRow("employee", caller.id, gymId)) ||
    (await hasRow("employee_trainer", caller.id, gymId));
}

/** Anyone who coaches at the gym: trainers and employee-trainers, plus front-desk staff. */
export async function canCoachAtGym(caller: Caller, gymId: string): Promise<boolean> {
  if (await canStaffGym(caller, gymId)) return true;
  return hasRow("trainer", caller.id, gymId);
}

/** Gyms where the caller is owner, employee or employee-trainer (a subquery). */
export function staffedGymIds(caller: Caller) {
  return db
    .selectFrom("gym_owner")
    .select("gym_id")
    .where("user_id", "=", caller.id)
    .union(db.selectFrom("employee").select("gym_id").where("user_id", "=", caller.id))
    .union(db.selectFrom("employee_trainer").select("gym_id").where("user_id", "=", caller.id));
}

/** Owner of the shop, or super user. */
export async function canManageShop(caller: Caller, shopId: string): Promise<boolean> {
  if (isSuperUser(caller)) return true;
  const row = await db
    .selectFrom("shop_owner")
    .select("id")
    .where("user_id", "=", caller.id)
    .where("shop_id", "=", shopId)
    .executeTakeFirst();
  return !!row;
}

/** Shop owner or vendor. Can manage the shop's items. */
export async function canStaffShop(caller: Caller, shopId: string): Promise<boolean> {
  if (await canManageShop(caller, shopId)) return true;
  const row = await db
    .selectFrom("shop_vendor")
    .select("id")
    .where("user_id", "=", caller.id)
    .where("shop_id", "=", shopId)
    .executeTakeFirst();
  return !!row;
}

/** Owner of the business (gym or shop), or super user. */
export async function canManageBusiness(caller: Caller, businessId: string): Promise<boolean> {
  return (await canManageGym(caller, businessId)) || (await canManageShop(caller, businessId));
}

/** The gym a membership type belongs to. */
export async function gymIdForMembershipType(typeId: string): Promise<string | null> {
  const row = await db
    .selectFrom("gym_membership_type")
    .select("gym_id")
    .where("id", "=", typeId)
    .executeTakeFirst();
  return row?.gym_id ?? null;
}

/** The gym a membership belongs to (through its membership type). */
export async function gymIdForMembership(membershipId: string): Promise<string | null> {
  const row = await db
    .selectFrom("membership")
    .innerJoin("gym_membership_type", "gym_membership_type.id", "membership.current_membership_type_id")
    .select("gym_membership_type.gym_id")
    .where("membership.id", "=", membershipId)
    .executeTakeFirst();
  return row?.gym_id ?? null;
}

/**
 * True when the caller coaches or staffs at any gym where `userId` is a member.
 * Used for trainer access to a client's sessions and meal plans.
 */
export async function coachesUser(caller: Caller, userId: string): Promise<boolean> {
  if (isSuperUser(caller)) return true;
  const gyms = await db
    .selectFrom("member")
    .select("gym_id")
    .where("user_id", "=", userId)
    .execute();
  for (const { gym_id } of gyms) {
    if (await canCoachAtGym(caller, gym_id)) return true;
  }
  return false;
}

/** Content with no author (system/seeded or orphaned by a deleted user) is super-user only. */
export function canEditAuthored(caller: Caller, authorId: string | null): boolean {
  if (isSuperUser(caller)) return true;
  return authorId !== null && authorId === caller.id;
}

/**
 * True when the caller owns or staffs at least one gym or shop (or is a super
 * user). Gates user lookup endpoints that expose emails.
 */
export async function staffsAnyBusiness(caller: Caller): Promise<boolean> {
  if (isSuperUser(caller)) return true;
  for (
    const table of ["gym_owner", "employee", "employee_trainer", "trainer", "shop_owner", "shop_vendor"] as const
  ) {
    const row = await db.selectFrom(table).select("id").where("user_id", "=", caller.id).executeTakeFirst();
    if (row) return true;
  }
  return false;
}

/**
 * Drops `email` from user-joined role rows unless the row is the caller's own
 * or `canSee(caller, businessId)` passes for the row's gym/shop. The check is
 * memoized per business.
 */
export async function redactEmails<T extends { user_id: string; email?: string }>(
  caller: Caller,
  rows: T[],
  businessIdOf: (row: T) => string,
  canSee: (caller: Caller, businessId: string) => Promise<boolean>,
): Promise<Array<T | Omit<T, "email">>> {
  const allowed = new Map<string, boolean>();
  const out: Array<T | Omit<T, "email">> = [];
  for (const row of rows) {
    if (row.user_id === caller.id) {
      out.push(row);
      continue;
    }
    const businessId = businessIdOf(row);
    if (!allowed.has(businessId)) allowed.set(businessId, await canSee(caller, businessId));
    if (allowed.get(businessId)) {
      out.push(row);
    } else {
      const { email: _email, ...rest } = row;
      out.push(rest);
    }
  }
  return out;
}
