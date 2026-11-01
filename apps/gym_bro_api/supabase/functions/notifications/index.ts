import { db } from "../_shared/config.ts";
import { forbidden, isSuperUser, json, jsonError, requireCaller } from "../_shared/auth.ts";
import { answerBusinessInvite, BUSINESS_ROLES } from "../_shared/business.ts";
import type { BusinessRole, NotificationInsert, NotificationType } from "../../types/schema/public.ts";

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

/** The business and role a business_invite notification is about. */
function inviteTarget(meta: Record<string, unknown>): { businessId: string; role: BusinessRole } | null {
  const businessId = meta.business_id;
  const role = meta.role;
  if (typeof businessId !== "string" || !UUID_RE.test(businessId)) return null;
  if (typeof role !== "string" || !(BUSINESS_ROLES as string[]).includes(role)) return null;
  return { businessId, role: role as BusinessRole };
}

function setInviteStatus(id: string, meta: Record<string, unknown>, status: "accepted" | "declined") {
  return db
    .updateTable("notification")
    .set({ is_read: true, metadata: { ...meta, invite_status: status } })
    .where("id", "=", id)
    .returningAll()
    .executeTakeFirstOrThrow();
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

    const target = notif.type === "business_invite" ? inviteTarget(meta) : null;
    if (!target) return jsonError("Not an invite notification", 400);
    const res = await answerBusinessInvite(caller, target.businessId, target.role, true);
    if (!res.ok) {
      // The invite was withdrawn or the business is gone.
      if (res.status === 404) await setInviteStatus(notif.id, meta, "declined");
      return jsonError(res.status === 404 ? "This invite is no longer valid" : res.error, 409);
    }
    return json(await db.selectFrom("notification").selectAll().where("id", "=", notif.id).executeTakeFirstOrThrow());
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

    const target = notif.type === "business_invite" ? inviteTarget(meta) : null;
    if (target) await answerBusinessInvite(caller, target.businessId, target.role, false);
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
