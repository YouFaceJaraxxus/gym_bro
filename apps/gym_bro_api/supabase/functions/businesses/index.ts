import { type Kysely, sql } from "npm:kysely@^0.27";
import { db } from "../_shared/config.ts";
import {
  canManageBusiness,
  forbidden,
  isSuperUser,
  json,
  jsonError,
  requireCaller,
} from "../_shared/auth.ts";
import type { BusinessInsert, BusinessUpdate, Database } from "../../types/schema/public.ts";
import { reconcileRoles } from "../_shared/roles.ts";

const COLS = [
  "id",
  "name",
  "location",
  "logo",
  "working_hours_from",
  "working_hours_to",
  "working_weekdays",
  "type",
] as const;

// Columns a PUT may change (type is immutable after creation).
const UPDATABLE = [
  "name",
  "location",
  "logo",
  "working_hours_from",
  "working_hours_to",
  "working_weekdays",
] as const;

// ── Path parsing ──────────────────────────────────────────────────────────────

function parseId(pathname: string): string | null {
  const match = pathname.match(/^\/businesses\/([^/]+)$/);
  return match ? match[1] : null;
}

// ── Helpers ───────────────────────────────────────────────────────────────────

/** Deletes a business and everything hanging off it. Returns false if it didn't exist. */
async function deleteBusinessCascade(trx: Kysely<Database>, id: string): Promise<boolean> {
  const biz = await trx
    .selectFrom("business")
    .select(["id", "type"])
    .where("id", "=", id)
    .forUpdate()
    .executeTakeFirst();
  if (!biz) return false;

  // Posts (images cascade from post, but be explicit).
  await trx
    .deleteFrom("post_image")
    .where("post_id", "in", trx.selectFrom("post").select("id").where("business_id", "=", id))
    .execute();
  await trx.deleteFrom("post").where("business_id", "=", id).execute();

  const affectedUsers: string[] = [];

  // ── Gym side ──
  const typeIds = trx.selectFrom("gym_membership_type").select("id").where("gym_id", "=", id);
  const membershipIds = trx
    .selectFrom("membership")
    .select("id")
    .where("current_membership_type_id", "in", typeIds);
  await trx
    .deleteFrom("membership_invoice")
    .where((eb) =>
      eb.or([
        eb("membership_type_id", "in", typeIds),
        eb("membership_id", "in", membershipIds),
      ])
    )
    .execute();
  await trx.deleteFrom("membership").where("current_membership_type_id", "in", typeIds).execute();
  await trx.deleteFrom("gym_membership_type").where("gym_id", "=", id).execute();

  for (const table of ["employee_trainer", "employee", "trainer", "member", "gym_owner"] as const) {
    const rows = await trx.deleteFrom(table).where("gym_id", "=", id).returning("user_id").execute();
    affectedUsers.push(...rows.map((r) => r.user_id));
  }
  await trx.deleteFrom("gym").where("id", "=", id).execute();

  // ── Shop side ──
  const itemIds = trx.selectFrom("shop_item").select("id").where("shop_id", "=", id);
  await trx.deleteFrom("invoice_item").where("shop_item_id", "in", itemIds).execute();
  await trx.deleteFrom("shop_item").where("shop_id", "=", id).execute();
  for (const table of ["shop_vendor", "shop_owner"] as const) {
    const rows = await trx.deleteFrom(table).where("shop_id", "=", id).returning("user_id").execute();
    affectedUsers.push(...rows.map((r) => r.user_id));
  }
  await trx.deleteFrom("shop").where("id", "=", id).execute();

  await trx.deleteFrom("business").where("id", "=", id).execute();
  await reconcileRoles(trx, affectedUsers);
  return true;
}

// ── Handler ───────────────────────────────────────────────────────────────────

Deno.serve(async (req: Request) => {
  const url = new URL(req.url);

  // Every route requires a signed-in caller.
  const { caller, response } = await requireCaller(req);
  if (response) return response;

  // ── GET /businesses/stats — matched before /:id ───────────────────────────────
  if (req.method === "GET" && url.pathname === "/businesses/stats") {
    const gymIds = isSuperUser(caller)
      ? (await db.selectFrom("gym").select("id").execute()).map((r) => r.id)
      : (await db.selectFrom("gym_owner").select("gym_id").where("user_id", "=", caller.id).execute())
        .map((r) => r.gym_id);

    if (gymIds.length === 0) {
      return json({
        gyms: 0,
        members_total: 0,
        active_memberships: 0,
        staff_total: 0,
        invoices_month_count: 0,
        invoices_month_total: "0.00",
        unpaid_invoices_count: 0,
        expiring_soon: [],
      });
    }

    // Lazily expire memberships so the active counts are accurate.
    await db
      .updateTable("membership")
      .set({ is_active: false })
      .where("is_active", "=", true)
      .where(sql<boolean>`to_date < CURRENT_DATE`)
      .execute();

    const [members, active, staff, monthInvoices, unpaid, expiring] = await Promise.all([
      db
        .selectFrom("member")
        .select(sql<string>`COUNT(DISTINCT user_id)`.as("count"))
        .where("gym_id", "in", gymIds)
        .executeTakeFirstOrThrow(),
      db
        .selectFrom("membership")
        .innerJoin("gym_membership_type", "gym_membership_type.id", "membership.current_membership_type_id")
        .select(sql<string>`COUNT(*)`.as("count"))
        .where("gym_membership_type.gym_id", "in", gymIds)
        .where("membership.is_active", "=", true)
        .executeTakeFirstOrThrow(),
      sql<{ count: string }>`
        SELECT COUNT(DISTINCT user_id) AS count FROM (
          SELECT user_id FROM employee         WHERE gym_id = ANY(${gymIds}::uuid[])
          UNION SELECT user_id FROM employee_trainer WHERE gym_id = ANY(${gymIds}::uuid[])
          UNION SELECT user_id FROM trainer          WHERE gym_id = ANY(${gymIds}::uuid[])
        ) s
      `.execute(db),
      db
        .selectFrom("membership_invoice")
        .innerJoin("gym_membership_type", "gym_membership_type.id", "membership_invoice.membership_type_id")
        .select([
          sql<string>`COUNT(*)`.as("count"),
          sql<string>`COALESCE(SUM(membership_invoice.amount), 0)::numeric(12, 2)::text`.as("total"),
        ])
        .where("gym_membership_type.gym_id", "in", gymIds)
        .where("membership_invoice.status", "!=", "void")
        .where(sql<boolean>`membership_invoice.issued_at >= date_trunc('month', now())`)
        .executeTakeFirstOrThrow(),
      db
        .selectFrom("membership_invoice")
        .innerJoin("gym_membership_type", "gym_membership_type.id", "membership_invoice.membership_type_id")
        .select(sql<string>`COUNT(*)`.as("count"))
        .where("gym_membership_type.gym_id", "in", gymIds)
        .where("membership_invoice.status", "=", "unpaid")
        .executeTakeFirstOrThrow(),
      db
        .selectFrom("membership")
        .innerJoin("gym_membership_type", "gym_membership_type.id", "membership.current_membership_type_id")
        .innerJoin("business", "business.id", "gym_membership_type.gym_id")
        .innerJoin("users", "users.id", "membership.user_id")
        .select([
          "membership.id as membership_id",
          "membership.user_id",
          "users.name",
          "users.last_name",
          "gym_membership_type.gym_id",
          "business.name as gym_name",
          sql<string>`to_char(membership.to_date, 'YYYY-MM-DD')`.as("to_date"),
        ])
        .where("gym_membership_type.gym_id", "in", gymIds)
        .where("membership.is_active", "=", true)
        .where(sql<boolean>`membership.to_date BETWEEN CURRENT_DATE AND CURRENT_DATE + 14`)
        .orderBy("membership.to_date", "asc")
        .execute(),
    ]);

    return json({
      gyms: gymIds.length,
      members_total: Number(members.count),
      active_memberships: Number(active.count),
      staff_total: Number(staff.rows[0]?.count ?? 0),
      invoices_month_count: Number(monthInvoices.count),
      invoices_month_total: monthInvoices.total,
      unpaid_invoices_count: Number(unpaid.count),
      expiring_soon: expiring,
    });
  }

  const id = parseId(url.pathname);

  // ── GET /businesses — the caller's owned businesses (super: all) ─────────────
  if (req.method === "GET" && !id) {
    const typeFilter = url.searchParams.get("type");

    // Super users can see every business, not just ones they own.
    if (isSuperUser(caller)) {
      let allQuery = db.selectFrom("business").select(COLS);
      if (typeFilter === "gym" || typeFilter === "shop") {
        allQuery = allQuery.where("type", "=", typeFilter);
      }
      return json(await allQuery.orderBy("name", "asc").execute());
    }

    const [gymOwners, shopOwners] = await Promise.all([
      db.selectFrom("gym_owner").select(["gym_id"]).where("user_id", "=", caller.id).execute(),
      db.selectFrom("shop_owner").select(["shop_id"]).where("user_id", "=", caller.id).execute(),
    ]);

    const ownedIds = [
      ...gymOwners.map((r) => r.gym_id),
      ...shopOwners.map((r) => r.shop_id),
    ];

    if (ownedIds.length === 0) return json([]);

    let query = db.selectFrom("business").select(COLS).where("id", "in", ownedIds);
    if (typeFilter === "gym" || typeFilter === "shop") {
      query = query.where("type", "=", typeFilter);
    }
    return json(await query.execute());
  }

  // ── GET /businesses/:id — any signed-in user ─────────────────────────────────
  if (req.method === "GET" && id) {
    const b = await db
      .selectFrom("business")
      .select(COLS)
      .where("id", "=", id)
      .executeTakeFirst();
    if (!b) return jsonError("Business not found", 404);
    return json(b);
  }

  // ── POST /businesses ──────────────────────────────────────────────────────────
  // Creates a business row, the gym or shop sub-row and the caller's owner row atomically.
  if (req.method === "POST" && !id) {
    const body = await req.json().catch(() => null);
    const { name, location, logo, working_hours_from, working_hours_to, working_weekdays, type } =
      body ?? {};

    if (!name || !location || !working_hours_from || !working_hours_to || !working_weekdays || !type) {
      return jsonError(
        "Missing required fields: name, location, working_hours_from, working_hours_to, working_weekdays, type",
        400,
      );
    }
    if (type !== "gym" && type !== "shop") return jsonError("type must be 'gym' or 'shop'", 400);

    const insert: BusinessInsert = {
      name,
      location,
      logo: logo ?? null,
      working_hours_from,
      working_hours_to,
      working_weekdays,
      type,
    };

    const business = await db.transaction().execute(async (trx) => {
      const biz = await trx
        .insertInto("business")
        .values(insert)
        .returning(COLS)
        .executeTakeFirstOrThrow();
      if (type === "gym") {
        await trx.insertInto("gym").values({ id: biz.id }).execute();
        await trx.insertInto("gym_owner").values({ user_id: caller.id, gym_id: biz.id }).execute();
      } else {
        await trx.insertInto("shop").values({ id: biz.id }).execute();
        await trx.insertInto("shop_owner").values({ user_id: caller.id, shop_id: biz.id }).execute();
      }
      return biz;
    });

    return json(business, 201);
  }

  // ── PUT /businesses/:id — type is immutable after creation ───────────────────
  if (req.method === "PUT" && id) {
    const body = await req.json().catch(() => null);
    if (!body || typeof body !== "object") return jsonError("Body must not be empty", 400);

    const update: BusinessUpdate = {};
    for (const key of UPDATABLE) {
      if (key in body) (update as Record<string, unknown>)[key] = body[key];
    }
    if (Object.keys(update).length === 0) return jsonError("Body must not be empty", 400);

    const exists = await db.selectFrom("business").select("id").where("id", "=", id).executeTakeFirst();
    if (!exists) return jsonError("Business not found", 404);
    if (!(await canManageBusiness(caller, id))) return forbidden();

    const b = await db
      .updateTable("business")
      .set(update)
      .where("id", "=", id)
      .returning(COLS)
      .executeTakeFirst();
    if (!b) return jsonError("Business not found", 404);
    return json(b);
  }

  // ── DELETE /businesses/:id ────────────────────────────────────────────────────
  // Removes everything hanging off the business in one transaction.
  if (req.method === "DELETE" && id) {
    const exists = await db.selectFrom("business").select("id").where("id", "=", id).executeTakeFirst();
    if (!exists) return jsonError("Business not found", 404);
    if (!(await canManageBusiness(caller, id))) return forbidden();

    const found = await db.transaction().execute((trx) => deleteBusinessCascade(trx, id));
    if (!found) return jsonError("Business not found", 404);
    return new Response(null, { status: 204 });
  }

  return jsonError("Not found", 404);
});
