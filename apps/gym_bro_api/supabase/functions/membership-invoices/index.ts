import { db } from "../_shared/config.ts";
import {
  canStaffGym,
  forbidden,
  isSuperUser,
  json,
  jsonError,
  requireCaller,
  staffedGymIds,
} from "../_shared/auth.ts";
import { notify } from "../_shared/notify.ts";
import type { InvoiceStatus, MembershipInvoiceInsert } from "../../types/schema/public.ts";
import { pgCode } from "../_shared/roles.ts";

const STATUSES: InvoiceStatus[] = ["unpaid", "paid", "void"];

// ── Path parsing ──────────────────────────────────────────────────────────────

function parseId(pathname: string): string | null {
  const match = pathname.match(/^\/membership-invoices\/([^/]+)$/);
  return match ? match[1] : null;
}

// ── Helpers ───────────────────────────────────────────────────────────────────

/** Invoices joined with member, gym and membership type info. */
function invoiceQuery() {
  return db
    .selectFrom("membership_invoice as mi")
    .innerJoin("membership as m", "m.id", "mi.membership_id")
    .innerJoin("users as u", "u.id", "m.user_id")
    .innerJoin("gym_membership_type as t", "t.id", "mi.membership_type_id")
    .innerJoin("business as b", "b.id", "t.gym_id")
    .select([
      "mi.id",
      "mi.membership_id",
      "mi.membership_type_id",
      "mi.issued_at",
      "mi.amount",
      "mi.status",
      "mi.paid_at",
      "m.user_id",
      "u.name as member_name",
      "u.last_name as member_last_name",
      "t.gym_id",
      "b.name as gym_name",
      "t.name as membership_type_name",
    ]);
}

/** The gym an invoice belongs to (through its membership type). */
async function gymIdForInvoice(invoiceId: string): Promise<string | null> {
  const row = await db
    .selectFrom("membership_invoice")
    .innerJoin("gym_membership_type", "gym_membership_type.id", "membership_invoice.membership_type_id")
    .select("gym_membership_type.gym_id")
    .where("membership_invoice.id", "=", invoiceId)
    .executeTakeFirst();
  return row?.gym_id ?? null;
}

// ── Handler ───────────────────────────────────────────────────────────────────

Deno.serve(async (req: Request) => {
  const { caller, response } = await requireCaller(req);
  if (response) return response;

  const url = new URL(req.url);
  const id = parseId(url.pathname);

  // ── POST /membership-invoices ─────────────────────────────────────────────────
  // membership_type_id defaults to the membership's current type and amount to
  // that type's monthly cost.
  if (req.method === "POST" && !id) {
    const body = await req.json().catch(() => null);
    const { membership_id, membership_type_id, amount } = body ?? {};
    if (!membership_id) return jsonError("Missing required field: membership_id", 400);

    const membership = await db
      .selectFrom("membership")
      .innerJoin("gym_membership_type", "gym_membership_type.id", "membership.current_membership_type_id")
      .select([
        "membership.user_id",
        "membership.current_membership_type_id",
        "gym_membership_type.gym_id",
      ])
      .where("membership.id", "=", membership_id)
      .executeTakeFirst();
    if (!membership) return jsonError("Membership not found", 400);
    if (!(await canStaffGym(caller, membership.gym_id))) return forbidden();

    const typeId: string = membership_type_id ?? membership.current_membership_type_id;
    const type = await db
      .selectFrom("gym_membership_type")
      .select(["gym_id", "monthly_cost"])
      .where("id", "=", typeId)
      .executeTakeFirst();
    if (!type) return jsonError("Membership type not found", 400);
    if (type.gym_id !== membership.gym_id) {
      return jsonError("Membership type must belong to the membership's gym", 400);
    }

    const insert: MembershipInvoiceInsert = {
      membership_id,
      membership_type_id: typeId,
      amount: amount ?? type.monthly_cost,
    };
    let created;
    try {
      created = await db
        .insertInto("membership_invoice")
        .values(insert)
        .returning("id")
        .executeTakeFirstOrThrow();
    } catch (err) {
      const code = pgCode(err);
      if (code === "23503") return jsonError("Membership or membership type not found", 400);
      if (code === "22P02") return jsonError("Invalid amount", 400);
      throw err;
    }

    const row = await invoiceQuery().where("mi.id", "=", created.id).executeTakeFirstOrThrow();
    await notify([row.user_id], {
      type: "invoice_issued",
      title: `New invoice from ${row.gym_name}`,
      body: `An invoice of ${row.amount} was issued for your ${row.membership_type_name} membership.`,
      metadata: {
        invoice_id: row.id,
        membership_id: row.membership_id,
        gym_id: row.gym_id,
        amount: row.amount,
      },
    });
    return json(row, 201);
  }

  // ── GET /membership-invoices — ?membership_id=, ?gym_id=, ?status=, ?user_id= ─
  // Super users see everything; everyone else sees invoices of gyms they staff
  // plus their own invoices. Filters narrow that set further.
  if (req.method === "GET" && !id) {
    const membershipId = url.searchParams.get("membership_id");
    const gymId = url.searchParams.get("gym_id");
    const status = url.searchParams.get("status");
    const userId = url.searchParams.get("user_id");

    let query = invoiceQuery();
    if (!isSuperUser(caller)) {
      query = query.where((eb) =>
        eb.or([
          eb("t.gym_id", "in", staffedGymIds(caller)),
          eb("m.user_id", "=", caller.id),
        ])
      );
    }
    if (membershipId) query = query.where("mi.membership_id", "=", membershipId);
    if (gymId) query = query.where("t.gym_id", "=", gymId);
    if (userId) query = query.where("m.user_id", "=", userId);
    if (status) {
      if (!STATUSES.includes(status as InvoiceStatus)) {
        return jsonError("status must be 'unpaid', 'paid' or 'void'", 400);
      }
      query = query.where("mi.status", "=", status as InvoiceStatus);
    }
    return json(await query.orderBy("mi.issued_at", "desc").execute());
  }

  // ── GET /membership-invoices/:id ──────────────────────────────────────────────
  if (req.method === "GET" && id) {
    const row = await invoiceQuery().where("mi.id", "=", id).executeTakeFirst();
    if (!row) return jsonError("Invoice not found", 404);
    if (row.user_id !== caller.id && !(await canStaffGym(caller, row.gym_id))) return forbidden();
    return json(row);
  }

  // ── PUT /membership-invoices/:id — status only ────────────────────────────────
  if (req.method === "PUT" && id) {
    const body = await req.json().catch(() => null);
    const status = body?.status;
    if (!STATUSES.includes(status)) {
      return jsonError("status must be 'unpaid', 'paid' or 'void'", 400);
    }

    const gymId = await gymIdForInvoice(id);
    if (!gymId) return jsonError("Invoice not found", 404);
    if (!(await canStaffGym(caller, gymId))) return forbidden();

    await db
      .updateTable("membership_invoice")
      .set({ status, paid_at: status === "paid" ? new Date().toISOString() : null })
      .where("id", "=", id)
      .execute();

    const row = await invoiceQuery().where("mi.id", "=", id).executeTakeFirst();
    if (!row) return jsonError("Invoice not found", 404);
    return json(row);
  }

  // ── DELETE /membership-invoices/:id ───────────────────────────────────────────
  if (req.method === "DELETE" && id) {
    const gymId = await gymIdForInvoice(id);
    if (!gymId) return jsonError("Invoice not found", 404);
    if (!(await canStaffGym(caller, gymId))) return forbidden();

    await db.deleteFrom("membership_invoice").where("id", "=", id).execute();
    return new Response(null, { status: 204 });
  }

  return jsonError("Not found", 404);
});
