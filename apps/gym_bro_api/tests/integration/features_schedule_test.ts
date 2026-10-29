// deno-lint-ignore-file no-explicit-any
// Classes (booking, waitlist, attendance, series, trainer assignment, listing
// filters) and staff shifts (rota, reassignment, notifications), each checked
// against staff of another gym too. Classes have no hard-delete endpoint, so
// created rows are removed with SQL in `finally` (see _db.ts); shifts and
// notifications go through the API.
import {
  call,
  checker,
  deleteNotifications,
  futureAt,
  notificationsOf,
  seededUsers,
  type Session,
  short,
  signin,
  suite,
} from "./_client.ts";
import { deleteNotificationsWhere, sql } from "./_db.ts";

// Owner of Coastal Barbell Club: staff, but of another gym.
const OTHER_GYM_OWNER = "andrew.foster@example.com";

Deno.test({
  name: "features: classes and shifts",
  ...suite,
  async fn(t) {
    const { check, assertAll } = checker();
    const { member, owner, trainer, employee, superU, vendor, gym } = await seededUsers();
    const outsider = await signin(OTHER_GYM_OWNER);
    const stamp = Date.now();

    // A second member of the same gym, for waitlist promotion.
    const roster = (await call("GET", `/members?gym_id=${gym.id}`, owner.token)).data as any[];
    const otherRow = roster.find((m) => m.user_id !== member.profile.id && typeof m.email === "string");
    check("gym has a second member", !!otherRow, `n=${roster.length}`);
    assertAll();
    const member2 = await signin(otherRow.email);

    await t.step("1. classes: create, book, waitlist, attendance, series cancel", async () => {
      const created: string[] = [];
      try {
        const base = {
          gym_id: gym.id,
          description: "integration test",
          location: "Studio T",
        };
        // Days ahead are randomised a little so reruns don't stack on one slot.
        const day = 3 + (stamp % 5);

        const single = await call("POST", "/classes", trainer.token, {
          ...base,
          title: `Test HIIT ${stamp}`,
          starts_at: futureAt(day, 18),
          ends_at: futureAt(day, 19),
          capacity: 10,
        });
        check("trainer creates a class", single.status === 201 && Array.isArray(single.data) && single.data.length === 1, short(single.data));
        const cls = single.data?.[0];
        if (cls?.id) created.push(cls.id);
        check("class defaults trainer_id to the creating trainer", cls?.trainer_id === trainer.profile.id && cls?.can_coach === true, short(cls));

        const series = await call("POST", "/classes", trainer.token, {
          ...base,
          title: `Test Yoga ${stamp}`,
          starts_at: futureAt(day, 7),
          ends_at: futureAt(day, 8),
          capacity: 5,
          repeat_weeks: 2,
        });
        const seriesRows = (series.data ?? []) as any[];
        created.push(...seriesRows.map((r) => r.id).filter(Boolean));
        check(
          "trainer creates a 2-week series",
          series.status === 201 && seriesRows.length === 2 && !!seriesRows[0].series_id &&
            seriesRows[0].series_id === seriesRows[1].series_id &&
            new Date(seriesRows[1].starts_at).getTime() - new Date(seriesRows[0].starts_at).getTime() === 7 * 86_400_000,
          short(series.data),
        );

        const badRepeat = await call("POST", "/classes", trainer.token, {
          ...base, title: "x", starts_at: futureAt(day, 9), ends_at: futureAt(day, 10), capacity: 5, repeat_weeks: 13,
        });
        check("repeat_weeks above 12 is rejected", badRepeat.status === 400, `status ${badRepeat.status}`);
        const badTimes = await call("POST", "/classes", trainer.token, {
          ...base, title: "x", starts_at: futureAt(day, 10), ends_at: futureAt(day, 9), capacity: 5,
        });
        check("ends_at before starts_at is rejected", badTimes.status === 400, `status ${badTimes.status}`);

        // ── Member permissions ──
        const memberCreate = await call("POST", "/classes", member.token, {
          ...base, title: "Member class", starts_at: futureAt(day, 12), ends_at: futureAt(day, 13), capacity: 5,
        });
        check("member can't create a class", memberCreate.status === 403, `status ${memberCreate.status}`);
        if (memberCreate.status === 201) created.push(...(memberCreate.data as any[]).map((r) => r.id));
        const memberEdit = await call("PUT", `/classes/${cls.id}`, member.token, { title: "pwned" });
        check("member can't edit a class", memberEdit.status === 403, `status ${memberEdit.status}`);
        const memberCancel = await call("DELETE", `/classes/${cls.id}`, member.token);
        check("member can't cancel a class", memberCancel.status === 403, `status ${memberCancel.status}`);
        const vendorRead = await call("GET", `/classes/${cls.id}`, vendor.token);
        check("unrelated vendor can't read the class", vendorRead.status === 403, `status ${vendorRead.status}`);
        const vendorBook = await call("POST", `/classes/${cls.id}/book`, vendor.token);
        check("non-member can't book", vendorBook.status === 403, `status ${vendorBook.status}`);

        // ── Booking ──
        const book = await call("POST", `/classes/${cls.id}/book`, member.token);
        check("member books the class", book.status === 201 && book.data.status === "booked", short(book.data));
        const again = await call("POST", `/classes/${cls.id}/book`, member.token);
        check("second booking is 409", again.status === 409, `status ${again.status}`);
        const listed = await call("GET", `/classes?gym_id=${gym.id}&mine=true&to=${futureAt(day + 1, 0)}`, member.token);
        check(
          "booked class appears in ?mine=true with my_booking_status",
          listed.status === 200 && (listed.data as any[]).some((c) => c.id === cls.id && c.my_booking_status === "booked" && c.booked_count === 1),
          `status ${listed.status}`,
        );

        const trainerEdit = await call("PUT", `/classes/${cls.id}`, trainer.token, { title: `Test HIIT ${stamp} (edited)`, capacity: 12 });
        check("trainer edits own class", trainerEdit.status === 200 && trainerEdit.data.capacity === 12, short(trainerEdit.data));

        const memberForOther = await call("POST", `/classes/${cls.id}/book`, member2.token, { user_id: member.profile.id });
        check("member can't book for someone else", memberForOther.status === 403, `status ${memberForOther.status}`);
        const staffBook = await call("POST", `/classes/${cls.id}/book`, trainer.token, { user_id: member2.profile.id });
        check("coach books a member in", staffBook.status === 201 && staffBook.data.user_id === member2.profile.id, short(staffBook.data));
        const staffBookNonMember = await call("POST", `/classes/${cls.id}/book`, trainer.token, { user_id: vendor.profile.id });
        check("coach can't book a non-member", staffBookNonMember.status === 400, `status ${staffBookNonMember.status}`);
        const moved = await call("PUT", `/classes/${cls.id}`, trainer.token, { starts_at: futureAt(day, 18, 30) });
        check(
          "moving the start keeps the duration",
          moved.status === 200 && new Date(moved.data.ends_at).getTime() - new Date(moved.data.starts_at).getTime() === 3_600_000,
          short(moved.data),
        );
        const movedNotice = (await notificationsOf(member2.token)).find((n) => n.metadata?.class_id === cls.id && /updated/i.test(n.title));
        check("booked members are told the class moved", !!movedNotice, short(movedNotice));
        const shrinkBelow = await call("PUT", `/classes/${cls.id}`, trainer.token, { capacity: 1 });
        check("capacity can't drop below the booked count", shrinkBelow.status === 400, `status ${shrinkBelow.status}`);

        // ── Capacity 1: waitlist and promotion ──
        const tiny = await call("POST", "/classes", trainer.token, {
          ...base, title: `Test PT ${stamp}`, starts_at: futureAt(day, 20), ends_at: futureAt(day, 21), capacity: 1,
        });
        const tinyCls = tiny.data?.[0];
        if (tinyCls?.id) created.push(tinyCls.id);
        check("trainer creates a capacity-1 class", tiny.status === 201 && tinyCls?.capacity === 1, short(tiny.data));

        const first = await call("POST", `/classes/${tinyCls.id}/book`, member.token);
        check("first member gets the seat", first.status === 201 && first.data.status === "booked", short(first.data));
        const second = await call("POST", `/classes/${tinyCls.id}/book`, member2.token);
        check(
          "second member is waitlisted at position 1",
          second.status === 201 && second.data.status === "waitlisted" && second.data.waitlist_position === 1,
          short(second.data),
        );

        const shrink = await call("PUT", `/classes/${tinyCls.id}`, trainer.token, { capacity: 1 });
        check("capacity can stay at the booked count", shrink.status === 200, `status ${shrink.status}`);

        // A coach can't seat a waitlisted member by "marking attendance" — that
        // would bypass capacity and the waitlist order.
        const jump = await call("PUT", `/classes/${tinyCls.id}/bookings/${second.data.id}`, trainer.token, { status: "attended" });
        check("coach can't mark a waitlisted booking attended", jump.status === 409, `status ${jump.status} ${short(jump.data)}`);

        const cancelOther = await call("POST", `/classes/${tinyCls.id}/cancel-booking`, member2.token, { user_id: member.profile.id });
        check("member can't cancel someone else's booking", cancelOther.status === 403, `status ${cancelOther.status}`);

        const cancel = await call("POST", `/classes/${tinyCls.id}/cancel-booking`, member.token);
        check("member cancels their booking", cancel.status === 200 && cancel.data.status === "cancelled", short(cancel.data));

        const detail = await call("GET", `/classes/${tinyCls.id}`, member2.token);
        check(
          "waitlisted member was promoted",
          detail.status === 200 && detail.data.my_booking_status === "booked" && detail.data.booked_count === 1 && detail.data.waitlist_count === 0,
          short(detail.data),
        );
        const promoted = (await notificationsOf(member2.token)).find((n) => n.metadata?.class_id === tinyCls.id);
        check("promoted member got a notification", !!promoted && promoted.type === "events" && /You're in/.test(promoted.title), short(promoted));

        // ── Attendance ──
        const coachView = await call("GET", `/classes/${tinyCls.id}`, trainer.token);
        const promotedBooking = (coachView.data?.bookings ?? []).find((b: any) => b.user_id === member2.profile.id);
        check("coach sees the bookings list", coachView.status === 200 && !!promotedBooking && coachView.data.can_coach === true, short(coachView.data?.bookings));
        const memberView = await call("GET", `/classes/${tinyCls.id}`, member2.token);
        check("member view has no bookings list", memberView.status === 200 && !("bookings" in memberView.data), short(memberView.data));
        const memberMark = await call("PUT", `/classes/${tinyCls.id}/bookings/${promotedBooking?.id}`, member2.token, { status: "attended" });
        check("member can't mark attendance", memberMark.status === 403, `status ${memberMark.status}`);
        const mark = await call("PUT", `/classes/${tinyCls.id}/bookings/${promotedBooking?.id}`, trainer.token, { status: "attended" });
        check("coach marks attendance", mark.status === 200 && mark.data.status === "attended", short(mark.data));
        const badMark = await call("PUT", `/classes/${tinyCls.id}/bookings/${promotedBooking?.id}`, trainer.token, { status: "cancelled" });
        check("attendance status is validated", badMark.status === 400, `status ${badMark.status}`);
        const cancelledMark = await call("PUT", `/classes/${tinyCls.id}/bookings/${cancel.data.id}`, trainer.token, { status: "booked" });
        check("coach can't revive a cancelled booking via attendance", cancelledMark.status === 409, `status ${cancelledMark.status}`);
        const ownerMark = await call("PUT", `/classes/${tinyCls.id}/bookings/${promotedBooking?.id}`, owner.token, { status: "no_show" });
        check("gym owner can mark attendance too", ownerMark.status === 200 && ownerMark.data.status === "no_show", short(ownerMark.data));

        // ── Cancelling ──
        const seriesBook = await call("POST", `/classes/${seriesRows[1].id}/book`, member.token);
        check("member books the second series class", seriesBook.status === 201, short(seriesBook.data));
        const seriesCancel = await call("DELETE", `/classes/${seriesRows[0].id}?series=true`, trainer.token);
        check(
          "trainer cancels the whole series",
          seriesCancel.status === 200 && seriesCancel.data.cancelled?.length === 2,
          short(seriesCancel.data),
        );
        const cancelledNotice = (await notificationsOf(member.token)).find((n) => n.metadata?.class_id === seriesRows[1].id);
        check("booked member was told about the cancellation", !!cancelledNotice && /cancelled/i.test(cancelledNotice.title), short(cancelledNotice));
        const bookCancelled = await call("POST", `/classes/${seriesRows[0].id}/book`, member.token);
        check("can't book a cancelled class", bookCancelled.status === 400, `status ${bookCancelled.status}`);
        const editCancelled = await call("PUT", `/classes/${seriesRows[0].id}`, trainer.token, { title: "x" });
        check("can't edit a cancelled class", editCancelled.status === 400, `status ${editCancelled.status}`);

        const single2 = await call("DELETE", `/classes/${cls.id}`, owner.token);
        check("owner cancels a trainer's class", single2.status === 200 && single2.data.cancelled?.[0] === cls.id, short(single2.data));
      } finally {
        await deleteNotifications(member.token, (n) => created.includes(n.metadata?.class_id));
        await deleteNotifications(member2.token, (n) => created.includes(n.metadata?.class_id));
        await deleteNotificationsWhere("class_id", created);
        await sql(`DELETE FROM gym_class WHERE id = ANY($1::uuid[])`, [created]);
      }
      assertAll();
    });

    await t.step("2. shifts: create, overlap, permissions, mine, notification, delete", async () => {
      let shiftId: string | null = null;
      const shiftIds: string[] = [];
      try {
        const day = 10 + (stamp % 7);
        const startsAt = futureAt(day, 9);
        const endsAt = futureAt(day, 17);
        const created = await call("POST", "/shifts", owner.token, {
          gym_id: gym.id, user_id: employee.profile.id, starts_at: startsAt, ends_at: endsAt, note: `test ${stamp}`,
        });
        shiftId = created.data?.id ?? null;
        if (shiftId) shiftIds.push(shiftId);
        check(
          "owner creates a shift for the employee",
          created.status === 201 && created.data.user_id === employee.profile.id && created.data.gym_name === gym.name,
          short(created.data),
        );

        const overlap = await call("POST", "/shifts", owner.token, {
          gym_id: gym.id, user_id: employee.profile.id, starts_at: futureAt(day, 12), ends_at: futureAt(day, 20),
        });
        check("overlapping shift is 409", overlap.status === 409, `status ${overlap.status}`);
        if (overlap.status === 201) {
          shiftIds.push(overlap.data.id);
          await call("DELETE", `/shifts/${overlap.data.id}`, owner.token);
        }

        const notStaff = await call("POST", "/shifts", owner.token, {
          gym_id: gym.id, user_id: member.profile.id, starts_at: futureAt(day, 9), ends_at: futureAt(day, 10),
        });
        check("can't schedule a non-staff member", notStaff.status === 400, `status ${notStaff.status}`);

        const memberCreate = await call("POST", "/shifts", member.token, {
          gym_id: gym.id, user_id: employee.profile.id, starts_at: futureAt(day, 18), ends_at: futureAt(day, 19),
        });
        check("member can't create shifts", memberCreate.status === 403, `status ${memberCreate.status}`);
        const employeeCreate = await call("POST", "/shifts", employee.token, {
          gym_id: gym.id, user_id: employee.profile.id, starts_at: futureAt(day, 18), ends_at: futureAt(day, 19),
        });
        check("employee can't create shifts", employeeCreate.status === 403, `status ${employeeCreate.status}`);
        const employeeEdit = await call("PUT", `/shifts/${shiftId}`, employee.token, { note: "x" });
        check("employee can't edit shifts", employeeEdit.status === 403, `status ${employeeEdit.status}`);

        const mine = await call("GET", `/shifts?mine=true&to=${futureAt(day + 1, 0)}`, employee.token);
        check("employee sees the shift in ?mine=true", mine.status === 200 && (mine.data as any[]).some((s) => s.id === shiftId), `status ${mine.status}`);
        const rota = await call("GET", `/shifts?gym_id=${gym.id}&to=${futureAt(day + 1, 0)}`, employee.token);
        check("employee reads the gym rota", rota.status === 200 && (rota.data as any[]).some((s) => s.id === shiftId), `status ${rota.status}`);
        const memberRota = await call("GET", `/shifts?gym_id=${gym.id}`, member.token);
        check("member can't read the gym rota", memberRota.status === 403, `status ${memberRota.status}`);
        const memberOne = await call("GET", `/shifts/${shiftId}`, member.token);
        check("member can't read a shift", memberOne.status === 403, `status ${memberOne.status}`);
        const staffList = await call("GET", `/shifts/staff?gym_id=${gym.id}`, owner.token);
        check(
          "owner lists schedulable staff",
          staffList.status === 200 && staffList.data.can_manage === true &&
            (staffList.data.staff as any[]).some((s) => s.user_id === employee.profile.id),
          short(staffList.data),
        );

        const notif = (await notificationsOf(employee.token)).find((n) => n.metadata?.shift_id === shiftId);
        check("employee got a shift_assigned notification", notif?.type === "shift_assigned", short(notif));

        const moved = await call("PUT", `/shifts/${shiftId}`, owner.token, { ends_at: futureAt(day, 18) });
        check("owner extends the shift", moved.status === 200 && new Date(moved.data.ends_at).toISOString() === futureAt(day, 18), short(moved.data));

        const memberDel = await call("DELETE", `/shifts/${shiftId}`, member.token);
        check("member can't delete shifts", memberDel.status === 403, `status ${memberDel.status}`);
        const del = await call("DELETE", `/shifts/${shiftId}`, owner.token);
        check("owner deletes the shift", del.status === 204, `status ${del.status}`);
        const gone = await call("GET", `/shifts/${shiftId}`, owner.token);
        check("deleted shift is gone", gone.status === 404, `status ${gone.status}`);
        const cancelNotice = (await notificationsOf(employee.token)).filter((n) => n.metadata?.shift_id === shiftId);
        if (del.status === 204) shiftId = null;
        check("employee was told the shift was cancelled", cancelNotice.some((n) => /cancelled/i.test(n.title)), `n=${cancelNotice.length}`);
      } finally {
        if (shiftId) await call("DELETE", `/shifts/${shiftId}`, owner.token);
        await deleteNotifications(employee.token, (n) => shiftIds.includes(n.metadata?.shift_id));
        await deleteNotificationsWhere("shift_id", shiftIds);
      }
      assertAll();
    });

    await t.step("3. classes: coaching gyms, validation, assignment, filters, waitlist order, series edits, started class", async () => {
      const created: string[] = [];
      const make = async (who: Session, extra: Record<string, unknown>) => {
        const r = await call("POST", "/classes", who.token, { gym_id: gym.id, description: "integration test", location: "Studio U", ...extra });
        if (r.status === 201) created.push(...(r.data as any[]).map((c) => c.id));
        return r;
      };
      try {
        const day = 4 + (stamp % 5);
        const until = futureAt(day + 30, 0);

        // ── Who can schedule where ──
        const tGyms = await call("GET", "/classes/coaching-gyms", trainer.token);
        const tGym = ((tGyms.data ?? []) as any[]).find((g) => g.gym_id === gym.id);
        check(
          "trainer's coaching gyms list the gym (no staff rights) with its trainers",
          tGyms.status === 200 && tGym?.can_staff === false && tGym.trainers.some((x: any) => x.user_id === trainer.profile.id),
          short(tGym),
        );
        const oGyms = await call("GET", "/classes/coaching-gyms", owner.token);
        check("owner's coaching gyms flag can_staff", ((oGyms.data ?? []) as any[]).find((g) => g.gym_id === gym.id)?.can_staff === true, short(oGyms.data));
        const mGyms = await call("GET", "/classes/coaching-gyms", member.token);
        check("a plain member coaches nowhere", mGyms.status === 200 && (mGyms.data as any[]).length === 0, short(mGyms.data));
        const xGyms = await call("GET", "/classes/coaching-gyms", outsider.token);
        check("another gym's owner doesn't get this gym", xGyms.status === 200 && !(xGyms.data as any[]).some((g) => g.gym_id === gym.id), short(xGyms.data));
        const sGyms = await call("GET", "/classes/coaching-gyms", superU.token);
        check("super user can schedule at every gym", ((sGyms.data ?? []) as any[]).some((g) => g.gym_id === gym.id && g.can_staff === true), `status ${sGyms.status}`);

        // ── Create: validation and trainer assignment ──
        const at = { starts_at: futureAt(day, 12), ends_at: futureAt(day, 13), capacity: 5 };
        const invalid: [string, unknown][] = [
          ["non-object body", "nope"],
          ["missing gym_id", { title: "x", ...at }],
          ["blank title", { gym_id: gym.id, title: "  ", ...at }],
          ["unparseable starts_at", { gym_id: gym.id, title: "x", ...at, starts_at: "nope" }],
          ["capacity 0", { gym_id: gym.id, title: "x", ...at, capacity: 0 }],
          ["fractional capacity", { gym_id: gym.id, title: "x", ...at, capacity: 2.5 }],
          ["repeat_weeks 0", { gym_id: gym.id, title: "x", ...at, repeat_weeks: 0 }],
          ["malformed trainer_id", { gym_id: gym.id, title: "x", ...at, trainer_id: "nope" }],
          ["trainer_id of a non-trainer", { gym_id: gym.id, title: "x", ...at, trainer_id: member.profile.id }],
        ];
        for (const [what, body] of invalid) {
          const r = await call("POST", "/classes", owner.token, body);
          if (r.status === 201) created.push(...(r.data as any[]).map((c) => c.id));
          check(`create with ${what} is 400`, r.status === 400, `status ${r.status} ${short(r.data)}`);
        }
        const forOther = await make(trainer, { title: "x", ...at, trainer_id: employee.profile.id });
        check("plain trainer can't schedule another trainer's class", forOther.status === 403, `status ${forOther.status}`);
        const outsiderCreate = await make(outsider, { title: "x", ...at });
        check("another gym's owner can't create classes here", outsiderCreate.status === 403, `status ${outsiderCreate.status}`);

        const unassigned = await make(owner, { title: `Test Open Gym ${stamp}`, ...at });
        const openCls = unassigned.data?.[0];
        check("owner (not a trainer) creates an unassigned class", unassigned.status === 201 && openCls?.trainer_id === null, short(openCls));
        const assigned = await make(owner, { title: `Test Spin ${stamp}`, starts_at: futureAt(day, 14), ends_at: futureAt(day, 15), capacity: 5, trainer_id: trainer.profile.id });
        const spin = assigned.data?.[0];
        check("owner assigns a class to a trainer", assigned.status === 201 && spin?.trainer_id === trainer.profile.id && !!spin?.trainer_name, short(spin));

        // ── Read / edit / cancel permissions on someone else's class ──
        const noSuch = crypto.randomUUID();
        check("GET of a malformed class id is 404", (await call("GET", "/classes/nope", member.token)).status === 404);
        check("GET of an unknown class is 404", (await call("GET", `/classes/${noSuch}`, member.token)).status === 404);
        check("PUT of an unknown class is 404", (await call("PUT", `/classes/${noSuch}`, owner.token, { title: "x" })).status === 404);
        check("DELETE of an unknown class is 404", (await call("DELETE", `/classes/${noSuch}`, owner.token)).status === 404);
        check("booking an unknown class is 404", (await call("POST", `/classes/${noSuch}/book`, member.token)).status === 404);
        check("cancel-booking on an unknown class is 404", (await call("POST", `/classes/${noSuch}/cancel-booking`, member.token)).status === 404);
        const unknownRoute = await call("GET", `/classes/${spin?.id}/nope`, member.token);
        check("unknown class sub-route is 404", unknownRoute.status === 404, `status ${unknownRoute.status}`);

        const trainerEditsOpen = await call("PUT", `/classes/${openCls?.id}`, trainer.token, { title: "mine now" });
        check("trainer can't edit a class that isn't theirs", trainerEditsOpen.status === 403, `status ${trainerEditsOpen.status}`);
        const trainerCancelsOpen = await call("DELETE", `/classes/${openCls?.id}`, trainer.token);
        check("trainer can't cancel a class that isn't theirs", trainerCancelsOpen.status === 403, `status ${trainerCancelsOpen.status}`);
        for (const [what, r] of [
          ["read", await call("GET", `/classes/${spin?.id}`, outsider.token)],
          ["edit", await call("PUT", `/classes/${spin?.id}`, outsider.token, { title: "x" })],
          ["cancel", await call("DELETE", `/classes/${spin?.id}`, outsider.token)],
          ["book", await call("POST", `/classes/${spin?.id}/book`, outsider.token)],
          ["list", await call("GET", `/classes?gym_id=${gym.id}`, outsider.token)],
        ] as const) {
          check(`another gym's owner can't ${what} this gym's classes`, r.status === 403, `status ${r.status}`);
        }

        const badEdits: [string, unknown][] = [
          ["non-object body", "nope"],
          ["blank title", { title: " " }],
          ["capacity 0", { capacity: 0 }],
          ["malformed trainer_id", { trainer_id: "nope" }],
          ["trainer_id of a non-trainer", { trainer_id: member.profile.id }],
          ["unparseable starts_at", { starts_at: "nope" }],
          ["unparseable ends_at", { ends_at: "nope" }],
          ["ends_at before starts_at", { ends_at: futureAt(day, 11) }],
        ];
        for (const [what, body] of badEdits) {
          const r = await call("PUT", `/classes/${openCls?.id}`, owner.token, body);
          check(`edit with ${what} is 400`, r.status === 400, `status ${r.status} ${short(r.data)}`);
        }
        const assign = await call("PUT", `/classes/${openCls?.id}`, owner.token, { trainer_id: trainer.profile.id });
        check("owner assigns the open class to the trainer", assign.status === 200 && assign.data.trainer_id === trainer.profile.id, short(assign.data));
        const nowMine = await call("PUT", `/classes/${openCls?.id}`, trainer.token, { description: "  ", location: "Studio W" });
        check(
          "assigned trainer can edit it; blank description clears it",
          nowMine.status === 200 && nowMine.data.description === null && nowMine.data.location === "Studio W",
          short(nowMine.data),
        );
        const handOff = await call("PUT", `/classes/${openCls?.id}`, trainer.token, { trainer_id: employee.profile.id });
        check("plain trainer can't hand a class to another trainer", handOff.status === 403, `status ${handOff.status}`);
        const unassign = await call("PUT", `/classes/${openCls?.id}`, owner.token, { trainer_id: null });
        check("owner unassigns the trainer", unassign.status === 200 && unassign.data.trainer_id === null, short(unassign.data));

        // ── Listing filters ──
        for (const [what, qs] of [["from", "from=nope"], ["gym_id", "gym_id=nope"], ["trainer_id", "trainer_id=nope"]]) {
          const r = await call("GET", `/classes?${qs}`, member.token);
          check(`list with malformed ${what} is 400`, r.status === 400, `status ${r.status}`);
        }
        const byTrainer = await call("GET", `/classes?gym_id=${gym.id}&trainer_id=${trainer.profile.id}&to=${until}`, member.token);
        const byTrainerIds = ((byTrainer.data ?? []) as any[]).map((c) => c.id);
        check(
          "trainer_id filter keeps the trainer's classes only",
          byTrainer.status === 200 && byTrainerIds.includes(spin?.id) && !byTrainerIds.includes(openCls?.id) &&
            (byTrainer.data as any[]).every((c) => c.trainer_id === trainer.profile.id),
          `n=${byTrainerIds.length}`,
        );
        const memberAll = await call("GET", `/classes?to=${until}`, member.token);
        check(
          "member's unfiltered list covers their gyms, with can_coach false",
          memberAll.status === 200 && (memberAll.data as any[]).some((c) => c.id === spin?.id && c.can_coach === false),
          `status ${memberAll.status}`,
        );
        const windowed = await call("GET", `/classes?gym_id=${gym.id}&from=${futureAt(day + 1, 0)}&to=${until}`, member.token);
        check("from/to window excludes earlier classes", windowed.status === 200 && !(windowed.data as any[]).some((c) => c.id === spin?.id), `status ${windowed.status}`);
        const superList = await call("GET", `/classes?gym_id=${gym.id}&to=${until}`, superU.token);
        check("super user lists any gym's classes", superList.status === 200 && (superList.data as any[]).some((c) => c.id === spin?.id && c.can_coach === true), `status ${superList.status}`);

        // ── Waitlist order with three people ──
        const tiny = await make(trainer, { title: `Test Rowing ${stamp}`, starts_at: futureAt(day, 16), ends_at: futureAt(day, 17), capacity: 1 });
        const row = tiny.data?.[0];
        const b1 = await call("POST", `/classes/${row?.id}/book`, member.token);
        const b2 = await call("POST", `/classes/${row?.id}/book`, member2.token);
        const b3 = await call("POST", `/classes/${row?.id}/book`, superU.token);
        check(
          "seat, then waitlist positions 1 and 2 (super user books without a membership)",
          b1.data?.status === "booked" && b2.data?.waitlist_position === 1 && b3.status === 201 && b3.data?.waitlist_position === 2,
          `${short(b1.data)} ${short(b2.data)} ${short(b3.data)}`,
        );
        const badUser = await call("POST", `/classes/${row?.id}/book`, trainer.token, { user_id: "nope" });
        check("booking with a malformed user_id is 400", badUser.status === 400, `status ${badUser.status}`);
        const leave = await call("POST", `/classes/${row?.id}/cancel-booking`, member2.token);
        check("waitlisted member leaves the waitlist", leave.status === 200 && leave.data.status === "cancelled", short(leave.data));
        const afterLeave = await call("GET", `/classes/${row?.id}`, superU.token);
        check(
          "the next in line moves up, nobody is promoted",
          afterLeave.data?.my_waitlist_position === 1 && afterLeave.data?.booked_count === 1 && afterLeave.data?.waitlist_count === 1,
          short(afterLeave.data),
        );
        const rejoin = await call("POST", `/classes/${row?.id}/book`, member2.token);
        check(
          "rejoining reuses the booking row at the back of the line",
          rejoin.status === 201 && rejoin.data.id === b2.data?.id && rejoin.data.waitlist_position === 2,
          short(rejoin.data),
        );
        const noBooking = await call("POST", `/classes/${row?.id}/cancel-booking`, owner.token);
        check("cancel without an active booking is 404", noBooking.status === 404, `status ${noBooking.status}`);
        const badCancelUser = await call("POST", `/classes/${row?.id}/cancel-booking`, trainer.token, { user_id: "nope" });
        check("cancel-booking with a malformed user_id is 400", badCancelUser.status === 400, `status ${badCancelUser.status}`);
        const grow = await call("PUT", `/classes/${row?.id}`, trainer.token, { capacity: 3 });
        check("raising capacity seats the whole waitlist", grow.status === 200 && grow.data.booked_count === 3 && grow.data.waitlist_count === 0, short(grow.data));
        const grown = (await notificationsOf(member2.token)).find((n) => n.metadata?.class_id === row?.id && /You're in/.test(n.title));
        check("member seated by the capacity change was notified", !!grown, short(grown));
        const coachCancels = await call("POST", `/classes/${row?.id}/cancel-booking`, trainer.token, { user_id: member.profile.id });
        check("coach cancels a member's booking", coachCancels.status === 200 && coachCancels.data.user_id === member.profile.id, short(coachCancels.data));

        // ── Attendance edge cases ──
        const seat = b3.data?.id;
        check("attendance on a malformed booking id is 404", (await call("PUT", `/classes/${row?.id}/bookings/nope`, trainer.token, { status: "attended" })).status === 404);
        check(
          "attendance on an unknown booking is 404",
          (await call("PUT", `/classes/${row?.id}/bookings/${noSuch}`, trainer.token, { status: "attended" })).status === 404,
        );
        check(
          "attendance via another class's path is 404",
          (await call("PUT", `/classes/${spin?.id}/bookings/${seat}`, trainer.token, { status: "attended" })).status === 404,
        );
        check(
          "attendance on an unknown class is 404",
          (await call("PUT", `/classes/${noSuch}/bookings/${seat}`, trainer.token, { status: "attended" })).status === 404,
        );
        const outsiderMark = await call("PUT", `/classes/${row?.id}/bookings/${seat}`, outsider.token, { status: "attended" });
        check("another gym's owner can't mark attendance", outsiderMark.status === 403, `status ${outsiderMark.status}`);
        await call("PUT", `/classes/${row?.id}/bookings/${seat}`, trainer.token, { status: "attended" });
        const undo = await call("PUT", `/classes/${row?.id}/bookings/${seat}`, trainer.token, { status: "booked" });
        check("coach can undo attendance back to booked", undo.status === 200 && undo.data.status === "booked", short(undo.data));

        // ── Series: edit forward, cancel one, cancel the rest ──
        const series = await make(trainer, { title: `Test Pilates ${stamp}`, starts_at: futureAt(day, 6), ends_at: futureAt(day, 7), capacity: 4, repeat_weeks: 3 });
        const [s0, s1, s2] = (series.data ?? []) as any[];
        check("trainer creates a 3-week series", series.status === 201 && !!s2, short(series.data));
        await call("POST", `/classes/${s1?.id}/book`, member.token);
        await call("POST", `/classes/${s2?.id}/book`, member2.token);
        const fwd = await call("PUT", `/classes/${s1?.id}`, trainer.token, {
          starts_at: new Date(new Date(s1?.starts_at).getTime() + 1_800_000).toISOString(),
          location: "Studio X",
          apply_to_series: true,
        });
        const [g0, g1, g2] = await Promise.all([s0, s1, s2].map((s) => call("GET", `/classes/${s?.id}`, trainer.token)));
        const shifted = (g: any, s: any) => new Date(g.data?.starts_at).getTime() - new Date(s?.starts_at).getTime() === 1_800_000;
        check(
          "apply_to_series moves this and later classes, not earlier ones",
          fwd.status === 200 && !shifted(g0, s0) && g0.data?.location === "Studio U" &&
            shifted(g1, s1) && shifted(g2, s2) && g1.data?.location === "Studio X" && g2.data?.location === "Studio X",
          `${short(g0.data?.starts_at)} ${short(g1.data?.starts_at)} ${short(g2.data?.starts_at)}`,
        );
        const n1 = (await notificationsOf(member.token)).find((n) => n.metadata?.class_id === s1?.id && /updated/i.test(n.title));
        const n2 = (await notificationsOf(member2.token)).find((n) => n.metadata?.class_id === s2?.id && /updated/i.test(n.title));
        check("each series attendee is told about their class", /upcoming/.test(n1?.body ?? "") && !!n2, `${short(n1)} ${short(n2)}`);

        const one = await call("DELETE", `/classes/${s2?.id}`, trainer.token);
        check("cancelling one series class without ?series leaves the others", one.status === 200 && one.data.cancelled?.length === 1, short(one.data));
        const twice = await call("DELETE", `/classes/${s2?.id}`, trainer.token);
        check("cancelling it again is a no-op", twice.status === 200 && twice.data.cancelled?.length === 0, short(twice.data));
        const rest = await call("DELETE", `/classes/${s0?.id}?series=true`, owner.token);
        check(
          "series cancel skips the already-cancelled class",
          rest.status === 200 && rest.data.cancelled?.length === 2 && !rest.data.cancelled.includes(s2?.id),
          short(rest.data),
        );
        const hidden = await call("GET", `/classes?gym_id=${gym.id}&to=${until}`, trainer.token);
        const shown = await call("GET", `/classes?gym_id=${gym.id}&to=${until}&include_cancelled=true`, trainer.token);
        check(
          "cancelled classes are hidden unless include_cancelled=true",
          !(hidden.data as any[]).some((c) => c.id === s0?.id) &&
            (shown.data as any[]).some((c) => c.id === s0?.id && c.cancelled_at),
          `${hidden.status} ${shown.status}`,
        );
        const cancelBooked = await call("POST", `/classes/${s1?.id}/cancel-booking`, member.token);
        check("member can still drop a booking on a cancelled class", cancelBooked.status === 200, `status ${cancelBooked.status}`);

        // ── A class that has started ──
        const past = await make(trainer, { title: `Test Past ${stamp}`, starts_at: futureAt(-1, 6), ends_at: futureAt(-1, 7), capacity: 5 });
        const pastBook = await call("POST", `/classes/${past.data?.[0]?.id}/book`, member.token);
        check("booking a class that already started is 400", pastBook.status === 400, `status ${pastBook.status}`);
        const startsSoon = Date.now() + 6_000;
        const soon = await make(trainer, {
          title: `Test Soon ${stamp}`,
          starts_at: new Date(startsSoon).toISOString(),
          ends_at: new Date(startsSoon + 3_600_000).toISOString(),
          capacity: 5,
        });
        const soonId = soon.data?.[0]?.id;
        const soonBook = await call("POST", `/classes/${soonId}/book`, member.token);
        check("member books a class about to start", soonBook.status === 201, short(soonBook.data));
        await new Promise((r) => setTimeout(r, Math.max(0, startsSoon - Date.now() + 500)));
        const lateCancel = await call("POST", `/classes/${soonId}/cancel-booking`, member.token);
        check("member can't cancel once the class started", lateCancel.status === 400, `status ${lateCancel.status}`);
        const lateMark = await call("PUT", `/classes/${soonId}/bookings/${soonBook.data?.id}`, trainer.token, { status: "attended" });
        check("coach marks attendance during the class", lateMark.status === 200 && lateMark.data.status === "attended", short(lateMark.data));
        const lateEnd = await call("DELETE", `/classes/${soonId}`, owner.token);
        const lateNotice = (await notificationsOf(member.token)).find((n) => n.metadata?.class_id === soonId);
        check("cancelling a started class notifies nobody", lateEnd.status === 200 && !lateNotice, short(lateNotice));
      } finally {
        for (const s of [member, member2, superU]) await deleteNotifications(s.token, (n) => created.includes(n.metadata?.class_id));
        await deleteNotificationsWhere("class_id", created);
        await sql(`DELETE FROM gym_class WHERE id = ANY($1::uuid[])`, [created]);
      }
      assertAll();
    });

    await t.step("4. shifts: validation, rota reads, edits, reassignment, past shifts, other gym", async () => {
      const shiftIds: string[] = [];
      const make = async (who: Session, body: Record<string, unknown>) => {
        const r = await call("POST", "/shifts", who.token, { gym_id: gym.id, ...body });
        if (r.status === 201) shiftIds.push(r.data.id);
        return r;
      };
      const noticesFor = async (s: Session, id: string | undefined) =>
        id ? (await notificationsOf(s.token)).filter((n) => n.metadata?.shift_id === id) : [];
      try {
        // Past the seeded rota (two weeks out), so nothing collides with it.
        const day = 20 + (stamp % 7);
        const until = futureAt(day + 2, 0);

        // ── Create: validation and who may ──
        const slot = { starts_at: futureAt(day, 6), ends_at: futureAt(day, 8) };
        const invalid: [string, unknown][] = [
          ["non-object body", "nope"],
          ["missing gym_id", { user_id: employee.profile.id, ...slot }],
          ["missing user_id", { gym_id: gym.id, ...slot }],
          ["unparseable starts_at", { gym_id: gym.id, user_id: employee.profile.id, ...slot, starts_at: "nope" }],
          ["ends_at before starts_at", { gym_id: gym.id, user_id: employee.profile.id, starts_at: slot.ends_at, ends_at: slot.starts_at }],
          ["the owner (not staff) as the user", { gym_id: gym.id, user_id: owner.profile.id, ...slot }],
        ];
        for (const [what, body] of invalid) {
          const r = await call("POST", "/shifts", owner.token, body);
          if (r.status === 201) shiftIds.push(r.data.id);
          check(`create with ${what} is 400`, r.status === 400, `status ${r.status} ${short(r.data)}`);
        }
        const trainerCreate = await make(trainer, { user_id: trainer.profile.id, ...slot });
        check("trainer can't create shifts", trainerCreate.status === 403, `status ${trainerCreate.status}`);
        const outsiderCreate = await make(outsider, { user_id: employee.profile.id, ...slot });
        check("another gym's owner can't schedule this gym's staff", outsiderCreate.status === 403, `status ${outsiderCreate.status}`);

        const tShift = await make(owner, { user_id: trainer.profile.id, ...slot, note: "  " });
        const tId = tShift.data?.id;
        check("owner schedules a trainer; blank note is null", tShift.status === 201 && tShift.data.note === null, short(tShift.data));
        const tNotice = await noticesFor(trainer, tId);
        check("trainer got a New shift notification", tNotice.some((n) => n.type === "shift_assigned" && n.title === "New shift"), short(tNotice));
        const adjacent = await make(owner, { user_id: trainer.profile.id, starts_at: futureAt(day, 8), ends_at: futureAt(day, 10) });
        check("back-to-back shifts don't overlap", adjacent.status === 201, `status ${adjacent.status} ${short(adjacent.data)}`);
        const eShift = await make(owner, { user_id: employee.profile.id, ...slot });
        const eId = eShift.data?.id;
        check("owner schedules the employee in the same slot", eShift.status === 201, short(eShift.data));
        const superShift = await make(superU, { user_id: employee.profile.id, starts_at: futureAt(day, 15), ends_at: futureAt(day, 16) });
        check("super user can schedule staff at any gym", superShift.status === 201, `status ${superShift.status}`);

        // ── Reads ──
        const noSuch = crypto.randomUUID();
        check("GET of a malformed shift id is 404", (await call("GET", "/shifts/nope", owner.token)).status === 404);
        check("GET of an unknown shift is 404", (await call("GET", `/shifts/${noSuch}`, owner.token)).status === 404);
        const unknownRoute = await call("GET", `/shifts/${tId}/nope`, owner.token);
        check("unknown shift sub-route is 404", unknownRoute.status === 404, `status ${unknownRoute.status}`);
        const ownRead = await call("GET", `/shifts/${tId}`, trainer.token);
        check("staff member reads their own shift", ownRead.status === 200 && ownRead.data.user_name.length > 0, short(ownRead.data));
        const colleague = await call("GET", `/shifts/${tId}`, employee.token);
        check("a colleague can read the shift", colleague.status === 200, `status ${colleague.status}`);
        const outsiderRead = await call("GET", `/shifts/${tId}`, outsider.token);
        check("another gym's owner can't read the shift", outsiderRead.status === 403, `status ${outsiderRead.status}`);

        const rota = await call("GET", `/shifts?gym_id=${gym.id}&from=${futureAt(day, 0)}&to=${until}`, trainer.token);
        const rotaIds = ((rota.data ?? []) as any[]).map((s) => s.id);
        check("trainer reads the gym rota", rota.status === 200 && rotaIds.includes(tId) && rotaIds.includes(eId), `n=${rotaIds.length}`);
        const later = await call("GET", `/shifts?gym_id=${gym.id}&from=${futureAt(day + 1, 0)}&to=${until}`, owner.token);
        check("rota from/to window excludes earlier shifts", later.status === 200 && !(later.data as any[]).some((s) => s.id === tId), `status ${later.status}`);
        check("rota with a malformed gym_id is 400", (await call("GET", "/shifts?gym_id=nope", owner.token)).status === 400);
        check("rota with a malformed from is 400", (await call("GET", `/shifts?gym_id=${gym.id}&from=nope`, owner.token)).status === 400);
        const outsiderRota = await call("GET", `/shifts?gym_id=${gym.id}`, outsider.token);
        check("another gym's owner can't read the rota", outsiderRota.status === 403, `status ${outsiderRota.status}`);
        const mineDefault = await call("GET", "/shifts", trainer.token);
        check(
          "GET /shifts with no params is my upcoming 30 days",
          mineDefault.status === 200 && (mineDefault.data as any[]).some((s) => s.id === tId) &&
            (mineDefault.data as any[]).every((s) => s.user_id === trainer.profile.id),
          `status ${mineDefault.status}`,
        );
        const mineHere = await call("GET", `/shifts?mine=true&gym_id=${gym.id}&to=${until}`, trainer.token);
        check(
          "?mine=true&gym_id narrows to my shifts at that gym",
          mineHere.status === 200 && (mineHere.data as any[]).some((s) => s.id === tId) &&
            (mineHere.data as any[]).every((s) => s.gym_id === gym.id && s.user_id === trainer.profile.id),
          `status ${mineHere.status}`,
        );
        const outsiderMine = await call("GET", `/shifts?mine=true&to=${until}`, outsider.token);
        check("other gym staff's ?mine=true has none of ours", outsiderMine.status === 200 && !(outsiderMine.data as any[]).some((s) => s.gym_id === gym.id), `status ${outsiderMine.status}`);

        const staffNoGym = await call("GET", "/shifts/staff", owner.token);
        check("staff list without gym_id is 400", staffNoGym.status === 400, `status ${staffNoGym.status}`);
        const staffEmp = await call("GET", `/shifts/staff?gym_id=${gym.id}`, employee.token);
        const me = ((staffEmp.data?.staff ?? []) as any[]).find((s) => s.user_id === employee.profile.id);
        check(
          "employee sees the staff list read-only, with every role per person",
          staffEmp.status === 200 && staffEmp.data.can_manage === false && me?.roles.includes("employee") && me?.roles.includes("trainer"),
          short(me),
        );
        check("member can't list schedulable staff", (await call("GET", `/shifts/staff?gym_id=${gym.id}`, member.token)).status === 403);
        check("another gym's owner can't list our staff", (await call("GET", `/shifts/staff?gym_id=${gym.id}`, outsider.token)).status === 403);

        // ── Edits ──
        check("PUT of an unknown shift is 404", (await call("PUT", `/shifts/${noSuch}`, owner.token, { note: "x" })).status === 404);
        const badEdits: [string, unknown][] = [
          ["non-object body", "nope"],
          ["malformed user_id", { user_id: "nope" }],
          ["a non-staff user_id", { user_id: member.profile.id }],
          ["unparseable ends_at", { ends_at: "nope" }],
          ["ends_at before starts_at", { ends_at: futureAt(day, 5) }],
        ];
        for (const [what, body] of badEdits) {
          const r = await call("PUT", `/shifts/${eId}`, owner.token, body);
          check(`edit with ${what} is 400`, r.status === 400, `status ${r.status} ${short(r.data)}`);
        }
        check("trainer can't edit shifts", (await call("PUT", `/shifts/${tId}`, trainer.token, { note: "x" })).status === 403);
        check("another gym's owner can't edit shifts", (await call("PUT", `/shifts/${tId}`, outsider.token, { note: "x" })).status === 403);
        const overlapEdit = await call("PUT", `/shifts/${adjacent.data?.id}`, owner.token, { starts_at: futureAt(day, 7) });
        check("moving a shift onto another of the same person's is 409", overlapEdit.status === 409, `status ${overlapEdit.status}`);

        const noteOnly = await call("PUT", `/shifts/${eId}`, owner.token, { note: "bring keys" });
        const afterNote = await noticesFor(employee, eId);
        check(
          "note-only edit saves without a Shift changed notification",
          noteOnly.status === 200 && noteOnly.data.note === "bring keys" && !afterNote.some((n) => n.title === "Shift changed"),
          short(afterNote),
        );
        const retime = await call("PUT", `/shifts/${eId}`, owner.token, { starts_at: futureAt(day, 5) });
        const afterRetime = await noticesFor(employee, eId);
        check(
          "changing the time notifies the employee",
          retime.status === 200 && retime.data.note === "bring keys" && afterRetime.some((n) => n.title === "Shift changed"),
          short(afterRetime),
        );
        const clash = await call("PUT", `/shifts/${eId}`, owner.token, { user_id: trainer.profile.id });
        check("reassigning onto someone's existing shift is 409", clash.status === 409, `status ${clash.status}`);
        const reassign = await call("PUT", `/shifts/${eId}`, owner.token, { user_id: trainer.profile.id, starts_at: futureAt(day, 12), ends_at: futureAt(day, 14) });
        const newOwner = await noticesFor(trainer, eId);
        const oldOwner = await noticesFor(employee, eId);
        check("owner reassigns the shift to the trainer", reassign.status === 200 && reassign.data.user_id === trainer.profile.id, short(reassign.data));
        check(
          "new assignee gets New shift, previous one gets Shift removed",
          newOwner.some((n) => n.title === "New shift") && oldOwner.some((n) => n.title === "Shift removed"),
          `${short(newOwner)} ${short(oldOwner)}`,
        );

        // ── Deletes ──
        check("DELETE of an unknown shift is 404", (await call("DELETE", `/shifts/${noSuch}`, owner.token)).status === 404);
        check("trainer can't delete shifts", (await call("DELETE", `/shifts/${tId}`, trainer.token)).status === 403);
        check("another gym's owner can't delete shifts", (await call("DELETE", `/shifts/${tId}`, outsider.token)).status === 403);
        const past = await make(owner, { user_id: trainer.profile.id, starts_at: futureAt(-1, 5), ends_at: futureAt(-1, 6) });
        const pastId = past.data?.id;
        check("owner can record a past shift", past.status === 201, `status ${past.status} ${short(past.data)}`);
        const delPast = await call("DELETE", `/shifts/${pastId}`, owner.token);
        const pastNotices = await noticesFor(trainer, pastId);
        check(
          "deleting a past shift sends no Shift cancelled",
          delPast.status === 204 && !pastNotices.some((n) => /cancelled/i.test(n.title)),
          short(pastNotices),
        );
      } finally {
        for (const id of shiftIds) await call("DELETE", `/shifts/${id}`, owner.token);
        for (const s of [employee, trainer]) await deleteNotifications(s.token, (n) => shiftIds.includes(n.metadata?.shift_id));
        await deleteNotificationsWhere("shift_id", shiftIds);
      }
      assertAll();
    });
  },
});
