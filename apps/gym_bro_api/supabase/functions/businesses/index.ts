import { type Kysely, sql } from "npm:kysely@^0.27";
import { db, supabaseAdmin } from "../_shared/config.ts";
import {
  canEditBusinessProfile,
  canManageBusiness,
  type Caller,
  forbidden,
  isSuperUser,
  json,
  jsonError,
  requireCaller,
} from "../_shared/auth.ts";
import {
  answerBusinessInvite,
  BUSINESS_COLS,
  BUSINESS_ROLES,
  businessTeamIds,
  inviteToBusiness,
  myBusinesses,
  pgCode,
} from "../_shared/business.ts";
import { notify } from "../_shared/notify.ts";
import type {
  BusinessRole,
  BusinessStatus,
  BusinessUpdate,
  Database,
  UserInsert,
} from "../../types/schema/public.ts";

// Gyms, shops (a business can be both) and their profiles.
//
//   GET    /businesses                       businesses I'm on the team of, with my roles
//                                            (?all=1: every business, super user)
//   GET    /businesses/search?q=&side=       approved businesses (gym|shop)
//   GET    /businesses/review?status=        super user: the verification queue
//   GET    /businesses/stats                 numbers over the gyms I own
//   GET    /businesses/invites               my unanswered team invites
//   POST   /businesses                       apply for a new business (pending review)
//   GET    /businesses/:id                   the profile
//   PUT    /businesses/:id                   edit it (owner/staff; sides: owner)
//   DELETE /businesses/:id                   owner
//   POST   /businesses/:id/review            super user: approve | reject | block
//   POST   /businesses/:id/resubmit          owner: back to pending after a rejection
//   PUT|DELETE /businesses/:id/follow
//   GET    /businesses/:id/team              team and open invites
//   POST   /businesses/:id/team              owner: invite someone {user_id|email, role}
//   DELETE /businesses/:id/team/:userId?role= owner removes, or a member leaves
//   POST   /businesses/:id/invites/:role/accept|decline

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

// Profile fields owners and staff may change.
const PROFILE_FIELDS = [
  "name",
  "location",
  "logo",
  "working_hours_from",
  "working_hours_to",
  "working_weekdays",
  "latitude",
  "longitude",
  "bio",
  "website",
  "phone",
] as const;

const REVIEW_STATUSES: readonly BusinessStatus[] = ["approved", "rejected", "blocked"];

// ── Path parsing ──────────────────────────────────────────────────────────────

type Route =
  | { kind: "list" }
  | { kind: "search" }
  | { kind: "review_queue" }
  | { kind: "stats" }
  | { kind: "my_invites" }
  | { kind: "one"; id: string }
  | { kind: "review"; id: string }
  | { kind: "resubmit"; id: string }
  | { kind: "follow"; id: string }
  | { kind: "team"; id: string }
  | { kind: "team_member"; id: string; userId: string }
  | { kind: "answer"; id: string; role: BusinessRole; accept: boolean }
  | { kind: "unknown" };

function parseRoute(pathname: string): Route {
  const p = pathname.replace(/^\/+|\/+$/g, "").split("/");
  if (p[0] !== "businesses") return { kind: "unknown" };
  if (p.length === 1) return { kind: "list" };
  if (p.length === 2) {
    if (p[1] === "search") return { kind: "search" };
    if (p[1] === "review") return { kind: "review_queue" };
    if (p[1] === "stats") return { kind: "stats" };
    if (p[1] === "invites") return { kind: "my_invites" };
  }
  const id = p[1];
  if (!UUID_RE.test(id)) return { kind: "unknown" };
  if (p.length === 2) return { kind: "one", id };
  if (p.length === 3 && p[2] === "review") return { kind: "review", id };
  if (p.length === 3 && p[2] === "resubmit") return { kind: "resubmit", id };
  if (p.length === 3 && p[2] === "follow") return { kind: "follow", id };
  if (p.length === 3 && p[2] === "team") return { kind: "team", id };
  if (p.length === 4 && p[2] === "team" && UUID_RE.test(p[3])) return { kind: "team_member", id, userId: p[3] };
  if (
    p.length === 5 && p[2] === "invites" && (BUSINESS_ROLES as string[]).includes(p[3]) &&
    (p[4] === "accept" || p[4] === "decline")
  ) {
    return { kind: "answer", id, role: p[3] as BusinessRole, accept: p[4] === "accept" };
  }
  return { kind: "unknown" };
}

// ── Helpers ───────────────────────────────────────────────────────────────────

/** Validates profile fields from a request body into an update. */
function profileUpdate(body: Record<string, unknown>): BusinessUpdate | string {
  const update: Record<string, unknown> = {};
  for (const key of PROFILE_FIELDS) {
    if (!(key in body)) continue;
    let v = body[key];
    if (typeof v === "string") v = v.trim();
    if ((key === "bio" || key === "website" || key === "phone" || key === "logo") && v === "") v = null;
    update[key] = v;
  }
  if ("name" in update && (typeof update.name !== "string" || !update.name)) return "name can't be empty";
  if ("location" in update && (typeof update.location !== "string" || !update.location)) {
    return "location can't be empty";
  }
  if (typeof update.bio === "string" && update.bio.length > 500) return "bio is at most 500 characters";
  if (typeof update.website === "string" && !/^https?:\/\/\S+$/.test(update.website)) {
    return "website must start with http:// or https://";
  }
  if (typeof update.phone === "string" && update.phone.length > 40) return "phone is at most 40 characters";
  return update as BusinessUpdate;
}

/** The roles the user holds (active) or was offered (invited) at the business. */
async function rolesAt(userId: string, businessId: string) {
  const rows = await db
    .selectFrom("business_member")
    .select(["role", "status"])
    .where("business_id", "=", businessId)
    .where("user_id", "=", userId)
    .execute();
  return {
    roles: rows.filter((r) => r.status === "active").map((r) => r.role),
    invited: rows.filter((r) => r.status === "invited").map((r) => r.role),
  };
}

/** The full profile of a business as `caller` sees it. */
async function businessProfile(caller: Caller, id: string) {
  const b = await db
    .selectFrom("business")
    .select([
      ...BUSINESS_COLS,
      "business.review_note",
      "business.reviewed_at",
      sql<string>`(SELECT COUNT(*) FROM business_follow f WHERE f.business_id = business.id)`.as(
        "follower_count",
      ),
      sql<boolean>`EXISTS (SELECT 1 FROM business_follow f
        WHERE f.business_id = business.id AND f.user_id = ${caller.id})`.as("is_following"),
    ])
    .where("business.id", "=", id)
    .executeTakeFirst();
  if (!b) return null;

  const mine = await rolesAt(caller.id, id);
  const onTeam = mine.roles.length > 0;
  // Until approved, only its team and super users see it.
  if (b.status !== "approved" && !onTeam && !isSuperUser(caller)) return null;

  const team = await db
    .selectFrom("business_member as m")
    .innerJoin("users as u", "u.id", "m.user_id")
    .select(["u.id", "u.username", "u.name", "u.last_name", "u.avatar_url", "m.role"])
    .where("m.business_id", "=", id)
    .where("m.status", "=", "active")
    .where("m.role", "in", ["owner", "trainer"])
    .orderBy("m.joined_at", "asc")
    .execute();

  const { review_note, reviewed_at, follower_count, ...profile } = b;
  return {
    ...profile,
    follower_count: Number(follower_count),
    // The review outcome is for the team and admins only.
    ...(onTeam || isSuperUser(caller) ? { review_note, reviewed_at } : {}),
    my_roles: mine.roles,
    my_invites: mine.invited,
    owners: team.filter((t) => t.role === "owner").map(({ role: _r, ...u }) => u),
    trainers: team.filter((t) => t.role === "trainer").map(({ role: _r, ...u }) => u),
  };
}

/** Deletes a business and everything hanging off it. Returns false if it didn't exist. */
async function deleteBusinessCascade(trx: Kysely<Database>, id: string): Promise<boolean> {
  const biz = await trx
    .selectFrom("business")
    .select(["id"])
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
  await trx.deleteFrom("member").where("gym_id", "=", id).execute();

  // ── Shop side ──
  const itemIds = trx.selectFrom("shop_item").select("id").where("shop_id", "=", id);
  await trx.deleteFrom("invoice_item").where("shop_item_id", "in", itemIds).execute();
  await trx.deleteFrom("shop_item").where("shop_id", "=", id).execute();

  // The team, followers and the rest cascade.
  await trx.deleteFrom("business").where("id", "=", id).execute();
  return true;
}

// ── Handler ───────────────────────────────────────────────────────────────────

Deno.serve(async (req: Request) => {
  const url = new URL(req.url);

  // Every route requires a signed-in caller.
  const { caller, response } = await requireCaller(req);
  if (response) return response;

  const route = parseRoute(url.pathname);
  if (route.kind === "unknown") return jsonError("Not found", 404);

  // ── GET /businesses/stats — matched before /:id ───────────────────────────────
  if (req.method === "GET" && route.kind === "stats") {
    const gymIds = isSuperUser(caller)
      ? (await db.selectFrom("business").select("id").where("has_gym", "=", true).execute()).map((r) => r.id)
      : (await myBusinesses(caller.id))
        .filter((b) => b.has_gym && b.status === "approved" && b.roles.includes("owner"))
        .map((b) => b.id);

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
        SELECT COUNT(DISTINCT user_id) AS count FROM business_member
        WHERE business_id = ANY(${gymIds}::uuid[]) AND status = 'active' AND role IN ('staff', 'trainer')
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


  // ── GET /businesses — the ones I'm on the team of (any status for owners) ────
  // Super users pass ?all=1 for every business on the platform.
  if (req.method === "GET" && route.kind === "list") {
    const side = url.searchParams.get("side") ?? url.searchParams.get("type");
    if (url.searchParams.get("all") === "1") {
      if (!isSuperUser(caller)) return forbidden();
      const all = await db
        .selectFrom("business")
        .select([...BUSINESS_COLS, "business.review_note"])
        .$if(side === "gym", (q) => q.where("business.has_gym", "=", true))
        .$if(side === "shop", (q) => q.where("business.has_shop", "=", true))
        .orderBy("business.name")
        .execute();
      const mine = new Map((await myBusinesses(caller.id)).map((b) => [b.id, b.roles]));
      return json(all.map((b) => ({ ...b, my_roles: mine.get(b.id) ?? [] })));
    }
    const mine = await myBusinesses(caller.id);
    const filtered = mine.filter((b) =>
      side === "gym" ? b.has_gym : side === "shop" ? b.has_shop : true
    );
    if (filtered.length === 0) return json([]);
    const full = await db
      .selectFrom("business")
      .select([...BUSINESS_COLS, "business.review_note"])
      .where("business.id", "in", filtered.map((b) => b.id))
      .orderBy("business.name")
      .execute();
    const roles = new Map(filtered.map((b) => [b.id, b.roles]));
    return json(full.map((b) => ({ ...b, my_roles: roles.get(b.id) ?? [] })));
  }

  // ── GET /businesses/search?q=&side=gym|shop ──────────────────────────────────
  if (req.method === "GET" && route.kind === "search") {
    const q = (url.searchParams.get("q") ?? "").trim().slice(0, 100);
    const side = url.searchParams.get("side");
    const limit = Math.min(50, Math.max(1, Number(url.searchParams.get("limit")) || 20));
    let query = db
      .selectFrom("business")
      .select(BUSINESS_COLS)
      .where("business.status", "=", "approved")
      .orderBy("business.name")
      .limit(limit);
    if (q) {
      const like = `%${q.replace(/[\\%_]/g, (c) => `\\${c}`)}%`;
      query = query.where((eb) =>
        eb.or([eb("business.name", "ilike", like), eb("business.location", "ilike", like)])
      );
    }
    if (side === "gym") query = query.where("business.has_gym", "=", true);
    if (side === "shop") query = query.where("business.has_shop", "=", true);
    return json(await query.execute());
  }

  // ── GET /businesses/review?status=pending — super user ───────────────────────
  if (req.method === "GET" && route.kind === "review_queue") {
    if (!isSuperUser(caller)) return forbidden();
    const status = (url.searchParams.get("status") ?? "pending") as BusinessStatus;
    if (!["pending", "approved", "rejected", "blocked"].includes(status)) {
      return jsonError("status must be pending, approved, rejected or blocked", 400);
    }
    const rows = await db
      .selectFrom("business")
      .leftJoin("users as u", "u.id", "business.created_by")
      .select([
        ...BUSINESS_COLS,
        "business.review_note",
        "business.reviewed_at",
        "u.id as applicant_id",
        "u.username as applicant_username",
        "u.name as applicant_name",
        "u.last_name as applicant_last_name",
        "u.email as applicant_email",
        "u.avatar_url as applicant_avatar_url",
      ])
      .where("business.status", "=", status)
      .orderBy("business.created_at", status === "pending" ? "asc" : "desc")
      .limit(200)
      .execute();
    return json(rows);
  }

  // ── GET /businesses/invites — my unanswered invites ─────────────────────────
  if (req.method === "GET" && route.kind === "my_invites") {
    const rows = await db
      .selectFrom("business_member as m")
      .innerJoin("business as b", "b.id", "m.business_id")
      .leftJoin("users as inv", "inv.id", "m.invited_by")
      .select([
        "b.id as business_id",
        "b.name as business_name",
        "b.logo",
        "b.has_gym",
        "b.has_shop",
        "m.role",
        "m.created_at",
        "inv.id as inviter_id",
        "inv.name as inviter_name",
        "inv.last_name as inviter_last_name",
      ])
      .where("m.user_id", "=", caller.id)
      .where("m.status", "=", "invited")
      .where("b.status", "=", "approved")
      .orderBy("m.created_at", "desc")
      .execute();
    return json(rows);
  }

  // ── POST /businesses — apply for a new business ──────────────────────────────
  // It starts pending; a super user approves it before the owner tools work.
  if (req.method === "POST" && route.kind === "list") {
    const body = await req.json().catch(() => null);
    if (!body || typeof body !== "object") return jsonError("Body must be an object", 400);
    // `type` is accepted for one side; has_gym / has_shop for either or both.
    const hasGym = body.has_gym === true || body.type === "gym";
    const hasShop = body.has_shop === true || body.type === "shop";
    if (!hasGym && !hasShop) return jsonError("A business must be a gym, a shop or both", 400);
    const { working_hours_from, working_hours_to, working_weekdays } = body;
    if (!body.name || !body.location || !working_hours_from || !working_hours_to || !working_weekdays) {
      return jsonError(
        "Missing required fields: name, location, working_hours_from, working_hours_to, working_weekdays",
        400,
      );
    }
    const fields = profileUpdate(body);
    if (typeof fields === "string") return jsonError(fields, 400);

    const business = await db.transaction().execute(async (trx) => {
      const biz = await trx
        .insertInto("business")
        .values({
          name: body.name,
          location: body.location,
          working_hours_from,
          working_hours_to,
          working_weekdays,
          logo: null,
          ...fields,
          latitude: Number.isFinite(body.latitude) ? body.latitude : null,
          longitude: Number.isFinite(body.longitude) ? body.longitude : null,
          has_gym: hasGym,
          has_shop: hasShop,
          // Super users set up businesses that are live straight away.
          status: isSuperUser(caller) ? "approved" : "pending",
          created_by: caller.id,
        })
        .returning("id")
        .executeTakeFirstOrThrow();
      await trx
        .insertInto("business_member")
        .values({ business_id: biz.id, user_id: caller.id, role: "owner", status: "active", joined_at: sql`NOW()` })
        .execute();
      await trx.insertInto("business_follow").values({ user_id: caller.id, business_id: biz.id }).execute();
      return biz;
    });

    return json(await businessProfile(caller, business.id), 201);
  }

  // From here on, routes address one business.
  if (!("id" in route)) return jsonError("Not found", 404);
  const id = route.id;

  // ── GET /businesses/:id — the profile ────────────────────────────────────────
  if (req.method === "GET" && route.kind === "one") {
    const profile = await businessProfile(caller, id);
    if (!profile) return jsonError("Business not found", 404);
    return json(profile);
  }

  const exists = await db
    .selectFrom("business")
    .select(["id", "name", "status", "has_gym", "has_shop"])
    .where("id", "=", id)
    .executeTakeFirst();
  if (!exists) return jsonError("Business not found", 404);

  // ── PUT /businesses/:id ──────────────────────────────────────────────────────
  // Owners and staff edit the profile; only owners switch the gym/shop sides.
  if (req.method === "PUT" && route.kind === "one") {
    const body = await req.json().catch(() => null);
    if (!body || typeof body !== "object") return jsonError("Body must not be empty", 400);
    if (!(await canEditBusinessProfile(caller, id))) return forbidden();

    const update = profileUpdate(body);
    if (typeof update === "string") return jsonError(update, 400);
    if ("has_gym" in body || "has_shop" in body) {
      if (!(await canManageBusiness(caller, id))) {
        return forbidden("Only an owner can turn the gym or shop on or off");
      }
      const hasGym = "has_gym" in body ? body.has_gym === true : exists.has_gym;
      const hasShop = "has_shop" in body ? body.has_shop === true : exists.has_shop;
      if (!hasGym && !hasShop) return jsonError("A business must be a gym, a shop or both", 400);
      update.has_gym = hasGym;
      update.has_shop = hasShop;
    }
    if (Object.keys(update).length === 0) return jsonError("Nothing to update", 400);

    await db.updateTable("business").set(update).where("id", "=", id).execute();
    return json(await businessProfile(caller, id));
  }

  // ── DELETE /businesses/:id ───────────────────────────────────────────────────
  if (req.method === "DELETE" && route.kind === "one") {
    // Owners may withdraw an application that was never approved, too.
    const ownsIt = await canManageBusiness(caller, id) ||
      (exists.status !== "blocked" && (await rolesAt(caller.id, id)).roles.includes("owner"));
    if (!ownsIt) return forbidden();
    const found = await db.transaction().execute((trx) => deleteBusinessCascade(trx, id));
    if (!found) return jsonError("Business not found", 404);
    return new Response(null, { status: 204 });
  }

  // ── POST /businesses/:id/review {status, note} — super user ─────────────────
  if (req.method === "POST" && route.kind === "review") {
    if (!isSuperUser(caller)) return forbidden();
    const body = await req.json().catch(() => null);
    const status = body?.status as BusinessStatus;
    if (!REVIEW_STATUSES.includes(status)) return jsonError("status must be approved, rejected or blocked", 400);
    const note = typeof body?.note === "string" && body.note.trim() ? body.note.trim().slice(0, 500) : null;
    if (status !== "approved" && !note) return jsonError("Say why in a note", 400);

    await db
      .updateTable("business")
      .set({ status, review_note: note, reviewed_by: caller.id, reviewed_at: sql`NOW()` })
      .where("id", "=", id)
      .execute();
    await db
      .insertInto("admin_audit_log")
      .values({ actor_id: caller.id, action: `business_${status}`, metadata: { business_id: id, note } })
      .execute();

    const owners = await businessTeamIds(id);
    const title = {
      approved: `${exists.name} is approved`,
      rejected: `${exists.name} wasn't approved`,
      blocked: `${exists.name} has been blocked`,
      pending: "",
    }[status];
    await notify(owners, {
      type: "business_review",
      title,
      body: note ?? `${exists.name} is live. You can now set it up and invite your team.`,
      metadata: { business_id: id, status },
    });
    return json(await businessProfile(caller, id));
  }

  // ── POST /businesses/:id/resubmit — owner, after a rejection ─────────────────
  if (req.method === "POST" && route.kind === "resubmit") {
    if (!(await rolesAt(caller.id, id)).roles.includes("owner")) return forbidden();
    if (exists.status !== "rejected") return jsonError("Only a rejected business can be resubmitted", 409);
    await db.updateTable("business").set({ status: "pending" }).where("id", "=", id).execute();
    return json(await businessProfile(caller, id));
  }

  // ── PUT|DELETE /businesses/:id/follow ────────────────────────────────────────
  if (route.kind === "follow" && (req.method === "PUT" || req.method === "DELETE")) {
    if (exists.status !== "approved") return jsonError("Business not found", 404);
    if (req.method === "PUT") {
      await db
        .insertInto("business_follow")
        .values({ user_id: caller.id, business_id: id })
        .onConflict((oc) => oc.doNothing())
        .execute();
    } else {
      await db.deleteFrom("business_follow").where("user_id", "=", caller.id).where("business_id", "=", id)
        .execute();
    }
    return json({ is_following: req.method === "PUT" });
  }

  // ── GET /businesses/:id/team — the team; open invites for owners ─────────────
  if (req.method === "GET" && route.kind === "team") {
    const mine = await rolesAt(caller.id, id);
    if (mine.roles.length === 0 && !isSuperUser(caller)) return forbidden();
    const seeAll = mine.roles.includes("owner") || mine.roles.includes("staff") || isSuperUser(caller);
    const rows = await db
      .selectFrom("business_member as m")
      .innerJoin("users as u", "u.id", "m.user_id")
      .select([
        "u.id as user_id",
        "u.username",
        "u.name",
        "u.last_name",
        "u.avatar_url",
        "u.email",
        "m.role",
        "m.status",
        "m.joined_at",
        "m.created_at",
      ])
      .where("m.business_id", "=", id)
      .$if(!seeAll, (q) => q.where("m.status", "=", "active"))
      .orderBy("u.name")
      .orderBy("u.last_name")
      .execute();
    // One entry per person with every role they hold or were offered.
    const people = new Map<string, Record<string, unknown> & { roles: { role: string; status: string }[] }>();
    for (const r of rows) {
      const { role, status, joined_at, created_at, email, ...user } = r;
      const entry = people.get(r.user_id) ?? { ...user, ...(seeAll ? { email } : {}), roles: [] };
      entry.roles.push({ role, status, ...(status === "active" ? { since: joined_at } : { sent: created_at }) });
      people.set(r.user_id, entry);
    }
    return json([...people.values()]);
  }

  // ── POST /businesses/:id/team {user_id | email, role} — owner ────────────────
  // Existing users get an invite to accept. A new email gets an account invite
  // (name, last_name and username needed) and the same team invite.
  if (req.method === "POST" && route.kind === "team") {
    if (!(await canManageBusiness(caller, id))) return forbidden();
    const body = await req.json().catch(() => null);
    const role = body?.role as BusinessRole;
    if (!BUSINESS_ROLES.includes(role)) return jsonError("role must be owner, staff or trainer", 400);

    let userId: string | null = typeof body?.user_id === "string" ? body.user_id : null;
    const email = typeof body?.email === "string" ? body.email.trim().toLowerCase() : "";
    if (userId && !UUID_RE.test(userId)) return jsonError("User not found", 404);
    if (!userId) {
      if (!email) return jsonError("Either user_id or email is required", 400);
      const existing = await db.selectFrom("users").select("id").where(sql`lower(email)`, "=", email)
        .executeTakeFirst();
      userId = existing?.id ?? null;
    }

    if (userId) {
      const target = await db.selectFrom("users").select("id").where("id", "=", userId).executeTakeFirst();
      if (!target) return jsonError("User not found", 404);
      const held = await rolesAt(userId, id);
      if (held.roles.includes(role)) return jsonError("They already have this role here", 409);
      if (held.invited.includes(role)) return jsonError("They already have an invite for this role", 409);
      if (userId === caller.id) {
        // Owners can make themselves staff or trainer without an invite.
        await db.insertInto("business_member").values({
          business_id: id,
          user_id: userId,
          role,
          status: "active",
          invited_by: caller.id,
          joined_at: sql`NOW()`,
        }).execute();
        if (role === "trainer") await db.updateTable("users").set({ is_trainer: true }).where("id", "=", userId).execute();
        return json({ invited: false, user_id: userId, role }, 201);
      }
      await inviteToBusiness(db, exists, userId, role, caller);
      return json({ invited: true, user_id: userId, role }, 201);
    }

    // ── Brand-new user ──
    const { name, last_name, username } = body ?? {};
    if (!name || !last_name || !username) {
      return jsonError(
        "name, last_name, and username are required when the email does not match an existing user",
        400,
      );
    }
    const usernameTaken = await db.selectFrom("users").select("id").where("username", "=", username)
      .executeTakeFirst();
    if (usernameTaken) return jsonError("Username is already taken", 409);

    const redirectTo = Deno.env.get("APP_INVITE_REDIRECT_URL") ?? "gymbroo://auth/callback";
    const { data, error: inviteErr } = await supabaseAdmin.auth.admin.inviteUserByEmail(
      email,
      { redirectTo, data: { username, name, last_name } },
    );
    if (inviteErr) return jsonError(inviteErr.message, 400);

    try {
      const insert: UserInsert = { email, name, last_name, username, auth_id: data.user.id };
      const u = await db.insertInto("users").values(insert).returning("id").executeTakeFirstOrThrow();
      // After the user row is committed: the invite notification is written on
      // another connection and needs it (FK). If this fails, the catch below
      // deletes the auth user, which cascades to the profile.
      await inviteToBusiness(db, exists, u.id, role, caller);
      return json({ invited: true, user_id: u.id, role }, 201);
    } catch (err) {
      // Don't leave an orphaned auth account behind.
      await supabaseAdmin.auth.admin.deleteUser(data.user.id).catch(() => {});
      if (pgCode(err) === "23505") return jsonError("A user with this email or username already exists", 409);
      throw err;
    }
  }

  // ── DELETE /businesses/:id/team/:userId?role= ────────────────────────────────
  // Owners remove anyone (or cancel an invite); anyone can leave. Without
  // ?role= every role goes. The last owner can't leave.
  if (req.method === "DELETE" && route.kind === "team_member") {
    const self = route.userId === caller.id;
    if (!self && !(await canManageBusiness(caller, id))) return forbidden();
    const role = url.searchParams.get("role") as BusinessRole | null;
    if (role && !BUSINESS_ROLES.includes(role)) return jsonError("role must be owner, staff or trainer", 400);

    const removingOwner = !role || role === "owner";
    if (removingOwner) {
      const owners = await businessTeamIds(id);
      if (owners.length === 1 && owners[0] === route.userId) {
        return jsonError("A business needs an owner. Add another owner first, or delete the business.", 409);
      }
    }
    const res = await db
      .deleteFrom("business_member")
      .where("business_id", "=", id)
      .where("user_id", "=", route.userId)
      .$if(!!role, (q) => q.where("role", "=", role!))
      .executeTakeFirst();
    if (Number(res.numDeletedRows) === 0) return jsonError("Not on the team", 404);
    return new Response(null, { status: 204 });
  }

  // ── POST /businesses/:id/invites/:role/accept|decline ────────────────────────
  if (req.method === "POST" && route.kind === "answer") {
    const res = await answerBusinessInvite(caller, id, route.role, route.accept);
    if (!res.ok) return jsonError(res.error, res.status);
    return json(await businessProfile(caller, id) ?? { ok: true });
  }

  return jsonError("Not found", 404);
});
