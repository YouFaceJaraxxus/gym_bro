// deno-lint-ignore-file no-explicit-any
// Nutrition: food items (subtypes, micronutrients, search, barcode lookup on
// local items only), recipes with server-computed macros, daily and weekly meal
// plans, a trainer's meal plan assignment (notification, assigned access to
// private plans/recipes/foods, diary targets and from-plan logging), and food
// log edits. Everything created (food items, recipes, plans, assignments,
// diary entries, notifications) is deleted through the API in `finally`.
import { call, checker, dayFromToday, deleteNotifications, notificationsOf, seededUsers, short, suite } from "./_client.ts";

const near = (a: unknown, b: number) => Math.abs(Number(a) - b) < 0.011;
const uniq = () => `it-${crypto.randomUUID().slice(0, 8)}`;
/** One lowercase token, so full-text name search can find it. */
const word = () => `gymbro${Array.from(crypto.getRandomValues(new Uint8Array(8)), (b) => String.fromCharCode(97 + (b % 26))).join("")}`;
/** ISO weekday (1 = Monday) of a YYYY-MM-DD date. */
const isoDow = (d: string) => ((new Date(`${d}T00:00:00Z`).getUTCDay() + 6) % 7) + 1;

Deno.test({
  name: "features: food items, recipes, meal plans, assignments, food log edits",
  ...suite,
  async fn(t) {
    const { check, assertAll } = checker();
    const { member, trainer, vendor, employee, superU } = await seededUsers();

    await t.step("24. food items: CRUD, subtypes, micronutrients, search, barcode", async () => {
      const ids: { id: string; token: string }[] = [];
      try {
        const token = word();
        const nutrients = await call("GET", "/food-items/nutrients");
        const vitC = (nutrients.data?.vitamins as any[])?.find((v) => v.name === "Vitamin C");
        const iron = (nutrients.data?.minerals as any[])?.find((m) => m.name === "Iron");
        check("nutrient reference rows are public", nutrients.status === 200 && !!vitC && !!iron, `status ${nutrients.status}`);
        const barcode = `8${Date.now()}`;

        const drink = await call("POST", "/food-items", member.token, {
          name: `${token} juice`, brand: "QA", barcode, type: "drink", drink_subtype: "juice_fruit", serving_unit: "ml",
          kcal_per_100: 45, protein_per_100: 0.5, carb_per_100: 10, is_public: false,
          vitamins: [{ vitamin_id: vitC?.id, amount_per_100: 30, unit: "mg" }, { amount_per_100: 1 }],
          minerals: [{ mineral_id: iron?.id, amount_per_100: 0.2 }],
        });
        if (drink.data?.id) ids.push({ id: drink.data.id, token: member.token });
        const drinkId = drink.data?.id;
        check(
          "member creates a private drink with micronutrients",
          drink.status === 201 && drink.data.type === "drink" && drink.data.serving_unit === "ml" && near(drink.data.kcal_per_100, 45) &&
            near(drink.data.fat_per_100, 0) && drink.data.is_system === false && drink.data.author_id === member.profile.id &&
            drink.data.vitamins.length === 1 && drink.data.vitamins[0].vitamin.name === "Vitamin C" && near(drink.data.vitamins[0].amount_per_100, 30) &&
            drink.data.minerals.length === 1 && drink.data.minerals[0].mineral.name === "Iron",
          short(drink.data),
        );
        const invalid: [string, any][] = [
          ["missing name", { type: "food", food_subtype: "fruit" }],
          ["unknown type", { name: "x", type: "meal" }],
          ["food without a subtype", { name: "x", type: "food" }],
          ["drink with a food subtype", { name: "x", type: "drink", drink_subtype: "soda", food_subtype: "fruit" }],
          ["spice with a food subtype value", { name: "x", type: "spice", spice_subtype: "fruit" }],
          ["unknown vitamin", { name: "x", type: "food", food_subtype: "fruit", vitamins: [{ vitamin_id: crypto.randomUUID(), amount_per_100: 1 }] }],
        ];
        for (const [label, body] of invalid) {
          const r = await call("POST", "/food-items", member.token, body);
          if (r.status === 201) ids.push({ id: r.data.id, token: member.token });
          check(`food item: ${label} is 400`, r.status === 400, `status ${r.status}`);
        }
        const negative = await call("POST", "/food-items", member.token, { name: "x", type: "food", food_subtype: "fruit", kcal_per_100: -100, is_public: false });
        if (negative.status === 201) ids.push({ id: negative.data.id, token: member.token });
        check("negative kcal_per_100 is 400", negative.status === 400, `status ${negative.status} kcal_per_100=${negative.data?.kcal_per_100}`);
        const anonPost = await call("POST", "/food-items", undefined, { name: "x", type: "food", food_subtype: "fruit" });
        check("creating a food item needs a signed-in user", anonPost.status === 401, `status ${anonPost.status}`);
        const spice = await call("POST", "/food-items", member.token, { name: `${token} rub`, type: "spice", spice_subtype: "rub", serving_unit: "oz" });
        if (spice.data?.id) ids.push({ id: spice.data.id, token: member.token });
        check("food items default to public; unknown serving_unit falls back to g", spice.status === 201 && spice.data.is_public === true && spice.data.serving_unit === "g", short(spice.data));

        // ── Reads ──
        const anon = await call("GET", `/food-items/${drinkId}`);
        check("anonymous gets 404 for a private food item", anon.status === 404, `status ${anon.status}`);
        const sup = await call("GET", `/food-items/${drinkId}`, superU.token);
        check("super user reads it", sup.status === 200, `status ${sup.status}`);
        const unknown = await call("GET", `/food-items/${crypto.randomUUID()}`);
        check("unknown food item is 404", unknown.status === 404, `status ${unknown.status}`);
        const mine = await call("GET", "/food-items?mine=true&page_size=100", member.token);
        const mineIds = ((mine.data as any[]) ?? []).map((f) => f.id);
        check("mine=true lists both items", mine.status === 200 && mineIds.includes(drinkId) && mineIds.includes(spice.data?.id), `status ${mine.status}`);
        const anonMine = await call("GET", "/food-items?mine=true");
        check("mine=true needs a signed-in user", anonMine.status === 401, `status ${anonMine.status}`);
        const search = await call("GET", `/food-items?name=${token}`);
        const searchIds = ((search.data as any[]) ?? []).map((f) => f.id);
        check("name search finds the public item only", search.status === 200 && searchIds.includes(spice.data?.id) && !searchIds.includes(drinkId), short(searchIds));
        const typed = await call("GET", `/food-items?name=${token}&type=drink`);
        check("type filter excludes the spice", typed.status === 200 && (typed.data as any[]).length === 0, `n=${typed.data?.length}`);

        // ── Edits ──
        const vendorPut = await call("PUT", `/food-items/${drinkId}`, vendor.token, { name: "hijack" });
        check("vendor can't edit the member's item", vendorPut.status === 403, `status ${vendorPut.status}`);
        const system = ((await call("GET", "/food-items?page_size=100")).data as any[]).find((f) => f.is_system);
        const sysPut = await call("PUT", `/food-items/${system?.id}`, member.token, { name: "hijack" });
        check("member can't edit a system food item", sysPut.status === 403, `status ${sysPut.status}`);
        const sysDel = await call("DELETE", `/food-items/${system?.id}`, trainer.token);
        check("trainer can't delete a system food item", sysDel.status === 403, `status ${sysDel.status}`);
        const missing = await call("PUT", `/food-items/${crypto.randomUUID()}`, member.token, { name: "x" });
        check("updating an unknown food item is 404", missing.status === 404, `status ${missing.status}`);
        const empty = await call("PUT", `/food-items/${drinkId}`, member.token, {});
        check("empty food item update is 400", empty.status === 400, `status ${empty.status}`);
        const badUnit = await call("PUT", `/food-items/${drinkId}`, member.token, { serving_unit: "oz" });
        check("PUT validates serving_unit", badUnit.status === 400, `status ${badUnit.status}`);
        const halfType = await call("PUT", `/food-items/${drinkId}`, member.token, { type: "food" });
        check("changing type without a matching subtype is 400", halfType.status === 400, `status ${halfType.status}`);
        const retype = await call("PUT", `/food-items/${drinkId}`, member.token, {
          type: "food", food_subtype: "fruit", drink_subtype: null, serving_unit: "g", is_public: true, kcal_per_100: 60, vitamins: [],
        });
        check(
          "member retypes, publishes and clears vitamins (minerals untouched)",
          retype.status === 200 && retype.data.type === "food" && retype.data.food_subtype === "fruit" && retype.data.drink_subtype === null &&
            retype.data.is_public === true && near(retype.data.kcal_per_100, 60) && retype.data.vitamins.length === 0 && retype.data.minerals.length === 1,
          short(retype.data),
        );
        const vendorSees = await call("GET", `/food-items/${drinkId}`, vendor.token);
        check("the published item is readable by others", vendorSees.status === 200, `status ${vendorSees.status}`);

        // ── Barcode lookup: own item first, then public (never reaches Open Food Facts here) ──
        const own = await call("GET", `/food-items/barcode/${barcode}`, member.token);
        check("member's barcode lookup finds the own item", own.status === 200 && own.data.id === drinkId && own.data.source === "local", short(own.data?.id));
        const shared = await call("GET", `/food-items/barcode/${barcode}`, vendor.token);
        check("vendor's lookup finds the member's public item", shared.status === 200 && shared.data.id === drinkId && shared.data.source === "local", short(shared.data?.id));
        const vendorItem = await call("POST", "/food-items", vendor.token, { name: `${token} vendor juice`, barcode, type: "drink", drink_subtype: "smoothie", is_public: false });
        if (vendorItem.data?.id) ids.push({ id: vendorItem.data.id, token: vendor.token });
        const ownFirst = await call("GET", `/food-items/barcode/${barcode}`, vendor.token);
        check("vendor's own item wins over someone else's public one", vendorItem.status === 201 && ownFirst.data?.id === vendorItem.data.id, short(ownFirst.data?.id));
        const stillMine = await call("GET", `/food-items/barcode/${barcode}`, member.token);
        check("member never gets the vendor's private item", stillMine.status === 200 && stillMine.data.id === drinkId, short(stillMine.data?.id));
        const padded = await call("GET", `/food-items/barcode/%20${barcode}%20`, member.token);
        check("barcode is trimmed", padded.status === 200 && padded.data.id === drinkId, `status ${padded.status}`);
        const tooShort = await call("GET", "/food-items/barcode/12345", member.token);
        check("barcode under 6 digits is 400", tooShort.status === 400, `status ${tooShort.status}`);

        // ── Delete ──
        const vendorDel = await call("DELETE", `/food-items/${drinkId}`, vendor.token);
        check("vendor can't delete the member's item", vendorDel.status === 403, `status ${vendorDel.status}`);
        const delMissing = await call("DELETE", `/food-items/${crypto.randomUUID()}`, member.token);
        check("deleting an unknown food item is 404", delMissing.status === 404, `status ${delMissing.status}`);
        for (const item of [...ids]) {
          const del = await call("DELETE", `/food-items/${item.id}`, item.token);
          check("author deletes the food item", del.status === 204, `status ${del.status}`);
          if (del.status === 204) ids.splice(ids.indexOf(item), 1);
        }
        const gone = await call("GET", `/food-items/${drinkId}`);
        check("a deleted food item is 404", gone.status === 404, `status ${gone.status}`);
      } finally {
        for (const item of ids) await call("DELETE", `/food-items/${item.id}`, item.token);
      }
      assertAll();
    });

    await t.step("25. recipes: ingredients → computed macros, privacy, propagation", async () => {
      const foodIds: string[] = [];
      const recipeIds: string[] = [];
      try {
        const name = uniq();
        const token = word();
        const oats = await call("POST", "/food-items", member.token, {
          name: `${name} oats`, type: "food", food_subtype: "grain_cereal", is_public: false,
          kcal_per_100: 200, protein_per_100: 10, carb_per_100: 20, fat_per_100: 5, fiber_per_100: 2,
        });
        const berries = await call("POST", "/food-items", member.token, {
          name: `${name} berries`, type: "food", food_subtype: "fruit", is_public: false,
          kcal_per_100: 50, protein_per_100: 1, carb_per_100: 10, fat_per_100: 0, fiber_per_100: 3,
        });
        for (const r of [oats, berries]) if (r.data?.id) foodIds.push(r.data.id);
        check("member creates two private ingredients", oats.status === 201 && berries.status === 201, `${oats.status} ${berries.status}`);
        assertAll();

        const created = await call("POST", "/recipes", member.token, {
          name: `${token} porridge`, servings: 2, prep_time_minutes: 5, kcal_per_serving: 9999,
          ingredients: [{ food_item_id: oats.data.id, quantity: 150, note: "rolled" }, { food_item_id: berries.data.id, quantity: 100 }, { quantity: 5 }],
          steps: [{ instruction: "Mix" }, { instruction: "Bake", image_url: "https://example.com/s.jpg" }],
          images: [{ url: "https://example.com/p.jpg" }], videos: [{ url: "https://example.com/v.mp4", title: "How" }],
        });
        const recipeId = created.data?.id;
        if (recipeId) recipeIds.push(recipeId);
        // (150 g oats + 100 g berries) / 2 servings; client-sent macros are ignored.
        check(
          "member creates a recipe; per-serving macros are computed from the ingredients",
          created.status === 201 && created.data.is_public === false && near(created.data.kcal_per_serving, 175) &&
            near(created.data.protein_per_serving, 8) && near(created.data.carb_per_serving, 20) &&
            near(created.data.fat_per_serving, 3.75) && near(created.data.fiber_per_serving, 3) &&
            created.data.ingredients.length === 2 && created.data.ingredients[0].food_item?.name === `${name} oats` &&
            created.data.ingredients[0].note === "rolled" && created.data.steps.map((s: any) => s.instruction).join() === "Mix,Bake" &&
            created.data.images[0].is_thumbnail === true && created.data.videos[0].title === "How",
          short(created.data),
        );
        const invalid: [string, any][] = [
          ["missing name", { servings: 1 }],
          ["zero servings", { name: "x", servings: 0 }],
          ["string servings", { name: "x", servings: "2" }],
          ["fractional servings", { name: "x", servings: 1.5 }],
          ["zero ingredient quantity", { name: "x", ingredients: [{ food_item_id: oats.data.id, quantity: 0 }] }],
          ["unknown ingredient", { name: "x", ingredients: [{ food_item_id: crypto.randomUUID(), quantity: 10 }] }],
        ];
        for (const [label, body] of invalid) {
          const r = await call("POST", "/recipes", member.token, body);
          if (r.status === 201) recipeIds.push(r.data.id);
          check(`recipe: ${label} is 400`, r.status === 400, `status ${r.status}`);
        }
        const anonPost = await call("POST", "/recipes", undefined, { name: "x" });
        check("creating a recipe needs a signed-in user", anonPost.status === 401, `status ${anonPost.status}`);

        // ── Reads ──
        const vendorRead = await call("GET", `/recipes/${recipeId}`, vendor.token);
        check("vendor gets 404 for the private recipe", vendorRead.status === 404, `status ${vendorRead.status}`);
        const anonRead = await call("GET", `/recipes/${recipeId}`);
        check("anonymous gets 404 for it", anonRead.status === 404, `status ${anonRead.status}`);
        const mine = await call("GET", "/recipes?mine=true&page_size=100", member.token);
        check("mine=true lists it", mine.status === 200 && (mine.data as any[]).some((r) => r.id === recipeId), `status ${mine.status}`);
        const anonMine = await call("GET", "/recipes?mine=true");
        check("mine=true needs a signed-in user", anonMine.status === 401, `status ${anonMine.status}`);
        const hidden = await call("GET", `/recipes?name=${token}`);
        check("name search hides the private recipe", hidden.status === 200 && (hidden.data as any[]).length === 0, `n=${hidden.data?.length}`);

        // ── Edits recompute macros ──
        const moreServings = await call("PUT", `/recipes/${recipeId}`, member.token, { servings: 4 });
        check("more servings halve the per-serving macros", moreServings.status === 200 && near(moreServings.data.kcal_per_serving, 87.5), short(moreServings.data?.kcal_per_serving));
        const fewer = await call("PUT", `/recipes/${recipeId}`, member.token, { ingredients: [{ food_item_id: oats.data.id, quantity: 100 }] });
        check("replacing ingredients recomputes", fewer.status === 200 && fewer.data.ingredients.length === 1 && near(fewer.data.kcal_per_serving, 50), short(fewer.data?.kcal_per_serving));
        const richer = await call("PUT", `/food-items/${oats.data.id}`, member.token, { kcal_per_100: 300 });
        const propagated = await call("GET", `/recipes/${recipeId}`, member.token);
        check("a food item macro edit propagates to the recipe", richer.status === 200 && near(propagated.data?.kcal_per_serving, 75), short(propagated.data?.kcal_per_serving));
        const inUse = await call("DELETE", `/food-items/${oats.data.id}`, member.token);
        check("an ingredient in use can't be deleted", inUse.status === 409, `status ${inUse.status}`);

        const vendorPut = await call("PUT", `/recipes/${recipeId}`, vendor.token, { name: "hijack" });
        check("vendor can't edit the recipe", vendorPut.status === 403, `status ${vendorPut.status}`);
        const missing = await call("PUT", `/recipes/${crypto.randomUUID()}`, member.token, { name: "x" });
        check("updating an unknown recipe is 404", missing.status === 404, `status ${missing.status}`);
        const empty = await call("PUT", `/recipes/${recipeId}`, member.token, {});
        check("empty recipe update is 400", empty.status === 400, `status ${empty.status}`);
        const negative = await call("PUT", `/recipes/${recipeId}`, member.token, { servings: -1 });
        check("PUT validates servings", negative.status === 400, `status ${negative.status}`);
        const publish = await call("PUT", `/recipes/${recipeId}`, member.token, { is_public: true, steps: [] });
        check("member publishes and clears the steps", publish.status === 200 && publish.data.is_public === true && publish.data.steps.length === 0 && publish.data.images.length === 1, short(publish.data));
        const found = await call("GET", `/recipes?name=${token}`);
        check("name search finds the published recipe", found.status === 200 && (found.data as any[]).some((r) => r.id === recipeId), `n=${found.data?.length}`);
        const vendorNow = await call("GET", `/recipes/${recipeId}`, vendor.token);
        check("vendor reads the published recipe", vendorNow.status === 200, `status ${vendorNow.status}`);

        // ── Delete ──
        const vendorDel = await call("DELETE", `/recipes/${recipeId}`, vendor.token);
        check("vendor can't delete the recipe", vendorDel.status === 403, `status ${vendorDel.status}`);
        const delMissing = await call("DELETE", `/recipes/${crypto.randomUUID()}`, member.token);
        check("deleting an unknown recipe is 404", delMissing.status === 404, `status ${delMissing.status}`);
        const del = await call("DELETE", `/recipes/${recipeId}`, member.token);
        check("author deletes the recipe", del.status === 204, `status ${del.status}`);
        if (del.status === 204) recipeIds.splice(recipeIds.indexOf(recipeId), 1);
        const oatsDel = await call("DELETE", `/food-items/${oats.data.id}`, member.token);
        check("then the ingredient can be deleted", oatsDel.status === 204, `status ${oatsDel.status}`);
        if (oatsDel.status === 204) foodIds.splice(foodIds.indexOf(oats.data.id), 1);
      } finally {
        for (const id of recipeIds) await call("DELETE", `/recipes/${id}`, member.token);
        for (const id of foodIds) await call("DELETE", `/food-items/${id}`, member.token);
      }
      assertAll();
    });

    await t.step("26. daily and weekly meal plans; trainer assigns one; assigned access and diary", async () => {
      let foodId: string | null = null;
      let recipeId: string | null = null;
      let dailyId: string | null = null;
      let planId: string | null = null;
      let assignmentId: string | null = null;
      const strayDaily: string[] = [];
      const strayPlans: string[] = [];
      const strayAssignments: string[] = [];
      const logIds: string[] = [];
      try {
        const name = uniq();
        // A far-future day no other suite logs on; the assignment starts that day.
        const date = dayFromToday(800 + (Date.now() % 100));
        const food = await call("POST", "/food-items", trainer.token, {
          name: `${name} chicken`, type: "food", food_subtype: "poultry", is_public: false,
          kcal_per_100: 100, protein_per_100: 10, carb_per_100: 5, fat_per_100: 2, fiber_per_100: 1,
        });
        foodId = food.data?.id ?? null;
        const recipe = await call("POST", "/recipes", trainer.token, { name: `${name} bowl`, servings: 1, ingredients: [{ food_item_id: foodId, quantity: 200 }] });
        recipeId = recipe.data?.id ?? null;
        check("trainer creates a private food item and recipe", food.status === 201 && recipe.status === 201 && near(recipe.data.kcal_per_serving, 200), short(recipe.data));
        assertAll();

        // ── Daily meal plan: totals are derived from the entries ──
        const daily = await call("POST", "/daily-meal-plans", trainer.token, {
          name: `${name} day`, kcal_total: 1,
          slots: [
            { slot_type: "breakfast", entries: [{ food_item_id: foodId, quantity: 150 }, { note: "no source, skipped" }] },
            { slot_type: "lunch", note: "main", entries: [{ recipe_id: recipeId, servings: 2 }] },
          ],
        });
        dailyId = daily.data?.id ?? null;
        check(
          "trainer creates a daily plan; totals come from its entries",
          daily.status === 201 && daily.data.is_public === false && near(daily.data.kcal_total, 550) && near(daily.data.protein_total, 55) &&
            daily.data.slots.length === 2 && daily.data.slots[0].entries.length === 1 &&
            daily.data.slots[0].entries[0].food_item?.name === `${name} chicken` && daily.data.slots[1].note === "main" &&
            daily.data.slots[1].entries[0].recipe?.name === `${name} bowl`,
          short(daily.data),
        );
        const invalidDaily: [string, any][] = [
          ["missing name", { slots: [] }],
          ["entry with both a food item and a recipe", { name: "x", slots: [{ entries: [{ food_item_id: foodId, recipe_id: recipeId, quantity: 1 }] }] }],
          ["food entry without a quantity", { name: "x", slots: [{ entries: [{ food_item_id: foodId }] }] }],
          ["unknown recipe", { name: "x", slots: [{ entries: [{ recipe_id: crypto.randomUUID() }] }] }],
        ];
        for (const [label, body] of invalidDaily) {
          const r = await call("POST", "/daily-meal-plans", trainer.token, body);
          if (r.status === 201) strayDaily.push(r.data.id);
          check(`daily plan: ${label} is 400`, r.status === 400, `status ${r.status}`);
        }
        const defaultSlot = await call("POST", "/daily-meal-plans", trainer.token, { name: `${name} x`, slots: [{ slot_type: "brunch" }] });
        if (defaultSlot.data?.id) strayDaily.push(defaultSlot.data.id);
        check("unknown slot_type falls back to breakfast", defaultSlot.status === 201 && defaultSlot.data.slots[0].slot_type === "breakfast" && near(defaultSlot.data.kcal_total, 0), short(defaultSlot.data?.slots));

        const memberDaily = await call("GET", `/daily-meal-plans/${dailyId}`, member.token);
        check("member can't read the private daily plan yet", memberDaily.status === 404, `status ${memberDaily.status}`);
        const mineDaily = await call("GET", "/daily-meal-plans?mine=true&page_size=100", trainer.token);
        check("mine=true lists it with its meal count", mineDaily.status === 200 && (mineDaily.data as any[]).some((d) => d.id === dailyId && d.meal_count === 2), `status ${mineDaily.status}`);
        const anonMine = await call("GET", "/daily-meal-plans?mine=true");
        check("mine=true needs a signed-in user", anonMine.status === 401, `status ${anonMine.status}`);
        const memberPut = await call("PUT", `/daily-meal-plans/${dailyId}`, member.token, { name: "hijack" });
        check("member can't edit the trainer's daily plan", memberPut.status === 403, `status ${memberPut.status}`);
        const emptyPut = await call("PUT", `/daily-meal-plans/${dailyId}`, trainer.token, {});
        check("empty daily plan update is 400", emptyPut.status === 400, `status ${emptyPut.status}`);
        const missingDaily = await call("PUT", `/daily-meal-plans/${crypto.randomUUID()}`, trainer.token, { name: "x" });
        check("updating an unknown daily plan is 404", missingDaily.status === 404, `status ${missingDaily.status}`);
        const addSnack = await call("PUT", `/daily-meal-plans/${dailyId}`, trainer.token, {
          slots: [
            { slot_type: "breakfast", entries: [{ food_item_id: foodId, quantity: 150 }] },
            { slot_type: "lunch", entries: [{ recipe_id: recipeId, servings: 2 }] },
            { slot_type: "evening_snack", entries: [{ food_item_id: foodId, quantity: 50 }] },
          ],
        });
        check("replacing slots recomputes the totals", addSnack.status === 200 && addSnack.data.slots.length === 3 && near(addSnack.data.kcal_total, 600), short(addSnack.data?.kcal_total));
        const halfRecipe = await call("PUT", `/recipes/${recipeId}`, trainer.token, { servings: 2 });
        const dailyAfter = await call("GET", `/daily-meal-plans/${dailyId}`, trainer.token);
        // Recipe is now 100 kcal a serving: 150 + 2 × 100 + 50.
        check("a recipe change propagates to the daily plan totals", halfRecipe.status === 200 && near(dailyAfter.data?.kcal_total, 400), short(dailyAfter.data?.kcal_total));

        // ── Weekly meal plan ──
        const plan = await call("POST", "/meal-plans", trainer.token, {
          name: `${name} plan`, num_weeks: 1, images: [{ url: "https://example.com/m.jpg" }],
          days: [{ daily_meal_plan_id: dailyId, week_number: 1, day_of_week: isoDow(date) }, { week_number: 1, day_of_week: 1 }],
        });
        planId = plan.data?.id ?? null;
        check(
          "trainer creates a private meal plan from the daily plan",
          plan.status === 201 && plan.data.is_public === false && plan.data.days.length === 1 && plan.data.days[0].day_of_week === isoDow(date) &&
            plan.data.days[0].daily_meal_plan?.id === dailyId && plan.data.images[0].is_thumbnail === true,
          short(plan.data),
        );
        const invalidPlans: [string, any, number][] = [
          ["missing name", { num_weeks: 1 }, 400],
          ["num_weeks above 4", { name: "x", num_weeks: 5 }, 400],
          ["string num_weeks", { name: "x", num_weeks: "2" }, 400],
          ["day_of_week 8", { name: "x", days: [{ daily_meal_plan_id: dailyId, week_number: 1, day_of_week: 8 }] }, 400],
          ["unknown daily plan", { name: "x", days: [{ daily_meal_plan_id: crypto.randomUUID(), week_number: 1, day_of_week: 1 }] }, 400],
          ["the same day twice", {
            name: "x", days: [{ daily_meal_plan_id: dailyId, week_number: 1, day_of_week: 2 }, { daily_meal_plan_id: dailyId, week_number: 1, day_of_week: 2 }],
          }, 409],
        ];
        for (const [label, body, want] of invalidPlans) {
          const r = await call("POST", "/meal-plans", trainer.token, body);
          if (r.status === 201) strayPlans.push(r.data.id);
          check(`meal plan: ${label} is ${want}`, r.status === want, `status ${r.status}`);
        }
        const dailyInUse = await call("DELETE", `/daily-meal-plans/${dailyId}`, trainer.token);
        check("a daily plan used by a meal plan can't be deleted", dailyInUse.status === 409, `status ${dailyInUse.status}`);
        const recipeInUse = await call("DELETE", `/recipes/${recipeId}`, trainer.token);
        check("a recipe used by a daily plan can't be deleted", recipeInUse.status === 409, `status ${recipeInUse.status}`);
        const foodInUse = await call("DELETE", `/food-items/${foodId}`, trainer.token);
        check("a food item used by a recipe/daily plan can't be deleted", foodInUse.status === 409, `status ${foodInUse.status}`);
        const before = await call("GET", `/meal-plans/${planId}`, member.token);
        check("member can't read the private meal plan before it's assigned", before.status === 404, `status ${before.status}`);

        // ── Assignment ──
        const selfAssign = await call("POST", "/meal-plan-assignments", member.token, { meal_plan_id: planId, user_id: member.profile.id });
        if (selfAssign.status === 201) strayAssignments.push(selfAssign.data.id);
        check("member can't self-assign the trainer's private plan", selfAssign.status === 403, `status ${selfAssign.status}`);
        const invalidAsg: [string, any, number][] = [
          ["missing user_id", { meal_plan_id: planId }, 400],
          ["unknown meal plan", { meal_plan_id: crypto.randomUUID(), user_id: member.profile.id }, 404],
          ["unknown user", { meal_plan_id: planId, user_id: crypto.randomUUID() }, 404],
          ["end_date before start_date", { meal_plan_id: planId, user_id: member.profile.id, start_date: date, end_date: dayFromToday(1) }, 400],
          ["unparseable start_date", { meal_plan_id: planId, user_id: member.profile.id, start_date: "someday" }, 400],
        ];
        for (const [label, body, want] of invalidAsg) {
          const r = await call("POST", "/meal-plan-assignments", trainer.token, body);
          if (r.status === 201) strayAssignments.push(r.data.id);
          check(`assignment: ${label} is ${want}`, r.status === want, `status ${r.status}`);
        }
        const asg = await call("POST", "/meal-plan-assignments", trainer.token, { meal_plan_id: planId, user_id: member.profile.id, start_date: date, note: "cut" });
        assignmentId = asg.data?.id ?? null;
        check(
          "trainer assigns the private plan to the member",
          asg.status === 201 && asg.data.meal_plan?.id === planId && asg.data.meal_plan_name === `${name} plan` &&
            asg.data.assigned_by_id === trainer.profile.id && !!asg.data.assigned_by_name && !!asg.data.user_name &&
            String(asg.data.start_date).slice(0, 10) === date && asg.data.note === "cut",
          short(asg.data),
        );
        const notice = (await notificationsOf(member.token)).find((n) => n.metadata?.assignment_id === assignmentId);
        check("member is notified", notice?.type === "training" && notice.metadata.meal_plan_id === planId, short(notice));

        for (const [label, path] of [["meal plan", `/meal-plans/${planId}`], ["daily plan", `/daily-meal-plans/${dailyId}`], ["recipe", `/recipes/${recipeId}`], ["food item", `/food-items/${foodId}`]]) {
          const own = await call("GET", path, member.token);
          check(`assigned member reads the private ${label}`, own.status === 200, `status ${own.status}`);
          const stranger = await call("GET", path, vendor.token);
          check(`vendor still gets 404 for the ${label}`, stranger.status === 404, `status ${stranger.status}`);
        }
        const staff = await call("GET", `/meal-plans/${planId}`, employee.token);
        check("gym staff coaching the member read the plan", staff.status === 200, `status ${staff.status}`);
        const coachList = await call("GET", `/meal-plan-assignments?user_id=${member.profile.id}`, employee.token);
        check("gym staff list the member's assignments", coachList.status === 200 && (coachList.data as any[]).some((a) => a.id === assignmentId), `status ${coachList.status}`);
        const vendorByPlan = await call("GET", `/meal-plan-assignments?meal_plan_id=${planId}`, vendor.token);
        check("vendor's meal_plan_id listing filters out the member's row", vendorByPlan.status === 200 && (vendorByPlan.data as any[]).length === 0, `n=${vendorByPlan.data?.length}`);
        const memberByPlan = await call("GET", `/meal-plan-assignments?meal_plan_id=${planId}`, member.token);
        check("member sees the assignment by plan", memberByPlan.status === 200 && (memberByPlan.data as any[]).some((a) => a.id === assignmentId), `status ${memberByPlan.status}`);

        // ── The assigned plan drives the diary for that day ──
        const summary = await call("GET", `/food-logs/summary?date=${date}`, member.token);
        const plannedSlots = (summary.data?.planned as any[]) ?? [];
        check(
          "diary summary shows the plan's targets and planned meals",
          summary.status === 200 && summary.data.plan?.assignment_id === assignmentId && summary.data.plan.daily_meal_plan_id === dailyId &&
            summary.data.plan.week_number === 1 && near(summary.data.targets?.kcal, 400) &&
            plannedSlots.map((s) => s.slot_type).join() === "breakfast,lunch,evening_snack" &&
            plannedSlots[1].entries[0].unit === "serving" && near(plannedSlots[1].entries[0].kcal, 200),
          short(summary.data?.plan),
        );
        const fromPlan = await call("POST", "/food-logs/from-plan", member.token, { date, slot_type: "breakfast" });
        if (Array.isArray(fromPlan.data)) logIds.push(...fromPlan.data.map((r: any) => r.id));
        check(
          "from-plan logs just the breakfast slot",
          fromPlan.status === 201 && fromPlan.data.length === 1 && fromPlan.data[0].slot_type === "breakfast" &&
            fromPlan.data[0].food_item_id === foodId && near(fromPlan.data[0].kcal, 150) && fromPlan.data[0].log_date === date,
          short(fromPlan.data),
        );
        const direct = await call("POST", "/food-logs", member.token, { log_date: date, slot_type: "dinner", food_item_id: foodId, amount: 100 });
        if (direct.data?.id) logIds.push(direct.data.id);
        check("assigned member logs the plan's private food item", direct.status === 201 && near(direct.data.kcal, 100), short(direct.data));
        const vendorLog = await call("POST", "/food-logs", vendor.token, { log_date: date, slot_type: "dinner", food_item_id: foodId, amount: 100 });
        if (vendorLog.status === 201) await call("DELETE", `/food-logs/${vendorLog.data.id}`, vendor.token);
        check("vendor can't log it", vendorLog.status === 404, `status ${vendorLog.status}`);
        const coachSummary = await call("GET", `/food-logs/summary?date=${date}&user_id=${member.profile.id}`, trainer.token);
        check(
          "trainer sees the member's totals against the plan",
          coachSummary.status === 200 && near(coachSummary.data.totals.kcal, 250) && near(coachSummary.data.targets?.kcal, 400) &&
            coachSummary.data.slots.map((s: any) => `${s.slot_type}:${s.count}`).join() === "breakfast:1,dinner:1",
          short(coachSummary.data?.totals),
        );

        // ── Edits and publishing ──
        const memberPlanPut = await call("PUT", `/meal-plans/${planId}`, member.token, { name: "hijack" });
        check("assigned member still can't edit the plan", memberPlanPut.status === 403, `status ${memberPlanPut.status}`);
        const emptyPlanPut = await call("PUT", `/meal-plans/${planId}`, trainer.token, {});
        check("empty meal plan update is 400", emptyPlanPut.status === 400, `status ${emptyPlanPut.status}`);
        const zeroWeeks = await call("PUT", `/meal-plans/${planId}`, trainer.token, { num_weeks: 0 });
        check("PUT validates num_weeks", zeroWeeks.status === 400, `status ${zeroWeeks.status}`);
        const missingPlan = await call("PUT", `/meal-plans/${crypto.randomUUID()}`, trainer.token, { name: "x" });
        check("updating an unknown meal plan is 404", missingPlan.status === 404, `status ${missingPlan.status}`);
        const publish = await call("PUT", `/meal-plans/${planId}`, trainer.token, {
          is_public: true, num_weeks: 2,
          days: [{ daily_meal_plan_id: dailyId, week_number: 1, day_of_week: 1 }, { daily_meal_plan_id: dailyId, week_number: 2, day_of_week: 1 }],
        });
        check(
          "trainer publishes a 2-week version, keeping images",
          publish.status === 200 && publish.data.is_public === true && publish.data.num_weeks === 2 && publish.data.days.length === 2 &&
            publish.data.days[1].week_number === 2 && publish.data.images.length === 1,
          short(publish.data),
        );
        const listed = await call("GET", `/meal-plans?name=${encodeURIComponent(name)}`);
        const row = (listed.data as any[])?.find((p) => p.id === planId);
        check("the public list shows it with its thumbnail", listed.status === 200 && row?.images?.[0]?.url === "https://example.com/m.jpg", short(row));
        const mine = await call("GET", "/meal-plans?mine=true&page_size=100", trainer.token);
        check("mine=true lists it", mine.status === 200 && (mine.data as any[]).some((p) => p.id === planId), `status ${mine.status}`);

        // ── Removing the assignment revokes access to the private parts ──
        const vendorDel = await call("DELETE", `/meal-plan-assignments/${assignmentId}`, vendor.token);
        check("vendor can't remove the assignment", vendorDel.status === 403, `status ${vendorDel.status}`);
        const delMissing = await call("DELETE", `/meal-plan-assignments/${crypto.randomUUID()}`, trainer.token);
        check("removing an unknown assignment is 404", delMissing.status === 404, `status ${delMissing.status}`);
        const unassign = await call("DELETE", `/meal-plan-assignments/${assignmentId}`, trainer.token);
        check("trainer removes the assignment", unassign.status === 204, `status ${unassign.status}`);
        if (unassign.status === 204) {
          await deleteNotifications(member.token, (n) => n.metadata?.assignment_id === assignmentId);
          assignmentId = null;
        }
        const revoked = await call("GET", `/recipes/${recipeId}`, member.token);
        check("member loses access to the plan's private recipe", revoked.status === 404, `status ${revoked.status}`);
        const after = await call("GET", `/food-logs/summary?date=${date}`, member.token);
        check("the diary no longer follows the removed plan", after.status === 200 && after.data.plan?.meal_plan_id !== planId && near(after.data.totals.kcal, 250), short(after.data?.plan));

        // ── Delete, top down ──
        const memberPlanDel = await call("DELETE", `/meal-plans/${planId}`, member.token);
        check("member can't delete the plan", memberPlanDel.status === 403, `status ${memberPlanDel.status}`);
        const planDelMissing = await call("DELETE", `/meal-plans/${crypto.randomUUID()}`, trainer.token);
        check("deleting an unknown meal plan is 404", planDelMissing.status === 404, `status ${planDelMissing.status}`);
        const dailyDelMissing = await call("DELETE", `/daily-meal-plans/${crypto.randomUUID()}`, trainer.token);
        check("deleting an unknown daily plan is 404", dailyDelMissing.status === 404, `status ${dailyDelMissing.status}`);
        const memberDailyDel = await call("DELETE", `/daily-meal-plans/${dailyId}`, member.token);
        check("member can't delete the daily plan", memberDailyDel.status === 403, `status ${memberDailyDel.status}`);
        const delPlan = await call("DELETE", `/meal-plans/${planId}`, trainer.token);
        if (delPlan.status === 204) planId = null;
        const delDaily = await call("DELETE", `/daily-meal-plans/${dailyId}`, trainer.token);
        if (delDaily.status === 204) dailyId = null;
        check("trainer deletes the meal plan, then the daily plan", delPlan.status === 204 && delDaily.status === 204, `${delPlan.status} ${delDaily.status}`);
      } finally {
        for (const id of logIds) await call("DELETE", `/food-logs/${id}`, member.token);
        if (assignmentId) {
          await deleteNotifications(member.token, (n) => n.metadata?.assignment_id === assignmentId);
          await call("DELETE", `/meal-plan-assignments/${assignmentId}`, trainer.token);
        }
        for (const id of strayAssignments) await call("DELETE", `/meal-plan-assignments/${id}`, superU.token);
        for (const id of [...strayPlans, planId]) if (id) await call("DELETE", `/meal-plans/${id}`, trainer.token);
        for (const id of [...strayDaily, dailyId]) if (id) await call("DELETE", `/daily-meal-plans/${id}`, trainer.token);
        if (recipeId) await call("DELETE", `/recipes/${recipeId}`, trainer.token);
        if (foodId) await call("DELETE", `/food-items/${foodId}`, trainer.token);
      }
      assertAll();
    });

    await t.step("27. food log edits: switching items, deleted items, ranges, validation", async () => {
      let foodId: string | null = null;
      let recipeId: string | null = null;
      const logIds: string[] = [];
      try {
        const name = uniq();
        const offset = 920 + (Date.now() % 50);
        const date = dayFromToday(offset);
        const seededFood = ((await call("GET", "/food-items?page_size=20")).data as any[]).find((f) => Number(f.kcal_per_100) > 0);
        const food = await call("POST", "/food-items", member.token, { name: `${name} egg`, type: "food", food_subtype: "egg", kcal_per_100: 100, is_public: false });
        foodId = food.data?.id ?? null;
        const recipe = await call("POST", "/recipes", member.token, { name: `${name} toast`, ingredients: [{ food_item_id: seededFood?.id, quantity: 100 }] });
        recipeId = recipe.data?.id ?? null;
        check("member creates a private food item and recipe", food.status === 201 && recipe.status === 201, `${food.status} ${recipe.status}`);
        assertAll();

        const invalid: [string, any, number][] = [
          ["impossible log_date", { log_date: "2026-13-45", slot_type: "lunch", food_item_id: foodId, amount: 1 }, 400],
          ["string amount", { log_date: date, slot_type: "lunch", food_item_id: foodId, amount: "5" }, 400],
          ["neither food item nor recipe", { log_date: date, slot_type: "lunch", amount: 5 }, 400],
          ["unknown recipe", { log_date: date, slot_type: "lunch", recipe_id: crypto.randomUUID(), amount: 1 }, 404],
        ];
        for (const [label, body, want] of invalid) {
          const r = await call("POST", "/food-logs", member.token, body);
          if (r.status === 201) logIds.push(r.data.id);
          check(`food log: ${label} is ${want}`, r.status === want, `status ${r.status}`);
        }
        const vendorRecipe = await call("POST", "/food-logs", vendor.token, { log_date: date, slot_type: "lunch", recipe_id: recipeId, amount: 1 });
        if (vendorRecipe.status === 201) await call("DELETE", `/food-logs/${vendorRecipe.data.id}`, vendor.token);
        check("another user can't log the member's private recipe", vendorRecipe.status === 404, `status ${vendorRecipe.status}`);

        // ── Switching the logged item recomputes the snapshot ──
        const e1 = await call("POST", "/food-logs", member.token, { log_date: date, slot_type: "breakfast", food_item_id: foodId, amount: 200 });
        if (e1.data?.id) logIds.push(e1.data.id);
        check("member logs 200 g of the food item", e1.status === 201 && near(e1.data.kcal, 200) && e1.data.unit === "g", short(e1.data));
        const toRecipe = await call("PUT", `/food-logs/${e1.data?.id}`, member.token, { food_item_id: null, recipe_id: recipeId, amount: 1 });
        check(
          "PUT switches the entry to a recipe serving",
          toRecipe.status === 200 && toRecipe.data.recipe_id === recipeId && toRecipe.data.food_item_id === null && toRecipe.data.unit === "serving" &&
            toRecipe.data.name === `${name} toast` && near(toRecipe.data.kcal, Number(recipe.data?.kcal_per_serving)),
          short(toRecipe.data),
        );
        const both = await call("PUT", `/food-logs/${e1.data?.id}`, member.token, { food_item_id: foodId, recipe_id: recipeId });
        check("switching to both a food item and a recipe is 400", both.status === 400, `status ${both.status}`);
        const badDate = await call("PUT", `/food-logs/${e1.data?.id}`, member.token, { log_date: "tomorrow" });
        check("PUT validates log_date", badDate.status === 400, `status ${badDate.status}`);
        const badSlot = await call("PUT", `/food-logs/${e1.data?.id}`, member.token, { slot_type: "brunch" });
        check("PUT validates slot_type", badSlot.status === 400, `status ${badSlot.status}`);
        const zero = await call("PUT", `/food-logs/${e1.data?.id}`, member.token, { amount: 0 });
        check("PUT validates amount", zero.status === 400, `status ${zero.status}`);
        const moved = await call("PUT", `/food-logs/${e1.data?.id}`, member.token, { log_date: dayFromToday(offset + 1), note: "  later  " });
        check("PUT moves the entry to another day and trims the note", moved.status === 200 && moved.data.log_date === dayFromToday(offset + 1) && moved.data.note === "later", short(moved.data));
        const missing = await call("PUT", `/food-logs/${crypto.randomUUID()}`, member.token, { note: "x" });
        check("updating an unknown entry is 404", missing.status === 404, `status ${missing.status}`);
        const delMissing = await call("DELETE", `/food-logs/${crypto.randomUUID()}`, member.token);
        check("deleting an unknown entry is 404", delMissing.status === 404, `status ${delMissing.status}`);

        // ── Deleting the food item keeps the diary snapshot ──
        const e2 = await call("POST", "/food-logs", member.token, { log_date: date, slot_type: "lunch", food_item_id: foodId, amount: 50 });
        if (e2.data?.id) logIds.push(e2.data.id);
        const delFood = await call("DELETE", `/food-items/${foodId}`, member.token);
        check("a food item referenced only by the diary can be deleted", e2.status === 201 && delFood.status === 204, `${e2.status} ${delFood.status}`);
        if (delFood.status === 204) foodId = null;
        const day = await call("GET", `/food-logs?date=${date}`, member.token);
        const kept = (day.data as any[])?.find((r) => r.id === e2.data?.id);
        check("the entry keeps its name and macros", day.status === 200 && kept?.food_item_id === null && kept.name === `${name} egg` && near(kept.kcal, 50), short(kept));
        const reamount = await call("PUT", `/food-logs/${e2.data?.id}`, member.token, { amount: 10 });
        check("changing the amount of an orphaned entry is 409", reamount.status === 409, `status ${reamount.status}`);
        const renote = await call("PUT", `/food-logs/${e2.data?.id}`, member.token, { note: "kept" });
        check("its note can still be edited", renote.status === 200 && renote.data.note === "kept" && near(renote.data.kcal, 50), short(renote.data));
        const totals = await call("GET", `/food-logs/summary?date=${date}`, member.token);
        check("the summary still counts it", totals.status === 200 && near(totals.data.totals.kcal, 50), short(totals.data?.totals));

        // ── Ranges and readers ──
        const backwards = await call("GET", `/food-logs?from=${dayFromToday(offset + 1)}&to=${date}`, member.token);
        check("to before from is 400", backwards.status === 400, `status ${backwards.status}`);
        const range = await call("GET", `/food-logs?from=${date}&to=${dayFromToday(offset + 1)}`, member.token);
        check("a from/to range spans both days", range.status === 200 && [e1.data?.id, e2.data?.id].every((id) => (range.data as any[]).some((r) => r.id === id)), `n=${range.data?.length}`);
        const badDay = await call("GET", "/food-logs?date=13-10-2026", member.token);
        check("malformed date is 400", badDay.status === 400, `status ${badDay.status}`);
        const badSummary = await call("GET", "/food-logs/summary?date=nope", member.token);
        check("malformed summary date is 400", badSummary.status === 400, `status ${badSummary.status}`);
        const badPlanDate = await call("POST", "/food-logs/from-plan", member.token, { date: "nope" });
        check("malformed from-plan date is 400", badPlanDate.status === 400, `status ${badPlanDate.status}`);
        const staff = await call("GET", `/food-logs/summary?date=${date}&user_id=${member.profile.id}`, employee.token);
        check("gym staff read the member's summary", staff.status === 200 && near(staff.data.totals.kcal, 50), `status ${staff.status}`);
        const sup = await call("GET", `/food-logs?date=${date}&user_id=${member.profile.id}`, superU.token);
        check("super user reads the member's diary", sup.status === 200 && (sup.data as any[]).some((r) => r.id === e2.data?.id), `status ${sup.status}`);
        const vendorPut = await call("PUT", `/food-logs/${e2.data?.id}`, vendor.token, { note: "x" });
        check("vendor can't edit the member's entry", vendorPut.status === 403, `status ${vendorPut.status}`);
      } finally {
        for (const id of logIds) await call("DELETE", `/food-logs/${id}`, member.token);
        if (recipeId) await call("DELETE", `/recipes/${recipeId}`, member.token);
        if (foodId) await call("DELETE", `/food-items/${foodId}`, member.token);
      }
      assertAll();
    });
  },
});
