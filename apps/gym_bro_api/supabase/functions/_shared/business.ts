import { type Kysely, sql } from "npm:kysely@^0.27";
import { db } from "./config.ts";
import { notify } from "./notify.ts";
import type { BusinessRole, BusinessStatus, Database } from "../../types/schema/public.ts";

/** Postgres error code (e.g. "23505" unique violation) from a pg error, if any. */
export function pgCode(err: unknown): string | undefined {
  return typeof err === "object" && err !== null && "code" in err
    ? String((err as { code: unknown }).code)
    : undefined;
}

export const BUSINESS_ROLES: readonly BusinessRole[] = ["owner", "staff", "trainer"];

/** Columns of a business as every endpoint returns it. */
export const BUSINESS_COLS = [
  "business.id",
  "business.name",
  "business.location",
  "business.logo",
  "business.working_hours_from",
  "business.working_hours_to",
  "business.working_weekdays",
  "business.latitude",
  "business.longitude",
  "business.has_gym",
  "business.has_shop",
  "business.status",
  "business.bio",
  "business.website",
  "business.phone",
  "business.created_at",
] as const;

/**
 * SQL subquery: ids of approved businesses (gyms, by default) where `userId`
 * actively holds one of `roles`. For `... IN (${teamBusinessIdsSql(...)})`.
 */
export function teamBusinessIdsSql(
  userId: string,
  roles: readonly BusinessRole[] = BUSINESS_ROLES,
  side: "gym" | "shop" | "any" = "gym",
) {
  return sql<{ business_id: string }>`
    SELECT tm.business_id FROM business_member tm JOIN business tb ON tb.id = tm.business_id
    WHERE tm.user_id = ${userId} AND tm.status = 'active' AND tb.status = 'approved'
      AND tm.role::text = ANY(${[...roles]}::text[])
      ${side === "gym" ? sql`AND tb.has_gym` : side === "shop" ? sql`AND tb.has_shop` : sql``}`;
}

/** User ids of the business's active team members with one of `roles`. */
export async function businessTeamIds(
  businessId: string,
  roles: readonly BusinessRole[] = ["owner"],
): Promise<string[]> {
  const rows = await db
    .selectFrom("business_member")
    .select("user_id")
    .distinct()
    .where("business_id", "=", businessId)
    .where("status", "=", "active")
    .where("role", "in", [...roles])
    .execute();
  return rows.map((r) => r.user_id);
}

// ── What someone is, shown on their profile ───────────────────────────────────

export type BusinessRef = { id: string; name: string; logo: string | null; has_gym: boolean; has_shop: boolean };
export type Affiliations = { is_trainer: boolean; owner_of: BusinessRef[]; trainer_at: BusinessRef[] };

/**
 * "Owner of …" and "Trainer at …" for each user: approved businesses and
 * accepted roles only. Staff roles are never shown.
 */
export async function affiliationsOf(userIds: string[]): Promise<Map<string, Affiliations>> {
  const ids = [...new Set(userIds)];
  const out = new Map<string, Affiliations>();
  if (ids.length === 0) return out;
  const users = await db.selectFrom("users").select(["id", "is_trainer"]).where("id", "in", ids).execute();
  for (const u of users) out.set(u.id, { is_trainer: u.is_trainer, owner_of: [], trainer_at: [] });
  const rows = await db
    .selectFrom("business_member as m")
    .innerJoin("business as b", "b.id", "m.business_id")
    .select(["m.user_id", "m.role", "b.id", "b.name", "b.logo", "b.has_gym", "b.has_shop"])
    .where("m.user_id", "in", ids)
    .where("m.status", "=", "active")
    .where("m.role", "in", ["owner", "trainer"])
    .where("b.status", "=", "approved")
    .orderBy("m.joined_at", "asc")
    .execute();
  for (const r of rows) {
    const a = out.get(r.user_id);
    if (!a) continue;
    const ref = { id: r.id, name: r.name, logo: r.logo, has_gym: r.has_gym, has_shop: r.has_shop };
    (r.role === "owner" ? a.owner_of : a.trainer_at).push(ref);
  }
  return out;
}

// ── The caller's own businesses (Home menu) ───────────────────────────────────

export type MyBusiness = BusinessRef & {
  status: BusinessStatus;
  review_note: string | null;
  roles: BusinessRole[];
};

/**
 * Every business the user is on the team of, with their roles. Owners see
 * their businesses in any status (to follow the review); staff and trainers
 * only approved ones.
 */
export async function myBusinesses(userId: string): Promise<MyBusiness[]> {
  const rows = await db
    .selectFrom("business_member as m")
    .innerJoin("business as b", "b.id", "m.business_id")
    .select([
      "b.id",
      "b.name",
      "b.logo",
      "b.has_gym",
      "b.has_shop",
      "b.status",
      "b.review_note",
      sql<BusinessRole[]>`array_agg(m.role::text ORDER BY m.role)`.as("roles"),
    ])
    .where("m.user_id", "=", userId)
    .where("m.status", "=", "active")
    .groupBy(["b.id"])
    .having(sql<boolean>`b.status = 'approved' OR bool_or(m.role = 'owner')`)
    .orderBy("b.name")
    .execute();
  return rows;
}

/** How many business invites the user hasn't answered yet. */
export async function pendingInviteCount(userId: string): Promise<number> {
  const row = await db
    .selectFrom("business_member as m")
    .innerJoin("business as b", "b.id", "m.business_id")
    .select(sql<string>`COUNT(*)`.as("count"))
    .where("m.user_id", "=", userId)
    .where("m.status", "=", "invited")
    .where("b.status", "=", "approved")
    .executeTakeFirstOrThrow();
  return Number(row.count);
}

// ── Invites ───────────────────────────────────────────────────────────────────

export const ROLE_LABELS: Record<BusinessRole, string> = {
  owner: "a co-owner",
  staff: "staff",
  trainer: "a trainer",
};

/**
 * Invites `userId` to the business in `role` (an `invited` row plus a
 * notification). Returns false when they already hold or were offered it.
 */
export async function inviteToBusiness(
  q: Kysely<Database>,
  business: { id: string; name: string },
  userId: string,
  role: BusinessRole,
  inviter: { id: string; name: string; last_name: string },
): Promise<boolean> {
  const res = await q
    .insertInto("business_member")
    .values({ business_id: business.id, user_id: userId, role, status: "invited", invited_by: inviter.id })
    .onConflict((oc) => oc.columns(["business_id", "user_id", "role"]).doNothing())
    .executeTakeFirst();
  if (Number(res.numInsertedOrUpdatedRows ?? 0) === 0) return false;
  const inviterName = `${inviter.name} ${inviter.last_name}`.trim();
  await notify([userId], {
    type: "business_invite",
    title: `Join ${business.name} as ${ROLE_LABELS[role]}`,
    body: `${inviterName} invited you to join ${business.name} as ${ROLE_LABELS[role]}.`,
    metadata: {
      invite_status: "pending",
      business_id: business.id,
      business_name: business.name,
      role,
      inviter_id: inviter.id,
    },
  });
  return true;
}

export type AnswerResult = { ok: true } | { ok: false; status: number; error: string };

/**
 * Accepts or declines the user's invite to `role` at the business. Accepting
 * a trainer role also makes them a trainer; joining follows the business.
 * Any invite notification for it is marked answered.
 */
export async function answerBusinessInvite(
  user: { id: string; name: string; last_name: string },
  businessId: string,
  role: BusinessRole,
  accept: boolean,
): Promise<AnswerResult> {
  const invite = await db
    .selectFrom("business_member as m")
    .innerJoin("business as b", "b.id", "m.business_id")
    .select(["b.name", "b.status as business_status"])
    .where("m.business_id", "=", businessId)
    .where("m.user_id", "=", user.id)
    .where("m.role", "=", role)
    .where("m.status", "=", "invited")
    .executeTakeFirst();
  if (!invite) return { ok: false, status: 404, error: "Invite not found" };
  if (accept && invite.business_status !== "approved") {
    return { ok: false, status: 409, error: "This business isn't active right now" };
  }

  await db.transaction().execute(async (trx) => {
    if (accept) {
      await trx
        .updateTable("business_member")
        .set({ status: "active", joined_at: sql`NOW()` })
        .where("business_id", "=", businessId)
        .where("user_id", "=", user.id)
        .where("role", "=", role)
        .execute();
      if (role === "trainer") {
        await trx.updateTable("users").set({ is_trainer: true }).where("id", "=", user.id).execute();
      }
      await trx
        .insertInto("business_follow")
        .values({ user_id: user.id, business_id: businessId })
        .onConflict((oc) => oc.doNothing())
        .execute();
    } else {
      await trx
        .deleteFrom("business_member")
        .where("business_id", "=", businessId)
        .where("user_id", "=", user.id)
        .where("role", "=", role)
        .execute();
    }
    await sql`
      UPDATE notification
      SET is_read = TRUE,
          metadata = metadata || jsonb_build_object('invite_status', ${accept ? "accepted" : "declined"}::text)
      WHERE user_id = ${user.id} AND type = 'business_invite'
        AND metadata->>'business_id' = ${businessId} AND metadata->>'role' = ${role}
        AND metadata->>'invite_status' = 'pending'
    `.execute(trx);
  });

  if (accept) {
    const fullName = `${user.name} ${user.last_name}`.trim();
    const owners = (await businessTeamIds(businessId)).filter((id) => id !== user.id);
    await notify(owners, {
      type: "business_join",
      title: `${fullName} joined ${invite.name}`,
      body: `${fullName} accepted your invitation to join ${invite.name} as ${ROLE_LABELS[role]}.`,
      metadata: { business_id: businessId, user_id: user.id, role },
    });
  }
  return { ok: true };
}
