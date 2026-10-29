import { sql } from "npm:kysely@^0.27";
import { db } from "../_shared/config.ts";
import { forbidden, json, jsonError, requireCaller } from "../_shared/auth.ts";
import { notify } from "../_shared/notify.ts";
import { displayName } from "../_shared/social.ts";
import {
  canInvite,
  ensureCustomer,
  inviteToSeries,
  removeEnrollment,
} from "../_shared/class_series.ts";

// A trainer's customers (clients). Adding someone invites them; accepting that
// invite, or any class invite from the trainer, makes them a customer, which
// also lets the trainer coach them (coachesUser). Class invites themselves
// live in class-series.
//
//   GET    /customers                           my customers, with their classes of mine
//   GET    /customers/eligible?q=               people I can add: followers, members where I coach, customers
//   POST   /customers                           add {user_id, series_ids?}
//   DELETE /customers/:userId                   remove (and take them off my classes)
//   GET    /customers/invites                   trainers who invited me
//   POST   /customers/invites/:trainerId/accept|decline
//   GET    /customers/trainers                  trainers I'm a customer of
//   DELETE /customers/trainers/:trainerId       stop being their customer (leaves their classes)

const UUID_RE =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const MAX_SERIES_PER_ADD = 20;

type Route =
  | { kind: "list" }
  | { kind: "eligible" }
  | { kind: "one"; userId: string }
  | { kind: "invites" }
  | { kind: "answer"; trainerId: string; accept: boolean }
  | { kind: "trainers" }
  | { kind: "trainer"; trainerId: string }
  | { kind: "unknown" };

function parsePath(pathname: string): Route {
  const p = pathname.replace(/\/+$/, "").split("/").filter(Boolean);
  if (p[0] !== "customers") return { kind: "unknown" };
  if (p.length === 1) return { kind: "list" };
  if (p.length === 2 && p[1] === "eligible") return { kind: "eligible" };
  if (p.length === 2 && p[1] === "invites") return { kind: "invites" };
  if (p.length === 2 && p[1] === "trainers") return { kind: "trainers" };
  if (p.length === 2 && UUID_RE.test(p[1])) {
    return { kind: "one", userId: p[1] };
  }
  if (p.length === 3 && p[1] === "trainers" && UUID_RE.test(p[2])) {
    return { kind: "trainer", trainerId: p[2] };
  }
  if (
    p.length === 4 && p[1] === "invites" && UUID_RE.test(p[2]) &&
    (p[3] === "accept" || p[3] === "decline")
  ) {
    return { kind: "answer", trainerId: p[2], accept: p[3] === "accept" };
  }
  return { kind: "unknown" };
}

/** Series the trainer teaches or created (a subquery). */
const mySeriesSql = (trainerId: string) =>
  db.selectFrom("class_series").select("id")
    .where((eb) =>
      eb.or([
        eb("trainer_id", "=", trainerId),
        eb("created_by", "=", trainerId),
      ])
    );

async function customersOf(trainerId: string, onlyUserId?: string) {
  const { rows } = await sql<{
    user_id: string;
    username: string;
    name: string;
    last_name: string;
    avatar_url: string | null;
    status: "pending" | "accepted";
    created_at: string;
    accepted_at: string | null;
    classes: {
      series_id: string;
      title: string;
      status: string;
      active: boolean;
    }[];
  }>`
    SELECT u.id AS user_id, u.username, u.name, u.last_name, u.avatar_url,
      tc.status, tc.created_at, tc.accepted_at,
      COALESCE((
        SELECT json_agg(json_build_object('series_id', s.id, 'title', s.title, 'status', e.status, 'active', s.active)
                        ORDER BY s.title)
        FROM class_enrollment e JOIN class_series s ON s.id = e.series_id
        WHERE e.user_id = u.id AND s.id IN (${mySeriesSql(trainerId)})
      ), '[]'::json) AS classes
    FROM trainer_customer tc JOIN users u ON u.id = tc.user_id
    WHERE tc.trainer_id = ${trainerId} AND NOT is_blocked_between(tc.user_id, ${trainerId})
      ${onlyUserId ? sql`AND tc.user_id = ${onlyUserId}` : sql``}
    ORDER BY (tc.status = 'pending'), u.name, u.last_name
  `.execute(db);
  return rows;
}

async function handler(req: Request): Promise<Response> {
  const { caller, response } = await requireCaller(req);
  if (response) return response;
  const url = new URL(req.url);
  const route = parsePath(url.pathname);
  if (route.kind === "unknown") return jsonError("Not found", 404);

  // ── GET /customers ───────────────────────────────────────────────────────────
  if (req.method === "GET" && route.kind === "list") {
    return json(await customersOf(caller.id));
  }

  // ── GET /customers/eligible?q= ───────────────────────────────────────────────
  if (req.method === "GET" && route.kind === "eligible") {
    const q = (url.searchParams.get("q") ?? "").trim().slice(0, 100);
    const pattern = `%${q.replace(/[\\%_]/g, (c) => `\\${c}`)}%`;
    const { rows } = await sql`
      WITH coached AS (
        SELECT gym_id FROM trainer WHERE user_id = ${caller.id}
        UNION SELECT gym_id FROM employee_trainer WHERE user_id = ${caller.id}
        UNION SELECT gym_id FROM employee WHERE user_id = ${caller.id}
        UNION SELECT gym_id FROM gym_owner WHERE user_id = ${caller.id}
      )
      SELECT u.id, u.username, u.name, u.last_name, u.avatar_url,
        EXISTS (SELECT 1 FROM follow f WHERE f.follower_id = u.id AND f.followee_id = ${caller.id}
                AND f.status = 'accepted') AS follows_you,
        EXISTS (SELECT 1 FROM member m WHERE m.user_id = u.id AND m.gym_id IN (SELECT gym_id FROM coached)) AS is_member,
        tc.status AS customer_status
      FROM users u
      LEFT JOIN trainer_customer tc ON tc.trainer_id = ${caller.id} AND tc.user_id = u.id
      WHERE u.id <> ${caller.id}
        AND (
          u.id IN (SELECT follower_id FROM follow WHERE followee_id = ${caller.id} AND status = 'accepted')
          OR u.id IN (SELECT user_id FROM member WHERE gym_id IN (SELECT gym_id FROM coached))
          OR tc.user_id IS NOT NULL
        )
        AND NOT is_blocked_between(u.id, ${caller.id})
        AND (${q} = '' OR CONCAT(u.name, ' ', u.last_name) ILIKE ${pattern} OR u.username ILIKE ${pattern})
      ORDER BY (tc.user_id IS NOT NULL), u.name, u.last_name
      LIMIT 50
    `.execute(db);
    return json(rows);
  }

  // ── POST /customers {user_id, series_ids?} ───────────────────────────────────
  if (req.method === "POST" && route.kind === "list") {
    const body = await req.json().catch(() => null);
    const userId = body?.user_id;
    if (typeof userId !== "string" || !UUID_RE.test(userId)) {
      return jsonError("user_id is required", 400);
    }
    const seriesIds: unknown = body?.series_ids ?? [];
    if (
      !Array.isArray(seriesIds) ||
      seriesIds.some((x) => typeof x !== "string" || !UUID_RE.test(x))
    ) {
      return jsonError("series_ids must be a list of class ids", 400);
    }
    if (seriesIds.length > MAX_SERIES_PER_ADD) {
      return jsonError(`Up to ${MAX_SERIES_PER_ADD} classes at once`, 400);
    }
    if (!(await canInvite(caller.id, userId))) {
      return jsonError(
        "Only your followers, members of gyms where you coach, or your customers can be added",
        400,
      );
    }

    // Only the caller's own classes, and only active ones.
    const series = seriesIds.length
      ? await db.selectFrom("class_series").select([
        "id",
        "gym_id",
        "title",
        "trainer_id",
        "active",
      ])
        .where("id", "in", seriesIds as string[])
        .where((eb) =>
          eb.or([
            eb("trainer_id", "=", caller.id),
            eb("created_by", "=", caller.id),
          ])
        )
        .execute()
      : [];
    if (series.length !== new Set(seriesIds as string[]).size) {
      return jsonError("You can only add people to your own classes", 400);
    }
    if (series.some((s) => !s.active)) {
      return jsonError("Some of these classes are paused", 400);
    }

    const isNew = await ensureCustomer(db, caller.id, userId);
    for (const s of series) {
      const r = await inviteToSeries(caller, s, userId);
      if (!r.ok) return jsonError(r.error, r.status);
    }
    // Class invites carry their own notifications; a bare add asks once.
    if (isNew && series.length === 0) {
      await notify([userId], {
        type: "events",
        title: `${displayName(caller)} wants to train you`,
        body: `${
          displayName(caller)
        } added you as a customer. Accept to let them plan your classes and workouts.`,
        metadata: { kind: "customer_invite", trainer_id: caller.id },
      });
    }
    const [row] = await customersOf(caller.id, userId);
    return json(row, isNew ? 201 : 200);
  }

  // ── DELETE /customers/:userId ────────────────────────────────────────────────
  if (req.method === "DELETE" && route.kind === "one") {
    const gone = await db.deleteFrom("trainer_customer")
      .where("trainer_id", "=", caller.id).where("user_id", "=", route.userId)
      .returning("user_id").executeTakeFirst();
    if (!gone) return jsonError("Not one of your customers", 404);
    await leaveTrainerClasses(caller.id, route.userId);
    return new Response(null, { status: 204 });
  }

  // ── GET /customers/invites ───────────────────────────────────────────────────
  if (req.method === "GET" && route.kind === "invites") {
    const rows = await db.selectFrom("trainer_customer as tc")
      .innerJoin("users as u", "u.id", "tc.trainer_id")
      .select([
        "u.id",
        "u.username",
        "u.name",
        "u.last_name",
        "u.avatar_url",
        "tc.created_at",
      ])
      .where("tc.user_id", "=", caller.id).where("tc.status", "=", "pending")
      // A pending class invite from the trainer already asks (accepting it
      // makes them a customer), so don't ask twice.
      .where(({ not, exists, selectFrom }) =>
        not(exists(
          selectFrom("class_enrollment as e")
            .innerJoin("class_series as s", "s.id", "e.series_id")
            .select("e.user_id")
            .whereRef("e.user_id", "=", "tc.user_id")
            .where("e.status", "=", "pending")
            .where((eb) =>
              eb.or([
                eb("s.trainer_id", "=", eb.ref("tc.trainer_id")),
                eb("s.created_by", "=", eb.ref("tc.trainer_id")),
              ])
            ),
        ))
      )
      .orderBy("tc.created_at", "desc")
      .execute();
    return json(rows);
  }

  // ── POST /customers/invites/:trainerId/accept|decline ────────────────────────
  if (req.method === "POST" && route.kind === "answer") {
    const pending = await db.selectFrom("trainer_customer").select("status")
      .where("trainer_id", "=", route.trainerId).where(
        "user_id",
        "=",
        caller.id,
      ).executeTakeFirst();
    if (!pending || pending.status !== "pending") {
      return jsonError("No pending invite from this trainer", 404);
    }
    if (route.accept) {
      await db.updateTable("trainer_customer").set({
        status: "accepted",
        accepted_at: sql<string>`NOW()`,
      })
        .where("trainer_id", "=", route.trainerId).where(
          "user_id",
          "=",
          caller.id,
        ).execute();
      await notify([route.trainerId], {
        type: "events",
        title: `${displayName(caller)} is now your customer`,
        body: `${displayName(caller)} accepted your invite.`,
        metadata: { kind: "customer_accepted", user_id: caller.id },
      });
    } else {
      // Declining the trainer declines their pending class invites too.
      await db.deleteFrom("trainer_customer")
        .where("trainer_id", "=", route.trainerId).where(
          "user_id",
          "=",
          caller.id,
        ).execute();
      await db.updateTable("class_enrollment").set({
        status: "declined",
        responded_at: sql<string>`NOW()`,
      })
        .where("user_id", "=", caller.id).where("status", "=", "pending")
        .where("series_id", "in", mySeriesSql(route.trainerId)).execute();
    }
    return json({
      trainer_id: route.trainerId,
      status: route.accept ? "accepted" : "declined",
    });
  }

  // ── GET /customers/trainers ──────────────────────────────────────────────────
  if (req.method === "GET" && route.kind === "trainers") {
    const rows = await db.selectFrom("trainer_customer as tc")
      .innerJoin("users as u", "u.id", "tc.trainer_id")
      .select([
        "u.id",
        "u.username",
        "u.name",
        "u.last_name",
        "u.avatar_url",
        "tc.accepted_at",
      ])
      .where("tc.user_id", "=", caller.id).where("tc.status", "=", "accepted")
      .orderBy("u.name")
      .execute();
    return json(rows);
  }

  // ── DELETE /customers/trainers/:trainerId ────────────────────────────────────
  if (req.method === "DELETE" && route.kind === "trainer") {
    const gone = await db.deleteFrom("trainer_customer")
      .where("trainer_id", "=", route.trainerId).where(
        "user_id",
        "=",
        caller.id,
      )
      .returning("user_id").executeTakeFirst();
    if (!gone) return jsonError("You're not this trainer's customer", 404);
    await leaveTrainerClasses(route.trainerId, caller.id);
    return new Response(null, { status: 204 });
  }

  if (route.kind === "one" || route.kind === "trainer") return forbidden();
  return jsonError("Method not allowed", 405);
}

/** Takes the person off every class of the trainer's (invites included). */
async function leaveTrainerClasses(trainerId: string, userId: string) {
  const enrolled = await db.selectFrom("class_enrollment").select("series_id")
    .where("user_id", "=", userId).where(
      "series_id",
      "in",
      mySeriesSql(trainerId),
    ).execute();
  for (const e of enrolled) await removeEnrollment(e.series_id, userId);
}

Deno.serve(handler);
