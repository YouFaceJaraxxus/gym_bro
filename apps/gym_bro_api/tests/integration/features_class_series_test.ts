// deno-lint-ignore-file no-explicit-any
// Class timetables (class-series): sessions generated 90 days ahead with several
// start times a day, per-class invites (accept books every session, decline
// and leave), capacity and waitlists, timetable edits and pausing, and the
// customers a trainer gets from invites (coaching access included). Series
// and their sessions are deleted with SQL in `finally`; follows, customers and
// notifications are put back.
import { call, checker, seededUsers, short, signin, suite } from "./_client.ts";
import { deleteNotificationsWhere, restorePair, snapshotPair, sql } from "./_db.ts";

const OTHER_GYM_OWNER = "andrew.foster@example.com";

/** A moment's local date ("YYYY-MM-DD"), time ("HH:MM") and ISO weekday in [timeZone]. */
function localSlot(at: Date | number, timeZone: string) {
  const parts = new Intl.DateTimeFormat("en-CA", {
    timeZone,
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
    hourCycle: "h23",
  }).formatToParts(at);
  const p = Object.fromEntries(parts.map((x) => [x.type, x.value]));
  const date = `${p.year}-${p.month}-${p.day}`;
  return { date, time: `${p.hour}:${p.minute}`, weekday: isoWeekday(date) };
}

/** 1 = Monday … 7 = Sunday. */
const isoWeekday = (date: string) => new Date(`${date}T00:00:00Z`).getUTCDay() || 7;
const nextDate = (date: string) => new Date(Date.parse(`${date}T00:00:00Z`) + 86_400_000).toISOString().slice(0, 10);

Deno.test({
  name: "features: class timetables, invites and customers",
  ...suite,
  async fn(t) {
    const { check, assertAll } = checker();
    const { member, trainer, vendor, owner, gym } = await seededUsers();
    const outsider = await signin(OTHER_GYM_OWNER);
    const T = trainer.profile.id as string;
    const L = member.profile.id as string;
    const V = vendor.profile.id as string;
    const stamp = Date.now();
    const created: string[] = [];
    let seriesId = "";
    const snap = await snapshotPair(V, T);
    const customers = (await sql<{ user_id: string; status: string }>(
      `SELECT user_id, status FROM trainer_customer WHERE trainer_id = $1`,
      [T],
    )) ?? [];
    // Start from no customers (they're put back in `finally`).
    await sql(`DELETE FROM trainer_customer WHERE trainer_id = $1`, [T]);

    const base = {
      gym_id: gym.id,
      capacity: 1,
      duration_minutes: 45,
      repeat: "weekly",
      weekdays: [1, 3, 5],
      times: ["07:00", "18:30"],
      timezone: "Europe/Belgrade",
    };
    const sessionsOf = async (seriesId: string) =>
      (await sql<{ id: string; starts_at: Date; cancelled_at: Date | null }>(
        `SELECT id, starts_at, cancelled_at FROM gym_class WHERE series_id = $1 ORDER BY starts_at`,
        [seriesId],
      )) ?? [];
    const bookingsOf = async (seriesId: string, userId: string) =>
      (await sql<{ status: string }>(
        `SELECT b.status FROM class_booking b JOIN gym_class c ON c.id = b.class_id
         WHERE c.series_id = $1 AND b.user_id = $2 AND c.starts_at > NOW() AND c.cancelled_at IS NULL`,
        [seriesId, userId],
      )) ?? [];

    try {
      await t.step("1. create: validation and 90 days of sessions", async () => {
        const invalid: [string, unknown][] = [
          ["no gym", { ...base, gym_id: undefined, title: "x" }],
          ["no title", { ...base }],
          ["no times", { ...base, title: "x", times: [] }],
          ["a bad time", { ...base, title: "x", times: ["25:00"] }],
          ["weekly without weekdays", { ...base, title: "x", weekdays: [] }],
          ["a bad weekday", { ...base, title: "x", weekdays: [8] }],
          ["a bad timezone", { ...base, title: "x", timezone: "Mars/Olympus" }],
          ["a 2-minute class", { ...base, title: "x", duration_minutes: 2 }],
          ["ends before it starts", { ...base, title: "x", starts_on: "2030-01-10", ends_on: "2030-01-01" }],
        ];
        for (const [name, body] of invalid) {
          const r = await call("POST", "/class-series", trainer.token, body);
          if (r.data?.id) created.push(r.data.id);
          check(`create with ${name} is 400`, r.status === 400, `status ${r.status} ${short(r.data)}`);
        }
        const notCoach = await call("POST", "/class-series", member.token, { ...base, title: "x" });
        check("members can't create classes", notCoach.status === 403, `status ${notCoach.status}`);
        const otherGym = await call("POST", "/class-series", outsider.token, { ...base, title: "x" });
        check("another gym's staff can't create classes here", otherGym.status === 403, `status ${otherGym.status}`);

        const createdAt = Date.now();
        const made = await call("POST", "/class-series", trainer.token, { ...base, title: `Series Test ${stamp}` });
        if (made.data?.id) created.push(made.data.id);
        seriesId = made.data?.id;
        check(
          "trainer creates a twice-a-day, three-days-a-week class",
          made.status === 201 && made.data.trainer_id === T && made.data.state === "active" && made.data.can_edit === true &&
            made.data.times.join() === "07:00,18:30" && made.data.weekdays.join() === "1,3,5",
          short(made.data),
        );
        // Every Mon/Wed/Fri 07:00 and 18:30 (local) from now through 90 days
        // ahead, each once. Today's slots within a minute of creating it may
        // or may not have been generated.
        const sessions = await sessionsOf(made.data.id);
        const today = localSlot(createdAt, base.timezone);
        const settled = localSlot(createdAt + 60_000, base.timezone);
        const lastDate = new Date(Date.parse(`${today.date}T00:00:00Z`) + 90 * 86_400_000).toISOString().slice(0, 10);
        const expected: string[] = [];
        for (let date = today.date; date <= lastDate; date = nextDate(date)) {
          if (!base.weekdays.includes(isoWeekday(date))) continue;
          for (const time of base.times) {
            const unsettled = date === today.date && (settled.date > today.date || time <= settled.time);
            if (!unsettled) expected.push(`${date} ${time}`);
          }
        }
        const got = sessions.map((s) => localSlot(new Date(s.starts_at), base.timezone));
        const gotKeys = got.map((s) => `${s.date} ${s.time}`);
        const offRule = got.filter((s) =>
          !base.weekdays.includes(s.weekday) || !base.times.includes(s.time) || s.date < today.date || s.date > lastDate
        );
        check(
          "sessions fall only on Mon/Wed/Fri at 07:00 and 18:30 local, from today through 90 days ahead",
          offRule.length === 0 && sessions.every((s) => new Date(s.starts_at).getTime() > createdAt),
          `off-rule: ${offRule.slice(0, 3).map((s) => `${s.date} ${s.time}`).join(", ")}`,
        );
        const missing = expected.filter((k) => !gotKeys.includes(k));
        check(
          "every upcoming slot has exactly one session",
          missing.length === 0 && new Set(gotKeys).size === gotKeys.length,
          `n=${sessions.length} expected=${expected.length} missing: ${missing.slice(0, 3).join(", ")}`,
        );
        const listed = (await call("GET", "/class-series", trainer.token)).data as any[];
        check("it's in the trainer's list", listed?.some((s) => s.id === made.data.id && s.upcoming_count === sessions.length));
        const gymList = await call("GET", `/class-series?gym_id=${gym.id}`, owner.token);
        check("and in the gym's list for the owner", gymList.data?.some((s: any) => s.id === made.data.id && s.can_edit));
        const classes = (await call("GET", `/classes?trainer_id=${T}`, trainer.token)).data as any[];
        check(
          "sessions show up as classes, marked recurring",
          classes?.some((c) => c.series_id === made.data.id && c.is_recurring === true),
          `n=${classes?.length}`,
        );
        const oneOff = await call("POST", "/class-series", trainer.token, {
          ...base,
          title: `One-off ${stamp}`,
          repeat: "none",
          starts_on: new Date(Date.now() + 3 * 86_400_000).toISOString().slice(0, 10),
          times: ["09:00", "12:00", "17:00"],
        });
        if (oneOff.data?.id) created.push(oneOff.data.id);
        check(
          "a one-off can run several times on its day",
          oneOff.status === 201 && (await sessionsOf(oneOff.data.id)).length === 3 && oneOff.data.weekdays.length === 0,
          short(oneOff.data),
        );
      });
      assertAll();

      await t.step("2. invites: eligibility, accept books every session, capacity, leave", async () => {
        await call("DELETE", `/social/users/${T}/follow`, vendor.token);
        const notEligible = await call("POST", `/class-series/${seriesId}/enrollments`, trainer.token, { user_id: V });
        check("a non-member non-follower can't be invited", notEligible.status === 400, short(notEligible.data));
        const byMember = await call("POST", `/class-series/${seriesId}/enrollments`, member.token, { user_id: V });
        check("members can't invite", byMember.status === 403, `status ${byMember.status}`);

        const invite = await call("POST", `/class-series/${seriesId}/enrollments`, trainer.token, { user_id: L });
        check(
          "trainer invites a gym member",
          invite.status === 201 && invite.data.enrollments.some((e: any) => e.user_id === L && e.status === "pending"),
          short(invite.data),
        );
        const again = await call("POST", `/class-series/${seriesId}/enrollments`, trainer.token, { user_id: L });
        check("inviting twice is 409", again.status === 409, `status ${again.status}`);
        const invites = (await call("GET", "/class-series/invites", member.token)).data as any[];
        const mine = invites?.find((i) => i.id === seriesId);
        check(
          "the member sees the invite, from the trainer",
          mine?.my_enrollment_status === "pending" && mine.invited_by?.id === T,
          short(mine),
        );
        const peek = await call("GET", `/class-series/${seriesId}`, member.token);
        check("an invitee can open the class but not its enrollments", peek.status === 200 && peek.data.enrollments === null);
        const stranger = await call("GET", `/class-series/${seriesId}`, outsider.token);
        check("strangers can't open it", stranger.status === 403, `status ${stranger.status}`);
        const custPending = (await call("GET", "/customers", trainer.token)).data as any[];
        check(
          "an invite makes them a pending customer with that class",
          custPending?.some((c) => c.user_id === L && c.status === "pending" && c.classes.some((x: any) => x.series_id === seriesId)),
          short(custPending?.find((c) => c.user_id === L)),
        );

        const asked = (await call("GET", "/customers/invites", member.token)).data as any[];
        check("a class invite doesn't also show as a trainer invite", !asked?.some((i) => i.id === T), short(asked));
        const accept = await call("POST", `/class-series/${seriesId}/accept`, member.token);
        const booked = await bookingsOf(seriesId, L);
        const sessions = (await sessionsOf(seriesId)).filter((s) => new Date(s.starts_at).getTime() > Date.now());
        check(
          "accepting books every upcoming session",
          accept.status === 200 && accept.data.my_enrollment_status === "accepted" && booked.length === sessions.length &&
            booked.every((b) => b.status === "booked"),
          `booked=${booked.length} sessions=${sessions.length}`,
        );
        const schedule = (await call("GET", "/classes?mine=true", member.token)).data as any[];
        check("they're in the member's schedule", schedule?.some((c) => c.series_id === seriesId && c.my_booking_status === "booked"));
        const custNow = (await call("GET", "/customers", trainer.token)).data as any[];
        check("…and an accepted customer", custNow?.some((c) => c.user_id === L && c.status === "accepted"));
        const coach = await call("GET", `/progress/summary?user_id=${L}`, trainer.token);
        check("the trainer can see their customer's progress", coach.status === 200, `status ${coach.status}`);
        const acceptTwice = await call("POST", `/class-series/${seriesId}/accept`, member.token);
        check("there's nothing left to accept", acceptTwice.status === 404, `status ${acceptTwice.status}`);

        // Capacity 1: a second accepted enrollee is waitlisted everywhere.
        const follow = await call("POST", `/social/users/${T}/follow`, vendor.token);
        check("vendor follows the trainer", follow.data?.relationship?.following === "accepted", short(follow.data));
        const invite2 = await call("POST", `/class-series/${seriesId}/enrollments`, trainer.token, { user_id: V });
        check("a follower can be invited", invite2.status === 201, short(invite2.data));
        await call("POST", `/class-series/${seriesId}/accept`, vendor.token);
        const waiting = await bookingsOf(seriesId, V);
        check("…and is waitlisted when the class is full", waiting.length > 0 && waiting.every((b) => b.status === "waitlisted"));

        // The member leaves: the waitlisted follower takes the seats.
        const leave = await call("DELETE", `/class-series/${seriesId}/enrollments/${L}`, member.token);
        const gone = await bookingsOf(seriesId, L);
        const promoted = await bookingsOf(seriesId, V);
        check(
          "leaving cancels my bookings and promotes the waitlist",
          leave.status === 204 && gone.every((b) => b.status === "cancelled") && promoted.every((b) => b.status === "booked"),
          `mine=${short(gone.slice(0, 2))} theirs=${short(promoted.slice(0, 2))}`,
        );
        const removeByStranger = await call("DELETE", `/class-series/${seriesId}/enrollments/${V}`, outsider.token);
        check("strangers can't remove people", removeByStranger.status === 403, `status ${removeByStranger.status}`);

        // Decline keeps the row so the trainer sees it; re-inviting works.
        await call("POST", `/class-series/${seriesId}/enrollments`, trainer.token, { user_id: L });
        const decline = await call("POST", `/class-series/${seriesId}/decline`, member.token);
        const detail = await call("GET", `/class-series/${seriesId}`, trainer.token);
        check(
          "a decline shows on the class",
          decline.status === 200 && detail.data.enrollments.some((e: any) => e.user_id === L && e.status === "declined"),
          short(detail.data?.enrollments),
        );
        const reinvite = await call("POST", `/class-series/${seriesId}/enrollments`, trainer.token, { user_id: L });
        check("a declined invite can be sent again", reinvite.status === 201, `status ${reinvite.status}`);
      });
      assertAll();

      await t.step("3. edits: details, timetable, capacity and pausing", async () => {
        const before = (await sessionsOf(seriesId)).filter((s) => !s.cancelled_at && new Date(s.starts_at).getTime() > Date.now());
        const byMember = await call("PUT", `/class-series/${seriesId}`, member.token, { title: "x" });
        check("members can't edit", byMember.status === 403, `status ${byMember.status}`);
        const empty = await call("PUT", `/class-series/${seriesId}`, trainer.token, {});
        check("an empty edit is 400", empty.status === 400, `status ${empty.status}`);
        const low = await call("PUT", `/class-series/${seriesId}`, trainer.token, { capacity: 0 });
        check("capacity 0 is 400", low.status === 400, `status ${low.status}`);

        const renamed = await call("PUT", `/class-series/${seriesId}`, trainer.token, {
          title: `Series Renamed ${stamp}`,
          capacity: 3,
          duration_minutes: 60,
        });
        const sample = (await call("GET", `/classes/${before[0].id}`, trainer.token)).data;
        check(
          "detail edits reach upcoming sessions",
          renamed.status === 200 && sample?.title === `Series Renamed ${stamp}` && sample.capacity === 3 &&
            new Date(sample.ends_at).getTime() - new Date(sample.starts_at).getTime() === 60 * 60_000,
          short(sample),
        );

        // Drop the 18:30 slot and Fridays: those sessions go (the booked ones are cancelled).
        const retimed = await call("PUT", `/class-series/${seriesId}`, trainer.token, { weekdays: [1, 3], times: ["07:00"] });
        const after = (await sessionsOf(seriesId)).filter((s) => !s.cancelled_at && new Date(s.starts_at).getTime() > Date.now());
        const vendorBookings = await bookingsOf(seriesId, V);
        check(
          "a timetable change keeps only matching sessions",
          retimed.status === 200 && after.length < before.length / 2 && after.length > 0 &&
            vendorBookings.filter((b) => b.status === "booked").length === after.length,
          `before=${before.length} after=${after.length} booked=${vendorBookings.filter((b) => b.status === "booked").length}`,
        );
        const told = await sql<{ n: number }>(
          `SELECT COUNT(*)::int AS n FROM notification WHERE user_id = $1 AND title LIKE 'Class cancelled:%'
             AND metadata->>'class_id' IN (SELECT id::text FROM gym_class WHERE series_id = $2)`,
          [V, seriesId],
        );
        check("people booked into dropped sessions are told", (told?.[0]?.n ?? 0) > 0, short(told));

        const paused = await call("PUT", `/class-series/${seriesId}`, trainer.token, { active: false });
        const left = (await sessionsOf(seriesId)).filter((s) => !s.cancelled_at && new Date(s.starts_at).getTime() > Date.now());
        check("pausing clears upcoming sessions", paused.status === 200 && paused.data.state === "paused" && left.length === 0, `left=${left.length}`);
        const inviteWhilePaused = await call("POST", `/class-series/${seriesId}/enrollments`, trainer.token, { user_id: V });
        check("no invites to a paused class", inviteWhilePaused.status === 400, `status ${inviteWhilePaused.status}`);
        const resumed = await call("PUT", `/class-series/${seriesId}`, trainer.token, { active: true });
        const back = (await sessionsOf(seriesId)).filter((s) => !s.cancelled_at && new Date(s.starts_at).getTime() > Date.now());
        const rebooked = (await bookingsOf(seriesId, V)).filter((b) => b.status === "booked");
        check(
          "resuming brings sessions back with enrollees booked",
          resumed.status === 200 && back.length === after.length && rebooked.length === back.length,
          `back=${back.length} rebooked=${rebooked.length}`,
        );
      });
      assertAll();

      await t.step("4. customers: add without classes, accept, remove", async () => {
        const nope = await call("POST", "/customers", trainer.token, { user_id: outsider.profile.id });
        check("strangers can't be added as customers", nope.status === 400, short(nope.data));
        await call("DELETE", `/customers/${V}`, trainer.token);
        const add = await call("POST", "/customers", trainer.token, { user_id: V });
        check("a follower can be added with no classes", add.status === 201 && add.data.status === "pending", short(add.data));
        const eligible = (await call("GET", "/customers/eligible", trainer.token)).data as any[];
        check("eligible lists them as a pending customer", eligible?.some((u) => u.id === V && u.customer_status === "pending"));
        const invites = (await call("GET", "/customers/invites", vendor.token)).data as any[];
        check("the vendor sees the trainer's invite", invites?.some((i) => i.id === T), short(invites));
        const accept = await call("POST", `/customers/invites/${T}/accept`, vendor.token);
        const trainers = (await call("GET", "/customers/trainers", vendor.token)).data as any[];
        check("accepting makes it mutual", accept.status === 200 && trainers?.some((x) => x.id === T), short(trainers));
        const remove = await call("DELETE", `/customers/${V}`, trainer.token);
        const after = (await call("GET", "/customers", trainer.token)).data as any[];
        check("the trainer can remove a customer", remove.status === 204 && !after?.some((c) => c.user_id === V));
        const coachGone = await call("GET", `/progress/summary?user_id=${V}`, trainer.token);
        check("…which ends coaching access", coachGone.status === 403, `status ${coachGone.status}`);
      });
      assertAll();
    } finally {
      await deleteNotificationsWhere("series_id", created);
      if (created.length) {
        await sql(
          `DELETE FROM notification WHERE metadata->>'class_id' IN
             (SELECT id::text FROM gym_class WHERE series_id = ANY($1::uuid[]))`,
          [created.filter(Boolean)],
        );
        await sql(`DELETE FROM class_series WHERE id = ANY($1::uuid[])`, [created.filter(Boolean)]);
      }
      await sql(`DELETE FROM trainer_customer WHERE trainer_id = $1`, [T]);
      for (const c of customers) {
        await sql(
          `INSERT INTO trainer_customer (trainer_id, user_id, status, accepted_at)
           VALUES ($1, $2, $3, CASE WHEN $3 = 'accepted' THEN NOW() END)`,
          [T, c.user_id, c.status],
        );
      }
      await sql(
        `DELETE FROM notification WHERE (metadata->>'trainer_id' = $1 OR metadata->>'user_id' = ANY($2::text[]))
           AND metadata->>'kind' IN ('customer_invite', 'customer_accepted', 'class_joined')`,
        [T, [L, V]],
      );
      await restorePair(V, T, snap);
    }
  },
});
