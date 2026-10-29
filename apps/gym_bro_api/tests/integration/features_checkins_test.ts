// deno-lint-ignore-file no-explicit-any
// Check-ins beyond the basic scan in features_commerce_test.ts: who can mint
// and scan QR tokens (members, staff, plain trainers, another gym's staff),
// membership warnings (active / expired / none), duplicates across methods and
// staff, the staff day list (date, tz_offset), member history paging, stats
// and member search validation, and routing. There is no check-out endpoint.
// Members here are picked so they don't collide with the commerce suite's
// duplicate window. Check-in rows have no DELETE endpoint; they're removed
// with SQL in `finally` (see _db.ts).
import { call, checker, dayFromToday, IRONCLAD, short, signin, suite } from "./_client.ts";
import { dbAvailable, sql } from "./_db.ts";

Deno.test({
  name: "features: check-ins (tokens, membership warnings, lists, other gyms)",
  ...suite,
  async fn(t) {
    const { check, assertAll } = checker();
    // Six sign-ins, not seededUsers(): this suite needs different members.
    const [owner, employee, trainer, active, expired, outsider] = await Promise.all([
      signin("marcus.bennett@example.com"), // Ironclad owner
      signin("priya.nair@example.com"), // Ironclad employee (and trainer)
      signin("elena.vasquez@example.com"), // Ironclad trainer only: not front desk
      signin("victor.huang@example.com"), // Ironclad member, active Basic membership
      signin("grace.okafor@example.com"), // Ironclad member, expired membership
      signin("jordan.park@example.com"), // Coastal Barbell Club employee
    ]);
    const gyms = (await call("GET", "/businesses", owner.token)).data as any[];
    const gym = gyms.find((b) => b.type === "gym" && b.name === IRONCLAD);
    const outsiderGyms = (await call("GET", "/check-ins/gyms", outsider.token)).data as any[];
    const otherGym = outsiderGyms?.find((g) => g.is_staff);
    check("found both gyms", !!gym && !!otherGym && otherGym.gym_id !== gym.id, short(outsiderGyms));
    assertAll();
    const canCleanDb = await dbAvailable();
    const checkInIds: string[] = [];
    const created = (status: number) => status === 201 || (!canCleanDb && status === 200);
    let activeToken = "";
    let staffToken = "";
    let scanId: string | undefined;

    try {
      await t.step("1. gyms list and QR tokens: members, staff, trainers, other gyms, validation", async () => {
        const mine = await call("GET", "/check-ins/gyms", active.token);
        check(
          "member's check-in gyms flag membership, not staff",
          mine.status === 200 && (mine.data as any[]).some((g) => g.gym_id === gym.id && g.is_member && !g.is_staff),
          short(mine.data),
        );
        const staffGyms = await call("GET", "/check-ins/gyms", employee.token);
        check(
          "employee's check-in gyms flag the staffed gym",
          (staffGyms.data as any[]).some((g) => g.gym_id === gym.id && g.is_staff && !g.is_member),
          short(staffGyms.data),
        );
        const trainerGyms = await call("GET", "/check-ins/gyms", trainer.token);
        check("plain trainer has no check-in gym there", trainerGyms.status === 200 && !(trainerGyms.data as any[]).some((g) => g.gym_id === gym.id), short(trainerGyms.data));
        check("other gym's staff don't see this gym", !outsiderGyms.some((g) => g.gym_id === gym.id), short(outsiderGyms));

        check("token without gym_id is 400", (await call("GET", "/check-ins/token", active.token)).status === 400);
        const malformed = await call("GET", "/check-ins/token?gym_id=nope", active.token);
        check("token for a malformed gym_id is 400", malformed.status === 400, `status ${malformed.status}`);
        const unknown = await call("GET", `/check-ins/token?gym_id=${crypto.randomUUID()}`, active.token);
        check("token for an unknown gym is 404", unknown.status === 404, `status ${unknown.status}`);
        const shopTok = await call("GET", `/check-ins/token?gym_id=${gyms.find((b) => b.type === "shop")?.id ?? crypto.randomUUID()}`, active.token);
        check("a shop isn't a gym (404)", shopTok.status === 404, `status ${shopTok.status}`);
        const trainerTok = await call("GET", `/check-ins/token?gym_id=${gym.id}`, trainer.token);
        check("plain trainer (not a member) can't get a token", trainerTok.status === 403, `status ${trainerTok.status}`);
        const outsiderTok = await call("GET", `/check-ins/token?gym_id=${gym.id}`, outsider.token);
        check("another gym's staff can't get a token here", outsiderTok.status === 403, `status ${outsiderTok.status}`);

        const tok = await call("GET", `/check-ins/token?gym_id=${gym.id}`, active.token);
        activeToken = tok.data?.token ?? "";
        const payload = JSON.parse(atob((activeToken.split(".")[0] ?? "").replace(/-/g, "+").replace(/_/g, "/")) || "{}");
        check(
          "member token carries user, gym and a 5-minute expiry",
          tok.status === 200 && payload.u === active.profile.id && payload.g === gym.id &&
            Math.abs(payload.exp * 1000 - (Date.now() + 300_000)) < 60_000 &&
            new Date(tok.data.expires_at).getTime() === payload.exp * 1000 && tok.data.gym_name === gym.name,
          short(tok.data),
        );
        const staffTok = await call("GET", `/check-ins/token?gym_id=${gym.id}`, employee.token);
        staffToken = staffTok.data?.token ?? "";
        check("front-desk staff can get a token to test the flow", staffTok.status === 200 && !!staffToken, `status ${staffTok.status}`);
        assertAll();
      });

      await t.step("2. scanning and manual check-in: roles, membership warnings, duplicates", async () => {
        const outsiderScan = await call("POST", "/check-ins", outsider.token, { token: activeToken });
        check("another gym's staff can't scan this gym's token", outsiderScan.status === 403, `status ${outsiderScan.status}`);
        const outsiderAsOwnGym = await call("POST", "/check-ins", outsider.token, { token: activeToken, gym_id: otherGym.gym_id });
        check(
          "scanning it at the other gym's desk is wrong_gym",
          outsiderAsOwnGym.status === 400 && outsiderAsOwnGym.data.code === "wrong_gym",
          short(outsiderAsOwnGym.data),
        );
        const trainerScan = await call("POST", "/check-ins", trainer.token, { token: activeToken });
        check("plain trainer can't scan", trainerScan.status === 403, `status ${trainerScan.status}`);
        const threeParts = await call("POST", "/check-ins", owner.token, { token: `${activeToken}.x` });
        check("token with an extra segment is token_invalid", threeParts.data?.code === "token_invalid", short(threeParts.data));

        const scan = await call("POST", "/check-ins", owner.token, { token: ` ${activeToken} ` });
        if (scan.data?.check_in?.id) checkInIds.push(scan.data.check_in.id);
        scanId = scan.data?.check_in?.id;
        check(
          "owner scans a member with an active membership (whitespace trimmed)",
          created(scan.status) && scan.data.check_in.method === "qr" && scan.data.check_in.checked_in_by === owner.profile.id &&
            scan.data.membership?.is_active === true && scan.data.warning === null,
          short(scan.data),
        );
        const manualDup = await call("POST", "/check-ins", employee.token, { gym_id: gym.id, user_id: active.profile.id });
        check(
          "a manual check-in by other staff right after is the same duplicate",
          manualDup.status === 200 && manualDup.data.duplicate === true && manualDup.data.check_in.id === scan.data?.check_in?.id &&
            manualDup.data.check_in.method === "qr",
          short(manualDup.data),
        );

        const lapsed = await call("POST", "/check-ins", employee.token, { gym_id: gym.id, user_id: expired.profile.id });
        if (lapsed.data?.check_in?.id) checkInIds.push(lapsed.data.check_in.id);
        check(
          "expired membership is checked in with a no_active_membership warning",
          created(lapsed.status) && lapsed.data.warning === "no_active_membership" && lapsed.data.membership?.is_active === false &&
            /^\d{4}-\d{2}-\d{2}$/.test(lapsed.data.membership?.to_date ?? ""),
          short(lapsed.data),
        );

        const staffScan = await call("POST", "/check-ins", owner.token, { token: staffToken });
        if (staffScan.data?.check_in?.id) checkInIds.push(staffScan.data.check_in.id);
        check(
          "a staff test token checks in with no membership at all",
          created(staffScan.status) && staffScan.data.check_in.user_id === employee.profile.id && staffScan.data.membership === null &&
            staffScan.data.warning === "no_active_membership",
          short(staffScan.data),
        );

        const outsiderManual = await call("POST", "/check-ins", outsider.token, { gym_id: gym.id, user_id: expired.profile.id });
        check("another gym's staff can't check our members in", outsiderManual.status === 403, `status ${outsiderManual.status}`);
        const trainerManual = await call("POST", "/check-ins", trainer.token, { gym_id: gym.id, user_id: expired.profile.id });
        check("plain trainer can't check members in", trainerManual.status === 403, `status ${trainerManual.status}`);
        const crossGym = await call("POST", "/check-ins", outsider.token, { gym_id: otherGym.gym_id, user_id: active.profile.id });
        check("other gym's desk can't check in a member of ours", crossGym.status === 400, `status ${crossGym.status}`);
        const ghost = await call("POST", "/check-ins", employee.token, { gym_id: gym.id, user_id: crypto.randomUUID() });
        check("manual check-in of an unknown user is 400", ghost.status === 400, `status ${ghost.status}`);
        const badGym = await call("POST", "/check-ins", employee.token, { gym_id: "nope", user_id: active.profile.id });
        check("manual check-in with a malformed gym_id is 400", badGym.status === 400, `status ${badGym.status} ${short(badGym.data)}`);
        const onlyGym = await call("POST", "/check-ins", employee.token, { gym_id: gym.id });
        check("manual check-in without user_id is 400", onlyGym.status === 400, `status ${onlyGym.status}`);
        assertAll();
      });

      await t.step("3. day list, history, stats, member search across roles and gyms", async () => {
        const today = await call("GET", `/check-ins?gym_id=${gym.id}`, owner.token);
        const todayRows = (today.data ?? []) as any[];
        check(
          "owner's day list has today's check-ins with member names",
          today.status === 200 && checkInIds.every((id) => todayRows.some((c) => c.id === id)) &&
            todayRows.find((c) => c.user_id === active.profile.id)?.name === active.profile.name,
          `n=${todayRows.length}`,
        );
        const yesterday = await call("GET", `/check-ins?gym_id=${gym.id}&date=${dayFromToday(-1)}`, owner.token);
        check("?date=yesterday excludes today's", yesterday.status === 200 && !(yesterday.data as any[]).some((c) => checkInIds.includes(c.id)), `status ${yesterday.status}`);
        // With tz_offset, "today" is the client's local day.
        const east = 14 * 60;
        const eastDay = new Date(Date.now() + east * 60_000).toISOString().slice(0, 10);
        const local = await call("GET", `/check-ins?gym_id=${gym.id}&date=${eastDay}&tz_offset=${east}`, owner.token);
        check("?tz_offset shifts the day to the client's", local.status === 200 && checkInIds.every((id) => (local.data as any[]).some((c) => c.id === id)), `status ${local.status}`);
        check("?date in the wrong format is 400", (await call("GET", `/check-ins?gym_id=${gym.id}&date=28-10-2026`, owner.token)).status === 400);
        check("day list without gym_id or mine is 400", (await call("GET", "/check-ins", owner.token)).status === 400);
        check("plain trainer can't read the day list", (await call("GET", `/check-ins?gym_id=${gym.id}`, trainer.token)).status === 403);
        check("another gym's staff can't read our day list", (await call("GET", `/check-ins?gym_id=${gym.id}`, outsider.token)).status === 403);
        const ownDesk = await call("GET", `/check-ins?gym_id=${otherGym.gym_id}`, outsider.token);
        check("…but they read their own, without our rows", ownDesk.status === 200 && !(ownDesk.data as any[]).some((c) => checkInIds.includes(c.id)), `status ${ownDesk.status}`);

        const history = await call("GET", "/check-ins?mine=true", active.token);
        const first = (history.data as any[])?.[0];
        check(
          "member history is newest first and only theirs",
          history.status === 200 && first?.id === scanId && (history.data as any[]).every((c) => c.user_id === active.profile.id),
          short(first),
        );
        const page0 = await call("GET", "/check-ins?mine=true&page_size=1", active.token);
        const page1 = await call("GET", "/check-ins?mine=true&page_size=1&page=1", active.token);
        check(
          "history pages with page/page_size",
          (page0.data as any[]).length === 1 && page0.data[0].id === scanId && !(page1.data as any[]).some((c) => c.id === scanId),
          `${short(page0.data)} ${short(page1.data)}`,
        );
        const elsewhere = await call("GET", `/check-ins?mine=true&gym_id=${otherGym.gym_id}`, active.token);
        check("history filtered to another gym is empty", elsewhere.status === 200 && (elsewhere.data as any[]).length === 0, short(elsewhere.data));
        const lapsedHistory = await call("GET", `/check-ins?mine=true&gym_id=${gym.id}`, expired.token);
        check(
          "lapsed member sees their own check-in",
          (lapsedHistory.data as any[]).some((c) => checkInIds.includes(c.id) && c.gym_name === gym.name),
          `status ${lapsedHistory.status}`,
        );

        const myStats = await call("GET", "/check-ins/stats?mine=true&tz_offset=60", active.token);
        check(
          "member stats count the new visit",
          myStats.status === 200 && myStats.data.total >= 1 && myStats.data.this_month >= 1 && myStats.data.this_week >= 1 &&
            Math.abs(new Date(myStats.data.last_check_in_at).getTime() - Date.now()) < 30 * 60_000,
          short(myStats.data),
        );
        const day1 = await call("GET", `/check-ins/stats?gym_id=${gym.id}&days=1`, owner.token);
        check(
          "gym stats for one day include our visitors",
          day1.status === 200 && day1.data.days === 1 && day1.data.per_day.length === 1 && day1.data.today >= 3 &&
            day1.data.unique_members >= 3 && [active, expired].every((u) => (day1.data.top_members as any[]).some((m) => m.id === u.profile.id)),
          short(day1.data),
        );
        const zero = await call("GET", `/check-ins/stats?gym_id=${gym.id}&days=0`, owner.token);
        check("days=0 falls back to 30", zero.data?.days === 30 && zero.data?.per_day.length === 30, `days ${zero.data?.days}`);
        const huge = await call("GET", `/check-ins/stats?gym_id=${gym.id}&days=1000`, owner.token);
        check("days is capped at 365", huge.data?.days === 365, `days ${huge.data?.days}`);
        check("stats without gym_id or mine is 400", (await call("GET", "/check-ins/stats", owner.token)).status === 400);
        check("plain trainer can't read gym stats", (await call("GET", `/check-ins/stats?gym_id=${gym.id}`, trainer.token)).status === 403);
        check("another gym's staff can't read our stats", (await call("GET", `/check-ins/stats?gym_id=${gym.id}`, outsider.token)).status === 403);

        const byEmail = await call("GET", `/check-ins/members?gym_id=${gym.id}&q=${encodeURIComponent(active.profile.email)}`, owner.token);
        check(
          "member search by email finds exactly that member",
          byEmail.status === 200 && (byEmail.data as any[]).length === 1 && byEmail.data[0].id === active.profile.id,
          short(byEmail.data),
        );
        const wildcard = await call("GET", `/check-ins/members?gym_id=${gym.id}&q=%25`, owner.token);
        check("'%' is matched literally, not as a wildcard", wildcard.status === 200 && (wildcard.data as any[]).length === 0, `n=${(wildcard.data as any[])?.length}`);
        const all = await call("GET", `/check-ins/members?gym_id=${gym.id}`, employee.token);
        check(
          "empty search lists members only (no staff)",
          all.status === 200 && (all.data as any[]).some((u) => u.id === expired.profile.id) && !(all.data as any[]).some((u) => u.id === employee.profile.id),
          `n=${(all.data as any[])?.length}`,
        );
        check("member search without gym_id is 400", (await call("GET", "/check-ins/members", owner.token)).status === 400);
        check("plain trainer can't search members", (await call("GET", `/check-ins/members?gym_id=${gym.id}`, trainer.token)).status === 403);
        check("another gym's staff can't search our members", (await call("GET", `/check-ins/members?gym_id=${gym.id}`, outsider.token)).status === 403);
        assertAll();
      });

      await t.step("4. auth and routing: anonymous, unknown routes, no check-out", async () => {
        const anon = await call("GET", `/check-ins/token?gym_id=${gym.id}`);
        check("anonymous token request is 401", anon.status === 401, `status ${anon.status}`);
        const anonScan = await call("POST", "/check-ins", undefined, { token: activeToken });
        check("anonymous scan is 401", anonScan.status === 401, `status ${anonScan.status}`);
        check("nested unknown route is 404", (await call("GET", "/check-ins/a/b", owner.token)).status === 404);
        check("unknown action is 404", (await call("GET", "/check-ins/nope", owner.token)).status === 404);
        const checkOut = await call("POST", `/check-ins/${checkInIds[0]}`, owner.token, {});
        check("there is no check-out / per-check-in endpoint", checkOut.status === 404, `status ${checkOut.status}`);
        check("DELETE of a check-in is 404 (history is kept)", (await call("DELETE", `/check-ins/${checkInIds[0]}`, owner.token)).status === 404);
        check("PUT on the collection is 404", (await call("PUT", "/check-ins", owner.token, {})).status === 404);
        assertAll();
      });
    } finally {
      await sql(`DELETE FROM check_in WHERE id = ANY($1::uuid[])`, [checkInIds]);
    }
  },
});
