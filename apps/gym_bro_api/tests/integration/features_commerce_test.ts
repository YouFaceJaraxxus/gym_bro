// deno-lint-ignore-file no-explicit-any
// Check-ins (QR + manual), shop items and orders, payments, and gym pricing:
// membership types, memberships and their invoices. Stripe and CHECKIN/cron
// secrets aren't configured locally, so card/checkout/webhook paths assert the
// `not_configured` answers. Check-in and order rows have no DELETE endpoint;
// they're removed with SQL in `finally` (see _db.ts) and stock is restored.
// Membership types, memberships, invoices and shop items are throwaway rows
// deleted through the API; notifications they caused are deleted too.
import { ANON, call, checker, dayFromToday, deleteNotifications, FN, notificationsOf, seededUsers, short, suite } from "./_client.ts";
import { dbAvailable, deleteNotificationsWhere, sql } from "./_db.ts";

Deno.test({
  name: "features: check-ins, orders, payments",
  ...suite,
  async fn(t) {
    const { check, assertAll } = checker();
    const { member, owner, employee, superU, vendor, gym } = await seededUsers();
    const canCleanDb = await dbAvailable();

    await t.step("3. check-ins: token, scan, duplicate, tamper, manual, stats, history", async () => {
      const checkInIds: string[] = [];
      try {
        const roster = (await call("GET", `/members?gym_id=${gym.id}`, owner.token)).data as any[];
        const other = roster.find((m) => m.user_id !== member.profile.id);
        check("gym has a second member", !!other);

        const gyms = await call("GET", "/check-ins/gyms", member.token);
        check("member lists check-in gyms", gyms.status === 200 && (gyms.data as any[]).some((g) => g.gym_id === gym.id && g.is_member), short(gyms.data));

        const tok = await call("GET", `/check-ins/token?gym_id=${gym.id}`, member.token);
        check("member gets a QR token", tok.status === 200 && typeof tok.data.token === "string" && tok.data.ttl_seconds === 300, short(tok.data));
        const vendorTok = await call("GET", `/check-ins/token?gym_id=${gym.id}`, vendor.token);
        check("non-member can't get a token for the gym", vendorTok.status === 403, `status ${vendorTok.status}`);

        const memberScan = await call("POST", "/check-ins", member.token, { token: tok.data.token });
        check("member can't scan tokens", memberScan.status === 403, `status ${memberScan.status}`);

        const scan = await call("POST", "/check-ins", employee.token, { token: tok.data.token, gym_id: gym.id });
        if (scan.data?.check_in?.id) checkInIds.push(scan.data.check_in.id);
        check(
          "employee scans the token",
          // A rerun within 30 minutes without DB cleanup lands in the duplicate window.
          (scan.status === 201 && scan.data.duplicate === false) || (!canCleanDb && scan.status === 200),
          short(scan.data),
        );
        check(
          "scan returns member and method qr",
          scan.data?.member?.id === member.profile.id && scan.data?.check_in?.method === "qr" && "warning" in scan.data,
          short(scan.data),
        );
        const rescan = await call("POST", "/check-ins", employee.token, { token: tok.data.token });
        check(
          "rescan is a duplicate of the same check-in",
          rescan.status === 200 && rescan.data.duplicate === true && rescan.data.check_in.id === scan.data?.check_in?.id,
          short(rescan.data),
        );

        const [payload, sig] = (tok.data.token as string).split(".");
        const forged = JSON.parse(atob(payload.replace(/-/g, "+").replace(/_/g, "/")));
        forged.u = other?.user_id;
        const forgedPayload = btoa(JSON.stringify(forged)).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
        const tampered = await call("POST", "/check-ins", employee.token, { token: `${forgedPayload}.${sig}` });
        check("tampered token is 400 token_invalid", tampered.status === 400 && tampered.data.code === "token_invalid", short(tampered.data));
        const garbage = await call("POST", "/check-ins", employee.token, { token: "not-a-token" });
        check("garbage token is 400 token_invalid", garbage.status === 400 && garbage.data.code === "token_invalid", short(garbage.data));
        const wrongGym = await call("POST", "/check-ins", employee.token, { token: tok.data.token, gym_id: crypto.randomUUID() });
        check("token for another gym is 400 wrong_gym", wrongGym.status === 400 && wrongGym.data.code === "wrong_gym", short(wrongGym.data));

        const manual = await call("POST", "/check-ins", employee.token, { gym_id: gym.id, user_id: other?.user_id });
        if (manual.data?.check_in?.id) checkInIds.push(manual.data.check_in.id);
        check(
          "employee checks a member in manually",
          (manual.status === 201 || (!canCleanDb && manual.status === 200)) && manual.data.check_in.method === "manual",
          short(manual.data),
        );
        const manualNonMember = await call("POST", "/check-ins", employee.token, { gym_id: gym.id, user_id: vendor.profile.id });
        check("manual check-in of a non-member is 400", manualNonMember.status === 400, `status ${manualNonMember.status}`);
        const memberManual = await call("POST", "/check-ins", member.token, { gym_id: gym.id, user_id: member.profile.id });
        check("member can't check people in manually", memberManual.status === 403, `status ${memberManual.status}`);
        const emptyBody = await call("POST", "/check-ins", employee.token, {});
        check("check-in without token or ids is 400", emptyBody.status === 400, `status ${emptyBody.status}`);

        const search = await call("GET", `/check-ins/members?gym_id=${gym.id}&q=${encodeURIComponent(member.profile.name)}`, employee.token);
        check("staff member search finds the member", search.status === 200 && (search.data as any[]).some((u) => u.id === member.profile.id), `status ${search.status}`);
        const memberSearch = await call("GET", `/check-ins/members?gym_id=${gym.id}`, member.token);
        check("member can't search the member list", memberSearch.status === 403, `status ${memberSearch.status}`);

        const stats = await call("GET", `/check-ins/stats?gym_id=${gym.id}&days=7`, employee.token);
        check(
          "staff stats count today's check-ins",
          stats.status === 200 && stats.data.today >= 2 && stats.data.unique_members >= 2 && stats.data.per_day.length === 7 &&
            stats.data.busiest_hours.length === 24 && (stats.data.top_members as any[]).some((m) => m.id === member.profile.id),
          short(stats.data),
        );
        const memberStats = await call("GET", `/check-ins/stats?gym_id=${gym.id}`, member.token);
        check("member can't read gym stats", memberStats.status === 403, `status ${memberStats.status}`);
        const myStats = await call("GET", "/check-ins/stats?mine=true", member.token);
        check("member reads own stats", myStats.status === 200 && myStats.data.total >= 1 && myStats.data.this_week >= 1, short(myStats.data));

        const history = await call("GET", "/check-ins?mine=true", member.token);
        check(
          "member reads own history with gym_name",
          history.status === 200 && (history.data as any[]).some((c) => c.id === scan.data?.check_in?.id && c.gym_name === gym.name) &&
            (history.data as any[]).every((c) => c.user_id === member.profile.id),
          `status ${history.status}`,
        );
        const today = await call("GET", `/check-ins?gym_id=${gym.id}`, employee.token);
        check("staff see today's check-ins", today.status === 200 && checkInIds.every((id) => (today.data as any[]).some((c) => c.id === id)), `status ${today.status}`);
        const memberToday = await call("GET", `/check-ins?gym_id=${gym.id}`, member.token);
        check("member can't read the gym's check-ins", memberToday.status === 403, `status ${memberToday.status}`);
      } finally {
        await sql(`DELETE FROM check_in WHERE id = ANY($1::uuid[])`, [checkInIds]);
      }
      assertAll();
    });

    await t.step("4. shop orders: place, stock, status flow, cancel restocks", async () => {
      const orderIds: string[] = [];
      const originalQty = new Map<string, number>();
      let shopId = "";
      try {
        const shops = await call("GET", "/orders/shops", member.token);
        const vendorRows = (await call("GET", `/shop-vendors?user_id=${vendor.profile.id}`, vendor.token)).data as any[];
        shopId = vendorRows?.[0]?.shop_id ?? "";
        check("storefront lists the vendor's shop", shops.status === 200 && (shops.data as any[]).some((s) => s.id === shopId), short(shops.data));

        const items = ((await call("GET", `/shop-items?shop_id=${shopId}&active_only=true`)).data as any[])
          .filter((i) => i.quantity >= 3);
        const [a, b] = items;
        check("shop has two stocked items", !!a && !!b, `n=${items.length}`);
        assertAll();
        for (const i of [a, b]) originalQty.set(i.id, i.quantity);
        const qtyOf = async (id: string) => (await call("GET", `/shop-items/${id}`)).data.quantity as number;

        const order = await call("POST", "/orders", member.token, {
          shop_id: shopId,
          items: [{ shop_item_id: a.id, quantity: 1 }, { shop_item_id: a.id, quantity: 1 }, { shop_item_id: b.id, quantity: 1 }],
          payment_method: "pay_at_pickup",
          note: "integration test",
        });
        if (order.data?.id) orderIds.push(order.data.id);
        const expectedTotal = (2 * Number(a.price) + Number(b.price)).toFixed(2);
        check(
          "member places a pay-at-pickup order (duplicate lines merged)",
          order.status === 201 && order.data.status === "pending" && order.data.item_count === 3 && order.data.items.length === 2 &&
            Number(order.data.total).toFixed(2) === expectedTotal,
          short(order.data),
        );
        check("stock is reserved", (await qtyOf(a.id)) === a.quantity - 2 && (await qtyOf(b.id)) === b.quantity - 1);

        const tooMany = await call("POST", "/orders", member.token, {
          shop_id: shopId, items: [{ shop_item_id: a.id, quantity: a.quantity }], payment_method: "pay_at_pickup",
        });
        check("ordering more than the stock is 409 out_of_stock", tooMany.status === 409 && tooMany.data.code === "out_of_stock", short(tooMany.data));
        if (tooMany.status === 201) orderIds.push(tooMany.data.id);
        const card = await call("POST", "/orders", member.token, {
          shop_id: shopId, items: [{ shop_item_id: a.id, quantity: 1 }], payment_method: "card",
        });
        check("card order without Stripe is 400 not_configured", card.status === 400 && card.data.code === "not_configured", short(card.data));
        if (card.status === 201) orderIds.push(card.data.id);
        const badQty = await call("POST", "/orders", member.token, {
          shop_id: shopId, items: [{ shop_item_id: a.id, quantity: 0 }], payment_method: "pay_at_pickup",
        });
        check("zero quantity is 400", badQty.status === 400, `status ${badQty.status}`);

        const mine = await call("GET", "/orders", member.token);
        check("buyer lists own orders", mine.status === 200 && (mine.data as any[]).some((o) => o.id === order.data.id), `status ${mine.status}`);
        const memberShop = await call("GET", `/orders?shop_id=${shopId}`, member.token);
        check("buyer can't list the shop's orders", memberShop.status === 403, `status ${memberShop.status}`);
        const vendorList = await call("GET", `/orders?shop_id=${shopId}&status=pending`, vendor.token);
        check("vendor lists pending shop orders", vendorList.status === 200 && (vendorList.data as any[]).some((o) => o.id === order.data.id), `status ${vendorList.status}`);
        const stranger = await call("GET", `/orders/${order.data.id}`, employee.token);
        check("unrelated user can't read the order", stranger.status === 403, `status ${stranger.status}`);
        const newOrderNotice = (await call("GET", "/notifications?page_size=50", vendor.token)).data?.items?.find((n: any) => n.metadata?.order_id === order.data.id);
        check("vendor got a purchase_made notification", newOrderNotice?.type === "purchase_made", short(newOrderNotice));

        const buyerPaid = await call("PUT", `/orders/${order.data.id}/status`, member.token, { status: "paid" });
        check("buyer can't mark the order paid", buyerPaid.status === 403, `status ${buyerPaid.status}`);
        const paid = await call("PUT", `/orders/${order.data.id}/status`, vendor.token, { status: "paid" });
        check("vendor marks the order paid", paid.status === 200 && paid.data.status === "paid" && !!paid.data.paid_at, short(paid.data));
        const paidAgain = await call("PUT", `/orders/${order.data.id}/status`, vendor.token, { status: "paid" });
        check("same status again is 409", paidAgain.status === 409, `status ${paidAgain.status}`);
        const buyerFulfil = await call("PUT", `/orders/${order.data.id}/status`, member.token, { status: "fulfilled" });
        check("buyer can't fulfil", buyerFulfil.status === 403, `status ${buyerFulfil.status}`);
        const buyerCancelPaid = await call("PUT", `/orders/${order.data.id}/status`, member.token, { status: "cancelled" });
        check("buyer can't cancel a paid order", buyerCancelPaid.status === 403, `status ${buyerCancelPaid.status}`);
        const fulfilled = await call("PUT", `/orders/${order.data.id}/status`, vendor.token, { status: "fulfilled" });
        check("vendor fulfils the order", fulfilled.status === 200 && fulfilled.data.status === "fulfilled" && !!fulfilled.data.fulfilled_at, short(fulfilled.data));
        const backToPending = await call("PUT", `/orders/${order.data.id}/status`, vendor.token, { status: "pending" });
        check("fulfilled order can't go back to pending", backToPending.status === 409, `status ${backToPending.status}`);
        const updates = ((await call("GET", "/notifications?page_size=50", member.token)).data?.items ?? [])
          .filter((n: any) => n.metadata?.order_id === order.data.id);
        check("buyer got order_update notifications", updates.length >= 2 && updates.every((n: any) => n.type === "order_update"), `n=${updates.length}`);

        // Buyer backs out of a second order: stock comes back.
        const beforeCancel = await qtyOf(b.id);
        const order2 = await call("POST", "/orders", member.token, {
          shop_id: shopId, items: [{ shop_item_id: b.id, quantity: 2 }], payment_method: "pay_at_pickup",
        });
        if (order2.data?.id) orderIds.push(order2.data.id);
        check("second order placed", order2.status === 201 && (await qtyOf(b.id)) === beforeCancel - 2, short(order2.data));
        const otherStaff = await call("PUT", `/orders/${order2.data.id}/status`, employee.token, { status: "cancelled" });
        check("gym staff (not shop staff) can't cancel", otherStaff.status === 403, `status ${otherStaff.status}`);
        const cancel = await call("PUT", `/orders/${order2.data.id}/status`, member.token, { status: "cancelled" });
        check("buyer cancels a pending order", cancel.status === 200 && cancel.data.status === "cancelled" && !!cancel.data.cancelled_at, short(cancel.data));
        check("cancel restocks", (await qtyOf(b.id)) === beforeCancel, `qty ${await qtyOf(b.id)} vs ${beforeCancel}`);
        const cancelAgain = await call("PUT", `/orders/${order2.data.id}/status`, member.token, { status: "cancelled" });
        check("cancelling twice is 409 (no double restock)", cancelAgain.status === 409 && (await qtyOf(b.id)) === beforeCancel, `status ${cancelAgain.status}`);
      } finally {
        await deleteNotifications(member.token, (n) => orderIds.includes(n.metadata?.order_id));
        await deleteNotifications(vendor.token, (n) => orderIds.includes(n.metadata?.order_id));
        await deleteNotificationsWhere("order_id", orderIds);
        await sql(`DELETE FROM invoice WHERE id = ANY($1::uuid[])`, [orderIds]);
        for (const [id, qty] of originalQty) {
          await sql(`UPDATE shop_item SET quantity = $2 WHERE id = $1`, [id, qty]);
        }
      }
      assertAll();
    });

    await t.step("5. payments without Stripe", async () => {
      const cfg = await call("GET", "/payments/config", member.token);
      check("config reports payments disabled", cfg.status === 200 && cfg.data.enabled === false && typeof cfg.data.currency === "string", short(cfg.data));
      const anonCfg = await call("GET", "/payments/config");
      check("config needs a signed-in user", anonCfg.status === 401, `status ${anonCfg.status}`);
      const checkout = await call("POST", "/payments/checkout", member.token, { kind: "order", order_id: crypto.randomUUID() });
      check("checkout is 503 not_configured", checkout.status === 503 && checkout.data.code === "not_configured", short(checkout.data));
      const list = await call("GET", "/payments", member.token);
      check("payment list is 503 not_configured", list.status === 503 && list.data.code === "not_configured", short(list.data));
      const hook = await fetch(`${FN}/payments/webhook`, {
        method: "POST",
        headers: { "Content-Type": "application/json", apikey: ANON, "Stripe-Signature": "t=1,v1=deadbeef" },
        body: JSON.stringify({ id: "evt_test", type: "checkout.session.completed" }),
      });
      const hookBody = await hook.json().catch(() => null);
      check("webhook is 503 not_configured", hook.status === 503 && hookBody?.code === "not_configured", `status ${hook.status} ${short(hookBody)}`);

      // Every other signed-in route stops at the same 503 before touching data;
      // the Stripe-backed behaviour behind them isn't coverable locally.
      const id = crypto.randomUUID();
      for (
        const [what, method, path, body] of [
          ["gyms for sale", "GET", "/payments/gyms", undefined],
          ["one payment", "GET", `/payments/${id}`, undefined],
          ["cancel a payment", "POST", `/payments/${id}/cancel`, undefined],
          ["cancel auto-renew", "POST", `/payments/memberships/${id}/cancel-auto-renew`, undefined],
          ["invoice checkout", "POST", "/payments/checkout", { kind: "invoice", invoice_id: id }],
          ["membership checkout", "POST", "/payments/checkout", { kind: "membership", membership_type_id: id, months: 1 }],
          ["checkout with an unknown kind", "POST", "/payments/checkout", { kind: "gift" }],
        ] as const
      ) {
        const r = await call(method, path, member.token, body);
        check(`${what} is 503 not_configured`, r.status === 503 && r.data?.code === "not_configured", `status ${r.status} ${short(r.data)}`);
      }
      const anonList = await call("GET", "/payments");
      check("payments need a signed-in user", anonList.status === 401, `status ${anonList.status}`);
      const unknownRoute = await call("GET", "/payments/not-a-uuid");
      check("unknown payments route is 404", unknownRoute.status === 404, `status ${unknownRoute.status}`);
      const hookGet = await call("GET", "/payments/webhook");
      check("webhook only takes POST", hookGet.status === 404, `status ${hookGet.status}`);
      assertAll();
    });

    await t.step("6. membership types, memberships, invoices: sell, invoice, pay, void, extend, expire", async () => {
      const tag = `it-${crypto.randomUUID().slice(0, 8)}`;
      const typeIds: string[] = [];
      const membershipIds: string[] = [];
      const invoiceIds: string[] = [];
      try {
        // Membership types (pricing) — owner only.
        const typ = (b: Record<string, unknown>, tok = owner.token) => call("POST", "/gym-membership-types", tok, b);
        check("type without monthly_cost is 400", (await typ({ name: tag, gym_id: gym.id })).status === 400);
        check("employee can't set prices", (await typ({ name: tag, monthly_cost: 30, gym_id: gym.id }, employee.token)).status === 403);
        check("member can't set prices", (await typ({ name: tag, monthly_cost: 30, gym_id: gym.id }, member.token)).status === 403);
        const ghostGym = await typ({ name: tag, monthly_cost: 30, gym_id: crypto.randomUUID() }, superU.token);
        check("type for an unknown gym is 400", ghostGym.status === 400, `status ${ghostGym.status}`);
        const a = await typ({ name: `${tag}-a`, monthly_cost: 30, gym_id: gym.id });
        const b = await typ({ name: `${tag}-b`, monthly_cost: 10, gym_id: gym.id, is_active: false });
        for (const r of [a, b]) if (r.data?.id) typeIds.push(r.data.id);
        check("owner creates an active type", a.status === 201 && a.data.is_active === true && Number(a.data.monthly_cost) === 30, short(a.data));
        check("owner creates an inactive type", b.status === 201 && b.data.is_active === false, short(b.data));
        assertAll();

        const active = (await call("GET", `/gym-membership-types?gym_id=${gym.id}&is_active=true`, member.token)).data as any[];
        const inactive = (await call("GET", `/gym-membership-types?gym_id=${gym.id}&is_active=false`, member.token)).data as any[];
        check(
          "is_active filter splits the types",
          active.some((x) => x.id === a.data.id) && !active.some((x) => x.id === b.data.id) &&
            inactive.some((x) => x.id === b.data.id) && inactive.every((x) => x.is_active === false && x.gym_id === gym.id),
          `active ${active.length} inactive ${inactive.length}`,
        );
        const one = await call("GET", `/gym-membership-types/${a.data.id}`, member.token);
        check("anyone reads a type", one.status === 200 && one.data.name === `${tag}-a`, short(one.data));
        check("unknown type is 404", (await call("GET", `/gym-membership-types/${crypto.randomUUID()}`, member.token)).status === 404);
        check("empty type update is 400", (await call("PUT", `/gym-membership-types/${a.data.id}`, owner.token, {})).status === 400);
        check("employee can't reprice", (await call("PUT", `/gym-membership-types/${a.data.id}`, employee.token, { monthly_cost: 1 })).status === 403);
        check("repricing an unknown type is 404", (await call("PUT", `/gym-membership-types/${crypto.randomUUID()}`, owner.token, { monthly_cost: 1 })).status === 404);
        const repriced = await call("PUT", `/gym-membership-types/${a.data.id}`, owner.token, { monthly_cost: 35.5, name: `${tag}-a2` });
        check("owner reprices and renames", repriced.status === 200 && Number(repriced.data.monthly_cost) === 35.5 && repriced.data.name === `${tag}-a2`, short(repriced.data));

        // Front desk sells a membership.
        const otherGymType = ((await call("GET", "/gym-membership-types", member.token)).data as any[]).find((x) => x.gym_id !== gym.id);
        const ms = (body: Record<string, unknown>, tok = employee.token) => call("POST", "/memberships", tok, body);
        const sale = { user_id: member.profile.id, current_membership_type_id: a.data.id, from_date: dayFromToday(-5), to_date: dayFromToday(5) };
        check("membership without dates is 400", (await ms({ user_id: member.profile.id, current_membership_type_id: a.data.id })).status === 400);
        check("membership of an unknown type is 400", (await ms({ ...sale, current_membership_type_id: crypto.randomUUID() })).status === 400);
        check("member can't sell themself a membership", (await ms(sale, member.token)).status === 403);
        check("unrelated user can't sell memberships", (await ms(sale, vendor.token)).status === 403);
        check("membership for an unknown user is 400", (await ms({ ...sale, user_id: crypto.randomUUID() })).status === 400);
        const sold = await ms(sale);
        if (sold.data?.id) membershipIds.push(sold.data.id);
        check("employee sells a membership", sold.status === 201 && sold.data.is_active === true && sold.data.auto_renew === false, short(sold.data));
        assertAll();
        const mId = sold.data.id;
        const activeNotice = (await notificationsOf(member.token)).find((n) => n.type === "member_subscription_extended" && n.metadata?.membership_id === mId);
        check("member is told the membership is active", !!activeNotice && activeNotice.metadata.to_date === dayFromToday(5), short(activeNotice));

        const mine = await call("GET", `/memberships?user_id=${member.profile.id}&is_active=true`, member.token);
        check("member lists active memberships", mine.status === 200 && (mine.data as any[]).some((m) => m.id === mId), `status ${mine.status}`);
        const byGym = await call("GET", `/memberships?gym_id=${gym.id}`, employee.token);
        check("staff list the gym's memberships", byGym.status === 200 && (byGym.data as any[]).some((m) => m.id === mId), `status ${byGym.status}`);
        check("read one membership", (await call("GET", `/memberships/${mId}`, member.token)).data?.id === mId);
        check("unknown membership is 404", (await call("GET", `/memberships/${crypto.randomUUID()}`, member.token)).status === 404);
        const expiring = (await notificationsOf(member.token)).filter((n) => n.type === "membership_expiring" && n.metadata?.membership_id === mId);
        check("listing own memberships warns once about the one ending within 7 days", expiring.length === 1, `n=${expiring.length}`);
        await call("GET", `/memberships?user_id=${member.profile.id}`, member.token);
        const expiringAgain = (await notificationsOf(member.token)).filter((n) => n.type === "membership_expiring" && n.metadata?.membership_id === mId);
        check("the expiry warning isn't repeated", expiringAgain.length === 1, `n=${expiringAgain.length}`);

        // Like invoices, memberships are visible to the member and the gym's staff only.
        const snoop = await call("GET", `/memberships?user_id=${member.profile.id}`, vendor.token);
        check("unrelated user can't list someone's memberships", snoop.status === 403 || !(snoop.data as any[]).some((m) => m.id === mId), `status ${snoop.status}`);
        check("unrelated user can't read someone's membership", (await call("GET", `/memberships/${mId}`, vendor.token)).status === 403);

        // Changes at the front desk.
        const put = (body: unknown, tok = employee.token, id = mId) => call("PUT", `/memberships/${id}`, tok, body);
        check("empty membership update is 400", (await put({})).status === 400);
        check("turning auto_renew on at the desk is 400", (await put({ auto_renew: true })).status === 400);
        const off = await put({ auto_renew: false });
        check("turning auto_renew off is allowed", off.status === 200 && off.data.auto_renew === false, short(off.data));
        check("member can't change their membership", (await put({ to_date: dayFromToday(400) }, member.token)).status === 403);
        check("changing an unknown membership is 404", (await put({ is_active: true }, employee.token, crypto.randomUUID())).status === 404);
        check("unknown new type is 400", (await put({ current_membership_type_id: crypto.randomUUID() })).status === 400);
        if (otherGymType) {
          check("another gym's type is 400", (await put({ current_membership_type_id: otherGymType.id })).status === 400);
        } else check("another gym has a membership type", false);
        const switched = await put({ current_membership_type_id: b.data.id });
        check("staff switch to another type of the same gym", switched.status === 200 && switched.data.current_membership_type_id === b.data.id, short(switched.data));
        await put({ current_membership_type_id: a.data.id });
        const extended = await put({ to_date: dayFromToday(35) });
        check("staff extend the membership", extended.status === 200, short(extended.data));
        const extNotice = (await notificationsOf(member.token)).find((n) =>
          n.type === "member_subscription_extended" && n.metadata?.membership_id === mId && n.metadata?.to_date === dayFromToday(35)
        );
        check("member is told it was extended", !!extNotice && /extended/.test(extNotice.title), short(extNotice));

        // A membership that already ended is flagged inactive on the next read.
        const lapsed = await ms({ ...sale, from_date: dayFromToday(-40), to_date: dayFromToday(-10), is_active: true });
        if (lapsed.data?.id) membershipIds.push(lapsed.data.id);
        const lapsedRead = await call("GET", `/memberships/${lapsed.data?.id}`, member.token);
        check("a lapsed membership reads as inactive", lapsed.status === 201 && lapsedRead.data?.is_active === false, short(lapsedRead.data));

        // Invoices.
        const issue = (body: Record<string, unknown>, tok = employee.token) => call("POST", "/membership-invoices", tok, body);
        check("invoice without membership_id is 400", (await issue({})).status === 400);
        check("invoice for an unknown membership is 400", (await issue({ membership_id: crypto.randomUUID() })).status === 400);
        check("member can't invoice", (await issue({ membership_id: mId }, member.token)).status === 403);
        check("invoice with an unknown type is 400", (await issue({ membership_id: mId, membership_type_id: crypto.randomUUID() })).status === 400);
        if (otherGymType) check("invoice with another gym's type is 400", (await issue({ membership_id: mId, membership_type_id: otherGymType.id })).status === 400);
        check("invoice with a non-numeric amount is 400", (await issue({ membership_id: mId, amount: "lots" })).status === 400);
        const inv = await issue({ membership_id: mId });
        if (inv.data?.id) invoiceIds.push(inv.data.id);
        check(
          "employee invoices the membership at the type's price",
          inv.status === 201 && inv.data.status === "unpaid" && Number(inv.data.amount) === 35.5 && inv.data.user_id === member.profile.id &&
            inv.data.gym_name === gym.name && inv.data.membership_type_name === `${tag}-a2`,
          short(inv.data),
        );
        const custom = await issue({ membership_id: mId, membership_type_id: b.data.id, amount: 12.34 });
        if (custom.data?.id) invoiceIds.push(custom.data.id);
        check("invoice with a custom amount and type", custom.status === 201 && Number(custom.data.amount) === 12.34 && custom.data.membership_type_id === b.data.id, short(custom.data));
        assertAll();
        const invId = inv.data.id;
        const issued = (await notificationsOf(member.token)).find((n) => n.type === "invoice_issued" && n.metadata?.invoice_id === invId);
        check("member is told about the invoice", !!issued && issued.metadata.membership_id === mId, short(issued));

        const myInv = await call("GET", `/membership-invoices?membership_id=${mId}`, member.token);
        check("member lists the membership's invoices", myInv.status === 200 && (myInv.data as any[]).length === 2, `n=${(myInv.data as any[])?.length}`);
        const snoopInv = await call("GET", `/membership-invoices?membership_id=${mId}`, vendor.token);
        check("unrelated user sees none of them", snoopInv.status === 200 && (snoopInv.data as any[]).length === 0, `n=${(snoopInv.data as any[])?.length}`);
        const unpaid = await call("GET", `/membership-invoices?gym_id=${gym.id}&status=unpaid`, employee.token);
        check("staff filter unpaid invoices", unpaid.status === 200 && (unpaid.data as any[]).some((i) => i.id === invId) && (unpaid.data as any[]).every((i) => i.status === "unpaid"), `status ${unpaid.status}`);
        check("unknown status filter is 400", (await call("GET", "/membership-invoices?status=late", employee.token)).status === 400);
        check("member reads their invoice", (await call("GET", `/membership-invoices/${invId}`, member.token)).status === 200);
        check("unrelated user can't read it", (await call("GET", `/membership-invoices/${invId}`, vendor.token)).status === 403);
        check("unknown invoice is 404", (await call("GET", `/membership-invoices/${crypto.randomUUID()}`, member.token)).status === 404);
        const pay = await call("POST", "/payments/checkout", member.token, { kind: "invoice", invoice_id: invId });
        check("paying by card needs Stripe (503 not_configured)", pay.status === 503 && pay.data?.code === "not_configured", short(pay.data));

        // Status transitions at the desk.
        const status = (s: unknown, tok = employee.token, id = invId) => call("PUT", `/membership-invoices/${id}`, tok, { status: s });
        check("unknown invoice status is 400", (await status("late")).status === 400);
        check("member can't mark it paid", (await status("paid", member.token)).status === 403);
        check("updating an unknown invoice is 404", (await status("paid", employee.token, crypto.randomUUID())).status === 404);
        const paid = await status("paid");
        check("unpaid → paid stamps paid_at", paid.status === 200 && paid.data.status === "paid" && !!paid.data.paid_at, short(paid.data));
        const paidList = await call("GET", `/membership-invoices?user_id=${member.profile.id}&status=paid`, member.token);
        check("member sees it paid", (paidList.data as any[]).some((i) => i.id === invId));
        const voided = await status("void");
        check("paid → void clears paid_at", voided.status === 200 && voided.data.status === "void" && voided.data.paid_at === null, short(voided.data));
        const reopened = await status("unpaid");
        check("void → unpaid", reopened.status === 200 && reopened.data.status === "unpaid", short(reopened.data));
        check("membership stays active throughout", (await call("GET", `/memberships/${mId}`, member.token)).data?.is_active === true);

        // Deletion order: types and memberships in use are protected.
        const delTypeInUse = await call("DELETE", `/gym-membership-types/${a.data.id}`, owner.token);
        check("deleting a type in use is 409", delTypeInUse.status === 409, `status ${delTypeInUse.status}`);
        const delMsWithInv = await call("DELETE", `/memberships/${mId}`, employee.token);
        check("deleting a membership with invoices is 409", delMsWithInv.status === 409, `status ${delMsWithInv.status}`);
        check("member can't delete an invoice", (await call("DELETE", `/membership-invoices/${invId}`, member.token)).status === 403);
        for (const id of invoiceIds) {
          const d = await call("DELETE", `/membership-invoices/${id}`, employee.token);
          check("staff delete the invoice", d.status === 204, `status ${d.status}`);
        }
        check("deleting it again is 404", (await call("DELETE", `/membership-invoices/${invId}`, employee.token)).status === 404);
        check("member can't delete the membership", (await call("DELETE", `/memberships/${mId}`, member.token)).status === 403);
        for (const id of membershipIds) {
          const d = await call("DELETE", `/memberships/${id}`, employee.token);
          check("staff delete the membership", d.status === 204, `status ${d.status}`);
        }
        check("deleting a membership again is 404", (await call("DELETE", `/memberships/${mId}`, employee.token)).status === 404);
        check("employee can't delete a type", (await call("DELETE", `/gym-membership-types/${a.data.id}`, employee.token)).status === 403);
        for (const id of typeIds) {
          const d = await call("DELETE", `/gym-membership-types/${id}`, owner.token);
          check("owner deletes the unused type", d.status === 204, `status ${d.status}`);
        }
        check("deleting a type again is 404", (await call("DELETE", `/gym-membership-types/${a.data.id}`, owner.token)).status === 404);
      } finally {
        for (const id of invoiceIds) await call("DELETE", `/membership-invoices/${id}`, owner.token);
        for (const id of membershipIds) await call("DELETE", `/memberships/${id}`, owner.token);
        for (const id of typeIds) await call("DELETE", `/gym-membership-types/${id}`, owner.token);
        // Already-deleted rows answer 404 above; their notifications go here.
        await deleteNotifications(member.token, (n) => membershipIds.includes(n.metadata?.membership_id) || invoiceIds.includes(n.metadata?.invoice_id));
        await deleteNotificationsWhere("membership_id", membershipIds);
        await deleteNotificationsWhere("invoice_id", invoiceIds);
      }
      assertAll();
    });

    await t.step("7. shop items and orders: vendor CRUD, validation, cancels both ways, back in stock", async () => {
      const tag = `it-${crypto.randomUUID().slice(0, 8)}`;
      const orderIds: string[] = [];
      let itemId = "";
      const shopId = ((await call("GET", `/shop-vendors?user_id=${vendor.profile.id}`, vendor.token)).data as any[])?.[0]?.shop_id ?? "";
      try {
        // Shop items: vendor/owner writes, public reads.
        const add = (b: Record<string, unknown>, tok = vendor.token) => call("POST", "/shop-items", tok, b);
        const good = { shop_id: shopId, type: "supplement", name: tag, description: "test item", price: 5, quantity: 1 };
        check("adding an item needs a signed-in user", (await call("POST", "/shop-items", undefined, good)).status === 401);
        check("item without price is 400", (await add({ ...good, price: undefined })).status === 400);
        check("item of an unknown type is 400", (await add({ ...good, type: "food" })).status === 400);
        check("negative quantity is 400", (await add({ ...good, quantity: -1 })).status === 400);
        check("fractional quantity is 400", (await add({ ...good, quantity: 1.5 })).status === 400);
        check("member can't add items", (await add(good, member.token)).status === 403);
        check("gym employee can't add shop items", (await add(good, employee.token)).status === 403);
        check("item for an unknown shop is 400", (await add({ ...good, shop_id: crypto.randomUUID() }, superU.token)).status === 400);
        const item = await add(good);
        itemId = item.data?.id ?? "";
        check("vendor adds an item", item.status === 201 && item.data.is_active === true && item.data.quantity === 1, short(item.data));
        assertAll();

        const pub = await call("GET", `/shop-items?shop_id=${shopId}`);
        check("anyone lists the shop's items", pub.status === 200 && (pub.data as any[]).some((i) => i.id === itemId) && (pub.data as any[]).every((i) => i.shop_id === shopId), `status ${pub.status}`);
        check("anyone reads an item", (await call("GET", `/shop-items/${itemId}`)).data?.name === tag);
        check("unknown item is 404", (await call("GET", `/shop-items/${crypto.randomUUID()}`)).status === 404);
        const edit = (b: unknown, tok = vendor.token, id = itemId) => call("PUT", `/shop-items/${id}`, tok, b);
        check("empty item update is 400", (await edit({})).status === 400);
        check("unknown type update is 400", (await edit({ type: "food" })).status === 400);
        check("bad quantity update is 400", (await edit({ quantity: -2 })).status === 400);
        check("member can't edit items", (await edit({ price: 1 }, member.token)).status === 403);
        check("editing an unknown item is 404", (await edit({ price: 1 }, vendor.token, crypto.randomUUID())).status === 404);
        const ownerEdit = await edit({ price: 6.5, description: "owner edit" }, owner.token);
        check("shop owner edits the item", ownerEdit.status === 200 && Number(ownerEdit.data.price) === 6.5, short(ownerEdit.data));

        // Order validation.
        const order = (b: Record<string, unknown>, tok = member.token) => call("POST", "/orders", tok, b);
        const line = [{ shop_item_id: itemId, quantity: 1 }];
        const otherShopItem = ((await call("GET", "/shop-items?active_only=true")).data as any[]).find((i) => i.shop_id !== shopId && i.quantity > 0);
        for (
          const [what, body, code] of [
            ["bad shop_id", { shop_id: "x", items: line, payment_method: "pay_at_pickup" }, undefined],
            ["no items", { shop_id: shopId, items: [], payment_method: "pay_at_pickup" }, undefined],
            ["unknown payment method", { shop_id: shopId, items: line, payment_method: "cash" }, undefined],
            ["note over 1000 chars", { shop_id: shopId, items: line, payment_method: "pay_at_pickup", note: "x".repeat(1001) }, undefined],
            ["line without shop_item_id", { shop_id: shopId, items: [{ quantity: 1 }], payment_method: "pay_at_pickup" }, undefined],
            ["unknown shop", { shop_id: crypto.randomUUID(), items: line, payment_method: "pay_at_pickup" }, undefined],
            ["unknown item", { shop_id: shopId, items: [{ shop_item_id: crypto.randomUUID(), quantity: 1 }], payment_method: "pay_at_pickup" }, "item_not_found"],
            ["another shop's item", { shop_id: shopId, items: [{ shop_item_id: otherShopItem?.id, quantity: 1 }], payment_method: "pay_at_pickup" }, "wrong_shop"],
          ] as const
        ) {
          const r = await order(body as Record<string, unknown>);
          if (r.status === 201) orderIds.push(r.data.id);
          check(`order with ${what} is 400${code ? ` ${code}` : ""}`, r.status === 400 && (!code || r.data.code === code), `status ${r.status} ${short(r.data)}`);
        }
        check("orders need a signed-in user", (await call("GET", "/orders")).status === 401);
        check("unknown status filter is 400", (await call("GET", "/orders?status=lost", member.token)).status === 400);
        check("bad shop_id filter is 400", (await call("GET", "/orders?shop_id=x", vendor.token)).status === 400);
        check("non-uuid order path is 404", (await call("GET", "/orders/abc", member.token)).status === 404);
        check("unknown order is 404", (await call("GET", `/orders/${crypto.randomUUID()}`, member.token)).status === 404);
        check("status change of an unknown order is 404", (await call("PUT", `/orders/${crypto.randomUUID()}/status`, vendor.token, { status: "paid" })).status === 404);

        // Buyer cancels: stock returns and the shop is told.
        const o1 = await order({ shop_id: shopId, items: line, payment_method: "pay_at_pickup" });
        if (o1.data?.id) orderIds.push(o1.data.id);
        check("member buys the last one", o1.status === 201 && Number(o1.data.total) === 6.5, short(o1.data));
        check("vendor reads the order", (await call("GET", `/orders/${o1.data?.id}`, vendor.token)).data?.id === o1.data?.id);
        const soldOut = await order({ shop_id: shopId, items: line, payment_method: "pay_at_pickup" });
        if (soldOut.status === 201) orderIds.push(soldOut.data.id);
        check("next order is 409 out_of_stock (available 0)", soldOut.status === 409 && soldOut.data.code === "out_of_stock" && soldOut.data.available === 0, short(soldOut.data));
        check("unknown status value is 400", (await call("PUT", `/orders/${o1.data?.id}/status`, vendor.token, { status: "lost" })).status === 400);
        check("staff can't skip from pending to fulfilled", (await call("PUT", `/orders/${o1.data?.id}/status`, vendor.token, { status: "fulfilled" })).status === 409);
        const buyerCancel = await call("PUT", `/orders/${o1.data?.id}/status`, member.token, { status: "cancelled" });
        check("buyer cancels", buyerCancel.status === 200 && buyerCancel.data.status === "cancelled", short(buyerCancel.data));
        const shopNotice = (await notificationsOf(vendor.token)).find((n) => n.type === "order_update" && n.metadata?.order_id === o1.data?.id);
        check("vendor is told the buyer cancelled", !!shopNotice && /cancelled an order/.test(shopNotice.title) && shopNotice.metadata.status === "cancelled", short(shopNotice));
        check("cancel returned the stock", (await call("GET", `/shop-items/${itemId}`)).data?.quantity === 1);

        // Vendor cancels: the buyer is told.
        const o2 = await order({ shop_id: shopId, items: line, payment_method: "pay_at_pickup" });
        if (o2.data?.id) orderIds.push(o2.data.id);
        const vendorCancel = await call("PUT", `/orders/${o2.data?.id}/status`, vendor.token, { status: "cancelled" });
        check("vendor cancels a pending order", vendorCancel.status === 200 && vendorCancel.data.status === "cancelled", short(vendorCancel.data));
        const buyerNotice = (await notificationsOf(member.token)).find((n) => n.type === "order_update" && n.metadata?.order_id === o2.data?.id);
        check("buyer is told the order was cancelled", !!buyerNotice && buyerNotice.metadata.status === "cancelled", short(buyerNotice));
        const cancelled = await call("GET", "/orders?status=cancelled", member.token);
        check("buyer filters own cancelled orders", cancelled.status === 200 && [o1.data?.id, o2.data?.id].every((id) => (cancelled.data as any[]).some((o) => o.id === id)), `status ${cancelled.status}`);

        // Restock from 0 → buyers whose order with it was cancelled hear it's back.
        await edit({ quantity: 0 });
        const restock = await edit({ quantity: 4 });
        check("vendor restocks", restock.status === 200 && restock.data.quantity === 4, short(restock.data));
        const back = (await notificationsOf(member.token)).filter((n) => n.type === "shop_item_update" && n.metadata?.shop_item_id === itemId);
        check("buyer gets one back-in-stock notification", back.length === 1 && back[0].title.includes(tag), `n=${back.length}`);
        await edit({ quantity: 5 });
        const backAgain = (await notificationsOf(member.token)).filter((n) => n.type === "shop_item_update" && n.metadata?.shop_item_id === itemId);
        check("restocking a stocked item doesn't notify again", backAgain.length === 1, `n=${backAgain.length}`);

        // Deactivated or expired items can't be ordered.
        await edit({ is_active: false });
        const inactive = await order({ shop_id: shopId, items: line, payment_method: "pay_at_pickup" });
        if (inactive.status === 201) orderIds.push(inactive.data.id);
        check("ordering a deactivated item is 409 item_inactive", inactive.status === 409 && inactive.data.code === "item_inactive", short(inactive.data));
        const activeList = (await call("GET", `/shop-items?shop_id=${shopId}&active_only=true`)).data as any[];
        check("active_only hides it", !activeList.some((i) => i.id === itemId));
        await edit({ is_active: true, active_until: new Date(Date.now() - 86_400_000).toISOString() });
        const expired = await order({ shop_id: shopId, items: line, payment_method: "pay_at_pickup" });
        if (expired.status === 201) orderIds.push(expired.data.id);
        check("ordering an expired item is 409 item_inactive", expired.status === 409 && expired.data.code === "item_inactive", short(expired.data));

        // Items on orders can't be deleted.
        check("member can't delete items", (await call("DELETE", `/shop-items/${itemId}`, member.token)).status === 403);
        check("deleting an unknown item is 404", (await call("DELETE", `/shop-items/${crypto.randomUUID()}`, vendor.token)).status === 404);
        const inUse = await call("DELETE", `/shop-items/${itemId}`, vendor.token);
        check("deleting an item on orders is 409", inUse.status === 409, `status ${inUse.status}`);
        await sql(`DELETE FROM invoice WHERE id = ANY($1::uuid[])`, [orderIds]);
        if (canCleanDb) {
          const del = await call("DELETE", `/shop-items/${itemId}`, vendor.token);
          check("vendor deletes the item once it's off every order", del.status === 204, `status ${del.status}`);
          if (del.status === 204) itemId = "";
        }
      } finally {
        await deleteNotifications(member.token, (n) => orderIds.includes(n.metadata?.order_id) || (itemId !== "" && n.metadata?.shop_item_id === itemId) || n.title?.includes?.(tag));
        await deleteNotifications(vendor.token, (n) => orderIds.includes(n.metadata?.order_id));
        await deleteNotificationsWhere("order_id", orderIds);
        await sql(`DELETE FROM notification WHERE title LIKE $1`, [`%${tag}%`]);
        await sql(`DELETE FROM invoice WHERE id = ANY($1::uuid[])`, [orderIds]);
        if (itemId) await call("DELETE", `/shop-items/${itemId}`, vendor.token);
      }
      assertAll();
    });
  },
});
