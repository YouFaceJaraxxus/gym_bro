// deno-lint-ignore-file no-explicit-any
// Food diary (logging, summaries, plan import, barcode lookup), post
// likes/comments, and the social graph (profile settings, follows, follow
// requests, friends, blocks, reports, search, nearby). Everything created is
// deleted through the API in `finally`; profile settings are put back through
// the API, and follow/friend/block rows and reports (no DELETE endpoint) are
// restored or removed in the database.
import {
  call,
  checker,
  dayFromToday,
  deleteNotifications,
  notificationsOf,
  seededUsers,
  short,
  signin,
  suite,
} from "./_client.ts";
import { deleteNotificationsSince, restorePair, snapshotPair, sql } from "./_db.ts";

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

// Seeded people no other suite acts as: Harper and Isabel are public
// accounts, Ingrid is private (and only takes messages from people she
// follows). Chloe is the super user who reviews reports.
Deno.test({
  name: "features: social graph, settings and reports",
  ...suite,
  async fn(t) {
    const { check, assertAll } = checker();
    const [harper, isabel, ingrid, chloe] = await Promise.all([
      signin("harper.reyes@example.com"),
      signin("isabel.gomez@example.com"),
      signin("ingrid.larsen@example.com"),
      signin("chloe.anderson@example.com"),
    ]);
    const H = harper.profile.id as string;
    const I = isabel.profile.id as string;
    const G = ingrid.profile.id as string;
    // Notifications from this run are told apart by actor + time.
    const since = new Date(Date.now() - 60_000).toISOString();
    const harperMe = (await call("GET", "/social/me", harper.token)).data;
    const isabelName = (await call("GET", "/social/me", isabel.token)).data?.username as string;

    await t.step("10. profile settings and validation", async () => {
      try {
        check(
          "own profile carries its settings",
          harperMe?.is_me === true && harperMe.relationship === null && typeof harperMe.settings?.discoverable === "boolean" &&
            typeof harperMe.settings.has_location === "boolean" && harperMe.counts && "followers" in harperMe.counts,
          short(harperMe?.settings),
        );
        const edit = await call("PUT", "/social/me", harper.token, {
          allow_non_follower_messages: false,
          show_activity_status: false,
          discoverable: false,
          name: "  Harpo ",
          interests: ["Yoga", "yoga", " Climbing "],
        });
        check(
          "edit settings, name and interests (trimmed, lower-cased, deduped)",
          edit.status === 200 && edit.data.name === "Harpo" && edit.data.interests.join() === "yoga,climbing",
          short(edit.data),
        );
        const me = await call("GET", "/social/me", harper.token);
        check(
          "settings are saved",
          me.data?.settings?.allow_non_follower_messages === false && me.data.settings.discoverable === false &&
            me.data.settings.show_activity_status === false,
          short(me.data?.settings),
        );
        const seen = await call("GET", `/social/users/${H}`, isabel.token);
        check(
          "others see the new name, no activity status, and that they can't message her",
          seen.status === 200 && seen.data.name === "Harpo" && seen.data.last_active_at === null && seen.data.message_status === null &&
            seen.data.is_me === false,
          short(seen.data),
        );

        const invalid: [string, unknown][] = [
          ["non-object body", "harper"],
          ["nothing to update", {}],
          ["is_private not a boolean", { is_private: "yes" }],
          ["discoverable not a boolean", { discoverable: 1 }],
          ["blank name", { name: "  " }],
          ["last_name over 100 chars", { last_name: "x".repeat(101) }],
          ["username too short", { username: "ab" }],
          ["username with a space", { username: "has space" }],
          ["more than 10 interests", { interests: Array.from({ length: 11 }, (_, i) => `interest${i}`) }],
          ["interest over 30 chars", { interests: ["x".repeat(31)] }],
          ["interests that aren't strings", { interests: [1] }],
          ["bio that isn't a string", { bio: 5 }],
          ["avatar_url that isn't a string", { avatar_url: 5 }],
        ];
        for (const [name, body] of invalid) {
          const r = await call("PUT", "/social/me", harper.token, body);
          check(`${name} is 400`, r.status === 400, `status ${r.status}`);
        }

        const taken = await call("PUT", "/social/me", harper.token, { username: isabelName });
        check("a taken username is 409", taken.status === 409, `status ${taken.status}`);
        const newName = `it_${crypto.randomUUID().slice(0, 8)}`;
        const renamed = await call("PUT", "/social/me", harper.token, { username: newName });
        const byName = await call("GET", `/social/users/by-username/${newName.toUpperCase()}`, isabel.token);
        check(
          "rename, then look up by username (case-insensitive)",
          renamed.status === 200 && renamed.data.username === newName && byName.status === 200 && byName.data.id === H,
          `status ${renamed.status}/${byName.status}`,
        );
        const oldName = await call("GET", `/social/users/by-username/${harperMe.username}`, isabel.token);
        check("the old username no longer resolves", oldName.status === 404, `status ${oldName.status}`);
        const unknown = await call("GET", `/social/users/${crypto.randomUUID()}`, isabel.token);
        const badId = await call("GET", "/social/users/not-a-uuid", isabel.token);
        check("unknown or malformed user id is 404", unknown.status === 404 && badId.status === 404, `status ${unknown.status}/${badId.status}`);
        const anon = await call("GET", "/social/me");
        check("social needs a signed-in user", anon.status === 401, `status ${anon.status}`);
      } finally {
        const restore = await call("PUT", "/social/me", harper.token, {
          username: harperMe.username,
          name: harperMe.name,
          bio: harperMe.bio,
          interests: harperMe.interests,
          avatar_url: harperMe.avatar_url,
          allow_non_follower_messages: harperMe.settings.allow_non_follower_messages,
          discoverable: harperMe.settings.discoverable,
          show_activity_status: harperMe.settings.show_activity_status,
        });
        check("profile restored", restore.status === 200 && restore.data.username === harperMe.username, `status ${restore.status}`);
      }
      assertAll();
    });

    await t.step("11. follows: public auto-accept, remove follower, private requests", async () => {
      const snapHI = await snapshotPair(H, I);
      const snapHG = await snapshotPair(H, G);
      // Going public accepts every pending request, so remember Ingrid's.
      const pending = ((await sql<{ follower_id: string }>(
        `SELECT follower_id FROM follow WHERE followee_id = $1 AND status = 'pending'`,
        [G],
      )) ?? []).map((r) => r.follower_id);
      try {
        await call("DELETE", `/social/users/${I}/follow`, harper.token);
        await call("DELETE", `/social/users/${H}/follow`, isabel.token);
        const before = (await call("GET", `/social/users/${I}`, harper.token)).data?.counts?.followers as number;
        const follow = await call("POST", `/social/users/${I}/follow`, harper.token);
        check("following a public account is accepted at once", follow.status === 200 && follow.data.relationship.following === "accepted", short(follow.data));
        const again = await call("POST", `/social/users/${I}/follow`, harper.token);
        check("following again is a no-op", again.status === 200 && again.data.relationship.following === "accepted", short(again.data));
        const notes = (await notificationsOf(isabel.token)).filter((n) => n.type === "follow" && n.metadata?.user_id === H);
        check("one 'follow' notification", notes.length === 1, String(notes.length));
        const after = (await call("GET", `/social/users/${I}`, harper.token)).data;
        check("follower count went up", after?.counts?.followers === before + 1, `${before} → ${after?.counts?.followers}`);

        const followers = await call("GET", `/social/users/${I}/followers`, harper.token);
        check("Harper is in Isabel's followers", (followers.data as any[])?.some((u) => u.id === H && u.relationship === null), short(followers.data));
        const filtered = await call("GET", `/social/users/${I}/followers?q=${encodeURIComponent(harperMe.name)}`, harper.token);
        const none = await call("GET", `/social/users/${I}/followers?q=zz${Date.now()}`, harper.token);
        check(
          "follower list filters by q",
          (filtered.data as any[])?.some((u) => u.id === H) && (none.data as any[])?.length === 0,
          `n=${filtered.data?.length}/${none.data?.length}`,
        );
        const following = await call("GET", `/social/users/${H}/following`, isabel.token);
        check(
          "Isabel is in Harper's following, with Isabel's view of the relationship",
          (following.data as any[])?.some((u) => u.id === I) && (following.data as any[]).find((u) => u.id === I)?.relationship === null,
          short(following.data),
        );

        const removed = await call("DELETE", `/social/users/${H}/follower`, isabel.token);
        check("remove a follower", removed.status === 200 && removed.data.relationship.followed_by === "none", short(removed.data));
        const harperSide = await call("GET", `/social/users/${I}`, harper.token);
        check("the removed follower no longer follows", harperSide.data?.relationship?.following === "none", short(harperSide.data?.relationship));
        const postFollower = await call("POST", `/social/users/${H}/follower`, isabel.token);
        check("POST …/follower is 405", postFollower.status === 405, `status ${postFollower.status}`);
        const self = await call("POST", `/social/users/${H}/follow`, harper.token);
        check("following yourself is 400", self.status === 400, `status ${self.status}`);
        const ghost = await call("POST", `/social/users/${crypto.randomUUID()}/follow`, harper.token);
        const badId = await call("POST", "/social/users/nope/follow", harper.token);
        check("following an unknown user is 404", ghost.status === 404 && badId.status === 404, `status ${ghost.status}/${badId.status}`);

        // ── Private account: request → decline / cancel / accept ──
        const badgesBefore = (await call("GET", "/social/badges", ingrid.token)).data;
        const request = await call("POST", `/social/users/${G}/follow`, harper.token);
        check("following a private account is a request", request.data?.relationship?.following === "pending", short(request.data));
        const badges = await call("GET", "/social/badges", ingrid.token);
        check(
          "badges count the new follow request",
          badges.status === 200 && badges.data.follow_requests === badgesBefore.follow_requests + 1 &&
            ["friend_requests", "unread_conversations", "message_requests", "unread_notifications"].every((k) => typeof badges.data[k] === "number"),
          short(badges.data),
        );
        const privateProfile = await call("GET", `/social/users/${G}`, harper.token);
        check(
          "pending follower sees no content (and no gyms)",
          privateProfile.data?.can_view_content === false && privateProfile.data.gyms.length === 0,
          short(privateProfile.data),
        );
        const hiddenFollowing = await call("GET", `/social/users/${G}/following`, harper.token);
        check("private account's following list is 403", hiddenFollowing.status === 403 && hiddenFollowing.data.code === "private_account", short(hiddenFollowing.data));
        const mutual = await call("GET", `/social/users/${G}/mutual-friends`, harper.token);
        check("mutual friends of a private account are still listed", mutual.status === 200 && Array.isArray(mutual.data), `status ${mutual.status}`);

        const decline = await call("DELETE", `/social/follow-requests/${H}`, ingrid.token);
        check("private account declines", decline.status === 200 && decline.data.relationship.followed_by === "none", short(decline.data));
        const declineAgain = await call("DELETE", `/social/follow-requests/${H}`, ingrid.token);
        const acceptNone = await call("POST", `/social/follow-requests/${H}/accept`, ingrid.token);
        check("no pending request → 404", declineAgain.status === 404 && acceptNone.status === 404, `status ${declineAgain.status}/${acceptNone.status}`);
        const wrongVerb = await call("POST", `/social/follow-requests/${H}`, ingrid.token);
        const wrongVerb2 = await call("DELETE", `/social/follow-requests/${H}/accept`, ingrid.token);
        check("accept is POST …/accept, decline is DELETE", wrongVerb.status === 404 && wrongVerb2.status === 404, `status ${wrongVerb.status}/${wrongVerb2.status}`);

        await call("POST", `/social/users/${G}/follow`, harper.token);
        const cancel = await call("DELETE", `/social/users/${G}/follow`, harper.token);
        const listed = await call("GET", "/social/follow-requests", ingrid.token);
        check(
          "cancelling a request removes it",
          cancel.data?.relationship?.following === "none" && !(listed.data as any[]).some((r) => r.id === H),
          short(cancel.data),
        );

        await call("POST", `/social/users/${G}/follow`, harper.token);
        const goPublic = await call("PUT", "/social/me", ingrid.token, { is_private: false });
        const nowVisible = await call("GET", `/social/users/${G}`, harper.token);
        check(
          "going public accepts pending requests",
          goPublic.status === 200 && goPublic.data.is_private === false && nowVisible.data?.relationship?.following === "accepted" &&
            nowVisible.data.can_view_content === true,
          short(nowVisible.data?.relationship),
        );
      } finally {
        await call("PUT", "/social/me", ingrid.token, { is_private: true });
        if (pending.length) {
          await sql(`UPDATE follow SET status = 'pending', accepted_at = NULL WHERE followee_id = $1 AND follower_id = ANY($2::uuid[])`, [G, pending]);
        }
        await restorePair(H, I, snapHI);
        await restorePair(H, G, snapHG);
        await deleteNotificationsSince([I, G], since, "user_id", [H]);
        await deleteNotificationsSince([H], since, "user_id", [I, G]);
      }
      assertAll();
    });

    await t.step("12. friends: request, cancel, decline, accept, unfriend", async () => {
      const snap = await snapshotPair(H, I);
      try {
        await sql(`DELETE FROM friendship WHERE requester_id = ANY($1) AND addressee_id = ANY($1)`, [[H, I]]);
        const ask = await call("POST", `/social/users/${I}/friend`, harper.token);
        check("send a friend request", ask.status === 200 && ask.data.relationship.friendship === "outgoing", short(ask.data));
        const note = (await notificationsOf(isabel.token)).find((n) => n.type === "friend_request" && n.metadata?.user_id === H);
        check("friend_request notification", !!note, short(note));
        const incoming = await call("GET", "/social/friend-requests", isabel.token);
        const row = (incoming.data as any[])?.find((u) => u.id === H);
        check(
          "incoming request listed with a mutual friend count",
          row?.relationship?.friendship === "incoming" && typeof row.mutual_count === "number",
          short(row),
        );
        const outgoing = await call("GET", "/social/friend-requests?direction=outgoing", harper.token);
        check("outgoing request listed", (outgoing.data as any[])?.some((u) => u.id === I), short(outgoing.data));

        const cancel = await call("DELETE", `/social/users/${I}/friend`, harper.token);
        const afterCancel = await call("GET", "/social/friend-requests", isabel.token);
        check(
          "requester cancels",
          cancel.data?.relationship?.friendship === "none" && !(afterCancel.data as any[]).some((u) => u.id === H),
          short(cancel.data),
        );
        await call("POST", `/social/users/${I}/friend`, harper.token);
        const decline = await call("DELETE", `/social/users/${H}/friend`, isabel.token);
        check("addressee declines", decline.data?.relationship?.friendship === "none", short(decline.data));

        await call("POST", `/social/users/${I}/friend`, harper.token);
        const accept = await call("POST", `/social/users/${H}/friend`, isabel.token);
        check(
          "accepting makes friends who follow each other",
          accept.data?.relationship?.friendship === "friends" && accept.data.relationship.following === "accepted" &&
            accept.data.relationship.followed_by === "accepted",
          short(accept.data),
        );
        const accepted = (await notificationsOf(harper.token)).find((n) => n.type === "friend_accepted" && n.metadata?.user_id === I);
        check("friend_accepted notification", !!accepted, short(accepted));
        const friends = await call("GET", `/social/users/${H}/friends`, isabel.token);
        check("friend list", (friends.data as any[])?.some((u) => u.id === I), short(friends.data));
        const harperProfile = await call("GET", `/social/users/${H}`, isabel.token);
        check(
          "friends see each other's activity status",
          harperProfile.data?.relationship?.friendship === "friends" && "last_active_at" in harperProfile.data,
          short(harperProfile.data?.relationship),
        );

        const unfriend = await call("DELETE", `/social/users/${H}/friend`, isabel.token);
        check(
          "unfriend keeps the follows",
          unfriend.data?.relationship?.friendship === "none" && unfriend.data.relationship.following === "accepted",
          short(unfriend.data),
        );
      } finally {
        await restorePair(H, I, snap);
        await deleteNotificationsSince([I, H], since, "user_id", [H, I]);
      }
      assertAll();
    });

    await t.step("13. blocks hide people from lists, lookups and requests", async () => {
      const snap = await snapshotPair(H, I);
      try {
        await call("POST", `/social/users/${I}/follow`, harper.token);
        await call("POST", `/social/users/${H}/follow`, isabel.token);
        const block = await call("POST", `/social/users/${I}/block`, harper.token);
        check(
          "block drops the follows both ways",
          block.data?.relationship?.blocked === true && block.data.relationship.following === "none" &&
            block.data.relationship.followed_by === "none",
          short(block.data),
        );
        const byName = await call("GET", `/social/users/by-username/${harperMe.username}`, isabel.token);
        const lists = await call("GET", `/social/users/${H}/followers`, isabel.token);
        const mutual = await call("GET", `/social/users/${H}/mutual-friends`, isabel.token);
        check(
          "blocked user gets 404 for the blocker's username and lists",
          byName.status === 404 && lists.status === 404 && mutual.status === 404,
          `status ${byName.status}/${lists.status}/${mutual.status}`,
        );
        const friend = await call("POST", `/social/users/${H}/friend`, isabel.token);
        check("blocked user can't send a friend request", friend.status === 404, `status ${friend.status}`);
        const suggestions = await call("GET", "/social/suggestions?page_size=50", isabel.token);
        check("blocker isn't suggested", !(suggestions.data as any[]).some((u) => u.id === H), `n=${suggestions.data?.length}`);
        const blockerView = await call("GET", `/social/users/${I}`, harper.token);
        check(
          "the blocker still sees the profile (to unblock), without content",
          blockerView.status === 200 && blockerView.data.relationship.blocked === true && blockerView.data.can_view_content === false &&
            blockerView.data.message_status === null,
          short(blockerView.data),
        );
        const both = await call("POST", `/social/users/${H}/block`, isabel.token);
        check("blocking back answers without a relationship", both.status === 200 && both.data.relationship === null, short(both.data));
        await call("DELETE", `/social/users/${H}/block`, isabel.token);
        const unblock = await call("DELETE", `/social/users/${I}/block`, harper.token);
        const visible = await call("GET", `/social/users/${H}`, isabel.token);
        check("unblock: the profile is visible again", unblock.data?.relationship?.blocked === false && visible.status === 200, `status ${visible.status}`);
      } finally {
        await restorePair(H, I, snap);
        await deleteNotificationsSince([I, H], since, "user_id", [H, I]);
      }
      assertAll();
    });

    await t.step("14. reports: users and messages, reviewed by a super user", async () => {
      const reportIds: string[] = [];
      let convId: string | null = null;
      try {
        const report = await call("POST", "/social/reports", harper.token, { user_id: I, reason: "spam", details: "  fake account  " });
        if (report.data?.id) reportIds.push(report.data.id);
        check("report a user", report.status === 201 && !!report.data.id, short(report.data));
        const invalid: [string, unknown, number][] = [
          ["unknown reason", { user_id: I, reason: "rude" }, 400],
          ["no user or message", { reason: "spam" }, 400],
          ["details over 1000 chars", { user_id: I, reason: "other", details: "x".repeat(1001) }, 400],
          ["malformed user id", { user_id: "nope", reason: "other" }, 404],
          ["unknown user id", { user_id: crypto.randomUUID(), reason: "other" }, 404],
        ];
        for (const [name, body, status] of invalid) {
          const r = await call("POST", "/social/reports", harper.token, body);
          if (r.status === 201) reportIds.push(r.data.id);
          check(`report with ${name} is ${status}`, r.status === status, `status ${r.status}`);
        }

        const dm = await call("POST", "/chat/conversations", isabel.token, { user_ids: [H] });
        convId = dm.data?.id ?? null;
        const msg = await call("POST", `/chat/conversations/${convId}/messages`, isabel.token, { body: "buy followers cheap" });
        const msgReport = await call("POST", "/social/reports", harper.token, { message_id: msg.data?.id, reason: "harassment" });
        if (msgReport.data?.id) reportIds.push(msgReport.data.id);
        check("report a message from my chat", msgReport.status === 201, short(msgReport.data));
        const stranger = await call("POST", "/social/reports", ingrid.token, { message_id: msg.data?.id, reason: "spam" });
        if (stranger.status === 201) reportIds.push(stranger.data.id);
        check("can't report a message from someone else's chat", stranger.status === 404, `status ${stranger.status}`);

        const list = await call("GET", "/social/reports", chloe.token);
        const userRow = (list.data as any[])?.find((r) => r.id === report.data?.id);
        const msgRow = (list.data as any[])?.find((r) => r.id === msgReport.data?.id);
        check(
          "super user sees open reports",
          userRow?.target_id === I && userRow.reporter_id === H && userRow.details === "fake account" && userRow.reason === "spam",
          short(userRow),
        );
        check(
          "a message report names the sender and quotes the message",
          msgRow?.target_id === I && msgRow.message_id === msg.data?.id && msgRow.message_body === "buy followers cheap",
          short(msgRow),
        );
        const memberList = await call("GET", "/social/reports", harper.token);
        const memberResolve = await call("POST", `/social/reports/${report.data?.id}/resolve`, harper.token);
        check("only super users review reports", memberList.status === 403 && memberResolve.status === 403, `status ${memberList.status}/${memberResolve.status}`);
        const resolve = await call("POST", `/social/reports/${report.data?.id}/resolve`, chloe.token);
        const open = await call("GET", "/social/reports", chloe.token);
        check(
          "resolved reports leave the queue",
          resolve.status === 200 && resolve.data.resolved === true && !(open.data as any[]).some((r) => r.id === report.data?.id),
          short(resolve.data),
        );
        const ghost = await call("POST", `/social/reports/${crypto.randomUUID()}/resolve`, chloe.token);
        const bad = await call("POST", "/social/reports/nope/resolve", chloe.token);
        check("resolving an unknown report is 404", ghost.status === 404 && bad.status === 404, `status ${ghost.status}/${bad.status}`);
      } finally {
        if (reportIds.length) await sql(`DELETE FROM user_report WHERE id = ANY($1::uuid[])`, [reportIds]);
        if (convId) await sql(`DELETE FROM conversation WHERE id = $1`, [convId]);
      }
      assertAll();
    });

    await t.step("15. search and nearby (discoverable only, distances only)", async () => {
      try {
        const empty = await call("GET", "/social/search?q=", harper.token);
        check("empty search is an empty list", empty.status === 200 && Array.isArray(empty.data) && empty.data.length === 0, short(empty.data));
        const at = await call("GET", `/social/search?q=@${isabelName}`, harper.token);
        check("@username search ranks the exact match first", at.data?.[0]?.id === I && "relationship" in at.data[0], short(at.data?.[0]));
        const full = await call("GET", `/social/search?q=${encodeURIComponent("Isabel Gomez")}`, harper.token);
        check("full-name search", (full.data as any[])?.some((u) => u.id === I), `n=${full.data?.length}`);

        // Isabel (no seeded location) moves next to Harper (seeded location).
        const loc = await sql<{ lat: number; lng: number }>(`SELECT location_lat::float AS lat, location_lng::float AS lng FROM users WHERE id = $1`, [H]);
        const set = await call("PUT", "/social/me/location", isabel.token, { lat: Number(loc?.[0]?.lat) + 0.004, lng: Number(loc?.[0]?.lng) });
        check("share a location", set.status === 200 && set.data.has_location === true, short(set.data));
        const nearby = await call("GET", "/social/nearby?radius_km=5", isabel.token);
        const harperRow = (nearby.data as any[])?.find((u) => u.id === H);
        check(
          "nearby shows a rounded distance and no coordinates",
          nearby.status === 200 && Number.isInteger(harperRow?.distance_km) && harperRow.distance_km <= 1 &&
            (nearby.data as any[]).every((u) => !Object.keys(u).some((k) => /^(location_)?(lat|lng)$/.test(k))),
          short(harperRow),
        );
        const hide = await call("PUT", "/social/me", harper.token, { discoverable: false });
        const hidden = await call("GET", "/social/nearby?radius_km=5", isabel.token);
        const suggested = await call("GET", "/social/suggestions?page_size=50", isabel.token);
        check(
          "non-discoverable people leave nearby and suggestions",
          hide.status === 200 && !(hidden.data as any[]).some((u) => u.id === H) && !(suggested.data as any[]).some((u) => u.id === H),
          `n=${hidden.data?.length}`,
        );
        const stillFindable = await call("GET", `/social/search?q=${harperMe.username}`, isabel.token);
        check("…but stay findable by search", (stillFindable.data as any[])?.some((u) => u.id === H), `n=${stillFindable.data?.length}`);
        const del = await call("DELETE", "/social/me/location", isabel.token);
        const me = await call("GET", "/social/me", isabel.token);
        check("stop sharing the location", del.status === 204 && me.data?.settings?.has_location === false, `status ${del.status}`);
      } finally {
        await call("PUT", "/social/me", harper.token, { discoverable: harperMe.settings.discoverable });
        await call("DELETE", "/social/me/location", isabel.token);
      }
      assertAll();
    });
  },
});
