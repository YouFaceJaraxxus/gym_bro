import { sql } from "npm:kysely@^0.27";
import { db } from "../_shared/config.ts";
import { json, jsonError } from "../_shared/auth.ts";
import { notify, optionalSecret } from "../_shared/notify.ts";
import { removeObjects } from "../_shared/media.ts";

// Scheduled maintenance, called by pg_cron every 15 minutes (see
// sql/cron.sql) with the shared CRON_SECRET in the x-cron-secret header.
// verify_jwt is off for this function in config.toml; the secret is the auth.
// Every step is idempotent, so a missed or doubled run is harmless.

const CLASS_REMINDER_WINDOW_MINUTES = 75;

/** Compares two strings in time independent of where they differ. */
function safeEqual(a: string, b: string): boolean {
  const ea = new TextEncoder().encode(a);
  const eb = new TextEncoder().encode(b);
  let diff = ea.length ^ eb.length;
  for (let i = 0; i < Math.max(ea.length, eb.length); i++) diff |= (ea[i] ?? 0) ^ (eb[i] ?? 0);
  return diff === 0;
}

// ── Steps ─────────────────────────────────────────────────────────────────────

/** Flags memberships that ended before today as inactive. */
async function expireLapsedMemberships(): Promise<number> {
  const result = await db
    .updateTable("membership")
    .set({ is_active: false })
    .where("is_active", "=", true)
    .where(sql<boolean>`to_date < CURRENT_DATE`)
    .executeTakeFirst();
  return Number(result.numUpdatedRows);
}

/**
 * One `membership_expiring` notification per active membership ending within
 * 7 days, unless one was already sent for it (by an earlier run or by the
 * memberships function's lazy check).
 */
async function notifyExpiringMemberships(): Promise<number> {
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
    .where("membership.is_active", "=", true)
    .where(sql<boolean>`membership.to_date BETWEEN CURRENT_DATE AND CURRENT_DATE + 7`)
    .where(({ not, exists, selectFrom }) =>
      not(exists(
        selectFrom("notification")
          .select("notification.id")
          .whereRef("notification.user_id", "=", "membership.user_id")
          .where("notification.type", "=", "membership_expiring")
          .where(sql<boolean>`notification.metadata->>'membership_id' = membership.id::text`),
      ))
    )
    .execute();

  for (const m of due) {
    await notify([m.user_id], {
      type: "membership_expiring",
      title: `Your ${m.gym_name} membership is expiring`,
      body: `Your membership ends on ${m.to_date}. Renew it to keep training.`,
      metadata: { membership_id: m.id, gym_id: m.gym_id, gym_name: m.gym_name, to_date: m.to_date },
    });
  }
  return due.length;
}

/**
 * Reminds booked members of classes starting within the window. Classes are
 * claimed (reminder_sent_at set) before notifying, so overlapping runs never
 * remind twice.
 */
async function sendClassReminders(): Promise<{ classes: number; notifications: number }> {
  const { rows: claimed } = await sql<{
    id: string;
    gym_id: string;
    title: string;
    starts_at: Date;
    gym_name: string;
  }>`
    UPDATE gym_class c
    SET reminder_sent_at = NOW()
    FROM business b
    WHERE b.id = c.gym_id
      AND c.cancelled_at IS NULL
      AND c.reminder_sent_at IS NULL
      AND c.starts_at > NOW()
      AND c.starts_at <= NOW() + make_interval(mins => ${CLASS_REMINDER_WINDOW_MINUTES})
    RETURNING c.id, c.gym_id, c.title, c.starts_at, b.name AS gym_name
  `.execute(db);

  let notifications = 0;
  for (const c of claimed) {
    const bookings = await db
      .selectFrom("class_booking")
      .select("user_id")
      .where("class_id", "=", c.id)
      .where("status", "=", "booked")
      .execute();
    if (bookings.length === 0) continue;

    const minutes = Math.max(1, Math.round((new Date(c.starts_at).getTime() - Date.now()) / 60_000));
    const when = minutes >= 55 && minutes <= 65 ? "in about an hour" : `in ${minutes} minutes`;
    await notify(bookings.map((b) => b.user_id), {
      type: "class_reminder",
      title: `${c.title} starts ${when}`,
      body: `Your class at ${c.gym_name} starts ${when}. See you there!`,
      metadata: { class_id: c.id, gym_id: c.gym_id, gym_name: c.gym_name },
    });
    notifications += bookings.length;
  }
  return { classes: claimed.length, notifications };
}

/**
 * Deletes upload slots (and their files) that were never attached to a
 * message or post within a day — abandoned sends, closed apps.
 */
async function sweepAbandonedUploads(): Promise<number> {
  const stale = await db
    .deleteFrom("media_upload")
    .where("claimed_at", "is", null)
    .where(sql<boolean>`created_at < NOW() - INTERVAL '24 hours'`)
    .returning(["bucket", "storage_path"])
    .execute();
  for (const bucket of ["chat-media", "user-media"] as const) {
    await removeObjects(bucket, stale.filter((s) => s.bucket === bucket).map((s) => s.storage_path));
  }
  return stale.length;
}

// ── Handler ───────────────────────────────────────────────────────────────────

Deno.serve(async (req: Request) => {
  const { pathname } = new URL(req.url);

  // ── POST /jobs/run ──────────────────────────────────────────────────────────
  if (req.method === "POST" && pathname === "/jobs/run") {
    const secret = optionalSecret("CRON_SECRET");
    if (!secret) return jsonError("Scheduled jobs are not configured (CRON_SECRET is unset)", 503, { code: "not_configured" });
    const provided = req.headers.get("x-cron-secret") ?? "";
    if (!safeEqual(provided, secret)) return jsonError("Unauthorized", 401);

    // The caller is pg_cron, so a failure is only ever seen in
    // net._http_response: report which step broke and why.
    const started = Date.now();
    let step = "expire_memberships";
    try {
      const memberships_expired = await expireLapsedMemberships();
      step = "expiring_notifications";
      const expiring_notifications = await notifyExpiringMemberships();
      step = "class_reminders";
      const class_reminders = await sendClassReminders();
      step = "sweep_uploads";
      const abandoned_uploads_removed = await sweepAbandonedUploads();

      return json({
        memberships_expired,
        expiring_notifications,
        class_reminders,
        abandoned_uploads_removed,
        duration_ms: Date.now() - started,
      });
    } catch (err) {
      const message = err instanceof Error ? err.message : String(err);
      console.error(`jobs step ${step} failed`, err);
      return jsonError(`Job step ${step} failed: ${message}`, 500, { code: "job_failed" });
    }
  }

  return jsonError("Not found", 404);
});
