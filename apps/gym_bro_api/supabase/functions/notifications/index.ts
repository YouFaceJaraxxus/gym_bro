import { db, supabaseAdmin } from "../_shared/config.ts";
import type {
  NotificationInsert,
  NotificationUpdate,
  NotificationType,
} from "../../types/schema/public.ts";

// ── Auth ──────────────────────────────────────────────────────────────────────

async function requireAuth(req: Request) {
  const token = req.headers.get("Authorization")?.replace(/^Bearer\s+/i, "");
  if (!token) return { user: null, error: "Missing Authorization header" };
  const { data: { user }, error } = await supabaseAdmin.auth.getUser(token);
  return { user: error ? null : user, error: error?.message ?? null };
}

// ── Path parsing ──────────────────────────────────────────────────────────────

function parseId(pathname: string): string | null {
  const match = pathname.match(/^\/notifications\/([^/]+)$/);
  return match ? match[1] : null;
}

function parseAction(pathname: string): { id: string; action: string } | null {
  const match = pathname.match(/^\/notifications\/([^/]+)\/(accept|decline|read)$/);
  return match ? { id: match[1], action: match[2] } : null;
}

// ── Internal user lookup ──────────────────────────────────────────────────────

async function getInternalUser(authId: string) {
  return db
    .selectFrom("users")
    .select(["id", "name", "last_name"])
    .where("auth_id", "=", authId)
    .executeTakeFirst();
}

// ── Handler ───────────────────────────────────────────────────────────────────

Deno.serve(async (req: Request) => {
  const { user, error: authError } = await requireAuth(req);
  if (!user) return jsonError(authError ?? "Unauthorized", 401);

  const url = new URL(req.url);
  const id = parseId(url.pathname);
  const actionMatch = parseAction(url.pathname);

  // ── POST /notifications/:id/accept ────────────────────────────────────────────
  if (req.method === "POST" && actionMatch?.action === "accept") {
    const notif = await db
      .selectFrom("notification")
      .selectAll()
      .where("id", "=", actionMatch.id)
      .executeTakeFirst();
    if (!notif) return jsonError("Notification not found", 404);

    const meta = (notif.metadata ?? {}) as Record<string, unknown>;
    if (meta.invite_status !== "pending") {
      return jsonError("Invite is no longer pending", 409);
    }

    // Verify the notification belongs to the current user
    const internal = await getInternalUser(user.id);
    if (!internal || notif.user_id !== internal.id) {
      return jsonError("Forbidden", 403);
    }

    if (notif.type === "employee_gym_invite") {
      const gymId = meta.gym_id as string;
      const employeeType = meta.employee_type as string;

      if (employeeType === "employee") {
        await db
          .insertInto("employee")
          .values({ user_id: internal.id, gym_id: gymId })
          .onConflict((oc) => oc.columns(["user_id", "gym_id"]).doNothing())
          .execute();
        await db.updateTable("users").set({ role: "employee" }).where("id", "=", internal.id).execute();
      } else {
        // employee_trainer: find or create the trainer row first
        let trainerRow = await db
          .selectFrom("trainer")
          .select(["id"])
          .where("user_id", "=", internal.id)
          .where("gym_id", "=", gymId)
          .executeTakeFirst();

        if (!trainerRow) {
          trainerRow = await db
            .insertInto("trainer")
            .values({ user_id: internal.id, gym_id: gymId })
            .returning(["id"])
            .executeTakeFirstOrThrow();
        }

        await db
          .insertInto("employee_trainer")
          .values({ user_id: internal.id, gym_id: gymId, trainer_id: trainerRow.id })
          .onConflict((oc) => oc.columns(["user_id", "gym_id"]).doNothing())
          .execute();
        await db.updateTable("users").set({ role: "employee_trainer" }).where("id", "=", internal.id).execute();
      }
    } else if (notif.type === "vendor_shop_invite") {
      const shopId = meta.shop_id as string;
      await db
        .insertInto("shop_vendor")
        .values({ user_id: internal.id, shop_id: shopId })
        .onConflict((oc) => oc.columns(["user_id", "shop_id"]).doNothing())
        .execute();
      await db.updateTable("users").set({ role: "shop_vendor" }).where("id", "=", internal.id).execute();
    } else {
      return jsonError("Not an invite notification", 400);
    }

    const updated = await db
      .updateTable("notification")
      .set({
        is_read: true,
        metadata: JSON.stringify({ ...meta, invite_status: "accepted" }),
      })
      .where("id", "=", actionMatch.id)
      .returningAll()
      .executeTakeFirstOrThrow();

    return json(updated);
  }

  // ── POST /notifications/:id/decline ──────────────────────────────────────────
  if (req.method === "POST" && actionMatch?.action === "decline") {
    const notif = await db
      .selectFrom("notification")
      .selectAll()
      .where("id", "=", actionMatch.id)
      .executeTakeFirst();
    if (!notif) return jsonError("Notification not found", 404);

    const meta = (notif.metadata ?? {}) as Record<string, unknown>;
    if (meta.invite_status !== "pending") {
      return jsonError("Invite is no longer pending", 409);
    }

    const internal = await getInternalUser(user.id);
    if (!internal || notif.user_id !== internal.id) {
      return jsonError("Forbidden", 403);
    }

    const updated = await db
      .updateTable("notification")
      .set({
        is_read: true,
        metadata: JSON.stringify({ ...meta, invite_status: "declined" }),
      })
      .where("id", "=", actionMatch.id)
      .returningAll()
      .executeTakeFirstOrThrow();

    return json(updated);
  }

  // ── POST /notifications/:id/read ──────────────────────────────────────────────
  if (req.method === "POST" && actionMatch?.action === "read") {
    const internal = await getInternalUser(user.id);
    if (!internal) return jsonError("User not found", 404);

    const updated = await db
      .updateTable("notification")
      .set({ is_read: true })
      .where("id", "=", actionMatch.id)
      .where("user_id", "=", internal.id)
      .returningAll()
      .executeTakeFirst();
    if (!updated) return jsonError("Notification not found", 404);
    return json(updated);
  }

  // ── POST /notifications ───────────────────────────────────────────────────────
  if (req.method === "POST" && !id) {
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

  // ── GET /notifications — required: ?user_id=, optional page/page_size/unread_only ─
  if (req.method === "GET" && !id) {
    const userId = url.searchParams.get("user_id");
    if (!userId) return jsonError("user_id is required", 400);

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
    const internal = await getInternalUser(user.id);
    if (!internal) return jsonError("User not found", 404);

    const row = await db
      .selectFrom("notification")
      .selectAll()
      .where("id", "=", id)
      .where("user_id", "=", internal.id)
      .executeTakeFirst();
    if (!row) return jsonError("Notification not found", 404);
    return json(row);
  }

  // ── PATCH /notifications/:id ──────────────────────────────────────────────────
  if (req.method === "PATCH" && id) {
    const internal = await getInternalUser(user.id);
    if (!internal) return jsonError("User not found", 404);

    const body = await req.json().catch(() => null);
    const allowed: NotificationUpdate = {};
    if (typeof body?.is_read === "boolean") allowed.is_read = body.is_read;
    if (body?.metadata !== undefined) allowed.metadata = body.metadata;

    if (!Object.keys(allowed).length) {
      return jsonError("Nothing to update", 400);
    }

    const updated = await db
      .updateTable("notification")
      .set(allowed)
      .where("id", "=", id)
      .where("user_id", "=", internal.id)
      .returningAll()
      .executeTakeFirst();
    if (!updated) return jsonError("Notification not found", 404);
    return json(updated);
  }

  // ── DELETE /notifications/:id ─────────────────────────────────────────────────
  if (req.method === "DELETE" && id) {
    const internal = await getInternalUser(user.id);
    if (!internal) return jsonError("User not found", 404);

    const result = await db
      .deleteFrom("notification")
      .where("id", "=", id)
      .where("user_id", "=", internal.id)
      .executeTakeFirst();
    if (!result.numDeletedRows) return jsonError("Notification not found", 404);
    return new Response(null, { status: 204 });
  }

  // ── POST /notifications/mark-all-read ─────────────────────────────────────────
  if (req.method === "POST" && url.pathname.endsWith("/mark-all-read")) {
    const internal = await getInternalUser(user.id);
    if (!internal) return jsonError("User not found", 404);

    await db
      .updateTable("notification")
      .set({ is_read: true })
      .where("user_id", "=", internal.id)
      .where("is_read", "=", false)
      .execute();

    return json({ ok: true });
  }

  return jsonError("Not found", 404);
});

function json(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

function jsonError(message: string, status: number): Response {
  return json({ error: message }, status);
}
