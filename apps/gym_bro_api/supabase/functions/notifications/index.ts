import type { Kysely } from "npm:kysely@^0.27";
import { db } from "../_shared/config.ts";
import { forbidden, isSuperUser, json, jsonError, requireCaller } from "../_shared/auth.ts";
import { businessName, gymOwnerIds, notify, shopOwnerIds } from "../_shared/notify.ts";
import { pgCode, reconcileRoles } from "../_shared/roles.ts";
import type {
  Database,
  NotificationInsert,
  NotificationType,
} from "../../types/schema/public.ts";

// ── Path parsing ──────────────────────────────────────────────────────────────

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

function parseId(pathname: string): string | null {
  const match = pathname.match(/^\/notifications\/([^/]+)$/);
  return match ? match[1] : null;
}

function parseAction(pathname: string): { id: string; action: string } | null {
  const match = pathname.match(/^\/notifications\/([^/]+)\/(accept|decline|read)$/);
  return match ? { id: match[1], action: match[2] } : null;
}

// ── Helpers ───────────────────────────────────────────────────────────────────

/**
 * True when the user who sent an invite may still invite people to the
 * business: super user, or owner of the gym / shop.
 */
async function inviterCanStillInvite(
  inviterId: unknown,
  kind: "gym" | "shop",
  businessId: string,
): Promise<boolean> {
  if (typeof inviterId !== "string" || !inviterId) return false;
  const inviter = await db.selectFrom("users").select("role").where("id", "=", inviterId).executeTakeFirst();
  if (!inviter) return false;
  if (inviter.role === "super_user") return true;
  const row = kind === "gym"
    ? await db.selectFrom("gym_owner").select("id").where("user_id", "=", inviterId)
      .where("gym_id", "=", businessId).executeTakeFirst()
    : await db.selectFrom("shop_owner").select("id").where("user_id", "=", inviterId)
      .where("shop_id", "=", businessId).executeTakeFirst();
  return !!row;
}

function setInviteStatus(id: string, meta: Record<string, unknown>, status: "accepted" | "declined") {
  return db
    .updateTable("notification")
    .set({ is_read: true, metadata: { ...meta, invite_status: status } })
    .where("id", "=", id)
    .returningAll()
    .executeTakeFirstOrThrow();
}

/**
 * Runs the role-row inserts and marks the invite accepted in one transaction.
 * Returns null (after marking the invite declined) if the business is gone.
 */
async function acceptInTransaction(
  id: string,
  meta: Record<string, unknown>,
  insertRows: (trx: Kysely<Database>) => Promise<void>,
) {
  try {
    return await db.transaction().execute(async (trx) => {
      await insertRows(trx);
      return trx
        .updateTable("notification")
        .set({ is_read: true, metadata: { ...meta, invite_status: "accepted" } })
        .where("id", "=", id)
        .returningAll()
        .executeTakeFirstOrThrow();
    });
  } catch (err) {
    if (pgCode(err) !== "23503") throw err;
    await setInviteStatus(id, meta, "declined");
    return null;
  }
}

// ── Handler ───────────────────────────────────────────────────────────────────

Deno.serve(async (req: Request) => {
  const { caller, response } = await requireCaller(req);
  if (response) return response;

  const url = new URL(req.url);
  const actionMatch = parseAction(url.pathname);
  // A malformed id can't match a notification (and would make Postgres throw).
  if (actionMatch && !UUID_RE.test(actionMatch.id)) return jsonError("Notification not found", 404);

  // ── POST /notifications/mark-all-read — matched before /:id ───────────────────
  if (req.method === "POST" && url.pathname === "/notifications/mark-all-read") {
    await db
      .updateTable("notification")
      .set({ is_read: true })
      .where("user_id", "=", caller.id)
      .where("is_read", "=", false)
      .execute();

    return json({ ok: true });
  }

  // ── POST /notifications/:id/accept ────────────────────────────────────────────
  if (req.method === "POST" && actionMatch?.action === "accept") {
    const notif = await db
      .selectFrom("notification")
      .selectAll()
      .where("id", "=", actionMatch.id)
      .executeTakeFirst();
    if (!notif) return jsonError("Notification not found", 404);

    // Verify the notification belongs to the current user
    if (notif.user_id !== caller.id) return forbidden();

    const meta = (notif.metadata ?? {}) as Record<string, unknown>;
    if (meta.invite_status !== "pending") {
      return jsonError("Invite is no longer pending", 409);
    }

    const fullName = `${caller.name} ${caller.last_name}`.trim();

    if (notif.type === "employee_gym_invite") {
      const gymId = meta.gym_id as string;
      const employeeType = meta.employee_type === "employee_trainer" ? "employee_trainer" : "employee";
      if (!gymId) return jsonError("Invite is missing gym_id", 400);

      // The inviter may have lost access since the invite was sent.
      if (!(await inviterCanStillInvite(meta.inviter_id, "gym", gymId))) {
        await setInviteStatus(notif.id, meta, "declined");
        return jsonError("This invite is no longer valid", 409);
      }

      const updated = await acceptInTransaction(notif.id, meta, async (trx) => {
        if (employeeType === "employee") {
          await trx
            .insertInto("employee")
            .values({ user_id: caller.id, gym_id: gymId })
            .onConflict((oc) => oc.columns(["user_id", "gym_id"]).doNothing())
            .execute();
          await reconcileRoles(trx, [caller.id]);
        } else {
          // employee_trainer: find or create the trainer row first
          let trainerRow = await trx
            .selectFrom("trainer")
            .select(["id"])
            .where("user_id", "=", caller.id)
            .where("gym_id", "=", gymId)
            .executeTakeFirst();
          if (!trainerRow) {
            trainerRow = await trx
              .insertInto("trainer")
              .values({ user_id: caller.id, gym_id: gymId })
              .returning(["id"])
              .executeTakeFirstOrThrow();
          }
          await trx
            .insertInto("employee_trainer")
            .values({ user_id: caller.id, gym_id: gymId, trainer_id: trainerRow.id })
            .onConflict((oc) => oc.columns(["user_id", "gym_id"]).doNothing())
            .execute();
          await reconcileRoles(trx, [caller.id]);
        }
      });
      if (!updated) return jsonError("This invite is no longer valid", 409);

      const gymName = (meta.gym_name as string | undefined) ?? await businessName(gymId);
      await notify((await gymOwnerIds(gymId)).filter((id) => id !== caller.id), {
        type: "employee_join",
        title: `${fullName} joined ${gymName}`,
        body: `${fullName} accepted your invitation to join ${gymName} as ${
          employeeType === "employee_trainer" ? "Employee Trainer" : "Employee"
        }.`,
        metadata: { gym_id: gymId, user_id: caller.id, employee_type: employeeType },
      });
      return json(updated);
    }

    if (notif.type === "vendor_shop_invite") {
      const shopId = meta.shop_id as string;
      if (!shopId) return jsonError("Invite is missing shop_id", 400);

      if (!(await inviterCanStillInvite(meta.inviter_id, "shop", shopId))) {
        await setInviteStatus(notif.id, meta, "declined");
        return jsonError("This invite is no longer valid", 409);
      }

      const updated = await acceptInTransaction(notif.id, meta, async (trx) => {
        await trx
          .insertInto("shop_vendor")
          .values({ user_id: caller.id, shop_id: shopId })
          .onConflict((oc) => oc.columns(["user_id", "shop_id"]).doNothing())
          .execute();
        await reconcileRoles(trx, [caller.id]);
      });
      if (!updated) return jsonError("This invite is no longer valid", 409);

      const shopName = (meta.shop_name as string | undefined) ?? await businessName(shopId);
      await notify((await shopOwnerIds(shopId)).filter((id) => id !== caller.id), {
        type: "vendor_join",
        title: `${fullName} joined ${shopName}`,
        body: `${fullName} accepted your invitation to join ${shopName} as a Vendor.`,
        metadata: { shop_id: shopId, user_id: caller.id },
      });
      return json(updated);
    }

    return jsonError("Not an invite notification", 400);
  }

  // ── POST /notifications/:id/decline ──────────────────────────────────────────
  if (req.method === "POST" && actionMatch?.action === "decline") {
    const notif = await db
      .selectFrom("notification")
      .selectAll()
      .where("id", "=", actionMatch.id)
      .executeTakeFirst();
    if (!notif) return jsonError("Notification not found", 404);
    if (notif.user_id !== caller.id) return forbidden();

    const meta = (notif.metadata ?? {}) as Record<string, unknown>;
    if (meta.invite_status !== "pending") {
      return jsonError("Invite is no longer pending", 409);
    }

    return json(await setInviteStatus(notif.id, meta, "declined"));
  }

  // ── POST /notifications/:id/read ──────────────────────────────────────────────
  if (req.method === "POST" && actionMatch?.action === "read") {
    const updated = await db
      .updateTable("notification")
      .set({ is_read: true })
      .where("id", "=", actionMatch.id)
      .where("user_id", "=", caller.id)
      .returningAll()
      .executeTakeFirst();
    if (!updated) return jsonError("Notification not found", 404);
    return json(updated);
  }

  const id = parseId(url.pathname);
  if (id && !UUID_RE.test(id)) return jsonError("Notification not found", 404);

  // ── POST /notifications — super user only (the server creates notifications) ─
  if (req.method === "POST" && !id) {
    if (!isSuperUser(caller)) return forbidden();

    const body = await req.json().catch(() => null);
    const { user_id, type, title, body: msgBody, metadata } = body ?? {};

    if (!user_id || !type || !title) {
      return jsonError("user_id, type, and title are required", 400);
    }

    const insert: NotificationInsert = {
      user_id,
      type: type as NotificationType,
      title,
      body: msgBody ?? null,
      metadata: metadata ? metadata : null,
    };

    const row = await db
      .insertInto("notification")
      .values(insert)
      .returningAll()
      .executeTakeFirstOrThrow();

    return json(row, 201);
  }

  // ── GET /notifications — the caller's own; optional page/page_size/unread_only ─
  // Super users may pass ?user_id= to read someone else's.
  if (req.method === "GET" && !id) {
    const requested = url.searchParams.get("user_id");
    const userId = isSuperUser(caller) && requested ? requested : caller.id;

    const page = Math.max(0, parseInt(url.searchParams.get("page") ?? "0", 10) || 0);
    const pageSize = Math.min(
      50,
      Math.max(1, parseInt(url.searchParams.get("page_size") ?? "20", 10) || 20),
    );
    const unreadOnly = url.searchParams.get("unread_only") === "true";

    let q = db
      .selectFrom("notification")
      .selectAll()
      .where("user_id", "=", userId)
      .orderBy("created_at", "desc")
      .limit(pageSize)
      .offset(page * pageSize);

    if (unreadOnly) q = q.where("is_read", "=", false);

    const rows = await q.execute();

    // Also return unread count for badge
    const countRow = await db
      .selectFrom("notification")
      .select(db.fn.count("id").as("count"))
      .where("user_id", "=", userId)
      .where("is_read", "=", false)
      .executeTakeFirstOrThrow();

    return json({ items: rows, unread_count: Number(countRow.count) });
  }

  // ── GET /notifications/:id ────────────────────────────────────────────────────
  if (req.method === "GET" && id) {
    const row = await db
      .selectFrom("notification")
      .selectAll()
      .where("id", "=", id)
      .where("user_id", "=", caller.id)
      .executeTakeFirst();
    if (!row) return jsonError("Notification not found", 404);
    return json(row);
  }

  // ── PATCH /notifications/:id — only is_read may change ────────────────────────
  if (req.method === "PATCH" && id) {
    const body = await req.json().catch(() => null);
    if (typeof body?.is_read !== "boolean") {
      return jsonError("is_read (boolean) is required", 400);
    }

    const updated = await db
      .updateTable("notification")
      .set({ is_read: body.is_read })
      .where("id", "=", id)
      .where("user_id", "=", caller.id)
      .returningAll()
      .executeTakeFirst();
    if (!updated) return jsonError("Notification not found", 404);
    return json(updated);
  }

  // ── DELETE /notifications/:id ─────────────────────────────────────────────────
  if (req.method === "DELETE" && id) {
    const result = await db
      .deleteFrom("notification")
      .where("id", "=", id)
      .where("user_id", "=", caller.id)
      .executeTakeFirst();
    if (!result.numDeletedRows) return jsonError("Notification not found", 404);
    return new Response(null, { status: 204 });
  }

  return jsonError("Not found", 404);
});
