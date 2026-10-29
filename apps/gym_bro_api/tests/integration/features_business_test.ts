// deno-lint-ignore-file no-explicit-any
// Businesses and the people in them: business CRUD + stats, co-owners (gym
// and shop), employees (invite → accept, role changes, removal), employee-
// trainers, trainers, shop vendors, members, what each role can do after a
// change, and that staff of one gym can't touch another. Everything happens in
// a throwaway gym + shop owned by a throwaway owner (so stats are exact), with
// a second throwaway account as the staff member whose roles change. Both
// businesses are deleted through the API (which also checks the cascade), the
// two accounts are deleted by the super user, and notifications the flow sent
// to seeded users are removed in `finally`.
import { call, checker, dayFromToday, deleteNotifications, notificationsOf, seededUsers, short, signin, suite } from "./_client.ts";
import { deleteNotificationsWhere, sql } from "./_db.ts";

const uid = () => crypto.randomUUID().slice(0, 8);

Deno.test({
  name: "features: businesses, owners, staff, members",
  ...suite,
  async fn(t) {
    const { check, assertAll } = checker();
    const { member, owner, employee, superU, vendor, gym } = await seededUsers();

    // T owns the throwaway gym G and shop S; U is the account whose roles change.
    const tag = uid();
    const pw = `pw-${crypto.randomUUID()}`;
    const mk = (who: string, role?: string) =>
      call("POST", "/users/signup", superU.token, {
        email: `it-${who}-${tag}@example.com`, password: pw, username: `it${who}${tag}`, name: "IT", last_name: who, role,
      });
    const tRes = await mk("owner", "owner");
    const uRes = await mk("staff");
    if (tRes.status !== 201 || uRes.status !== 201) throw new Error(`throwaway signup: ${short(tRes.data)} ${short(uRes.data)}`);
    const T = await signin(`it-owner-${tag}@example.com`, pw);
    const U = await signin(`it-staff-${tag}@example.com`, pw);
    const roleOf = async (id: string) => (await call("GET", `/users/${id}`, superU.token)).data?.role;
    const noticeFor = async (token: string, type: string, key: string, value: string) =>
      (await notificationsOf(token)).find((n) => n.type === type && n.metadata?.[key] === value && n.metadata?.invite_status === "pending");

    let G = "";
    let S = "";
    try {
      await t.step("1. businesses: create, validate, list, read, update, authz, stats", async () => {
        const base = { location: "Test St 1", working_hours_from: "06:00", working_hours_to: "22:00", working_weekdays: [1, 2, 3, 4, 5] };
        const missing = await call("POST", "/businesses", T.token, { name: `it-${tag}`, type: "gym" });
        check("create without hours/location is 400", missing.status === 400, `status ${missing.status}`);
        const badType = await call("POST", "/businesses", T.token, { ...base, name: `it-${tag}`, type: "spa" });
        check("create with an unknown type is 400", badType.status === 400, `status ${badType.status}`);

        const g = await call("POST", "/businesses", T.token, { ...base, name: `it-gym-${tag}`, type: "gym", latitude: 44.8, longitude: 20.4 });
        G = g.data?.id ?? "";
        check("owner creates a gym", g.status === 201 && g.data.type === "gym" && Number(g.data.latitude) === 44.8, short(g.data));
        const s = await call("POST", "/businesses", T.token, { ...base, name: `it-shop-${tag}`, type: "shop", latitude: "x" });
        S = s.data?.id ?? "";
        check("owner creates a shop (non-numeric latitude dropped)", s.status === 201 && s.data.type === "shop" && s.data.latitude === null, short(s.data));
        assertAll();

        // A plain member can create a business too; it should make them its owner.
        const x = await call("POST", "/businesses", U.token, { ...base, name: `it-x-${tag}`, type: "shop" });
        try {
          check("member creates a business", x.status === 201, short(x.data));
          const xOwners = await call("GET", `/shop-owners?shop_id=${x.data?.id}`, U.token);
          check("creator gets the owner row", xOwners.status === 200 && (xOwners.data as any[]).some((o) => o.user_id === U.profile.id), short(xOwners.data));
          check("creating a business sets users.role to owner", (await roleOf(U.profile.id)) === "owner", `role ${await roleOf(U.profile.id)}`);
        } finally {
          if (x.data?.id) await call("DELETE", `/businesses/${x.data.id}`, U.token);
        }
        check("deleting their only business leaves them a member", (await roleOf(U.profile.id)) === "member", `role ${await roleOf(U.profile.id)}`);

        const mine = await call("GET", "/businesses", T.token);
        check("owner lists exactly their businesses", mine.status === 200 && (mine.data as any[]).map((b) => b.id).sort().join() === [G, S].sort().join(), short(mine.data));
        const gymsOnly = await call("GET", "/businesses?type=gym", T.token);
        check("?type=gym filters", gymsOnly.status === 200 && (gymsOnly.data as any[]).length === 1 && gymsOnly.data[0].id === G, short(gymsOnly.data));
        const shopsOnly = await call("GET", "/businesses?type=shop", T.token);
        check("?type=shop filters", shopsOnly.status === 200 && (shopsOnly.data as any[]).length === 1 && shopsOnly.data[0].id === S, short(shopsOnly.data));
        const memberList = await call("GET", "/businesses", member.token);
        check("member with no businesses gets []", memberList.status === 200 && (memberList.data as any[]).length === 0, short(memberList.data));
        const superList = await call("GET", "/businesses?type=gym", superU.token);
        check("super user lists every gym", superList.status === 200 && [G, gym.id].every((id) => (superList.data as any[]).some((b) => b.id === id)) && (superList.data as any[]).every((b) => b.type === "gym"), `status ${superList.status}`);

        const read = await call("GET", `/businesses/${G}`, member.token);
        check("any signed-in user reads a business", read.status === 200 && read.data.name === `it-gym-${tag}`, short(read.data));
        const anon = await call("GET", `/businesses/${G}`);
        check("anonymous read is 401", anon.status === 401, `status ${anon.status}`);
        const unknown = await call("GET", `/businesses/${crypto.randomUUID()}`, member.token);
        check("unknown business is 404", unknown.status === 404, `status ${unknown.status}`);

        const upd = await call("PUT", `/businesses/${G}`, T.token, { name: `it-gym2-${tag}`, working_hours_to: "23:00", type: "shop" });
        check("owner updates the gym (type is ignored)", upd.status === 200 && upd.data.name === `it-gym2-${tag}` && upd.data.working_hours_to.startsWith("23:00") && upd.data.type === "gym", short(upd.data));
        const onlyType = await call("PUT", `/businesses/${G}`, T.token, { type: "shop" });
        check("type-only update is 400 (immutable)", onlyType.status === 400, `status ${onlyType.status}`);
        const empty = await call("PUT", `/businesses/${G}`, T.token, {});
        check("empty update is 400", empty.status === 400, `status ${empty.status}`);
        for (const [who, s] of [["member", member], ["another gym's owner", owner], ["another gym's employee", employee]] as const) {
          const r = await call("PUT", `/businesses/${G}`, s.token, { name: "hijack" });
          check(`${who} can't update the gym`, r.status === 403, `status ${r.status}`);
        }
        const updUnknown = await call("PUT", `/businesses/${crypto.randomUUID()}`, T.token, { name: "x" });
        check("updating an unknown business is 404", updUnknown.status === 404, `status ${updUnknown.status}`);
        const superUpd = await call("PUT", `/businesses/${S}`, superU.token, { location: "Super St 2" });
        check("super user updates any business", superUpd.status === 200 && superUpd.data.location === "Super St 2", short(superUpd.data));
        const delUnknown = await call("DELETE", `/businesses/${crypto.randomUUID()}`, T.token);
        check("deleting an unknown business is 404", delUnknown.status === 404, `status ${delUnknown.status}`);
        const delOther = await call("DELETE", `/businesses/${G}`, owner.token);
        check("another gym's owner can't delete the gym", delOther.status === 403, `status ${delOther.status}`);

        const stats = await call("GET", "/businesses/stats", T.token);
        check(
          "new owner's stats are all zero but one gym",
          stats.status === 200 && stats.data.gyms === 1 && stats.data.members_total === 0 && stats.data.staff_total === 0 &&
            stats.data.active_memberships === 0 && stats.data.invoices_month_total === "0.00" && stats.data.expiring_soon.length === 0,
          short(stats.data),
        );
        const memberStats = await call("GET", "/businesses/stats", member.token);
        check("non-owner stats are empty", memberStats.status === 200 && memberStats.data.gyms === 0, short(memberStats.data));
        assertAll();
      });

      await t.step("2. co-owners: gym-owners and shop-owners (super user only)", async () => {
        const byOwner = await call("POST", "/gym-owners", T.token, { user_id: U.profile.id, gym_id: G });
        check("owner can't add a co-owner", byOwner.status === 403, `status ${byOwner.status}`);
        const missing = await call("POST", "/gym-owners", superU.token, { gym_id: G });
        check("co-owner without user_id is 400", missing.status === 400, `status ${missing.status}`);
        const badUser = await call("POST", "/gym-owners", superU.token, { user_id: crypto.randomUUID(), gym_id: G });
        check("co-owner with an unknown user is 400", badUser.status === 400, `status ${badUser.status}`);

        const add = await call("POST", "/gym-owners", superU.token, { user_id: U.profile.id, gym_id: G });
        check("super user adds a gym co-owner", add.status === 201 && add.data.gym_id === G, short(add.data));
        const dup = await call("POST", "/gym-owners", superU.token, { user_id: U.profile.id, gym_id: G });
        check("adding the same co-owner twice is 409", dup.status === 409, `status ${dup.status}`);
        check("co-owner's role becomes owner", (await roleOf(U.profile.id)) === "owner");

        const list = await call("GET", `/gym-owners?gym_id=${G}`, member.token);
        check(
          "gym-owners lists both owners with names (no emails)",
          list.status === 200 && [T.profile.id, U.profile.id].every((id) => (list.data as any[]).some((o) => o.user_id === id)) &&
            (list.data as any[]).every((o) => !("email" in o) && typeof o.name === "string"),
          short(list.data),
        );
        const byUser = await call("GET", `/gym-owners?user_id=${U.profile.id}`, member.token);
        check("?user_id= filters", byUser.status === 200 && (byUser.data as any[]).length === 1 && byUser.data[0].gym_id === G, short(byUser.data));
        const one = await call("GET", `/gym-owners/${add.data.id}`, member.token);
        check("read one gym-owner row", one.status === 200 && one.data.user_id === U.profile.id, short(one.data));
        const none = await call("GET", `/gym-owners/${crypto.randomUUID()}`, member.token);
        check("unknown gym-owner row is 404", none.status === 404, `status ${none.status}`);

        // What the co-owner can now do — and can't (the shop is still T's alone).
        const coBiz = await call("GET", "/businesses", U.token);
        check("co-owner sees the gym in their businesses", coBiz.status === 200 && (coBiz.data as any[]).some((b) => b.id === G), short(coBiz.data));
        const coUpd = await call("PUT", `/businesses/${G}`, U.token, { location: "Co St 3" });
        check("co-owner updates the gym", coUpd.status === 200 && coUpd.data.location === "Co St 3", short(coUpd.data));
        const coType = await call("POST", "/gym-membership-types", U.token, { name: `it-co-${tag}`, monthly_cost: 1, gym_id: G });
        check("co-owner manages pricing", coType.status === 201, short(coType.data));
        if (coType.data?.id) await call("DELETE", `/gym-membership-types/${coType.data.id}`, U.token);
        const coShop = await call("PUT", `/businesses/${S}`, U.token, { location: "nope" });
        check("gym co-owner can't update the owner's shop", coShop.status === 403, `status ${coShop.status}`);

        const delByOwner = await call("DELETE", `/gym-owners/${add.data.id}`, T.token);
        check("owner can't remove a co-owner", delByOwner.status === 403, `status ${delByOwner.status}`);
        const del = await call("DELETE", `/gym-owners/${add.data.id}`, superU.token);
        check("super user removes the co-owner", del.status === 204, `status ${del.status}`);
        check("removed co-owner is a member again", (await roleOf(U.profile.id)) === "member");
        const after = await call("PUT", `/businesses/${G}`, U.token, { location: "again" });
        check("removed co-owner can't update the gym", after.status === 403, `status ${after.status}`);
        const delAgain = await call("DELETE", `/gym-owners/${add.data.id}`, superU.token);
        check("removing it again is 404", delAgain.status === 404, `status ${delAgain.status}`);

        // Shop co-owners.
        const sByOwner = await call("POST", "/shop-owners", T.token, { user_id: U.profile.id, shop_id: S });
        check("owner can't add a shop co-owner", sByOwner.status === 403, `status ${sByOwner.status}`);
        const sMissing = await call("POST", "/shop-owners", superU.token, { user_id: U.profile.id });
        check("shop co-owner without shop_id is 400", sMissing.status === 400, `status ${sMissing.status}`);
        const sBadShop = await call("POST", "/shop-owners", superU.token, { user_id: U.profile.id, shop_id: crypto.randomUUID() });
        check("shop co-owner of an unknown shop is 400", sBadShop.status === 400, `status ${sBadShop.status}`);
        const sAdd = await call("POST", "/shop-owners", superU.token, { user_id: U.profile.id, shop_id: S });
        check("super user adds a shop co-owner", sAdd.status === 201 && sAdd.data.shop_id === S, short(sAdd.data));
        const sDup = await call("POST", "/shop-owners", superU.token, { user_id: U.profile.id, shop_id: S });
        check("adding the same shop co-owner twice is 409", sDup.status === 409, `status ${sDup.status}`);
        const sList = await call("GET", `/shop-owners?shop_id=${S}`, member.token);
        check("shop-owners lists both", sList.status === 200 && (sList.data as any[]).length === 2, short(sList.data));
        const sByUser = await call("GET", `/shop-owners?user_id=${U.profile.id}`, member.token);
        check("shop-owners ?user_id= filters", sByUser.status === 200 && (sByUser.data as any[]).every((o) => o.user_id === U.profile.id && o.shop_id === S), short(sByUser.data));
        const sOne = await call("GET", `/shop-owners/${sAdd.data.id}`, member.token);
        check("read one shop-owner row", sOne.status === 200 && sOne.data.user_id === U.profile.id, short(sOne.data));
        const sNone = await call("GET", `/shop-owners/${crypto.randomUUID()}`, member.token);
        check("unknown shop-owner row is 404", sNone.status === 404, `status ${sNone.status}`);
        const sUpd = await call("PUT", `/businesses/${S}`, U.token, { location: "Shop St 4" });
        check("shop co-owner updates the shop", sUpd.status === 200, `status ${sUpd.status}`);
        const sItem = await call("POST", "/shop-items", U.token, { shop_id: S, type: "equipment", name: `it-co-${tag}`, price: 1, quantity: 1 });
        check("shop co-owner manages items", sItem.status === 201, short(sItem.data));
        if (sItem.data?.id) await call("DELETE", `/shop-items/${sItem.data.id}`, U.token);
        const sDelByOwner = await call("DELETE", `/shop-owners/${sAdd.data.id}`, T.token);
        check("owner can't remove a shop co-owner", sDelByOwner.status === 403, `status ${sDelByOwner.status}`);
        const sDel = await call("DELETE", `/shop-owners/${sAdd.data.id}`, superU.token);
        check("super user removes the shop co-owner", sDel.status === 204, `status ${sDel.status}`);
        check("removed shop co-owner is a member again", (await roleOf(U.profile.id)) === "member");
        const sDelAgain = await call("DELETE", `/shop-owners/${sAdd.data.id}`, superU.token);
        check("removing the shop co-owner again is 404", sDelAgain.status === 404, `status ${sDelAgain.status}`);
        assertAll();
      });

      await t.step("3. employees: invite, decline, accept, role changes, removal", async () => {
        const v = (b: Record<string, unknown>) => call("POST", "/employees", T.token, b);
        const noGym = await v({ user_id: U.profile.id });
        check("employee without gym_id is 400", noGym.status === 400, `status ${noGym.status}`);
        const badType = await v({ user_id: U.profile.id, gym_id: G, employee_type: "manager" });
        check("unknown employee_type is 400", badType.status === 400, `status ${badType.status}`);
        const unknownGym = await v({ user_id: U.profile.id, gym_id: crypto.randomUUID() });
        check("unknown gym is 404", unknownGym.status === 404, `status ${unknownGym.status}`);
        const noTarget = await v({ gym_id: G });
        check("neither user_id nor email is 400", noTarget.status === 400, `status ${noTarget.status}`);
        const self = await v({ user_id: T.profile.id, gym_id: G });
        check("owner can't add themself", self.status === 400, `status ${self.status}`);
        const ghost = await v({ user_id: crypto.randomUUID(), gym_id: G });
        check("unknown user_id is 404", ghost.status === 404, `status ${ghost.status}`);
        // New-account branch, stopped before any invite email goes out.
        const noNames = await v({ gym_id: G, email: `it-nobody-${tag}@example.com` });
        check("new email without names is 400", noNames.status === 400, `status ${noNames.status}`);
        const takenName = await v({ gym_id: G, email: `it-nobody-${tag}@example.com`, name: "N", last_name: "B", username: member.profile.username });
        check("new email with a taken username is 409", takenName.status === 409, `status ${takenName.status}`);
        for (const [who, s] of [["member", member], ["another gym's owner", owner], ["another gym's employee", employee]] as const) {
          const r = await call("POST", "/employees", s.token, { user_id: U.profile.id, gym_id: G });
          check(`${who} can't hire at the gym`, r.status === 403, `status ${r.status}`);
        }

        // Invite → decline → re-invite → accept.
        const inv1 = await v({ user_id: U.profile.id, gym_id: G });
        check("owner invites an existing user", inv1.status === 200 && inv1.data.invited === true, short(inv1.data));
        const n1 = await noticeFor(U.token, "employee_gym_invite", "gym_id", G);
        check("invitee gets a pending invite", !!n1 && n1.metadata.employee_type === "employee", short(n1));
        check("pending invite grants nothing", (await call("POST", "/members", U.token, { gym_id: G, user_id: member.profile.id })).status === 403);
        const strangerAccept = await call("POST", `/notifications/${n1?.id}/accept`, member.token);
        check("someone else can't accept the invite", strangerAccept.status === 403, `status ${strangerAccept.status}`);
        const decline = await call("POST", `/notifications/${n1?.id}/decline`, U.token);
        check("invitee declines", decline.status === 200 && decline.data.metadata?.invite_status === "declined", short(decline.data));
        const lateAccept = await call("POST", `/notifications/${n1?.id}/accept`, U.token);
        check("a declined invite can't be accepted", lateAccept.status === 409, `status ${lateAccept.status}`);
        check("declining hires nobody", !((await call("GET", `/employees?gym_id=${G}`, T.token)).data as any[]).length);

        await v({ user_id: U.profile.id, gym_id: G });
        const n2 = await noticeFor(U.token, "employee_gym_invite", "gym_id", G);
        const accept = await call("POST", `/notifications/${n2?.id}/accept`, U.token);
        check("invitee accepts", accept.status === 200 && accept.data.metadata?.invite_status === "accepted", short(accept.data));
        const joined = (await notificationsOf(T.token)).find((n) => n.type === "employee_join" && n.metadata?.user_id === U.profile.id);
        check("owner is told the employee joined", !!joined && joined.metadata.gym_id === G, short(joined));
        check("employee's role is employee", (await roleOf(U.profile.id)) === "employee");
        const again = await v({ user_id: U.profile.id, gym_id: G });
        check("inviting a current employee is 409", again.status === 409, `status ${again.status}`);

        const staffAsOwner = await call("GET", `/employees?gym_id=${G}`, T.token);
        const empRow = (staffAsOwner.data as any[])?.find((e) => e.user_id === U.profile.id);
        check("owner sees the employee with email", staffAsOwner.status === 200 && empRow?.email === `it-staff-${tag}@example.com` && empRow.role === "employee", short(empRow));
        const staffAsStranger = await call("GET", `/employees?gym_id=${G}`, member.token);
        check("outsiders see the employee without email", staffAsStranger.status === 200 && (staffAsStranger.data as any[]).every((e) => !("email" in e)), short(staffAsStranger.data));
        const byUser = await call("GET", `/employees?user_id=${U.profile.id}`, U.token);
        check("employee lists own rows (with email)", byUser.status === 200 && byUser.data.length === 1 && byUser.data[0].email, short(byUser.data));
        const oneEmp = await call("GET", `/employees/${empRow?.id}`, member.token);
        check("read one employee row (email redacted)", oneEmp.status === 200 && oneEmp.data.user_id === U.profile.id && !("email" in oneEmp.data), short(oneEmp.data));
        check("unknown employee row is 404", (await call("GET", `/employees/${crypto.randomUUID()}`, T.token)).status === 404);

        // What the employee can now do at G (front desk) — and can't (management, other gyms).
        const addMember = await call("POST", "/members", U.token, { gym_id: G, user_id: member.profile.id });
        check("employee adds a member", addMember.status === 201 && addMember.data.gym_id === G, short(addMember.data));
        const welcome = (await notificationsOf(member.token)).find((n) => n.type === "member_join" && n.metadata?.gym_id === G);
        check("new member gets a welcome notification", !!welcome, short(welcome));
        const ownerJoin = (await notificationsOf(T.token)).find((n) => n.type === "member_join" && n.metadata?.user_id === member.profile.id);
        check("owner is told about the new member", !!ownerJoin && ownerJoin.metadata.gym_id === G, short(ownerJoin));
        const empSeesEmails = await call("GET", `/members?gym_id=${G}`, U.token);
        check("employee sees member emails", empSeesEmails.status === 200 && (empSeesEmails.data as any[]).some((m) => m.user_id === member.profile.id && m.email), short(empSeesEmails.data));
        for (
          const [what, r] of [
            ["update the gym", await call("PUT", `/businesses/${G}`, U.token, { location: "x" })],
            ["hire", await call("POST", "/employees", U.token, { user_id: member.profile.id, gym_id: G })],
            ["change staff roles", await call("PUT", "/employees/role", U.token, { user_id: U.profile.id, gym_id: G, employee_type: "employee_trainer" })],
            ["set prices", await call("POST", "/gym-membership-types", U.token, { name: "x", monthly_cost: 1, gym_id: G })],
            ["add members at another gym", await call("POST", "/members", U.token, { gym_id: gym.id, user_id: member.profile.id })],
          ] as const
        ) check(`employee can't ${what}`, r.status === 403, `status ${r.status}`);

        // Role changes.
        const role = (b: Record<string, unknown>, tok = T.token) => call("PUT", "/employees/role", tok, b);
        check("role change without gym_id is 400", (await role({ user_id: U.profile.id, employee_type: "employee" })).status === 400);
        check("role change to an unknown type is 400", (await role({ user_id: U.profile.id, gym_id: G, employee_type: "boss" })).status === 400);
        check("another gym's owner can't change roles here", (await role({ user_id: U.profile.id, gym_id: G, employee_type: "employee_trainer" }, owner.token)).status === 403);
        check("role change for a non-staff user is 404", (await role({ user_id: member.profile.id, gym_id: G, employee_type: "employee_trainer" })).status === 404);
        const toEt = await role({ user_id: U.profile.id, gym_id: G, employee_type: "employee_trainer" });
        check("owner promotes to employee-trainer", toEt.status === 200 && toEt.data.employee_type === "employee_trainer" && toEt.data.role === "employee_trainer", short(toEt.data));
        const ets = (await call("GET", `/employee-trainers?gym_id=${G}`, T.token)).data as any[];
        const emps = (await call("GET", `/employees?gym_id=${G}`, T.token)).data as any[];
        check("moved from employees to employee-trainers", ets.some((e) => e.user_id === U.profile.id) && !emps.some((e) => e.user_id === U.profile.id), `ets ${ets.length} emps ${emps.length}`);
        const trainers1 = (await call("GET", `/trainers?gym_id=${G}`, member.token)).data as any[];
        check("promotion creates the trainer row", trainers1.some((r) => r.user_id === U.profile.id));
        const same = await role({ user_id: U.profile.id, gym_id: G, employee_type: "employee_trainer" });
        check("same role again is an idempotent 200", same.status === 200 && same.data.id === toEt.data.id, short(same.data));
        const back = await role({ user_id: U.profile.id, gym_id: G, employee_type: "employee" });
        check("owner demotes back to employee", back.status === 200 && back.data.employee_type === "employee" && back.data.role === "employee", short(back.data));
        const leftover = ((await call("GET", `/trainers?gym_id=${G}`, member.token)).data as any[]).find((r) => r.user_id === U.profile.id);
        check("demotion leaves the trainer row in place", !!leftover);
        if (leftover) await call("DELETE", `/trainers/${leftover.id}`, T.token);

        // Removal.
        const empId = back.data?.id;
        check("employee can't remove themself", (await call("DELETE", `/employees/${empId}`, U.token)).status === 403);
        check("another gym's owner can't remove them", (await call("DELETE", `/employees/${empId}`, owner.token)).status === 403);
        const fire = await call("DELETE", `/employees/${empId}`, T.token);
        check("owner removes the employee", fire.status === 204, `status ${fire.status}`);
        check("removed employee is a member again", (await roleOf(U.profile.id)) === "member");
        const afterFire = await call("POST", "/members", U.token, { gym_id: G, user_id: vendor.profile.id });
        check("removed employee can't add members", afterFire.status === 403, `status ${afterFire.status}`);
        check("removing again is 404", (await call("DELETE", `/employees/${empId}`, T.token)).status === 404);
        assertAll();
      });

      await t.step("4. employee-trainers and trainers: add directly, coach access, removal", async () => {
        const et = (b: Record<string, unknown>, tok = T.token) => call("POST", "/employee-trainers", tok, b);
        check("employee-trainer without gym_id is 400", (await et({ user_id: U.profile.id })).status === 400);
        check("member can't add employee-trainers", (await et({ user_id: U.profile.id, gym_id: G }, member.token)).status === 403);
        check("another gym's owner can't add here", (await et({ user_id: U.profile.id, gym_id: G }, owner.token)).status === 403);
        check("unknown user is 400", (await et({ user_id: crypto.randomUUID(), gym_id: G })).status === 400);
        const add = await et({ user_id: U.profile.id, gym_id: G });
        check("owner adds an employee-trainer", add.status === 201 && add.data.gym_id === G && !!add.data.trainer_id, short(add.data));
        check("adding twice is 409", (await et({ user_id: U.profile.id, gym_id: G })).status === 409);
        check("their role is employee_trainer", (await roleOf(U.profile.id)) === "employee_trainer");
        const one = await call("GET", `/employee-trainers/${add.data?.id}`, member.token);
        check("read one employee-trainer (email redacted for outsiders)", one.status === 200 && one.data.user_id === U.profile.id && !("email" in one.data), short(one.data));
        const mine = await call("GET", `/employee-trainers?user_id=${U.profile.id}`, U.token);
        check("employee-trainer lists own rows with email", mine.status === 200 && mine.data.length === 1 && !!mine.data[0].email, short(mine.data));
        check("unknown employee-trainer is 404", (await call("GET", `/employee-trainers/${crypto.randomUUID()}`, T.token)).status === 404);
        const trainerRow = ((await call("GET", `/trainers?gym_id=${G}`, member.token)).data as any[]).find((r) => r.id === add.data?.trainer_id);
        check("the linked trainer row exists", !!trainerRow && trainerRow.user_id === U.profile.id);
        const etAddsMember = await call("POST", "/members", U.token, { gym_id: G, user_id: vendor.profile.id });
        check("employee-trainer does front-desk work (adds a member)", etAddsMember.status === 201, short(etAddsMember.data));
        if (etAddsMember.data?.id) await call("DELETE", `/members/${etAddsMember.data.id}`, U.token);
        check("employee-trainer can't remove themself", (await call("DELETE", `/employee-trainers/${add.data?.id}`, U.token)).status === 403);
        const del = await call("DELETE", `/employee-trainers/${add.data?.id}`, T.token);
        check("owner removes the employee-trainer", del.status === 204, `status ${del.status}`);
        check("removal deletes the linked trainer row", !((await call("GET", `/trainers?gym_id=${G}`, member.token)).data as any[]).some((r) => r.user_id === U.profile.id));
        check("removed employee-trainer is a member again", (await roleOf(U.profile.id)) === "member");
        check("removing again is 404", (await call("DELETE", `/employee-trainers/${add.data?.id}`, T.token)).status === 404);

        // Plain trainers coach (see member emails) but don't do front-desk work.
        const tr = (b: Record<string, unknown>, tok = T.token) => call("POST", "/trainers", tok, b);
        check("trainer without user_id is 400", (await tr({ gym_id: G })).status === 400);
        check("employee of another gym can't add trainers here", (await tr({ user_id: U.profile.id, gym_id: G }, employee.token)).status === 403);
        check("trainer with an unknown user is 400", (await tr({ user_id: crypto.randomUUID(), gym_id: G })).status === 400);
        const addT = await tr({ user_id: U.profile.id, gym_id: G });
        check("owner adds a trainer", addT.status === 201 && addT.data.gym_id === G, short(addT.data));
        check("adding the trainer twice is 409", (await tr({ user_id: U.profile.id, gym_id: G })).status === 409);
        check("their role is trainer", (await roleOf(U.profile.id)) === "trainer");
        const byUser = await call("GET", `/trainers?user_id=${U.profile.id}`, member.token);
        check("trainers ?user_id= filters (no emails)", byUser.status === 200 && byUser.data.length === 1 && !("email" in byUser.data[0]), short(byUser.data));
        const oneT = await call("GET", `/trainers/${addT.data?.id}`, member.token);
        check("read one trainer", oneT.status === 200 && oneT.data.user_id === U.profile.id, short(oneT.data));
        check("unknown trainer is 404", (await call("GET", `/trainers/${crypto.randomUUID()}`, member.token)).status === 404);
        const roster = await call("GET", `/members?gym_id=${G}`, U.token);
        check("trainer sees member emails", roster.status === 200 && (roster.data as any[]).some((m) => m.user_id === member.profile.id && m.email), short(roster.data));
        const trainerAdds = await call("POST", "/members", U.token, { gym_id: G, user_id: vendor.profile.id });
        check("trainer can't add members", trainerAdds.status === 403, `status ${trainerAdds.status}`);
        check("trainer can't remove themself", (await call("DELETE", `/trainers/${addT.data?.id}`, U.token)).status === 403);
        const delT = await call("DELETE", `/trainers/${addT.data?.id}`, T.token);
        check("owner removes the trainer", delT.status === 204, `status ${delT.status}`);
        check("removed trainer is a member again", (await roleOf(U.profile.id)) === "member");
        const rosterAfter = await call("GET", `/members?gym_id=${G}`, U.token);
        check("removed trainer no longer sees member emails", rosterAfter.status === 200 && (rosterAfter.data as any[]).every((m) => !("email" in m)), short(rosterAfter.data));
        check("removing the trainer again is 404", (await call("DELETE", `/trainers/${addT.data?.id}`, T.token)).status === 404);
        assertAll();
      });

      await t.step("5. members: add by id/email, validation, roster, resend-invite, removal, stats", async () => {
        const m = (b: Record<string, unknown>, tok = T.token) => call("POST", "/members", tok, b);
        check("member without gym_id is 400", (await m({ user_id: vendor.profile.id })).status === 400);
        check("member of an unknown gym is 404", (await m({ user_id: vendor.profile.id, gym_id: crypto.randomUUID() })).status === 404);
        check("member can't add members", (await m({ user_id: vendor.profile.id, gym_id: G }, member.token)).status === 403);
        check("neither user_id nor email is 400", (await m({ gym_id: G })).status === 400);
        check("unknown user_id is 400", (await m({ gym_id: G, user_id: crypto.randomUUID() })).status === 400);
        check("new email without names is 400", (await m({ gym_id: G, email: `it-nobody-${tag}@example.com` })).status === 400);
        check(
          "new email with a taken username is 409",
          (await m({ gym_id: G, email: `it-nobody-${tag}@example.com`, name: "N", last_name: "B", username: vendor.profile.username })).status === 409,
        );
        const dup = await m({ gym_id: G, user_id: member.profile.id });
        check("adding an existing member again is 409", dup.status === 409, `status ${dup.status}`);
        const byEmail = await m({ gym_id: G, email: vendor.profile.email ?? "ravi.deshmukh@example.com" });
        check("owner adds an existing user by email", byEmail.status === 201 && byEmail.data.user_id === vendor.profile.id, short(byEmail.data));
        check("adding a member leaves users.role alone", (await roleOf(vendor.profile.id)) === "shop_vendor");

        const asOwner = (await call("GET", `/members?gym_id=${G}`, T.token)).data as any[];
        check("roster has both members with emails for the owner", asOwner.length === 2 && asOwner.every((r) => !!r.email), short(asOwner));
        const asVendor = (await call("GET", `/members?gym_id=${G}`, vendor.token)).data as any[];
        check(
          "a member sees only their own email in the roster",
          asVendor.find((r) => r.user_id === vendor.profile.id)?.email && asVendor.every((r) => r.user_id === vendor.profile.id || !("email" in r)),
          short(asVendor),
        );
        const liamRow = asOwner.find((r) => r.user_id === member.profile.id);
        const myGyms = await call("GET", `/members?user_id=${member.profile.id}`, member.token);
        check("?user_id= lists a user's gyms", myGyms.status === 200 && [G, gym.id].every((g) => (myGyms.data as any[]).some((r) => r.gym_id === g)), short(myGyms.data));
        const one = await call("GET", `/members/${liamRow?.id}`, vendor.token);
        check("read one member row", one.status === 200 && one.data.user_id === member.profile.id && one.data.gym_id === G, short(one.data));
        check("unknown member row is 404", (await call("GET", `/members/${crypto.randomUUID()}`, T.token)).status === 404);

        const resendMember = await call("POST", `/members/${liamRow?.id}/resend-invite`, member.token);
        check("member can't resend invites", resendMember.status === 403, `status ${resendMember.status}`);
        const resendUnknown = await call("POST", `/members/${crypto.randomUUID()}/resend-invite`, T.token);
        check("resend-invite for an unknown member is 404", resendUnknown.status === 404, `status ${resendUnknown.status}`);
        const resendActive = await call("POST", `/members/${liamRow?.id}/resend-invite`, T.token);
        check("resend-invite to an already-registered user is refused (400)", resendActive.status === 400, `status ${resendActive.status} ${short(resendActive.data)}`);

        // Stats now reflect the members, a membership expiring soon and an unpaid invoice.
        const type = await call("POST", "/gym-membership-types", T.token, { name: `it-${tag}`, monthly_cost: 25.5, gym_id: G });
        const ms = await call("POST", "/memberships", T.token, {
          user_id: member.profile.id, current_membership_type_id: type.data?.id, from_date: dayFromToday(-20), to_date: dayFromToday(10),
        });
        const inv = await call("POST", "/membership-invoices", T.token, { membership_id: ms.data?.id });
        check("membership + invoice for stats", type.status === 201 && ms.status === 201 && inv.status === 201, `${type.status} ${ms.status} ${inv.status}`);
        const stats = await call("GET", "/businesses/stats", T.token);
        check(
          "stats count members, active memberships, invoices and expiring soon",
          stats.status === 200 && stats.data.members_total === 2 && stats.data.active_memberships === 1 && stats.data.invoices_month_count === 1 &&
            stats.data.invoices_month_total === "25.50" && stats.data.unpaid_invoices_count === 1 &&
            stats.data.expiring_soon.length === 1 && stats.data.expiring_soon[0].user_id === member.profile.id &&
            stats.data.expiring_soon[0].to_date === dayFromToday(10),
          short(stats.data),
        );
        await call("PUT", `/membership-invoices/${inv.data?.id}`, T.token, { status: "void" });
        const voided = await call("GET", "/businesses/stats", T.token);
        check("void invoices drop out of the month's totals", voided.data?.invoices_month_count === 0 && voided.data?.unpaid_invoices_count === 0, short(voided.data));

        const vendorRow = asOwner.find((r) => r.user_id === vendor.profile.id);
        check("a member can't remove their own membership row", (await call("DELETE", `/members/${vendorRow?.id}`, vendor.token)).status === 403);
        check("another gym's owner can't remove members here", (await call("DELETE", `/members/${vendorRow?.id}`, owner.token)).status === 403);
        const del = await call("DELETE", `/members/${vendorRow?.id}`, T.token);
        check("owner removes a member", del.status === 204, `status ${del.status}`);
        check("removing again is 404", (await call("DELETE", `/members/${vendorRow?.id}`, T.token)).status === 404);
        assertAll();
      });

      await t.step("6. gym isolation: staff of one gym can't touch another", async () => {
        const typeId = ((await call("GET", `/gym-membership-types?gym_id=${G}`, T.token)).data as any[])[0]?.id;
        const msId = ((await call("GET", `/memberships?gym_id=${G}`, T.token)).data as any[])[0]?.id;
        const invId = ((await call("GET", `/membership-invoices?gym_id=${G}`, T.token)).data as any[])[0]?.id;
        const liamRowG = ((await call("GET", `/members?gym_id=${G}`, T.token)).data as any[]).find((r) => r.user_id === member.profile.id);
        const ironRoster = (await call("GET", `/members?gym_id=${gym.id}`, owner.token)).data as any[];
        const ironMember = ironRoster.find((r) => r.user_id === member.profile.id);
        const ironEmp = ((await call("GET", `/employees?gym_id=${gym.id}`, owner.token)).data as any[])[0];
        const ironTrainer = ((await call("GET", `/trainers?gym_id=${gym.id}`, owner.token)).data as any[])[0];
        check("fixtures found", !!(typeId && msId && invId && liamRowG && ironMember && ironEmp && ironTrainer));
        assertAll();

        const denied: [string, Promise<{ status: number }>][] = [
          // Ironclad's owner and employee against the throwaway gym.
          ["Ironclad owner deletes G's member", call("DELETE", `/members/${liamRowG.id}`, owner.token)],
          ["Ironclad owner edits G's price", call("PUT", `/gym-membership-types/${typeId}`, owner.token, { monthly_cost: 0 })],
          ["Ironclad owner deletes G's type", call("DELETE", `/gym-membership-types/${typeId}`, owner.token)],
          ["Ironclad employee sells G's membership", call("POST", "/memberships", employee.token, { user_id: member.profile.id, current_membership_type_id: typeId, from_date: dayFromToday(0), to_date: dayFromToday(30) })],
          ["Ironclad employee extends G's membership", call("PUT", `/memberships/${msId}`, employee.token, { to_date: dayFromToday(365) })],
          ["Ironclad employee deletes G's membership", call("DELETE", `/memberships/${msId}`, employee.token)],
          ["Ironclad employee invoices G's membership", call("POST", "/membership-invoices", employee.token, { membership_id: msId })],
          ["Ironclad employee marks G's invoice paid", call("PUT", `/membership-invoices/${invId}`, employee.token, { status: "paid" })],
          ["Ironclad employee reads G's invoice", call("GET", `/membership-invoices/${invId}`, employee.token)],
          ["Ironclad employee deletes G's invoice", call("DELETE", `/membership-invoices/${invId}`, employee.token)],
          ["Ironclad employee adds a member to G", call("POST", "/members", employee.token, { gym_id: G, user_id: vendor.profile.id })],
          // G's owner against Ironclad.
          ["G owner adds a member to Ironclad", call("POST", "/members", T.token, { gym_id: gym.id, user_id: vendor.profile.id })],
          ["G owner removes an Ironclad member", call("DELETE", `/members/${ironMember.id}`, T.token)],
          ["G owner hires at Ironclad", call("POST", "/employees", T.token, { user_id: vendor.profile.id, gym_id: gym.id })],
          ["G owner fires an Ironclad employee", call("DELETE", `/employees/${ironEmp.id}`, T.token)],
          ["G owner changes an Ironclad role", call("PUT", "/employees/role", T.token, { user_id: ironEmp.user_id, gym_id: gym.id, employee_type: "employee_trainer" })],
          ["G owner removes an Ironclad trainer", call("DELETE", `/trainers/${ironTrainer.id}`, T.token)],
          ["G owner adds an Ironclad trainer", call("POST", "/trainers", T.token, { user_id: vendor.profile.id, gym_id: gym.id })],
          ["G owner prices Ironclad", call("POST", "/gym-membership-types", T.token, { name: "x", monthly_cost: 1, gym_id: gym.id })],
          ["G owner edits Ironclad", call("PUT", `/businesses/${gym.id}`, T.token, { name: "x" })],
          ["G owner deletes Ironclad", call("DELETE", `/businesses/${gym.id}`, T.token)],
        ];
        for (const [what, p] of denied) {
          const r = await p;
          check(`${what} → 403`, r.status === 403, `status ${r.status}`);
        }
        const ironInvoices = await call("GET", `/membership-invoices?gym_id=${G}`, employee.token);
        check("another gym's staff list none of G's invoices", ironInvoices.status === 200 && (ironInvoices.data as any[]).length === 0, short(ironInvoices.data));
        const ironRosterAsT = await call("GET", `/members?gym_id=${gym.id}`, T.token);
        check("G's owner sees Ironclad's roster without emails", ironRosterAsT.status === 200 && (ironRosterAsT.data as any[]).every((r) => !("email" in r)), `status ${ironRosterAsT.status}`);
        check("Ironclad roster untouched", ((await call("GET", `/members?gym_id=${gym.id}`, owner.token)).data as any[]).length === ironRoster.length);
        assertAll();
      });

      await t.step("7. shop vendors: invite, accept, vendor rights, removal", async () => {
        const v = (b: Record<string, unknown>, tok = T.token) => call("POST", "/shop-vendors", tok, b);
        check("vendor without shop_id is 400", (await v({ user_id: U.profile.id })).status === 400);
        check("vendor at an unknown shop is 404", (await v({ user_id: U.profile.id, shop_id: crypto.randomUUID() })).status === 404);
        check("member can't add vendors", (await v({ user_id: U.profile.id, shop_id: S }, member.token)).status === 403);
        check("another shop's vendor can't add vendors here", (await v({ user_id: U.profile.id, shop_id: S }, vendor.token)).status === 403);
        check("neither user_id nor email is 400", (await v({ shop_id: S })).status === 400);
        check("owner can't add themself", (await v({ user_id: T.profile.id, shop_id: S })).status === 400);
        check("unknown user_id is 404", (await v({ user_id: crypto.randomUUID(), shop_id: S })).status === 404);
        check("new email without names is 400", (await v({ shop_id: S, email: `it-nobody-${tag}@example.com` })).status === 400);
        check(
          "new email with a taken username is 409",
          (await v({ shop_id: S, email: `it-nobody-${tag}@example.com`, name: "N", last_name: "B", username: vendor.profile.username })).status === 409,
        );

        const inv = await v({ user_id: U.profile.id, shop_id: S });
        check("owner invites a vendor", inv.status === 200 && inv.data.invited === true, short(inv.data));
        const n = await noticeFor(U.token, "vendor_shop_invite", "shop_id", S);
        check("invitee gets a pending vendor invite", !!n);
        check("pending vendor invite grants nothing", (await call("POST", "/shop-items", U.token, { shop_id: S, type: "equipment", name: "x", price: 1, quantity: 1 })).status === 403);
        const accept = await call("POST", `/notifications/${n?.id}/accept`, U.token);
        check("invitee accepts", accept.status === 200 && accept.data.metadata?.invite_status === "accepted", short(accept.data));
        const again = await call("POST", `/notifications/${n?.id}/accept`, U.token);
        check("accepting twice is 409", again.status === 409, `status ${again.status}`);
        const joined = (await notificationsOf(T.token)).find((x) => x.type === "vendor_join" && x.metadata?.shop_id === S);
        check("owner is told the vendor joined", !!joined && joined.metadata.user_id === U.profile.id, short(joined));
        check("vendor's role is shop_vendor", (await roleOf(U.profile.id)) === "shop_vendor");
        check("inviting a current vendor is 409", (await v({ user_id: U.profile.id, shop_id: S })).status === 409);

        const asOwner = (await call("GET", `/shop-vendors?shop_id=${S}`, T.token)).data as any[];
        const row = asOwner.find((r) => r.user_id === U.profile.id);
        check("owner lists the vendor with email", !!row?.email && row.role === "shop_vendor", short(asOwner));
        const asStranger = (await call("GET", `/shop-vendors?shop_id=${S}`, member.token)).data as any[];
        check("outsiders see vendors without email", asStranger.length === 1 && !("email" in asStranger[0]), short(asStranger));
        const one = await call("GET", `/shop-vendors/${row?.id}`, U.token);
        check("vendor reads own row with email", one.status === 200 && !!one.data.email, short(one.data));
        check("unknown vendor row is 404", (await call("GET", `/shop-vendors/${crypto.randomUUID()}`, T.token)).status === 404);

        // Vendor rights: items yes, staff/business/other shops no.
        const item = await call("POST", "/shop-items", U.token, { shop_id: S, type: "supplement", name: `it-v-${tag}`, price: 9.99, quantity: 3 });
        check("vendor adds an item", item.status === 201, short(item.data));
        const vendorShopId = ((await call("GET", `/shop-vendors?user_id=${vendor.profile.id}`, vendor.token)).data as any[])[0]?.shop_id;
        for (
          const [what, r] of [
            ["add vendors", await v({ user_id: member.profile.id, shop_id: S }, U.token)],
            ["remove themself", await call("DELETE", `/shop-vendors/${row?.id}`, U.token)],
            ["update the shop", await call("PUT", `/businesses/${S}`, U.token, { location: "x" })],
            ["sell at another shop", await call("POST", "/shop-items", U.token, { shop_id: vendorShopId, type: "equipment", name: "x", price: 1, quantity: 1 })],
          ] as const
        ) check(`vendor can't ${what}`, r.status === 403, `status ${r.status}`);
        check("another shop's vendor can't remove this vendor", (await call("DELETE", `/shop-vendors/${row?.id}`, vendor.token)).status === 403);

        // Taking a gym job while still a vendor, then losing it.
        await call("POST", "/employees", T.token, { user_id: U.profile.id, gym_id: G });
        const ge = await noticeFor(U.token, "employee_gym_invite", "gym_id", G);
        await call("POST", `/notifications/${ge?.id}/accept`, U.token);
        const empRow = ((await call("GET", `/employees?gym_id=${G}`, T.token)).data as any[]).find((e) => e.user_id === U.profile.id);
        check("vendor also became an employee", !!empRow);
        await call("DELETE", `/employees/${empRow?.id}`, T.token);
        // users.role follows the jobs the user still holds; the shop_vendor row remains.
        check("losing the gym job keeps the vendor role", (await roleOf(U.profile.id)) === "shop_vendor", `role ${await roleOf(U.profile.id)}`);

        const del = await call("DELETE", `/shop-vendors/${row?.id}`, T.token);
        check("owner removes the vendor", del.status === 204, `status ${del.status}`);
        check("removed vendor is a member", (await roleOf(U.profile.id)) === "member");
        const after = await call("PUT", `/shop-items/${item.data?.id}`, U.token, { price: 1 });
        check("removed vendor can't edit items", after.status === 403, `status ${after.status}`);
        check("removing again is 404", (await call("DELETE", `/shop-vendors/${row?.id}`, T.token)).status === 404);
        assertAll();
      });

      await t.step("8. deleting businesses cascades (orders, items, members, memberships, staff)", async () => {
        // U back on staff so the cascade has a role to reconcile.
        await call("POST", "/employee-trainers", T.token, { user_id: U.profile.id, gym_id: G });
        const item = ((await call("GET", `/shop-items?shop_id=${S}`)).data as any[])[0];
        const order = await call("POST", "/orders", member.token, { shop_id: S, items: [{ shop_item_id: item?.id, quantity: 1 }], payment_method: "pay_at_pickup" });
        check("member orders from the shop", order.status === 201, short(order.data));
        const msId = ((await call("GET", `/memberships?gym_id=${G}`, T.token)).data as any[])[0]?.id;
        const invId = ((await call("GET", `/membership-invoices?gym_id=${G}`, T.token)).data as any[])[0]?.id;

        const delShop = await call("DELETE", `/businesses/${S}`, T.token);
        check("owner deletes the shop", delShop.status === 204, `status ${delShop.status} ${short(delShop.data)}`);
        if (delShop.status === 204) S = "";
        check("its orders are gone", (await call("GET", `/orders/${order.data?.id}`, member.token)).status === 404);
        check("its items are gone", (await call("GET", `/shop-items/${item?.id}`)).status === 404);

        const delGym = await call("DELETE", `/businesses/${G}`, T.token);
        check("owner deletes the gym", delGym.status === 204, `status ${delGym.status} ${short(delGym.data)}`);
        const gymId = G;
        if (delGym.status === 204) G = "";
        check("the gym is gone", (await call("GET", `/businesses/${gymId}`, T.token)).status === 404);
        check("its members are gone", ((await call("GET", `/members?gym_id=${gymId}`, T.token)).data as any[]).length === 0);
        check("its memberships are gone", (await call("GET", `/memberships/${msId}`, member.token)).status === 404);
        check("its invoices are gone", (await call("GET", `/membership-invoices/${invId}`, member.token)).status === 404);
        check("its staff are gone", ((await call("GET", `/trainers?gym_id=${gymId}`, T.token)).data as any[]).length === 0);
        check("staff role is reconciled", (await roleOf(U.profile.id)) === "member");
        const stats = await call("GET", "/businesses/stats", T.token);
        check("owner with no gyms has empty stats", stats.status === 200 && stats.data.gyms === 0, short(stats.data));
        assertAll();
      });
    } finally {
      for (const id of [S, G]) if (id) await call("DELETE", `/businesses/${id}`, T.token);
      // Every notice the flow sent names the throwaway gym/shop, so the tag finds them.
      const mentionsTag = (n: any) => `${n.title} ${n.body}`.includes(tag);
      await deleteNotifications(member.token, mentionsTag);
      await deleteNotifications(vendor.token, mentionsTag);
      await deleteNotificationsWhere("user_id", [T.profile.id, U.profile.id]);
      await sql(`DELETE FROM notification WHERE title LIKE $1 OR body LIKE $1`, [`%${tag}%`]);
      for (const id of [T.profile.id, U.profile.id]) {
        const del = await call("DELETE", `/users/${id}`, superU.token);
        if (del.status !== 204) console.warn(`couldn't delete throwaway user ${id}: ${del.status} ${short(del.data)}`);
      }
    }
  },
});
