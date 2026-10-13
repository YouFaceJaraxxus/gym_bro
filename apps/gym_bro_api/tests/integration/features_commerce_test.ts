// deno-lint-ignore-file no-explicit-any
// Check-ins (QR + manual), shop orders and payments. Stripe and CHECKIN/cron
// secrets aren't configured locally, so card/checkout/webhook paths assert the
// `not_configured` answers. Check-in and order rows have no DELETE endpoint;
// they're removed with SQL in `finally` (see _db.ts) and stock is restored.
import { ANON, call, checker, deleteNotifications, FN, seededUsers, short, suite } from "./_client.ts";
import { dbAvailable, deleteNotificationsWhere, sql } from "./_db.ts";

Deno.test({
  name: "features: check-ins, orders, payments",
  ...suite,
  async fn(t) {
    const { check, assertAll } = checker();
    const { member, owner, employee, vendor, gym } = await seededUsers();
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
      assertAll();
    });
  },
});
