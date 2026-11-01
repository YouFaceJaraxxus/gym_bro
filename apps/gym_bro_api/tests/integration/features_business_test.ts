// deno-lint-ignore-file no-explicit-any
// Businesses and the people in them: applying for a business (pending) and
// the super user's review (reject → resubmit → approve), profile edits and
// the gym/shop sides, team invites (accept / decline, by notification or by
// the business's invite route), what owners, staff and trainers may each do,
// "Owner of" / "Trainer at" on profiles, follows, leaving the team (the last
// owner can't), switching trainer mode on and off, gym members, isolation
// from another gym, and the delete cascade.
//
// Everything happens in a throwaway gym (G) + shop (S) applied for by a
// throwaway owner (T), with two more throwaway accounts: U (staff) and W
// (trainer). Both businesses are deleted through the API (which also checks
// the cascade), the three accounts are deleted by the super user, and
// notifications the flow sent to seeded users are removed in `finally`.
import { call, checker, dayFromToday, deleteNotifications, notificationsOf, type Session, seededUsers, short, signin, suite } from "./_client.ts";
import { dbAvailable, deleteNotificationsWhere, sql } from "./_db.ts";

const uid = () => crypto.randomUUID().slice(0, 8);

Deno.test({
  name: "features: businesses, review, team roles, members",
  ...suite,
  async fn(t) {
    const { check, assertAll } = checker();
    const { member, owner, employee, superU, vendor, gym } = await seededUsers();

    const tag = uid();
    const pw = `pw-${crypto.randomUUID()}`;
    const mk = (who: string) =>
      call("POST", "/users/signup", superU.token, {
        email: `it-${who}-${tag}@example.com`, password: pw, username: `it${who}${tag}`, name: "IT", last_name: who,
      });
    const created = await Promise.all([mk("owner"), mk("staff"), mk("coach")]);
    if (created.some((r) => r.status !== 201)) throw new Error(`throwaway signup: ${created.map((r) => short(r.data)).join(" ")}`);
    const [T, U, W] = await Promise.all([
      signin(`it-owner-${tag}@example.com`, pw),
      signin(`it-staff-${tag}@example.com`, pw),
      signin(`it-coach-${tag}@example.com`, pw),
    ]);

    const me = async (s: Session) => (await call("GET", "/users/me", s.token)).data;
    const rolesAt = async (s: Session, businessId: string): Promise<string[]> =>
      ((await me(s))?.businesses as any[] ?? []).find((b) => b.id === businessId)?.roles ?? [];
    const profileOf = async (id: string, viewer = member) => (await call("GET", `/social/users/${id}`, viewer.token)).data;
    const pendingInvite = async (s: Session, businessId: string, role: string) =>
      (await notificationsOf(s.token)).find((n) =>
        n.type === "business_invite" && n.metadata?.business_id === businessId && n.metadata?.role === role &&
        n.metadata?.invite_status === "pending"
      );
    const ids = (rows: any[] | undefined) => (rows ?? []).map((r) => r.id);

    let G = "";
    let S = "";
    let superBiz = "";
    const everCreated: string[] = []; // for the audit-log cleanup
    try {
      await t.step("1. applying: create (pending), validate, review (reject → resubmit → approve)", async () => {
        const base = { location: "Test St 1", working_hours_from: "06:00", working_hours_to: "22:00", working_weekdays: [1, 2, 3, 4, 5] };
        const missing = await call("POST", "/businesses", T.token, { name: `it-${tag}`, has_gym: true });
        check("create without hours/location is 400", missing.status === 400, `status ${missing.status}`);
        const noSide = await call("POST", "/businesses", T.token, { ...base, name: `it-${tag}` });
        check("create that is neither a gym nor a shop is 400", noSide.status === 400, `status ${noSide.status}`);
        const badType = await call("POST", "/businesses", T.token, { ...base, name: `it-${tag}`, type: "spa" });
        check("create with an unknown type is 400", badType.status === 400, `status ${badType.status}`);
        const badSite = await call("POST", "/businesses", T.token, { ...base, name: `it-${tag}`, has_gym: true, website: "ftp://x" });
        check("create with a non-http website is 400", badSite.status === 400, `status ${badSite.status}`);

        const g = await call("POST", "/businesses", T.token, {
          ...base, name: `it-gym-${tag}`, has_gym: true, latitude: 44.8, longitude: 20.4, bio: "Test gym", website: "https://gym.example.com",
        });
        G = g.data?.id ?? "";
        everCreated.push(G);
        check(
          "anyone can apply for a gym: it starts pending, with them as owner",
          g.status === 201 && g.data.status === "pending" && g.data.has_gym === true && g.data.has_shop === false &&
            Number(g.data.latitude) === 44.8 && g.data.bio === "Test gym" && JSON.stringify(g.data.my_roles) === JSON.stringify(["owner"]) &&
            ids(g.data.owners).join() === T.profile.id && g.data.is_following === true,
          short(g.data),
        );
        const s = await call("POST", "/businesses", T.token, { ...base, name: `it-shop-${tag}`, type: "shop", latitude: "x" });
        S = s.data?.id ?? "";
        everCreated.push(S);
        check(
          "`type` still picks one side (non-numeric latitude dropped)",
          s.status === 201 && s.data.status === "pending" && s.data.has_shop === true && s.data.has_gym === false && s.data.latitude === null,
          short(s.data),
        );
        assertAll();

        // While pending: only the team and super users see it, and owner tools wait.
        const hidden = await call("GET", `/businesses/${G}`, member.token);
        check("a pending business is hidden from everyone else (404)", hidden.status === 404, `status ${hidden.status}`);
        const asSuper = await call("GET", `/businesses/${G}`, superU.token);
        check("super user sees it", asSuper.status === 200 && asSuper.data.status === "pending", `status ${asSuper.status}`);
        const search = await call("GET", `/businesses/search?q=${tag}`, member.token);
        check("search leaves pending businesses out", search.status === 200 && (search.data as any[]).length === 0, short(search.data));
        const myList = await call("GET", "/businesses", T.token);
        check(
          "the owner lists their applications with status",
          myList.status === 200 && ids(myList.data).sort().join() === [G, S].sort().join() &&
            (myList.data as any[]).every((b) => b.status === "pending" && JSON.stringify(b.my_roles) === JSON.stringify(["owner"])),
          short(myList.data),
        );
        const tMe = await me(T);
        check("…and so does their profile (Home menu)", (tMe?.businesses as any[])?.some((b) => b.id === G && b.status === "pending"), short(tMe?.businesses));
        const followPending = await call("PUT", `/businesses/${G}/follow`, member.token);
        check("a pending business can't be followed (404)", followPending.status === 404, `status ${followPending.status}`);
        for (
          const [what, r] of [
            ["set prices", await call("POST", "/gym-membership-types", T.token, { name: "x", monthly_cost: 1, gym_id: G })],
            ["invite a team", await call("POST", `/businesses/${G}/team`, T.token, { user_id: U.profile.id, role: "staff" })],
            ["add members", await call("POST", "/members", T.token, { gym_id: G, user_id: member.profile.id })],
            ["post as the gym", await call("POST", "/posts", T.token, { business_id: G, content: "hello" })],
            ["sell in the shop", await call("POST", "/shop-items", T.token, { shop_id: S, type: "equipment", name: "x", price: 1, quantity: 1 })],
          ] as const
        ) check(`owner can't ${what} while pending`, r.status === 403, `status ${r.status}`);
        const fix = await call("PUT", `/businesses/${G}`, T.token, { phone: "+1 555 0100" });
        check("…but can fix the profile before review", fix.status === 200 && fix.data.phone === "+1 555 0100", short(fix.data));
        const tProfile = await profileOf(T.profile.id);
        check("a pending business isn't shown as 'Owner of'", (tProfile?.owner_of as any[])?.length === 0, short(tProfile?.owner_of));

        // The review queue.
        const queueDenied = await call("GET", "/businesses/review", T.token);
        check("only super users see the review queue", queueDenied.status === 403, `status ${queueDenied.status}`);
        const queue = await call("GET", "/businesses/review", superU.token);
        const row = (queue.data as any[])?.find((b) => b.id === G);
        check(
          "the queue lists the application with its applicant",
          queue.status === 200 && row?.applicant_id === T.profile.id && row?.applicant_email === `it-owner-${tag}@example.com`,
          short(row),
        );
        const badQueue = await call("GET", "/businesses/review?status=nope", superU.token);
        check("unknown queue status is 400", badQueue.status === 400, `status ${badQueue.status}`);
        const review = (body: unknown, s: Session = superU, id = G) => call("POST", `/businesses/${id}/review`, s.token, body);
        check("an owner can't review their own business", (await review({ status: "approved" }, T)).status === 403);
        check("review to an unknown status is 400", (await review({ status: "pending" })).status === 400);
        check("rejecting without a note is 400", (await review({ status: "rejected" })).status === 400);
        const rejected = await review({ status: "rejected", note: `Add a phone number ${tag}` });
        check("super user rejects with a note", rejected.status === 200 && rejected.data.status === "rejected", short(rejected.data));
        const toldNo = (await notificationsOf(T.token)).find((n) => n.type === "business_review" && n.metadata?.business_id === G);
        check("the owner is told why", toldNo?.metadata?.status === "rejected" && String(toldNo?.body).includes(tag), short(toldNo));
        const seenByOwner = await call("GET", `/businesses/${G}`, T.token);
        check("the owner sees the review note", seenByOwner.data?.review_note === `Add a phone number ${tag}`, short(seenByOwner.data));
        check("someone else can't resubmit", (await call("POST", `/businesses/${G}/resubmit`, member.token)).status === 403);
        const resubmit = await call("POST", `/businesses/${G}/resubmit`, T.token);
        check("the owner resubmits it (pending again)", resubmit.status === 200 && resubmit.data.status === "pending", short(resubmit.data));
        const again = await call("POST", `/businesses/${G}/resubmit`, T.token);
        check("only a rejected business can be resubmitted (409)", again.status === 409, `status ${again.status}`);
        const approved = await review({ status: "approved" });
        const approvedS = await review({ status: "approved" }, superU, S);
        check("super user approves both", approved.data?.status === "approved" && approvedS.data?.status === "approved", `${short(approved.data)} ${short(approvedS.data)}`);
        const toldYes = (await notificationsOf(T.token)).filter((n) => n.type === "business_review" && n.metadata?.status === "approved");
        check("the owner is told each is approved", [G, S].every((id) => toldYes.some((n) => n.metadata.business_id === id)), `n=${toldYes.length}`);

        const sup = await call("POST", "/businesses", superU.token, { ...base, name: `it-super-${tag}`, has_shop: true });
        superBiz = sup.data?.id ?? "";
        everCreated.push(superBiz);
        check("a super user's business is approved straight away", sup.status === 201 && sup.data.status === "approved", short(sup.data));
        if (superBiz && (await call("DELETE", `/businesses/${superBiz}`, superU.token)).status === 204) superBiz = "";
        assertAll();
      });

      await t.step("2. businesses once approved: list, search, read, update, authz, stats", async () => {
        const gymsOnly = await call("GET", "/businesses?side=gym", T.token);
        check("?side=gym filters", gymsOnly.status === 200 && ids(gymsOnly.data).join() === G, short(gymsOnly.data));
        const shopsOnly = await call("GET", "/businesses?type=shop", T.token);
        check("?type=shop still filters", shopsOnly.status === 200 && ids(shopsOnly.data).join() === S, short(shopsOnly.data));
        const memberList = await call("GET", "/businesses", member.token);
        check("a member on no team gets []", memberList.status === 200 && (memberList.data as any[]).length === 0, short(memberList.data));
        const found = await call("GET", "/businesses/search?side=gym&limit=50", member.token);
        check(
          "search finds approved gyms only",
          found.status === 200 && [G, gym.id].every((id) => ids(found.data).includes(id)) && !ids(found.data).includes(S) &&
            (found.data as any[]).every((b) => b.has_gym && b.status === "approved"),
          `status ${found.status}`,
        );

        const read = await call("GET", `/businesses/${G}`, member.token);
        check(
          "any signed-in user reads an approved business (no review note)",
          read.status === 200 && read.data.name === `it-gym-${tag}` && read.data.follower_count === 1 && read.data.is_following === false &&
            !("review_note" in read.data) && JSON.stringify(read.data.my_roles) === "[]",
          short(read.data),
        );
        check("anonymous read is 401", (await call("GET", `/businesses/${G}`)).status === 401);
        check("unknown business is 404", (await call("GET", `/businesses/${crypto.randomUUID()}`, member.token)).status === 404);

        const upd = await call("PUT", `/businesses/${G}`, T.token, { name: `it-gym2-${tag}`, working_hours_to: "23:00", website: "" });
        check(
          "owner updates the gym (empty website clears it)",
          upd.status === 200 && upd.data.name === `it-gym2-${tag}` && upd.data.working_hours_to.startsWith("23:00") && upd.data.website === null,
          short(upd.data),
        );
        check("a 501-character bio is 400", (await call("PUT", `/businesses/${G}`, T.token, { bio: "x".repeat(501) })).status === 400);
        check("an empty name is 400", (await call("PUT", `/businesses/${G}`, T.token, { name: " " })).status === 400);
        check("empty update is 400", (await call("PUT", `/businesses/${G}`, T.token, {})).status === 400);
        for (const [who, s] of [["member", member], ["another gym's owner", owner], ["another gym's staff", employee]] as const) {
          const r = await call("PUT", `/businesses/${G}`, s.token, { name: "hijack" });
          check(`${who} can't update the gym`, r.status === 403, `status ${r.status}`);
        }
        check("updating an unknown business is 404", (await call("PUT", `/businesses/${crypto.randomUUID()}`, T.token, { name: "x" })).status === 404);
        const superUpd = await call("PUT", `/businesses/${S}`, superU.token, { location: "Super St 2" });
        check("super user updates any business", superUpd.status === 200 && superUpd.data.location === "Super St 2", short(superUpd.data));
        check("deleting an unknown business is 404", (await call("DELETE", `/businesses/${crypto.randomUUID()}`, T.token)).status === 404);
        check("another gym's owner can't delete the gym", (await call("DELETE", `/businesses/${G}`, owner.token)).status === 403);

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

      await t.step("3. sides: the owner turns the gym and shop on and off (at least one)", async () => {
        const both = await call("PUT", `/businesses/${G}`, T.token, { has_shop: true });
        check("owner adds a shop to the gym", both.status === 200 && both.data.has_gym && both.data.has_shop, short(both.data));
        const item = await call("POST", "/shop-items", T.token, { shop_id: G, type: "equipment", name: `it-side-${tag}`, price: 1, quantity: 1 });
        check("…and sells there", item.status === 201, short(item.data));
        if (item.data?.id) await call("DELETE", `/shop-items/${item.data.id}`, T.token);
        const none = await call("PUT", `/businesses/${G}`, T.token, { has_gym: false, has_shop: false });
        check("turning both off is 400", none.status === 400, `status ${none.status}`);
        const shopOnly = await call("PUT", `/businesses/${G}`, T.token, { has_gym: false });
        check("owner turns the gym side off", shopOnly.status === 200 && !shopOnly.data.has_gym && shopOnly.data.has_shop, short(shopOnly.data));
        const noGym = await call("POST", "/gym-membership-types", T.token, { name: "x", monthly_cost: 1, gym_id: G });
        check("gym tools stop working without the gym side", noGym.status === 403, `status ${noGym.status}`);
        const back = await call("PUT", `/businesses/${G}`, T.token, { has_gym: true, has_shop: false });
        check("and back to just a gym", back.status === 200 && back.data.has_gym && !back.data.has_shop, short(back.data));
        const other = await call("PUT", `/businesses/${G}`, owner.token, { has_shop: true });
        check("another business's owner can't switch sides", other.status === 403, `status ${other.status}`);
        assertAll();
      });

      await t.step("4. team invites: validate, decline, accept (notification or invite route)", async () => {
        const invite = (b: Record<string, unknown>, s: Session = T, id = G) => call("POST", `/businesses/${id}/team`, s.token, b);
        check("an unknown role is 400", (await invite({ user_id: U.profile.id, role: "manager" })).status === 400);
        check("a missing role is 400", (await invite({ user_id: U.profile.id })).status === 400);
        check("neither user_id nor email is 400", (await invite({ role: "staff" })).status === 400);
        check("unknown user_id is 404", (await invite({ user_id: crypto.randomUUID(), role: "staff" })).status === 404);
        check("malformed user_id is 404", (await invite({ user_id: "nope", role: "staff" })).status === 404);
        check("unknown business is 404", (await invite({ user_id: U.profile.id, role: "staff" }, T, crypto.randomUUID())).status === 404);
        // New-account branch, stopped before any invite email goes out.
        check("new email without names is 400", (await invite({ role: "staff", email: `it-nobody-${tag}@example.com` })).status === 400);
        check(
          "new email with a taken username is 409",
          (await invite({ role: "staff", email: `it-nobody-${tag}@example.com`, name: "N", last_name: "B", username: member.profile.username })).status === 409,
        );
        for (const [who, s] of [["member", member], ["another gym's owner", owner], ["another gym's staff", employee]] as const) {
          check(`${who} can't invite to the gym`, (await invite({ user_id: U.profile.id, role: "staff" }, s)).status === 403);
        }

        // U: invited as staff → declines → invited again → accepts from the notification.
        const inv1 = await invite({ user_id: U.profile.id, role: "staff" });
        check("owner invites an existing user as staff", inv1.status === 201 && inv1.data.invited === true && inv1.data.role === "staff", short(inv1.data));
        const n1 = await pendingInvite(U, G, "staff");
        check("the invitee gets a business_invite", !!n1 && n1.metadata.inviter_id === T.profile.id && n1.title.includes(tag), short(n1));
        const listed = await call("GET", "/businesses/invites", U.token);
        check(
          "…listed under their invites, and counted on their profile",
          (listed.data as any[])?.some((i) => i.business_id === G && i.role === "staff" && i.inviter_id === T.profile.id) &&
            (await me(U))?.pending_invites === 1,
          short(listed.data),
        );
        check("an open invite grants nothing", (await call("POST", "/members", U.token, { gym_id: G, user_id: member.profile.id })).status === 403);
        check("…not even the team list", (await call("GET", `/businesses/${G}/team`, U.token)).status === 403);
        const ownerTeam = await call("GET", `/businesses/${G}/team`, T.token);
        const uEntry = (ownerTeam.data as any[])?.find((p) => p.user_id === U.profile.id);
        check("the owner sees the open invite on the team", uEntry?.roles?.[0]?.role === "staff" && uEntry.roles[0].status === "invited" && !!uEntry.email, short(uEntry));
        check("inviting again while it's open is 409", (await invite({ user_id: U.profile.id, role: "staff" })).status === 409);
        check("someone else can't accept it", (await call("POST", `/notifications/${n1?.id}/accept`, member.token)).status === 403);
        const decline = await call("POST", `/businesses/${G}/invites/staff/decline`, U.token);
        check("the invitee declines from the business's invite route", decline.status === 200 && JSON.stringify(decline.data.my_roles) === "[]", short(decline.data));
        const n1After = (await notificationsOf(U.token)).find((n) => n.id === n1?.id);
        check("…which marks the notification declined", n1After?.metadata?.invite_status === "declined", short(n1After));
        check("…and leaves no invite behind", ((await call("GET", "/businesses/invites", U.token)).data as any[]).length === 0);
        check("a declined invite can't be accepted (404)", (await call("POST", `/businesses/${G}/invites/staff/accept`, U.token)).status === 404);

        await invite({ user_id: U.profile.id, role: "staff" });
        const n2 = await pendingInvite(U, G, "staff");
        const accept = await call("POST", `/notifications/${n2?.id}/accept`, U.token);
        check("the invitee accepts from the notification", accept.status === 200 && accept.data.metadata?.invite_status === "accepted", short(accept.data));
        const joined = (await notificationsOf(T.token)).find((n) => n.type === "business_join" && n.metadata?.user_id === U.profile.id);
        check("the owner is told they joined", joined?.metadata?.business_id === G && joined.metadata.role === "staff", short(joined));
        const uMe = await me(U);
        check(
          "they're active staff (and not a trainer)",
          JSON.stringify(await rolesAt(U, G)) === JSON.stringify(["staff"]) && uMe?.is_trainer === false && uMe?.pending_invites === 0,
          short(uMe),
        );
        check("inviting someone to a role they hold is 409", (await invite({ user_id: U.profile.id, role: "staff" })).status === 409);
        check("joining follows the business", (await call("GET", `/businesses/${G}`, U.token)).data?.is_following === true);

        // A trainer invite U turns down: no trainer flag.
        await invite({ user_id: U.profile.id, role: "trainer" });
        const n3 = await pendingInvite(U, G, "trainer");
        const declineN = await call("POST", `/notifications/${n3?.id}/decline`, U.token);
        check("declining a trainer invite from the notification", declineN.status === 200 && declineN.data.metadata?.invite_status === "declined", short(declineN.data));
        check("…leaves them staff only, not a trainer", JSON.stringify(await rolesAt(U, G)) === JSON.stringify(["staff"]) && (await me(U))?.is_trainer === false);

        // W: invited as a trainer and accepts from the business's invite route.
        await invite({ user_id: W.profile.id, role: "trainer" });
        const wAccept = await call("POST", `/businesses/${G}/invites/trainer/accept`, W.token);
        check("a trainer invite accepted from the invite route", wAccept.status === 200 && JSON.stringify(wAccept.data.my_roles) === JSON.stringify(["trainer"]), short(wAccept.data));
        check("accepting a trainer role makes them a trainer", (await me(W))?.is_trainer === true);
        const wNote = (await notificationsOf(W.token)).find((n) => n.type === "business_invite" && n.metadata?.business_id === G);
        check("…and marks its notification accepted", wNote?.metadata?.invite_status === "accepted", short(wNote));
        check("accepting twice is 404 (nothing open)", (await call("POST", `/businesses/${G}/invites/trainer/accept`, W.token)).status === 404);
        check("an unknown role in the invite route is 404", (await call("POST", `/businesses/${G}/invites/boss/accept`, W.token)).status === 404);

        // The owner coaches too: adding yourself needs no invite.
        const self = await invite({ user_id: T.profile.id, role: "trainer" });
        check("an owner adds themselves as a trainer straight away", self.status === 201 && self.data.invited === false, short(self.data));
        check("…holding both roles", JSON.stringify(await rolesAt(T, G)) === JSON.stringify(["owner", "trainer"]) && (await me(T))?.is_trainer === true);
        check("adding an owner as owner again is 409", (await invite({ user_id: T.profile.id, role: "owner" })).status === 409);
        assertAll();
      });

      await t.step("5. permission tiers: owner vs staff vs trainer", async () => {
        // Staff (U): front desk and profile, not management.
        const staffBio = await call("PUT", `/businesses/${G}`, U.token, { bio: `Edited by staff ${tag}` });
        check("staff edit the profile", staffBio.status === 200 && staffBio.data.bio === `Edited by staff ${tag}`, short(staffBio.data));
        const addMember = await call("POST", "/members", U.token, { gym_id: G, user_id: member.profile.id });
        check("staff add a member", addMember.status === 201 && addMember.data.gym_id === G, short(addMember.data));
        const welcome = (await notificationsOf(member.token)).find((n) => n.type === "member_join" && n.metadata?.gym_id === G);
        check("the new member gets a welcome notification", !!welcome, short(welcome));
        const ownerJoin = (await notificationsOf(T.token)).find((n) => n.type === "member_join" && n.metadata?.user_id === member.profile.id);
        check("the owner is told about the new member", ownerJoin?.metadata?.gym_id === G, short(ownerJoin));
        const staffRoster = await call("GET", `/members?gym_id=${G}`, U.token);
        check("staff see member emails", (staffRoster.data as any[])?.some((m) => m.user_id === member.profile.id && m.email), short(staffRoster.data));
        const staffTeam = await call("GET", `/businesses/${G}/team`, U.token);
        check("staff see the whole team with emails", staffTeam.status === 200 && (staffTeam.data as any[]).every((p) => typeof p.email === "string"), short(staffTeam.data));
        const staffPost = await call("POST", "/posts", U.token, { business_id: G, content: `Staff post ${tag}` });
        check("staff post as the gym", staffPost.status === 201, short(staffPost.data));
        if (staffPost.data?.id) await call("DELETE", `/posts/${staffPost.data.id}`, U.token);
        for (
          const [what, r] of [
            ["switch sides", await call("PUT", `/businesses/${G}`, U.token, { has_shop: true })],
            ["invite", await call("POST", `/businesses/${G}/team`, U.token, { user_id: member.profile.id, role: "staff" })],
            ["remove a trainer", await call("DELETE", `/businesses/${G}/team/${W.profile.id}?role=trainer`, U.token)],
            ["set prices", await call("POST", "/gym-membership-types", U.token, { name: "x", monthly_cost: 1, gym_id: G })],
            ["delete the gym", await call("DELETE", `/businesses/${G}`, U.token)],
            ["review it", await call("POST", `/businesses/${G}/review`, U.token, { status: "approved" })],
            ["add members at another gym", await call("POST", "/members", U.token, { gym_id: gym.id, user_id: vendor.profile.id })],
          ] as const
        ) check(`staff can't ${what}`, r.status === 403, `status ${r.status}`);
        check("staff get no owner stats", (await call("GET", "/businesses/stats", U.token)).data?.gyms === 0);

        // Trainer (W): posts and coaching, not the profile or the front desk.
        const trainerPost = await call("POST", "/posts", W.token, { business_id: G, content: `Trainer post ${tag}` });
        check("trainers post as the gym", trainerPost.status === 201, short(trainerPost.data));
        if (trainerPost.data?.id) await call("DELETE", `/posts/${trainerPost.data.id}`, W.token);
        const coachRoster = await call("GET", `/members?gym_id=${G}`, W.token);
        check("trainers see member emails (to coach them)", (coachRoster.data as any[])?.some((m) => m.user_id === member.profile.id && m.email), short(coachRoster.data));
        const trainerTeam = await call("GET", `/businesses/${G}/team`, W.token);
        check(
          "trainers see the active team without emails",
          trainerTeam.status === 200 && (trainerTeam.data as any[]).every((p) => !("email" in p) && p.roles.every((r: any) => r.status === "active")),
          short(trainerTeam.data),
        );
        for (
          const [what, r] of [
            ["edit the profile", await call("PUT", `/businesses/${G}`, W.token, { bio: "x" })],
            ["add members", await call("POST", "/members", W.token, { gym_id: G, user_id: vendor.profile.id })],
            ["invite", await call("POST", `/businesses/${G}/team`, W.token, { user_id: member.profile.id, role: "trainer" })],
            ["set prices", await call("POST", "/gym-membership-types", W.token, { name: "x", monthly_cost: 1, gym_id: G })],
          ] as const
        ) check(`trainers can't ${what}`, r.status === 403, `status ${r.status}`);

        // Owner (T): pricing, which staff can't.
        const price = await call("POST", "/gym-membership-types", T.token, { name: `it-tier-${tag}`, monthly_cost: 1, gym_id: G });
        check("the owner sets prices", price.status === 201, short(price.data));
        if (price.data?.id) await call("DELETE", `/gym-membership-types/${price.data.id}`, T.token);
        assertAll();
      });

      await t.step("6. profiles: Owner of / Trainer at (staff never shown), follows", async () => {
        const tP = await profileOf(T.profile.id);
        check(
          "the owner's profile: owner of G and trainer at G",
          tP?.is_trainer === true && ids(tP.owner_of).includes(G) && ids(tP.trainer_at).includes(G) && !("role" in tP),
          short({ owner_of: tP?.owner_of, trainer_at: tP?.trainer_at }),
        );
        const uP = await profileOf(U.profile.id);
        check("staff aren't shown anywhere", uP?.is_trainer === false && uP.owner_of.length === 0 && uP.trainer_at.length === 0, short(uP));
        const wP = await profileOf(W.profile.id);
        check("the trainer's profile: trainer at G", wP?.is_trainer === true && ids(wP.trainer_at).join() === G && wP.owner_of.length === 0, short(wP?.trainer_at));
        const biz = await call("GET", `/businesses/${G}`, member.token);
        check(
          "the business lists owners and trainers, not staff",
          ids(biz.data?.owners).join() === T.profile.id && [T.profile.id, W.profile.id].every((id) => ids(biz.data?.trainers).includes(id)) &&
            !ids(biz.data?.trainers).includes(U.profile.id),
          short({ owners: biz.data?.owners, trainers: biz.data?.trainers }),
        );

        // Seeded people: Andrew owns and coaches at Coastal; Priya is staff (not shown).
        const andrew = await signin("andrew.foster@example.com");
        const aP = await profileOf(andrew.profile.id);
        check(
          "seeded owner who also coaches",
          aP?.owner_of?.some((b: any) => b.name === "Coastal Barbell Club" && b.has_gym && b.has_shop) &&
            aP?.trainer_at?.some((b: any) => b.name === "Coastal Barbell Club"),
          short({ owner_of: aP?.owner_of, trainer_at: aP?.trainer_at }),
        );
        const marcusP = await profileOf(owner.profile.id);
        check("seeded owner of a gym and a shop", marcusP?.owner_of?.length === 2 && marcusP.trainer_at.length === 0, short(marcusP?.owner_of));
        const priyaP = await profileOf(employee.profile.id);
        check("seeded staff show no affiliation", priyaP?.owner_of?.length === 0 && priyaP.trainer_at.length === 0 && priyaP.is_trainer === false, short(priyaP));

        // Following.
        const before = (await call("GET", `/businesses/${G}`, vendor.token)).data;
        const follow = await call("PUT", `/businesses/${G}/follow`, vendor.token);
        check("anyone follows an approved business", follow.status === 200 && follow.data.is_following === true, short(follow.data));
        const twice = await call("PUT", `/businesses/${G}/follow`, vendor.token);
        const after = (await call("GET", `/businesses/${G}`, vendor.token)).data;
        check(
          "following is idempotent and counted",
          twice.status === 200 && after?.is_following === true && after.follower_count === before.follower_count + 1,
          `${before?.follower_count} → ${after?.follower_count}`,
        );
        const unfollow = await call("DELETE", `/businesses/${G}/follow`, vendor.token);
        const gone = (await call("GET", `/businesses/${G}`, vendor.token)).data;
        check("unfollow", unfollow.status === 200 && unfollow.data.is_following === false && gone?.follower_count === before.follower_count, short(gone));
        check("following an unknown business is 404", (await call("PUT", `/businesses/${crypto.randomUUID()}/follow`, vendor.token)).status === 404);
        assertAll();
      });

      await t.step("7. leaving the team: the last owner can't; owners remove and cancel", async () => {
        const leave = (who: Session, userId: string, role?: string) =>
          call("DELETE", `/businesses/${G}/team/${userId}${role ? `?role=${role}` : ""}`, who.token);
        const last = await leave(T, T.profile.id, "owner");
        check("the last owner can't leave (409)", last.status === 409, `status ${last.status} ${short(last.data)}`);
        check("…not even by leaving every role", (await leave(T, T.profile.id)).status === 409);
        check("an unknown ?role= is 400", (await leave(T, U.profile.id, "boss")).status === 400);

        // U becomes a co-owner, then steps down again.
        await call("POST", `/businesses/${G}/team`, T.token, { user_id: U.profile.id, role: "owner" });
        await call("POST", `/businesses/${G}/invites/owner/accept`, U.token);
        check("a co-owner holds owner and staff", JSON.stringify(await rolesAt(U, G)) === JSON.stringify(["owner", "staff"]));
        const coPrice = await call("POST", "/gym-membership-types", U.token, { name: `it-co-${tag}`, monthly_cost: 1, gym_id: G });
        check("a co-owner manages pricing", coPrice.status === 201, short(coPrice.data));
        if (coPrice.data?.id) await call("DELETE", `/gym-membership-types/${coPrice.data.id}`, U.token);
        const stepDown = await leave(U, U.profile.id, "owner");
        check("with another owner, an owner can step down", stepDown.status === 204, `status ${stepDown.status}`);
        check("…keeping their other roles", JSON.stringify(await rolesAt(U, G)) === JSON.stringify(["staff"]));

        // W leaves on their own.
        const wLeaves = await leave(W, W.profile.id, "trainer");
        check("a trainer leaves the gym", wLeaves.status === 204, `status ${wLeaves.status}`);
        const wP = await profileOf(W.profile.id);
        check("…which drops 'Trainer at', not trainer mode", wP?.trainer_at?.length === 0 && wP.is_trainer === true, short(wP));
        check("leaving again is 404", (await leave(W, W.profile.id, "trainer")).status === 404);

        // The owner cancels an open invite; the notification then can't be accepted.
        await call("POST", `/businesses/${G}/team`, T.token, { user_id: W.profile.id, role: "staff" });
        const wInvite = await pendingInvite(W, G, "staff");
        const cancel = await leave(T, W.profile.id, "staff");
        check("the owner cancels an invite", cancel.status === 204 && ((await call("GET", "/businesses/invites", W.token)).data as any[]).length === 0, `status ${cancel.status}`);
        const stale = await call("POST", `/notifications/${wInvite?.id}/accept`, W.token);
        check("its notification can't be accepted any more (409)", stale.status === 409, `status ${stale.status} ${short(stale.data)}`);

        // The owner removes U's staff role.
        const fire = await leave(T, U.profile.id, "staff");
        check("the owner removes a staff member", fire.status === 204, `status ${fire.status}`);
        check("…who loses front-desk access", (await call("POST", "/members", U.token, { gym_id: G, user_id: vendor.profile.id })).status === 403);
        check("…and the team list", (await call("GET", `/businesses/${G}/team`, U.token)).status === 403);
        check("removing again is 404", (await leave(T, U.profile.id, "staff")).status === 404);
        assertAll();
      });

      await t.step("8. trainer mode: PUT /users/me/trainer", async () => {
        check("it needs a session", (await call("PUT", "/users/me/trainer", undefined, { enabled: true })).status === 401);
        check("enabled is required", (await call("PUT", "/users/me/trainer", U.token, {})).status === 400);
        check("enabled must be a boolean", (await call("PUT", "/users/me/trainer", U.token, { enabled: "yes" })).status === 400);
        const on = await call("PUT", "/users/me/trainer", U.token, { enabled: true });
        check("anyone can become a trainer, no gym needed", on.status === 200 && on.data.is_trainer === true && Array.isArray(on.data.businesses), short(on.data));
        const uP = await profileOf(U.profile.id);
        check("…shown on their profile", uP?.is_trainer === true && uP.trainer_at.length === 0, short(uP));
        const off = await call("PUT", "/users/me/trainer", U.token, { enabled: false });
        check("…and switch it off again", off.status === 200 && off.data.is_trainer === false, short(off.data));

        // Switching off also leaves every gym they train at.
        await call("POST", `/businesses/${G}/team`, T.token, { user_id: W.profile.id, role: "trainer" });
        await call("POST", `/businesses/${G}/invites/trainer/accept`, W.token);
        check("W trains at G again", JSON.stringify(await rolesAt(W, G)) === JSON.stringify(["trainer"]));
        const wOff = await call("PUT", "/users/me/trainer", W.token, { enabled: false });
        check("switching trainer mode off", wOff.status === 200 && wOff.data.is_trainer === false, short(wOff.data));
        const biz = await call("GET", `/businesses/${G}`, member.token);
        check("…drops their trainer roles", !ids(biz.data?.trainers).includes(W.profile.id) && (await rolesAt(W, G)).length === 0, short(biz.data?.trainers));
        assertAll();
      });

      await t.step("9. members: add by id/email, validation, roster, resend-invite, removal, stats", async () => {
        const m = (b: Record<string, unknown>, s: Session = T) => call("POST", "/members", s.token, b);
        check("member without gym_id is 400", (await m({ user_id: vendor.profile.id })).status === 400);
        check("member of an unknown gym is 404", (await m({ user_id: vendor.profile.id, gym_id: crypto.randomUUID() })).status === 404);
        check("member can't add members", (await m({ user_id: vendor.profile.id, gym_id: G }, member)).status === 403);
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
        check("being a member gives no team role", (await rolesAt(vendor, G)).length === 0);

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
        const liamP = await profileOf(member.profile.id, T);
        check("their profile lists the gyms they're a member of", ids(liamP?.gyms).includes(G) && ids(liamP?.gyms).includes(gym.id), short(liamP?.gyms));
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

      await t.step("10. gym isolation: the team of one gym can't touch another", async () => {
        const typeId = ((await call("GET", `/gym-membership-types?gym_id=${G}`, T.token)).data as any[])[0]?.id;
        const msId = ((await call("GET", `/memberships?gym_id=${G}`, T.token)).data as any[])[0]?.id;
        const invId = ((await call("GET", `/membership-invoices?gym_id=${G}`, T.token)).data as any[])[0]?.id;
        const liamRowG = ((await call("GET", `/members?gym_id=${G}`, T.token)).data as any[]).find((r) => r.user_id === member.profile.id);
        const ironRoster = (await call("GET", `/members?gym_id=${gym.id}`, owner.token)).data as any[];
        const ironMember = ironRoster.find((r) => r.user_id === member.profile.id);
        const ironTeam = (await call("GET", `/businesses/${gym.id}/team`, owner.token)).data as any[];
        const hasRole = (p: any, role: string) => p.roles.some((r: any) => r.role === role && r.status === "active");
        const ironStaff = ironTeam?.find((p) => hasRole(p, "staff"));
        const ironTrainer = ironTeam?.find((p) => hasRole(p, "trainer"));
        check("fixtures found", !!(typeId && msId && invId && liamRowG && ironMember && ironStaff && ironTrainer));
        assertAll();

        const denied: [string, Promise<{ status: number }>][] = [
          // Ironclad's owner and staff against the throwaway gym.
          ["Ironclad owner deletes G's member", call("DELETE", `/members/${liamRowG.id}`, owner.token)],
          ["Ironclad owner edits G's price", call("PUT", `/gym-membership-types/${typeId}`, owner.token, { monthly_cost: 0 })],
          ["Ironclad owner deletes G's type", call("DELETE", `/gym-membership-types/${typeId}`, owner.token)],
          ["Ironclad owner removes G's owner", call("DELETE", `/businesses/${G}/team/${T.profile.id}`, owner.token)],
          ["Ironclad staff edit G's profile", call("PUT", `/businesses/${G}`, employee.token, { bio: "x" })],
          ["Ironclad staff sell G's membership", call("POST", "/memberships", employee.token, { user_id: member.profile.id, current_membership_type_id: typeId, from_date: dayFromToday(0), to_date: dayFromToday(30) })],
          ["Ironclad staff extend G's membership", call("PUT", `/memberships/${msId}`, employee.token, { to_date: dayFromToday(365) })],
          ["Ironclad staff delete G's membership", call("DELETE", `/memberships/${msId}`, employee.token)],
          ["Ironclad staff invoice G's membership", call("POST", "/membership-invoices", employee.token, { membership_id: msId })],
          ["Ironclad staff mark G's invoice paid", call("PUT", `/membership-invoices/${invId}`, employee.token, { status: "paid" })],
          ["Ironclad staff read G's invoice", call("GET", `/membership-invoices/${invId}`, employee.token)],
          ["Ironclad staff delete G's invoice", call("DELETE", `/membership-invoices/${invId}`, employee.token)],
          ["Ironclad staff add a member to G", call("POST", "/members", employee.token, { gym_id: G, user_id: vendor.profile.id })],
          // G's owner against Ironclad.
          ["G owner adds a member to Ironclad", call("POST", "/members", T.token, { gym_id: gym.id, user_id: vendor.profile.id })],
          ["G owner removes an Ironclad member", call("DELETE", `/members/${ironMember.id}`, T.token)],
          ["G owner hires at Ironclad", call("POST", `/businesses/${gym.id}/team`, T.token, { user_id: vendor.profile.id, role: "staff" })],
          ["G owner removes Ironclad staff", call("DELETE", `/businesses/${gym.id}/team/${ironStaff.user_id}?role=staff`, T.token)],
          ["G owner removes an Ironclad trainer", call("DELETE", `/businesses/${gym.id}/team/${ironTrainer.user_id}?role=trainer`, T.token)],
          ["G owner adds an Ironclad trainer", call("POST", `/businesses/${gym.id}/team`, T.token, { user_id: vendor.profile.id, role: "trainer" })],
          ["G owner lists Ironclad's team", call("GET", `/businesses/${gym.id}/team`, T.token)],
          ["G owner prices Ironclad", call("POST", "/gym-membership-types", T.token, { name: "x", monthly_cost: 1, gym_id: gym.id })],
          ["G owner edits Ironclad", call("PUT", `/businesses/${gym.id}`, T.token, { name: "x" })],
          ["G owner switches Ironclad's sides", call("PUT", `/businesses/${gym.id}`, T.token, { has_shop: true })],
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
        const ironTeamAfter = (await call("GET", `/businesses/${gym.id}/team`, owner.token)).data as any[];
        check("Ironclad team untouched", ironTeamAfter?.length === ironTeam.length);
        assertAll();
      });

      await t.step("11. blocking and deleting businesses cascades (orders, items, members, memberships, team, follows)", async () => {
        // A blocked business stops working for its team and disappears for everyone else.
        const block = await call("POST", `/businesses/${S}/review`, superU.token, { status: "blocked", note: `Blocked ${tag}` });
        check("super user blocks the shop", block.status === 200 && block.data.status === "blocked", short(block.data));
        const blockedItem = await call("POST", "/shop-items", T.token, { shop_id: S, type: "equipment", name: "x", price: 1, quantity: 1 });
        check("a blocked shop's owner can't sell", blockedItem.status === 403, `status ${blockedItem.status}`);
        check("…or edit its profile", (await call("PUT", `/businesses/${S}`, T.token, { bio: "x" })).status === 403);
        check("…and it's hidden from others", (await call("GET", `/businesses/${S}`, member.token)).status === 404);
        check("…but can't withdraw it either (403)", (await call("DELETE", `/businesses/${S}`, T.token)).status === 403);
        const unblock = await call("POST", `/businesses/${S}/review`, superU.token, { status: "approved" });
        check("approving it again restores it", unblock.data?.status === "approved", short(unblock.data));

        // U back on the team (staff + trainer) so the cascade has roles to remove.
        for (const role of ["staff", "trainer"]) {
          await call("POST", `/businesses/${G}/team`, T.token, { user_id: U.profile.id, role });
          await call("POST", `/businesses/${G}/invites/${role}/accept`, U.token);
        }
        check("U is staff + trainer again", JSON.stringify(await rolesAt(U, G)) === JSON.stringify(["staff", "trainer"]));
        const item = await call("POST", "/shop-items", T.token, { shop_id: S, type: "equipment", name: `it-c-${tag}`, price: 2, quantity: 5 });
        const order = await call("POST", "/orders", member.token, { shop_id: S, items: [{ shop_item_id: item.data?.id, quantity: 1 }], payment_method: "pay_at_pickup" });
        check("member orders from the shop", order.status === 201, short(order.data));
        await call("PUT", `/businesses/${S}/follow`, member.token);
        const msId = ((await call("GET", `/memberships?gym_id=${G}`, T.token)).data as any[])[0]?.id;
        const invId = ((await call("GET", `/membership-invoices?gym_id=${G}`, T.token)).data as any[])[0]?.id;

        const delShop = await call("DELETE", `/businesses/${S}`, T.token);
        check("owner deletes the shop", delShop.status === 204, `status ${delShop.status} ${short(delShop.data)}`);
        const shopId = S;
        if (delShop.status === 204) S = "";
        check("its orders are gone", (await call("GET", `/orders/${order.data?.id}`, member.token)).status === 404);
        check("its items are gone", (await call("GET", `/shop-items/${item.data?.id}`)).status === 404);

        const delGym = await call("DELETE", `/businesses/${G}`, T.token);
        check("owner deletes the gym", delGym.status === 204, `status ${delGym.status} ${short(delGym.data)}`);
        const gymId = G;
        if (delGym.status === 204) G = "";
        check("the gym is gone", (await call("GET", `/businesses/${gymId}`, T.token)).status === 404);
        check("its members are gone", ((await call("GET", `/members?gym_id=${gymId}`, T.token)).data as any[]).length === 0);
        check("its memberships are gone", (await call("GET", `/memberships/${msId}`, member.token)).status === 404);
        check("its invoices are gone", (await call("GET", `/membership-invoices/${invId}`, member.token)).status === 404);
        check("its team is gone", (await me(U))?.businesses?.length === 0 && (await me(T))?.businesses?.length === 0);
        if (await dbAvailable()) {
          const left = await sql<{ n: number }>(
            `SELECT (SELECT COUNT(*) FROM business_member WHERE business_id = ANY($1::uuid[]))
                  + (SELECT COUNT(*) FROM business_follow WHERE business_id = ANY($1::uuid[])) AS n`,
            [[gymId, shopId]],
          );
          check("no team or follower rows are left", Number(left?.[0]?.n) === 0, short(left));
        }
        const stats = await call("GET", "/businesses/stats", T.token);
        check("owner with no gyms has empty stats", stats.status === 200 && stats.data.gyms === 0, short(stats.data));
        assertAll();
      });
    } finally {
      for (const id of [S, G]) if (id) await call("DELETE", `/businesses/${id}`, T.token);
      if (superBiz) await call("DELETE", `/businesses/${superBiz}`, superU.token);
      // Every notice the flow sent names the throwaway gym/shop, so the tag finds them.
      const mentionsTag = (n: any) => `${n.title} ${n.body}`.includes(tag);
      await deleteNotifications(member.token, mentionsTag);
      await deleteNotifications(vendor.token, mentionsTag);
      await deleteNotificationsWhere("user_id", [T.profile.id, U.profile.id, W.profile.id]);
      await sql(`DELETE FROM notification WHERE title LIKE $1 OR body LIKE $1`, [`%${tag}%`]);
      await sql(
        `DELETE FROM admin_audit_log WHERE actor_id = $1 AND action LIKE 'business_%' AND metadata->>'business_id' = ANY($2::text[])`,
        [superU.profile.id, everCreated.filter(Boolean)],
      );
      for (const id of [T.profile.id, U.profile.id, W.profile.id]) {
        const del = await call("DELETE", `/users/${id}`, superU.token);
        if (del.status !== 204) console.warn(`couldn't delete throwaway user ${id}: ${del.status} ${short(del.data)}`);
      }
    }
  },
});
