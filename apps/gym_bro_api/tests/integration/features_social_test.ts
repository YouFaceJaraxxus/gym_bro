// deno-lint-ignore-file no-explicit-any
// Food diary (logging, summaries, plan import, barcode lookup) and post
// likes/comments. Everything created is deleted through the API in `finally`.
import { call, checker, dayFromToday, deleteNotifications, notificationsOf, seededUsers, short, suite } from "./_client.ts";

const r2 = (n: number) => Math.round(n * 100) / 100;
const near = (a: number, b: number) => Math.abs(a - b) < 0.011;

Deno.test({
  name: "features: food diary and post social",
  ...suite,
  async fn(t) {
    const { check, assertAll } = checker();
    // The seeded gym owner also owns the vendor's shop (Peak Performance).
    const { member, trainer, vendor, superU, owner: shopOwner } = await seededUsers();
    const stamp = Date.now();

    await t.step("8. food diary", async () => {
      const logIds: string[] = [];
      let foodItemId: string | null = null;
      try {
        // A far-future day so seeded diary entries never mix into the totals.
        const date = dayFromToday(400 + (stamp % 300));
        const foods = (await call("GET", "/food-items?page_size=20", member.token)).data as any[];
        const food = foods.find((f) => Number(f.kcal_per_100) > 0);
        const recipes = (await call("GET", "/recipes?page_size=20", member.token)).data as any[];
        const recipe = recipes.find((r) => Number(r.kcal_per_serving) > 0);
        check("a public food item and recipe exist", !!food && !!recipe, `foods=${foods?.length} recipes=${recipes?.length}`);
        assertAll();

        const logFood = await call("POST", "/food-logs", member.token, {
          log_date: date, slot_type: "breakfast", food_item_id: food.id, amount: 150, note: "test",
        });
        if (logFood.data?.id) logIds.push(logFood.data.id);
        const foodKcal = r2(Number(food.kcal_per_100) * 1.5);
        check(
          "member logs a food item (server-computed macros)",
          logFood.status === 201 && logFood.data.log_date === date && near(Number(logFood.data.kcal), foodKcal) &&
            logFood.data.unit === (food.serving_unit ?? "g"),
          short(logFood.data),
        );
        const logRecipe = await call("POST", "/food-logs", member.token, {
          log_date: date, slot_type: "lunch", recipe_id: recipe.id, amount: 2,
        });
        if (logRecipe.data?.id) logIds.push(logRecipe.data.id);
        const recipeKcal = r2(Number(recipe.kcal_per_serving) * 2);
        check(
          "member logs a recipe in servings",
          logRecipe.status === 201 && logRecipe.data.unit === "serving" && near(Number(logRecipe.data.kcal), recipeKcal) && logRecipe.data.name === recipe.name,
          short(logRecipe.data),
        );

        const both = await call("POST", "/food-logs", member.token, { log_date: date, slot_type: "lunch", food_item_id: food.id, recipe_id: recipe.id, amount: 1 });
        check("food item and recipe together is 400", both.status === 400, `status ${both.status}`);
        const badSlot = await call("POST", "/food-logs", member.token, { log_date: date, slot_type: "brunch", food_item_id: food.id, amount: 1 });
        check("unknown slot_type is 400", badSlot.status === 400, `status ${badSlot.status}`);
        const badAmount = await call("POST", "/food-logs", member.token, { log_date: date, slot_type: "lunch", food_item_id: food.id, amount: -5 });
        check("negative amount is 400", badAmount.status === 400, `status ${badAmount.status}`);
        const unknownFood = await call("POST", "/food-logs", member.token, { log_date: date, slot_type: "lunch", food_item_id: crypto.randomUUID(), amount: 5 });
        check("unknown food item is 404", unknownFood.status === 404, `status ${unknownFood.status}`);

        const summary = await call("GET", `/food-logs/summary?date=${date}`, member.token);
        check(
          "summary totals add up",
          summary.status === 200 && near(summary.data.totals.kcal, r2(foodKcal + recipeKcal)) && summary.data.slots.length === 2 &&
            summary.data.slots[0].slot_type === "breakfast" && summary.data.slots[0].count === 1,
          short(summary.data?.totals),
        );

        const put = await call("PUT", `/food-logs/${logFood.data.id}`, member.token, { amount: 300 });
        check("PUT recomputes macros from the new amount", put.status === 200 && near(Number(put.data.kcal), r2(foodKcal * 2)) && Number(put.data.amount) === 300, short(put.data));
        const moveSlot = await call("PUT", `/food-logs/${logFood.data.id}`, member.token, { slot_type: "dinner" });
        check("PUT moves the entry to another slot", moveSlot.status === 200 && moveSlot.data.slot_type === "dinner" && near(Number(moveSlot.data.kcal), r2(foodKcal * 2)), short(moveSlot.data));
        const summary2 = await call("GET", `/food-logs/summary?date=${date}`, member.token);
        check("summary reflects the edit", summary2.status === 200 && near(summary2.data.totals.kcal, r2(foodKcal * 2 + recipeKcal)), short(summary2.data?.totals));
        const emptyPut = await call("PUT", `/food-logs/${logFood.data.id}`, member.token, {});
        check("empty PUT is 400", emptyPut.status === 400, `status ${emptyPut.status}`);

        const coachList = await call("GET", `/food-logs?date=${date}&user_id=${member.profile.id}`, trainer.token);
        check("trainer reads the member's diary", coachList.status === 200 && (coachList.data as any[]).length === 2, `status ${coachList.status}`);
        const coachSummary = await call("GET", `/food-logs/summary?date=${date}&user_id=${member.profile.id}`, trainer.token);
        check("trainer reads the member's summary", coachSummary.status === 200 && near(coachSummary.data.totals.kcal, summary2.data.totals.kcal), `status ${coachSummary.status}`);
        const vendorList = await call("GET", `/food-logs?date=${date}&user_id=${member.profile.id}`, vendor.token);
        check("vendor can't read the member's diary", vendorList.status === 403, `status ${vendorList.status}`);
        const vendorSummary = await call("GET", `/food-logs/summary?user_id=${member.profile.id}`, vendor.token);
        check("vendor can't read the member's summary", vendorSummary.status === 403, `status ${vendorSummary.status}`);
        const coachPut = await call("PUT", `/food-logs/${logFood.data.id}`, trainer.token, { amount: 1 });
        check("trainer can't edit the member's entry", coachPut.status === 403, `status ${coachPut.status}`);
        const vendorDel = await call("DELETE", `/food-logs/${logFood.data.id}`, vendor.token);
        check("vendor can't delete the member's entry", vendorDel.status === 403, `status ${vendorDel.status}`);
        const range = await call("GET", `/food-logs?from=2026-01-01&to=2026-12-31`, member.token);
        check("range over 92 days is 400", range.status === 400, `status ${range.status}`);

        // ── From the assigned meal plan ──
        // Plan days are ISO weekdays: the summary's plan.day_of_week must be the
        // date's weekday. Look a week ahead for a day that has planned meals.
        let planDate = dayFromToday(1);
        let plannedSummary = await call("GET", `/food-logs/summary?date=${planDate}`, member.token);
        for (let i = 1; i <= 7; i++) {
          const d = dayFromToday(i);
          const s = await call("GET", `/food-logs/summary?date=${d}`, member.token);
          const isoDow = ((new Date(`${d}T00:00:00Z`).getUTCDay() + 6) % 7) + 1;
          if (s.data?.plan) {
            check(`plan day for ${d} is its ISO weekday`, s.data.plan.day_of_week === isoDow, `got ${s.data.plan.day_of_week}, want ${isoDow}`);
          }
          if ((s.data?.planned ?? []).length) {
            planDate = d;
            plannedSummary = s;
            break;
          }
        }
        const before = await call("GET", `/food-logs?date=${planDate}`, member.token);
        const plannedEntries = (plannedSummary.data?.planned ?? []).reduce((n: number, s: any) => n + s.entries.length, 0);
        const fromPlan = await call("POST", "/food-logs/from-plan", member.token, { date: planDate });
        if (Array.isArray(fromPlan.data)) logIds.push(...fromPlan.data.map((r: any) => r.id));
        if (plannedEntries > 0) {
          check(
            "from-plan logs every planned entry for the day",
            fromPlan.status === 201 && fromPlan.data.length === plannedEntries && fromPlan.data.every((r: any) => r.log_date === planDate),
            `status ${fromPlan.status} n=${fromPlan.data?.length} planned=${plannedEntries}`,
          );
          const after = await call("GET", `/food-logs/summary?date=${planDate}`, member.token);
          const plannedKcal = (plannedSummary.data.planned as any[]).flatMap((s) => s.entries).reduce((n, e) => n + e.kcal, 0);
          const beforeKcal = (before.data as any[]).reduce((n, r) => n + Number(r.kcal), 0);
          check("from-plan totals match the planned macros", near(after.data.totals.kcal, r2(beforeKcal + plannedKcal)), `${after.data.totals.kcal} vs ${beforeKcal}+${plannedKcal}`);
        } else {
          check("from-plan without planned meals is 404", fromPlan.status === 404, `status ${fromPlan.status}`);
        }
        const badSlotPlan = await call("POST", "/food-logs/from-plan", member.token, { date: planDate, slot_type: "brunch" });
        check("from-plan validates slot_type", badSlotPlan.status === 400, `status ${badSlotPlan.status}`);
        const vendorPlan = await call("POST", "/food-logs/from-plan", vendor.token, { date: planDate });
        check("from-plan for a user without a plan is 404", vendorPlan.status === 404, `status ${vendorPlan.status}`);
        if (vendorPlan.status === 201) for (const r of vendorPlan.data) await call("DELETE", `/food-logs/${r.id}`, vendor.token);

        // ── Reference data and barcode lookup (local items only, no network) ──
        const nutrients = await call("GET", "/food-items/nutrients", member.token);
        check(
          "nutrients list vitamins and minerals",
          nutrients.status === 200 && nutrients.data.vitamins.length >= 13 && nutrients.data.minerals.length >= 11,
          short(nutrients.data),
        );
        const barcode = String(stamp).slice(-13).padStart(13, "9");
        const item = await call("POST", "/food-items", member.token, {
          name: `Test Bar ${stamp}`, brand: "QA", barcode, type: "food", food_subtype: "fruit",
          kcal_per_100: 400, protein_per_100: 20, carb_per_100: 50, fat_per_100: 10, is_public: false,
        });
        foodItemId = item.data?.id ?? null;
        check("member creates a private food item with a barcode", item.status === 201 && item.data.barcode === barcode, short(item.data));
        const lookup = await call("GET", `/food-items/barcode/${barcode}`, member.token);
        check("barcode lookup finds the local item", lookup.status === 200 && lookup.data.id === foodItemId && lookup.data.source === "local", short(lookup.data));
        const badCode = await call("GET", "/food-items/barcode/12ab", member.token);
        check("malformed barcode is 400", badCode.status === 400, `status ${badCode.status}`);
        const anonLookup = await call("GET", `/food-items/barcode/${barcode}`);
        check("barcode lookup needs a signed-in user", anonLookup.status === 401, `status ${anonLookup.status}`);
        const vendorSeesPrivate = await call("GET", `/food-items/${foodItemId}`, vendor.token);
        check("another user can't read the private food item", vendorSeesPrivate.status === 403 || vendorSeesPrivate.status === 404, `status ${vendorSeesPrivate.status}`);
        const vendorLogsPrivate = await call("POST", "/food-logs", vendor.token, { slot_type: "lunch", food_item_id: foodItemId, amount: 10 });
        check("another user can't log the private food item", vendorLogsPrivate.status === 404, `status ${vendorLogsPrivate.status}`);
        if (vendorLogsPrivate.status === 201) await call("DELETE", `/food-logs/${vendorLogsPrivate.data.id}`, vendor.token);
      } finally {
        for (const id of logIds) await call("DELETE", `/food-logs/${id}`, member.token);
        if (foodItemId) await call("DELETE", `/food-items/${foodItemId}`, member.token);
      }
      assertAll();
    });

    await t.step("9. posts: likes and comments", async () => {
      let postId: string | null = null;
      try {
        const shopId = ((await call("GET", `/shop-vendors?user_id=${vendor.profile.id}`, vendor.token)).data as any[])?.[0]?.shop_id;
        const post = await call("POST", "/posts", vendor.token, { business_id: shopId, content: `Integration test post ${stamp}` });
        postId = post.data?.id ?? null;
        check("vendor posts on their shop", post.status === 201 && post.data.like_count === 0 && post.data.comment_count === 0, short(post.data));
        const memberPost = await call("POST", "/posts", member.token, { business_id: shopId, content: "spam" });
        check("member can't post as the shop", memberPost.status === 403, `status ${memberPost.status}`);
        if (memberPost.status === 201) await call("DELETE", `/posts/${memberPost.data.id}`, member.token);

        // ── Likes ──
        const like = await call("POST", `/posts/${postId}/like`, member.token);
        check("member likes the post", like.status === 200 && like.data.liked === true && like.data.like_count === 1, short(like.data));
        const likeAgain = await call("POST", `/posts/${postId}/like`, member.token);
        check("liking twice is idempotent", likeAgain.status === 200 && likeAgain.data.like_count === 1, short(likeAgain.data));
        const trainerLike = await call("POST", `/posts/${postId}/like`, trainer.token);
        check("a second user's like counts", trainerLike.status === 200 && trainerLike.data.like_count === 2, short(trainerLike.data));
        const seen = await call("GET", `/posts/${postId}`, member.token);
        check("post shows liked_by_me and like_count", seen.status === 200 && seen.data.liked_by_me === true && seen.data.like_count === 2, short(seen.data));
        const anonSeen = await call("GET", `/posts/${postId}`);
        check("anonymous read has liked_by_me false", anonSeen.status === 200 && anonSeen.data.liked_by_me === false, short(anonSeen.data));
        const unlike = await call("DELETE", `/posts/${postId}/like`, member.token);
        check("member unlikes", unlike.status === 200 && unlike.data.liked === false && unlike.data.like_count === 1, short(unlike.data));
        const unlikeAgain = await call("DELETE", `/posts/${postId}/like`, member.token);
        check("unliking twice is idempotent", unlikeAgain.status === 200 && unlikeAgain.data.like_count === 1, short(unlikeAgain.data));
        const anonLike = await call("POST", `/posts/${postId}/like`);
        check("anonymous can't like", anonLike.status === 401, `status ${anonLike.status}`);
        const missingLike = await call("POST", `/posts/${crypto.randomUUID()}/like`, member.token);
        check("liking an unknown post is 404", missingLike.status === 404, `status ${missingLike.status}`);

        // ── Comments ──
        const comment = await call("POST", `/posts/${postId}/comments`, member.token, { body: "  Do you ship?  " });
        check("member comments on a shop post", comment.status === 201 && comment.data.body === "Do you ship?" && comment.data.can_edit === true, short(comment.data));
        const empty = await call("POST", `/posts/${postId}/comments`, member.token, { body: "  " });
        check("empty comment is 400", empty.status === 400, `status ${empty.status}`);
        const notice = (await notificationsOf(vendor.token)).find((n) => n.metadata?.comment_id === comment.data?.id);
        check("post author got a post_comment notification", notice?.type === "post_comment" && notice.metadata.post_id === postId, short(notice));

        const listAsVendor = await call("GET", `/posts/${postId}/comments`, vendor.token);
        const asVendor = (listAsVendor.data as any[])?.find((c) => c.id === comment.data.id);
        check("vendor sees the comment without edit rights", listAsVendor.status === 200 && asVendor?.can_edit === false && asVendor?.author?.id === member.profile.id, short(asVendor));
        const counted = await call("GET", `/posts/${postId}`, vendor.token);
        check("post comment_count", counted.data?.comment_count === 1, short(counted.data));

        const vendorEdit = await call("PUT", `/posts/comments/${comment.data.id}`, vendor.token, { body: "edited by vendor" });
        check("someone else can't edit the comment", vendorEdit.status === 403, `status ${vendorEdit.status}`);
        const edit = await call("PUT", `/posts/comments/${comment.data.id}`, member.token, { body: "Do you ship abroad?" });
        check("author edits the comment", edit.status === 200 && edit.data.body === "Do you ship abroad?", short(edit.data));
        const modComment = await call("POST", `/posts/${postId}/comments`, trainer.token, { body: "first!" });
        const ownerList = await call("GET", `/posts/${postId}/comments`, shopOwner.token);
        const ownerRow = (ownerList.data as any[])?.find((c) => c.id === modComment.data?.id);
        check("shop owner sees can_delete on others' comments", ownerRow?.can_delete === true && ownerRow?.can_edit === false, short(ownerRow));
        const vendorMod = await call("DELETE", `/posts/comments/${modComment.data?.id}`, vendor.token);
        check("vendor (not owner) can't moderate comments", vendorMod.status === 403, `status ${vendorMod.status}`);
        const ownerMod = await call("DELETE", `/posts/comments/${modComment.data?.id}`, shopOwner.token);
        check("shop owner moderates (deletes) a comment", ownerMod.status === 204, `status ${ownerMod.status}`);
        const trainerDel = await call("DELETE", `/posts/comments/${comment.data.id}`, trainer.token);
        check("unrelated user can't delete the comment", trainerDel.status === 403, `status ${trainerDel.status}`);
        const del = await call("DELETE", `/posts/comments/${comment.data.id}`, member.token);
        check("author deletes the comment", del.status === 204, `status ${del.status}`);
        const gone = await call("PUT", `/posts/comments/${comment.data.id}`, member.token, { body: "x" });
        check("deleted comment is gone", gone.status === 404, `status ${gone.status}`);

        // Gym posts only take comments from that gym's members and staff.
        const posts = await call("GET", `/posts?business_id=${(await gymNotJoinedBy(member.token, superU.token))}`);
        const gymPost = (posts.data as any[])?.[0];
        if (gymPost) {
          const outsider = await call("POST", `/posts/${gymPost.id}/comments`, member.token, { body: "hello" });
          check("non-member can't comment on a gym post", outsider.status === 403, `status ${outsider.status}`);
          if (outsider.status === 201) await call("DELETE", `/posts/comments/${outsider.data.id}`, member.token);
        } else {
          check("found a gym post the member can't comment on", false);
        }
      } finally {
        if (postId) {
          await deleteNotifications(vendor.token, (n) => n.metadata?.post_id === postId);
          const del = await call("DELETE", `/posts/${postId}`, vendor.token);
          check("delete post (cleanup)", del.status === 204, `status ${del.status}`);
        }
      }
      assertAll();
    });
  },
});

/** A gym (with posts) the caller isn't a member or staff of. */
async function gymNotJoinedBy(token: string, superToken: string): Promise<string> {
  const mine = new Set(((await call("GET", "/check-ins/gyms", token)).data as any[]).map((g) => g.gym_id));
  const all = (await call("GET", "/businesses?type=gym", superToken)).data as any[];
  for (const g of (Array.isArray(all) ? all : []).filter((b) => b.type === "gym" && !mine.has(b.id))) {
    const posts = await call("GET", `/posts?business_id=${g.id}&page_size=1`);
    if ((posts.data as any[])?.length) return g.id;
  }
  return "";
}
