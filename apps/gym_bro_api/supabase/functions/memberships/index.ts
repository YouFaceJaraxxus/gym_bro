import { sql } from "npm:kysely@^0.27";
import { db } from "../_shared/config.ts";
import {
  canStaffGym,
  forbidden,
  gymIdForMembership,
  gymIdForMembershipType,
  isSuperUser,
  json,
  jsonError,
  requireCaller,
  staffedGymIds,
} from "../_shared/auth.ts";
import { businessName, notify } from "../_shared/notify.ts";
import type { MembershipInsert, MembershipUpdate } from "../../types/schema/public.ts";
import { pgCode } from "../_shared/roles.ts";
import { cancelSubscriptionAtPeriodEnd, StripeError, stripeEnabled } from "../_shared/stripe.ts";

// ── Path parsing ──────────────────────────────────────────────────────────────

function parseId(pathname: string): string | null {
  const match = pathname.match(/^\/memberships\/([^/]+)$/);
  return match ? match[1] : null;
}

// ── Helpers ───────────────────────────────────────────────────────────────────

/** Flags memberships that ended before today as inactive. */
async function expireLapsedMemberships(): Promise<void> {
  await db
    .updateTable("membership")
    .set({ is_active: false })
    .where("is_active", "=", true)
    .where(sql<boolean>`to_date < CURRENT_DATE`)
    .execute();
}

/**
 * Creates one `membership_expiring` notification per active membership of the
 * user that ends within 7 days, unless one was already sent for it.
 */
async function notifyExpiringSoon(userId: string): Promise<void> {
  const due = await db
    .selectFrom("membership")
    .innerJoin("gym_membership_type", "gym_membership_type.id", "membership.current_membership_type_id")
    .innerJoin("business", "business.id", "gym_membership_type.gym_id")
    .select([
      "membership.id",
      "membership.user_id",
      "gym_membership_type.gym_id",
      "business.name as gym_name",
      sql<string>`to_char(membership.to_date, 'YYYY-MM-DD')`.as("to_date"),
    ])
    .where("membership.user_id", "=", userId)
    .where("membership.is_active", "=", true)
    .where(sql<boolean>`membership.to_date BETWEEN CURRENT_DATE AND CURRENT_DATE + 7`)
    .where(({ not, exists, selectFrom }) =>
      not(exists(
        selectFrom("notification")
          .select("notification.id")
          .where("notification.user_id", "=", userId)
          .where("notification.type", "=", "membership_expiring")
          .where(sql<boolean>`notification.metadata->>'membership_id' = membership.id::text`),
      ))
    )
    .execute();

  for (const m of due) {
    await notify([m.user_id], {
      type: "membership_expiring",
      title: `Your ${m.gym_name} membership is expiring`,
      body: `Your membership ends on ${m.to_date}. Renew it at the front desk to keep training.`,
      metadata: { membership_id: m.id, gym_id: m.gym_id, to_date: m.to_date },
    });
  }
}

async function notifyExtended(
  userId: string,
  membershipId: string,
  gymId: string,
  toDate: string,
  isNew: boolean,
): Promise<void> {
  const gymName = await businessName(gymId);
  await notify([userId], {
    type: "member_subscription_extended",
    title: isNew ? `Your ${gymName} membership is active` : `Your ${gymName} membership was extended`,
    body: `Your membership is valid until ${toDate}.`,
    metadata: { membership_id: membershipId, gym_id: gymId, to_date: toDate },
  });
}

// ── Handler ───────────────────────────────────────────────────────────────────

Deno.serve(async (req: Request) => {
  const { caller, response } = await requireCaller(req);
  if (response) return response;

  const url = new URL(req.url);
  const id = parseId(url.pathname);

  // ── POST /memberships ─────────────────────────────────────────────────────────
  if (req.method === "POST" && !id) {
    const body = await req.json().catch(() => null);
    const { user_id, current_membership_type_id, from_date, to_date, is_active } = body ?? {};
    if (!user_id || !current_membership_type_id || !from_date || !to_date) {
      return jsonError(
        "Missing required fields: user_id, current_membership_type_id, from_date, to_date",
        400,
      );
    }
    const gymId = await gymIdForMembershipType(current_membership_type_id);
    if (!gymId) return jsonError("Membership type not found", 400);
    if (!(await canStaffGym(caller, gymId))) return forbidden();

    const insert: MembershipInsert = {
      user_id,
      current_membership_type_id,
      from_date,
      to_date,
      ...(is_active != null && { is_active }),
    };
    let created;
    try {
      created = await db
        .insertInto("membership")
        .values(insert)
        .returningAll()
        .returning(sql<string>`to_char(to_date, 'YYYY-MM-DD')`.as("to_date_ymd"))
        .executeTakeFirstOrThrow();
    } catch (err) {
      if (pgCode(err) === "23503") return jsonError("User not found", 400);
      throw err;
    }
    const { to_date_ymd, ...row } = created;
    await notifyExtended(row.user_id, row.id, gymId, to_date_ymd, true);
    return json(row, 201);
  }

  // ── GET /memberships — optional ?user_id=, ?is_active=, ?gym_id= filters ─────
  // Super users see everything; everyone else sees memberships of gyms they
  // staff plus their own. Filters narrow that set further.
  if (req.method === "GET" && !id) {
    await expireLapsedMemberships();

    const userId = url.searchParams.get("user_id");
    const gymId = url.searchParams.get("gym_id");
    const isActiveParam = url.searchParams.get("is_active");

    let query = db.selectFrom("membership").selectAll();
    if (!isSuperUser(caller)) {
      query = query.where((eb) =>
        eb.or([
          eb(
            "current_membership_type_id",
            "in",
            db.selectFrom("gym_membership_type").select("id").where("gym_id", "in", staffedGymIds(caller)),
          ),
          eb("user_id", "=", caller.id),
        ])
      );
    }
    if (userId) query = query.where("user_id", "=", userId);
    if (gymId) {
      query = query.where(
        "current_membership_type_id",
        "in",
        db.selectFrom("gym_membership_type").select("id").where("gym_id", "=", gymId),
      );
    }
    if (isActiveParam != null) {
      query = query.where("is_active", "=", isActiveParam === "true");
    }
    const rows = await query.execute();
    // Only the member or staff who can see their memberships trigger the warning.
    if (userId && (userId === caller.id || rows.length > 0)) await notifyExpiringSoon(userId);
    return json(rows);
  }

  // ── GET /memberships/:id ──────────────────────────────────────────────────────
  if (req.method === "GET" && id) {
    await expireLapsedMemberships();
    const row = await db
      .selectFrom("membership")
      .selectAll()
      .where("id", "=", id)
      .executeTakeFirst();
    if (!row) return jsonError("Membership not found", 404);
    if (row.user_id !== caller.id) {
      const gymId = await gymIdForMembership(id);
      if (!gymId || !(await canStaffGym(caller, gymId))) return forbidden();
    }
    return json(row);
  }

  // ── PUT /memberships/:id ──────────────────────────────────────────────────────
  // Updatable: to_date, is_active, current_membership_type_id (same gym only),
  // auto_renew (staff can only turn it off; turning it on happens through a
  // Stripe subscription purchase in the payments function).
  if (req.method === "PUT" && id) {
    const body = await req.json().catch(() => null);
    if (!body || typeof body !== "object") return jsonError("Body must not be empty", 400);

    const update: MembershipUpdate = {};
    if (body.to_date !== undefined) update.to_date = body.to_date;
    if (body.is_active !== undefined) update.is_active = body.is_active;
    if (body.current_membership_type_id !== undefined) {
      update.current_membership_type_id = body.current_membership_type_id;
    }
    if (body.auto_renew !== undefined) {
      if (body.auto_renew !== false) {
        return jsonError("auto_renew can only be turned off here; members turn it on by paying in the app", 400);
      }
      update.auto_renew = false;
    }
    if (Object.keys(update).length === 0) return jsonError("Body must not be empty", 400);

    const existing = await db
      .selectFrom("membership")
      .innerJoin("gym_membership_type", "gym_membership_type.id", "membership.current_membership_type_id")
      .select([
        "gym_membership_type.gym_id",
        "membership.auto_renew",
        "membership.stripe_subscription_id",
        sql<string>`to_char(membership.to_date, 'YYYY-MM-DD')`.as("to_date_ymd"),
      ])
      .where("membership.id", "=", id)
      .executeTakeFirst();
    if (!existing) return jsonError("Membership not found", 404);
    if (!(await canStaffGym(caller, existing.gym_id))) return forbidden();

    // Stop the Stripe subscription first so the member isn't charged again.
    if (update.auto_renew === false && existing.auto_renew && existing.stripe_subscription_id && stripeEnabled()) {
      try {
        await cancelSubscriptionAtPeriodEnd(existing.stripe_subscription_id);
      } catch (err) {
        if (!(err instanceof StripeError && err.code === "resource_missing")) {
          console.error("cancel subscription failed", existing.stripe_subscription_id, err);
          return jsonError(`Couldn't stop the card subscription: ${(err as Error).message}`, 502);
        }
      }
    }

    if (update.current_membership_type_id) {
      const newGymId = await gymIdForMembershipType(update.current_membership_type_id);
      if (!newGymId) return jsonError("Membership type not found", 400);
      if (newGymId !== existing.gym_id) {
        return jsonError("Membership type must belong to the same gym", 400);
      }
    }

    const updated = await db
      .updateTable("membership")
      .set({ ...update, last_updated_date: new Date().toISOString() })
      .where("id", "=", id)
      .returningAll()
      .returning(sql<string>`to_char(to_date, 'YYYY-MM-DD')`.as("to_date_ymd"))
      .executeTakeFirst();
    if (!updated) return jsonError("Membership not found", 404);

    const { to_date_ymd, ...row } = updated;
    if (to_date_ymd > existing.to_date_ymd) {
      await notifyExtended(row.user_id, row.id, existing.gym_id, to_date_ymd, false);
    }
    return json(row);
  }

  // ── DELETE /memberships/:id ───────────────────────────────────────────────────
  if (req.method === "DELETE" && id) {
    const existing = await db
      .selectFrom("membership")
      .innerJoin("gym_membership_type", "gym_membership_type.id", "membership.current_membership_type_id")
      .select(["gym_membership_type.gym_id"])
      .where("membership.id", "=", id)
      .executeTakeFirst();
    if (!existing) return jsonError("Membership not found", 404);
    if (!(await canStaffGym(caller, existing.gym_id))) return forbidden();

    try {
      await db.deleteFrom("membership").where("id", "=", id).execute();
    } catch (err) {
      if (pgCode(err) === "23503") {
        return jsonError("This membership has invoices — void or delete them first", 409);
      }
      throw err;
    }
    return new Response(null, { status: 204 });
  }

  return jsonError("Not found", 404);
});
