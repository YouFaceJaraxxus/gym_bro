import type { User } from "jsr:@supabase/supabase-js@2";
import { db, supabaseAdmin } from "./config.ts";
import type { BusinessRole } from "../../types/schema/public.ts";

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

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
  is_super_user: boolean;
  is_trainer: boolean;
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
    .select(["id", "is_super_user", "is_trainer", "name", "last_name", "email"])
    .where("auth_id", "=", user.id)
    .executeTakeFirst();
  if (!profile) return { response: jsonError("Profile not found", 404) };
  return { caller: { authUser: user, ...profile } };
}

export function isSuperUser(caller: Pick<Caller, "is_super_user">): boolean {
  return caller.is_super_user;
}

export const forbidden = (message = "You don't have permission to do this") => jsonError(message, 403);

// ── Business permissions ──────────────────────────────────────────────────────
// What someone may do at a business comes from their active business_member
// rows, and only while the business is approved:
// * owner:   everything (team, pricing, gym/shop sides, deleting it)
// * staff:   profile, posts, members, memberships and billing, shop items and orders
// * trainer: posts, the classes they teach, coaching the gym's members
// gym_id / shop_id columns hold business ids. A gym check also needs has_gym,
// a shop check has_shop.

type Side = "gym" | "shop" | "any";

async function hasBusinessRole(
  caller: Caller,
  businessId: string,
  roles: BusinessRole[],
  side: Side,
): Promise<boolean> {
  if (isSuperUser(caller)) return true;
  if (!UUID_RE.test(businessId)) return false;
  const row = await db
    .selectFrom("business_member as m")
    .innerJoin("business as b", "b.id", "m.business_id")
    .select("m.role")
    .where("m.user_id", "=", caller.id)
    .where("m.business_id", "=", businessId)
    .where("m.status", "=", "active")
    .where("m.role", "in", roles)
    .where("b.status", "=", "approved")
    .$if(side === "gym", (q) => q.where("b.has_gym", "=", true))
    .$if(side === "shop", (q) => q.where("b.has_shop", "=", true))
    .executeTakeFirst();
  return !!row;
}

/** Owner of the business (gym or shop), or super user. Team, sides, deleting it. */
export function canManageBusiness(caller: Caller, businessId: string): Promise<boolean> {
  return hasBusinessRole(caller, businessId, ["owner"], "any");
}

/**
 * Owner or staff: may edit the business profile. An owner may also while it
 * is pending or rejected (to fix it before review), but not once blocked.
 */
export async function canEditBusinessProfile(caller: Caller, businessId: string): Promise<boolean> {
  if (await hasBusinessRole(caller, businessId, ["owner", "staff"], "any")) return true;
  if (!UUID_RE.test(businessId)) return false;
  const row = await db
    .selectFrom("business_member as m")
    .innerJoin("business as b", "b.id", "m.business_id")
    .select("m.role")
    .where("m.user_id", "=", caller.id)
    .where("m.business_id", "=", businessId)
    .where("m.status", "=", "active")
    .where("m.role", "=", "owner")
    .where("b.status", "in", ["pending", "rejected"])
    .executeTakeFirst();
  return !!row;
}

/** Anyone on the team (owner, staff, trainer): may post as the business. */
export function canPostAsBusiness(caller: Caller, businessId: string): Promise<boolean> {
  return hasBusinessRole(caller, businessId, ["owner", "staff", "trainer"], "any");
}

/** Owner of the gym, or super user. Pricing (membership types) and shifts. */
export function canManageGym(caller: Caller, gymId: string): Promise<boolean> {
  return hasBusinessRole(caller, gymId, ["owner"], "gym");
}

/** Owner or staff at the gym. Front-desk work: members, memberships, invoices, check-ins. */
export function canStaffGym(caller: Caller, gymId: string): Promise<boolean> {
  return hasBusinessRole(caller, gymId, ["owner", "staff"], "gym");
}

/** Anyone who works at the gym, trainers included: classes and coaching its members. */
export function canCoachAtGym(caller: Caller, gymId: string): Promise<boolean> {
  return hasBusinessRole(caller, gymId, ["owner", "staff", "trainer"], "gym");
}

/** Gyms where the caller is owner or staff (a subquery of business ids). */
export function staffedGymIds(caller: Caller) {
  return db
    .selectFrom("business_member as m")
    .innerJoin("business as b", "b.id", "m.business_id")
    .select("m.business_id as gym_id")
    .where("m.user_id", "=", caller.id)
    .where("m.status", "=", "active")
    .where("m.role", "in", ["owner", "staff"])
    .where("b.status", "=", "approved")
    .where("b.has_gym", "=", true);
}

/** Owner of the shop, or super user. */
export function canManageShop(caller: Caller, shopId: string): Promise<boolean> {
  return hasBusinessRole(caller, shopId, ["owner"], "shop");
}

/** Shop owner or staff. Items and orders. */
export function canStaffShop(caller: Caller, shopId: string): Promise<boolean> {
  return hasBusinessRole(caller, shopId, ["owner", "staff"], "shop");
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
 * True when the caller coaches or staffs at any gym where `userId` is a member,
 * or is a trainer `userId` accepted as theirs. Used for trainer access to a
 * client's sessions and meal plans.
 */
export async function coachesUser(caller: Caller, userId: string): Promise<boolean> {
  if (isSuperUser(caller)) return true;
  if (caller.is_trainer) {
    const customer = await db.selectFrom("trainer_customer").select("user_id")
      .where("trainer_id", "=", caller.id).where("user_id", "=", userId).where("status", "=", "accepted")
      .executeTakeFirst();
    if (customer) return true;
  }
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
 * True when the caller is on the team of at least one approved gym or shop
 * (or is a super user). Gates user lookup endpoints that expose emails.
 */
export async function staffsAnyBusiness(caller: Caller): Promise<boolean> {
  if (isSuperUser(caller)) return true;
  const row = await db
    .selectFrom("business_member as m")
    .innerJoin("business as b", "b.id", "m.business_id")
    .select("m.role")
    .where("m.user_id", "=", caller.id)
    .where("m.status", "=", "active")
    .where("b.status", "=", "approved")
    .executeTakeFirst();
  return !!row;
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
