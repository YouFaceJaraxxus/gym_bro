-- ── Enums ─────────────────────────────────────────────────────────────────────

CREATE TYPE food_item_type AS ENUM ('food', 'spice', 'drink');

CREATE TYPE food_subtype AS ENUM (
  -- Produce
  'vegetable', 'fruit', 'mushroom', 'herb_fresh',
  -- Protein
  'meat_beef', 'meat_pork', 'meat_lamb', 'meat_game', 'poultry',
  'fish', 'seafood', 'egg',
  -- Dairy & alternatives
  'dairy_milk', 'dairy_cheese', 'dairy_yogurt', 'dairy_cream', 'dairy_butter',
  'plant_milk',
  -- Grains & starches
  'grain_cereal', 'pasta_noodle', 'rice', 'bread_bakery',
  'potato_tuber', 'corn_maize',
  -- Legumes, nuts & seeds
  'legume_bean', 'legume_lentil', 'nut', 'seed',
  -- Fats & oils
  'oil_fat',
  -- Processed & packaged
  'canned_food', 'frozen_food', 'processed_meat', 'ready_meal',
  'snack_chips', 'snack_bar', 'cereal_bar',
  -- Sweets & baking
  'chocolate_candy', 'biscuit_cookie', 'sweetener', 'jam_spread',
  'baking_ingredient',
  -- Condiments & sauces
  'sauce_condiment', 'dressing',
  -- Other
  'baby_food', 'supplement_powder', 'other_food'
);

CREATE TYPE drink_subtype AS ENUM (
  'water_still', 'water_sparkling', 'water_flavoured',
  'juice_fruit', 'juice_vegetable',
  'smoothie', 'shake',
  'milk_dairy', 'milk_plant',
  'coffee', 'espresso', 'tea_black', 'tea_green', 'tea_herbal',
  'soda', 'energy_drink', 'sports_drink', 'isotonic',
  'alcohol_beer', 'alcohol_cider', 'alcohol_wine', 'alcohol_spirit', 'alcohol_cocktail',
  'protein_shake', 'meal_replacement',
  'kombucha', 'kefir_drink',
  'other_drink'
);

CREATE TYPE spice_subtype AS ENUM (
  'herb_dried', 'spice_ground', 'spice_whole', 'spice_seed',
  'seasoning_blend', 'rub', 'marinade_dry',
  'salt', 'pepper',
  'extract_essence',
  'other_spice'
);

CREATE TYPE serving_unit AS ENUM ('g', 'ml');

CREATE TYPE meal_slot_type AS ENUM (
  'breakfast',
  'morning_snack',
  'lunch',
  'afternoon_snack',
  'dinner',
  'evening_snack',
  'pre_workout',
  'post_workout'
);

-- ── Vitamin & Mineral lookup ───────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS vitamin (
  id           UUID    PRIMARY KEY DEFAULT gen_random_uuid(),
  name         TEXT    NOT NULL UNIQUE,    -- e.g. 'Vitamin C'
  symbol       TEXT,                       -- e.g. 'C', 'B12', 'D3'
  default_unit TEXT    NOT NULL DEFAULT 'mg'
);

CREATE TABLE IF NOT EXISTS mineral (
  id           UUID    PRIMARY KEY DEFAULT gen_random_uuid(),
  name         TEXT    NOT NULL UNIQUE,    -- e.g. 'Iron'
  symbol       TEXT,                       -- e.g. 'Fe'
  default_unit TEXT    NOT NULL DEFAULT 'mg'
);

-- ── Food Item ─────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS food_item (
  id              UUID           PRIMARY KEY DEFAULT gen_random_uuid(),
  name            TEXT           NOT NULL,
  brand           TEXT,
  barcode         TEXT,          -- EAN/UPC for scanner lookup
  type            food_item_type NOT NULL,
  food_subtype    food_subtype,
  drink_subtype   drink_subtype,
  spice_subtype   spice_subtype,
  serving_unit    serving_unit   NOT NULL DEFAULT 'g',
  -- Macros per 100g or 100ml
  kcal_per_100    NUMERIC(7,2)   NOT NULL DEFAULT 0,
  protein_per_100 NUMERIC(7,2)   NOT NULL DEFAULT 0,
  carb_per_100    NUMERIC(7,2)   NOT NULL DEFAULT 0,
  fat_per_100     NUMERIC(7,2)   NOT NULL DEFAULT 0,
  fiber_per_100   NUMERIC(7,2)   NOT NULL DEFAULT 0,
  author_id       UUID           REFERENCES users(id) ON DELETE SET NULL,
  is_public       BOOLEAN        NOT NULL DEFAULT TRUE,
  is_system       BOOLEAN        NOT NULL DEFAULT FALSE,
  created_at      TIMESTAMPTZ    NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ    NOT NULL DEFAULT NOW(),
  CONSTRAINT food_item_one_subtype CHECK (
    (type = 'food'  AND food_subtype  IS NOT NULL AND drink_subtype IS NULL     AND spice_subtype IS NULL) OR
    (type = 'drink' AND drink_subtype IS NOT NULL AND food_subtype  IS NULL     AND spice_subtype IS NULL) OR
    (type = 'spice' AND spice_subtype IS NOT NULL AND food_subtype  IS NULL     AND drink_subtype IS NULL)
  )
);

CREATE INDEX IF NOT EXISTS food_item_author_id_idx    ON food_item(author_id);
CREATE INDEX IF NOT EXISTS food_item_type_idx         ON food_item(type);
CREATE INDEX IF NOT EXISTS food_item_barcode_idx      ON food_item(barcode) WHERE barcode IS NOT NULL;
CREATE INDEX IF NOT EXISTS food_item_public_idx       ON food_item(is_public) WHERE is_public = TRUE;
CREATE INDEX IF NOT EXISTS food_item_name_search_idx  ON food_item USING GIN (to_tsvector('english', name));

-- ── Food Item Micronutrients ───────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS food_item_vitamin (
  food_item_id UUID           NOT NULL REFERENCES food_item(id) ON DELETE CASCADE,
  vitamin_id   UUID           NOT NULL REFERENCES vitamin(id)   ON DELETE CASCADE,
  amount_per_100 NUMERIC(10,4) NOT NULL DEFAULT 0,
  unit         TEXT,          -- overrides vitamin.default_unit if set (e.g. some vitamins use IU)
  PRIMARY KEY (food_item_id, vitamin_id)
);

CREATE TABLE IF NOT EXISTS food_item_mineral (
  food_item_id UUID           NOT NULL REFERENCES food_item(id) ON DELETE CASCADE,
  mineral_id   UUID           NOT NULL REFERENCES mineral(id)   ON DELETE CASCADE,
  amount_per_100 NUMERIC(10,4) NOT NULL DEFAULT 0,
  unit         TEXT,          -- overrides mineral.default_unit if set
  PRIMARY KEY (food_item_id, mineral_id)
);

-- ── Recipe ────────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS recipe (
  id                  UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  name                TEXT        NOT NULL,
  description         TEXT,
  author_id           UUID        REFERENCES users(id) ON DELETE SET NULL,
  servings            INT         NOT NULL DEFAULT 1 CHECK (servings > 0),
  prep_time_minutes   INT,
  cook_time_minutes   INT,
  -- Macros per serving (recomputed by app when ingredients change)
  kcal_per_serving    NUMERIC(7,2) NOT NULL DEFAULT 0,
  protein_per_serving NUMERIC(7,2) NOT NULL DEFAULT 0,
  carb_per_serving    NUMERIC(7,2) NOT NULL DEFAULT 0,
  fat_per_serving     NUMERIC(7,2) NOT NULL DEFAULT 0,
  fiber_per_serving   NUMERIC(7,2) NOT NULL DEFAULT 0,
  is_public           BOOLEAN     NOT NULL DEFAULT FALSE,
  is_system           BOOLEAN     NOT NULL DEFAULT FALSE,
  created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS recipe_author_id_idx   ON recipe(author_id);
CREATE INDEX IF NOT EXISTS recipe_public_idx      ON recipe(is_public) WHERE is_public = TRUE;
CREATE INDEX IF NOT EXISTS recipe_name_search_idx ON recipe USING GIN (to_tsvector('english', name));

-- ── Recipe Ingredients ────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS recipe_ingredient (
  id           UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
  recipe_id    UUID         NOT NULL REFERENCES recipe(id) ON DELETE CASCADE,
  food_item_id UUID         NOT NULL REFERENCES food_item(id) ON DELETE RESTRICT,
  quantity     NUMERIC(8,2) NOT NULL CHECK (quantity > 0),  -- in food_item.serving_unit
  note         TEXT,
  position     INT          NOT NULL DEFAULT 0
);

CREATE INDEX IF NOT EXISTS recipe_ingredient_recipe_id_idx ON recipe_ingredient(recipe_id);

-- ── Recipe Steps ──────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS recipe_step (
  id          UUID    PRIMARY KEY DEFAULT gen_random_uuid(),
  recipe_id   UUID    NOT NULL REFERENCES recipe(id) ON DELETE CASCADE,
  position    INT     NOT NULL DEFAULT 0,
  instruction TEXT    NOT NULL,
  image_url   TEXT
);

CREATE INDEX IF NOT EXISTS recipe_step_recipe_id_idx ON recipe_step(recipe_id);

-- ── Recipe Media ──────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS recipe_image (
  id           UUID    PRIMARY KEY DEFAULT gen_random_uuid(),
  recipe_id    UUID    NOT NULL REFERENCES recipe(id) ON DELETE CASCADE,
  url          TEXT    NOT NULL,
  is_thumbnail BOOLEAN NOT NULL DEFAULT FALSE,
  position     INT     NOT NULL DEFAULT 0
);

CREATE TABLE IF NOT EXISTS recipe_video (
  id        UUID    PRIMARY KEY DEFAULT gen_random_uuid(),
  recipe_id UUID    NOT NULL REFERENCES recipe(id) ON DELETE CASCADE,
  url       TEXT    NOT NULL,
  title     TEXT,
  position  INT     NOT NULL DEFAULT 0
);

CREATE INDEX IF NOT EXISTS recipe_image_recipe_id_idx ON recipe_image(recipe_id);
CREATE INDEX IF NOT EXISTS recipe_video_recipe_id_idx ON recipe_video(recipe_id);

-- ── Daily Meal Plan ───────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS daily_meal_plan (
  id             UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  name           TEXT        NOT NULL,
  description    TEXT,
  author_id      UUID        REFERENCES users(id) ON DELETE SET NULL,
  is_public      BOOLEAN     NOT NULL DEFAULT FALSE,
  is_system      BOOLEAN     NOT NULL DEFAULT FALSE,
  -- Totals recomputed by app when entries change
  kcal_total     NUMERIC(8,2) NOT NULL DEFAULT 0,
  protein_total  NUMERIC(7,2) NOT NULL DEFAULT 0,
  carb_total     NUMERIC(7,2) NOT NULL DEFAULT 0,
  fat_total      NUMERIC(7,2) NOT NULL DEFAULT 0,
  fiber_total    NUMERIC(7,2) NOT NULL DEFAULT 0,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at     TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS daily_meal_plan_author_id_idx   ON daily_meal_plan(author_id);
CREATE INDEX IF NOT EXISTS daily_meal_plan_public_idx      ON daily_meal_plan(is_public) WHERE is_public = TRUE;

-- ── Daily Meal Plan Slots ─────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS daily_meal_plan_slot (
  id                  UUID           PRIMARY KEY DEFAULT gen_random_uuid(),
  daily_meal_plan_id  UUID           NOT NULL REFERENCES daily_meal_plan(id) ON DELETE CASCADE,
  slot_type           meal_slot_type NOT NULL,
  position            INT            NOT NULL DEFAULT 0,
  note                TEXT
);

CREATE INDEX IF NOT EXISTS dmp_slot_plan_id_idx ON daily_meal_plan_slot(daily_meal_plan_id);

-- ── Daily Meal Plan Slot Entries (food item OR recipe) ────────────────────────

CREATE TABLE IF NOT EXISTS daily_meal_plan_slot_entry (
  id                       UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
  daily_meal_plan_slot_id  UUID         NOT NULL REFERENCES daily_meal_plan_slot(id) ON DELETE CASCADE,
  food_item_id             UUID         REFERENCES food_item(id) ON DELETE RESTRICT,
  recipe_id                UUID         REFERENCES recipe(id)    ON DELETE RESTRICT,
  -- quantity is in food_item.serving_unit (g or ml) — only used when food_item_id is set
  quantity                 NUMERIC(8,2),
  -- servings is used when recipe_id is set (e.g. 0.5 = half a recipe serving)
  servings                 NUMERIC(5,2) DEFAULT 1.0,
  position                 INT          NOT NULL DEFAULT 0,
  note                     TEXT,
  CONSTRAINT entry_has_one_source CHECK (
    (food_item_id IS NOT NULL AND recipe_id IS NULL) OR
    (food_item_id IS NULL     AND recipe_id IS NOT NULL)
  ),
  CONSTRAINT entry_quantity_present CHECK (
    (food_item_id IS NOT NULL AND quantity IS NOT NULL) OR
    (recipe_id    IS NOT NULL)
  )
);

CREATE INDEX IF NOT EXISTS dmp_slot_entry_slot_id_idx ON daily_meal_plan_slot_entry(daily_meal_plan_slot_id);

-- ── Meal Plan ─────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS meal_plan (
  id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  name        TEXT        NOT NULL,
  description TEXT,
  author_id   UUID        REFERENCES users(id) ON DELETE SET NULL,
  is_public   BOOLEAN     NOT NULL DEFAULT FALSE,
  is_system   BOOLEAN     NOT NULL DEFAULT FALSE,
  num_weeks   INT         NOT NULL DEFAULT 1 CHECK (num_weeks BETWEEN 1 AND 4),
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS meal_plan_author_id_idx ON meal_plan(author_id);
CREATE INDEX IF NOT EXISTS meal_plan_public_idx    ON meal_plan(is_public) WHERE is_public = TRUE;

CREATE TABLE IF NOT EXISTS meal_plan_image (
  id           UUID    PRIMARY KEY DEFAULT gen_random_uuid(),
  meal_plan_id UUID    NOT NULL REFERENCES meal_plan(id) ON DELETE CASCADE,
  url          TEXT    NOT NULL,
  is_thumbnail BOOLEAN NOT NULL DEFAULT FALSE,
  position     INT     NOT NULL DEFAULT 0
);

CREATE INDEX IF NOT EXISTS meal_plan_image_plan_id_idx ON meal_plan_image(meal_plan_id);

-- ── Meal Plan Days ────────────────────────────────────────────────────────────
-- Maps a week+day slot in a meal_plan to a reusable daily_meal_plan.
-- A day slot left unassigned simply has no row here.

CREATE TABLE IF NOT EXISTS meal_plan_day (
  id                 UUID    PRIMARY KEY DEFAULT gen_random_uuid(),
  meal_plan_id       UUID    NOT NULL REFERENCES meal_plan(id)       ON DELETE CASCADE,
  daily_meal_plan_id UUID    NOT NULL REFERENCES daily_meal_plan(id) ON DELETE RESTRICT,
  week_number        INT     NOT NULL CHECK (week_number >= 1),
  day_of_week        INT     NOT NULL CHECK (day_of_week BETWEEN 1 AND 7),
  note               TEXT,
  UNIQUE (meal_plan_id, week_number, day_of_week)
);

CREATE INDEX IF NOT EXISTS meal_plan_day_plan_id_idx ON meal_plan_day(meal_plan_id);

-- ── Meal Plan Assignment ──────────────────────────────────────────────────────
-- A trainer assigns a meal_plan to a gym member with an optional start date.

CREATE TABLE IF NOT EXISTS meal_plan_assignment (
  id             UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  meal_plan_id   UUID        NOT NULL REFERENCES meal_plan(id)  ON DELETE CASCADE,
  user_id        UUID        NOT NULL REFERENCES users(id)      ON DELETE CASCADE,
  assigned_by_id UUID        REFERENCES users(id)               ON DELETE SET NULL,
  start_date     DATE,
  end_date       DATE,
  note           TEXT,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT assignment_date_order CHECK (end_date IS NULL OR start_date IS NULL OR end_date >= start_date)
);

CREATE INDEX IF NOT EXISTS meal_plan_assignment_user_id_idx ON meal_plan_assignment(user_id);
CREATE INDEX IF NOT EXISTS meal_plan_assignment_plan_id_idx ON meal_plan_assignment(meal_plan_id);
