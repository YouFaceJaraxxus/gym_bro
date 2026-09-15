import type {
  ColumnType,
  Generated,
  Insertable,
  Selectable,
  Updateable,
} from "npm:kysely@^0.27";

// ── Enums ─────────────────────────────────────────────────────────────────────

export type UserRole =
  | "owner"
  | "trainer"
  | "employee"
  | "employee_trainer"
  | "member"
  | "super_user"
  | "shop_vendor";

export type BusinessType = "gym" | "shop";

export type ShopItemType = "equipment" | "supplement" | "gift_card";

export type MuscleGroup =
  | "chest_all" | "chest_upper" | "chest_lower"
  | "back_all" | "back_upper" | "back_mid" | "back_lower"
  | "back_rhomboids" | "back_traps" | "back_lats"
  | "delts_all" | "delts_front" | "delts_medial" | "delts_rear"
  | "biceps"
  | "triceps_all" | "triceps_long" | "triceps_lateral" | "triceps_medial"
  | "forearms_all" | "forearms_top" | "forearms_bottom"
  | "abs_upper" | "abs_lower" | "abs_obliques"
  | "quads_all" | "quads_medial" | "quads_lateral"
  | "hamstrings"
  | "glutes_all" | "glutes_medius" | "glutes_minimus" | "glutes_maximus"
  | "calves"
  | "neck";

export type WorkoutSetType = "standard" | "superset" | "dropset" | "circuit";

export type RepType = "count" | "failure" | "unspecified";

export type BodySide = "both" | "left" | "right";

export type RoutineScheduleType = "fixed_weeks" | "wildcard";

export type NotificationType =
  | "employee_gym_invite"
  | "vendor_shop_invite"
  | "member_invite"
  | "news"
  | "events"
  | "training"
  | "training_update"
  | "class_reminder"
  | "shop_item_update"
  | "purchase_made"
  | "membership_expiring"
  | "invoice_issued"
  | "member_subscription_extended"
  | "member_join"
  | "employee_join"
  | "vendor_join";

// ── Meal plan enums ───────────────────────────────────────────────────────────

export type FoodItemType = "food" | "spice" | "drink";

export type FoodSubtype =
  | "vegetable" | "fruit" | "mushroom" | "herb_fresh"
  | "meat_beef" | "meat_pork" | "meat_lamb" | "meat_game" | "poultry"
  | "fish" | "seafood" | "egg"
  | "dairy_milk" | "dairy_cheese" | "dairy_yogurt" | "dairy_cream" | "dairy_butter"
  | "plant_milk"
  | "grain_cereal" | "pasta_noodle" | "rice" | "bread_bakery"
  | "potato_tuber" | "corn_maize"
  | "legume_bean" | "legume_lentil" | "nut" | "seed"
  | "oil_fat"
  | "canned_food" | "frozen_food" | "processed_meat" | "ready_meal"
  | "snack_chips" | "snack_bar" | "cereal_bar"
  | "chocolate_candy" | "biscuit_cookie" | "sweetener" | "jam_spread"
  | "baking_ingredient"
  | "sauce_condiment" | "dressing"
  | "baby_food" | "supplement_powder" | "other_food";

export type DrinkSubtype =
  | "water_still" | "water_sparkling" | "water_flavoured"
  | "juice_fruit" | "juice_vegetable"
  | "smoothie" | "shake"
  | "milk_dairy" | "milk_plant"
  | "coffee" | "espresso" | "tea_black" | "tea_green" | "tea_herbal"
  | "soda" | "energy_drink" | "sports_drink" | "isotonic"
  | "alcohol_beer" | "alcohol_cider" | "alcohol_wine" | "alcohol_spirit" | "alcohol_cocktail"
  | "protein_shake" | "meal_replacement"
  | "kombucha" | "kefir_drink"
  | "other_drink";

export type SpiceSubtype =
  | "herb_dried" | "spice_ground" | "spice_whole" | "spice_seed"
  | "seasoning_blend" | "rub" | "marinade_dry"
  | "salt" | "pepper"
  | "extract_essence"
  | "other_spice";

export type ServingUnit = "g" | "ml";

export type MealSlotType =
  | "breakfast"
  | "morning_snack"
  | "lunch"
  | "afternoon_snack"
  | "dinner"
  | "evening_snack"
  | "pre_workout"
  | "post_workout";

// ── Tables ────────────────────────────────────────────────────────────────────

export interface UsersTable {
  id: Generated<string>;
  username: string;
  email: string;
  // Managed by Supabase Auth for auth-flow users; empty string for legacy rows.
  password: ColumnType<string, string | undefined, string>;
  name: string;
  last_name: string;
  role: Generated<UserRole>; // DB default: 'member'
  avatar_url: string | null;
  // Links to auth.users. Null for rows created outside the auth flow.
  auth_id: ColumnType<string | null, string | null | undefined, string | null>;
  created_at: Generated<string>;
  updated_at: Generated<string>;
}

export interface BusinessTable {
  id: Generated<string>;
  name: string;
  location: string;
  logo: string | null;
  working_hours_from: string; // TIME as HH:MM:SS string
  working_hours_to: string;
  working_weekdays: number[]; // ISO weekday ints 1–7
  type: BusinessType;
}

export interface GymTable {
  id: string; // FK → business.id (also PK)
}

export interface ShopTable {
  id: string; // FK → business.id (also PK)
}

export interface TrainerTable {
  id: Generated<string>;
  user_id: string;
  gym_id: string;
}

export interface MemberTable {
  id: Generated<string>;
  user_id: string;
  gym_id: string;
}

export interface EmployeeTable {
  id: Generated<string>;
  user_id: string;
  gym_id: string;
}

export interface EmployeeTrainerTable {
  id: Generated<string>;
  user_id: string;
  gym_id: string;
  trainer_id: string | null; // FK → trainer.id
}

export interface GymOwnerTable {
  id: Generated<string>;
  user_id: string;
  gym_id: string;
}

export interface ShopOwnerTable {
  id: Generated<string>;
  user_id: string;
  shop_id: string;
}

export interface ShopVendorTable {
  id: Generated<string>;
  user_id: string;
  shop_id: string;
}

export interface GymMembershipTypeTable {
  id: Generated<string>;
  name: string;
  monthly_cost: ColumnType<string, string | number, string | number>; // NUMERIC
  gym_id: string;
  is_active: Generated<boolean>;
}

export interface MembershipTable {
  id: Generated<string>;
  user_id: string;
  current_membership_type_id: string;
  from_date: string; // DATE as ISO string
  to_date: string;
  last_updated_date: Generated<string>;
  is_active: Generated<boolean>;
}

export interface MembershipInvoiceTable {
  id: Generated<string>;
  membership_id: string;
  membership_type_id: string;
  issued_at: Generated<string>;
  amount: ColumnType<string, string | number, string | number>; // NUMERIC
}

export interface ShopItemTable {
  id: Generated<string>;
  shop_id: string;
  type: ShopItemType;
  name: string;
  description: string | null;
  price: ColumnType<string, string | number, string | number>; // NUMERIC
  quantity: Generated<number>;
  is_active: Generated<boolean>;
  active_until: string | null; // TIMESTAMPTZ as ISO string
  image_url: string | null;
}

export interface InvoiceTable {
  id: Generated<string>;
  date: Generated<string>; // DATE as ISO string, defaults to CURRENT_DATE
  // Maintained by trigger; never set manually. Use ColumnType<select, never, never>.
  total: ColumnType<string, never, never>;
}

export interface InvoiceItemTable {
  id: Generated<string>;
  invoice_id: string;
  shop_item_id: string;
  quantity: number;
}

export interface NotificationTable {
  id: Generated<string>;
  user_id: string;
  type: NotificationType;
  title: string;
  body: string | null;
  // JSONB — invite notifications include invite_status, inviter_id, entity_name,
  // gym_id/employee_type (employee_gym_invite) or shop_id (vendor_shop_invite).
  metadata: ColumnType<
    Record<string, unknown> | null,
    Record<string, unknown> | null | undefined,
    Record<string, unknown> | null | undefined
  >;
  is_read: Generated<boolean>;
  created_at: Generated<string>;
}

// ── Workout system tables ─────────────────────────────────────────────────────

export interface ExerciseTable {
  id: Generated<string>;
  name: string;
  description: string | null;
  note: string | null;
  image_url: string | null;
  video_url: string | null;
  author_id: string | null;
  primary_muscles: MuscleGroup[];
  secondary_muscles: MuscleGroup[];
  is_public: Generated<boolean>;
  created_at: Generated<string>;
  updated_at: Generated<string>;
}

export interface TrainingTable {
  id: Generated<string>;
  name: string;
  description: string | null;
  notes: string | null;
  author_id: string | null;
  is_public: Generated<boolean>;
  created_at: Generated<string>;
  updated_at: Generated<string>;
}

export interface TrainingImageTable {
  id: Generated<string>;
  training_id: string;
  url: string;
  is_thumbnail: Generated<boolean>;
  position: Generated<number>;
}

export interface TrainingSetTable {
  id: Generated<string>;
  training_id: string;
  type: Generated<WorkoutSetType>;
  position: Generated<number>;
  rest_seconds: number | null;
  note: string | null;
}

export interface TrainingSetExerciseTable {
  id: Generated<string>;
  training_set_id: string;
  exercise_id: string;
  position: Generated<number>;
  is_alternating: Generated<boolean>;
  rest_between_drops_seconds: number | null;
  note: string | null;
}

export interface TrainingSetDropTable {
  id: Generated<string>;
  training_set_exercise_id: string;
  drop_number: Generated<number>;
  rep_type: Generated<RepType>;
  rep_count: number | null;
  weight_kg: ColumnType<string | null, string | number | null, string | number | null>;
  side: Generated<BodySide>;
  note: string | null;
}

export interface RoutineTable {
  id: Generated<string>;
  name: string;
  description: string | null;
  notes: string | null;
  author_id: string | null;
  is_public: Generated<boolean>;
  schedule_type: Generated<RoutineScheduleType>;
  num_weeks: number | null;
  created_at: Generated<string>;
  updated_at: Generated<string>;
}

export interface RoutineImageTable {
  id: Generated<string>;
  routine_id: string;
  url: string;
  is_thumbnail: Generated<boolean>;
  position: Generated<number>;
}

export interface RoutineTrainingTable {
  id: Generated<string>;
  routine_id: string;
  training_id: string;
  week_number: number | null;
  day_of_week: number | null;
  position: Generated<number>;
  note: string | null;
}

export interface TrainingSessionTable {
  id: Generated<string>;
  user_id: string;
  trainer_id: string | null;
  training_id: string | null;
  started_at: Generated<string>;
  ended_at: string | null;
  notes: string | null;
  created_at: Generated<string>;
  updated_at: Generated<string>;
}

export interface SessionSetLogTable {
  id: Generated<string>;
  session_id: string;
  training_set_id: string | null;
  exercise_id: string | null;
  position: Generated<number>;
  note: string | null;
}

export interface SessionDropLogTable {
  id: Generated<string>;
  session_set_log_id: string;
  training_set_drop_id: string | null;
  drop_number: Generated<number>;
  rep_type_actual: Generated<RepType>;
  rep_count_actual: number | null;
  weight_kg_actual: ColumnType<string | null, string | number | null, string | number | null>;
  side: Generated<BodySide>;
  note: string | null;
}

// ── Meal plan system tables ───────────────────────────────────────────────────

export interface VitaminTable {
  id: Generated<string>;
  name: string;
  symbol: string | null;
  default_unit: Generated<string>;
}

export interface MineralTable {
  id: Generated<string>;
  name: string;
  symbol: string | null;
  default_unit: Generated<string>;
}

export interface FoodItemTable {
  id: Generated<string>;
  name: string;
  brand: string | null;
  barcode: string | null;
  type: FoodItemType;
  food_subtype: FoodSubtype | null;
  drink_subtype: DrinkSubtype | null;
  spice_subtype: SpiceSubtype | null;
  serving_unit: Generated<ServingUnit>;
  // Macros per 100g or 100ml — NUMERIC, returned as string by pg.
  kcal_per_100: ColumnType<string, string | number | undefined, string | number>;
  protein_per_100: ColumnType<string, string | number | undefined, string | number>;
  carb_per_100: ColumnType<string, string | number | undefined, string | number>;
  fat_per_100: ColumnType<string, string | number | undefined, string | number>;
  fiber_per_100: ColumnType<string, string | number | undefined, string | number>;
  author_id: string | null;
  is_public: Generated<boolean>;
  is_system: Generated<boolean>;
  created_at: Generated<string>;
  updated_at: Generated<string>;
}

export interface FoodItemVitaminTable {
  food_item_id: string;
  vitamin_id: string;
  amount_per_100: ColumnType<string, string | number | undefined, string | number>;
  unit: string | null;
}

export interface FoodItemMineralTable {
  food_item_id: string;
  mineral_id: string;
  amount_per_100: ColumnType<string, string | number | undefined, string | number>;
  unit: string | null;
}

export interface RecipeTable {
  id: Generated<string>;
  name: string;
  description: string | null;
  author_id: string | null;
  servings: Generated<number>;
  prep_time_minutes: number | null;
  cook_time_minutes: number | null;
  // Macros per serving — recomputed by the app whenever ingredients change.
  kcal_per_serving: ColumnType<string, string | number | undefined, string | number>;
  protein_per_serving: ColumnType<string, string | number | undefined, string | number>;
  carb_per_serving: ColumnType<string, string | number | undefined, string | number>;
  fat_per_serving: ColumnType<string, string | number | undefined, string | number>;
  fiber_per_serving: ColumnType<string, string | number | undefined, string | number>;
  is_public: Generated<boolean>;
  is_system: Generated<boolean>;
  created_at: Generated<string>;
  updated_at: Generated<string>;
}

export interface RecipeIngredientTable {
  id: Generated<string>;
  recipe_id: string;
  food_item_id: string;
  quantity: ColumnType<string, string | number, string | number>; // in food_item.serving_unit
  note: string | null;
  position: Generated<number>;
}

export interface RecipeStepTable {
  id: Generated<string>;
  recipe_id: string;
  position: Generated<number>;
  instruction: string;
  image_url: string | null;
}

export interface RecipeImageTable {
  id: Generated<string>;
  recipe_id: string;
  url: string;
  is_thumbnail: Generated<boolean>;
  position: Generated<number>;
}

export interface RecipeVideoTable {
  id: Generated<string>;
  recipe_id: string;
  url: string;
  title: string | null;
  position: Generated<number>;
}

export interface DailyMealPlanTable {
  id: Generated<string>;
  name: string;
  description: string | null;
  author_id: string | null;
  is_public: Generated<boolean>;
  is_system: Generated<boolean>;
  // Totals recomputed by the app whenever entries change.
  kcal_total: ColumnType<string, string | number | undefined, string | number>;
  protein_total: ColumnType<string, string | number | undefined, string | number>;
  carb_total: ColumnType<string, string | number | undefined, string | number>;
  fat_total: ColumnType<string, string | number | undefined, string | number>;
  fiber_total: ColumnType<string, string | number | undefined, string | number>;
  created_at: Generated<string>;
  updated_at: Generated<string>;
}

export interface DailyMealPlanSlotTable {
  id: Generated<string>;
  daily_meal_plan_id: string;
  slot_type: MealSlotType;
  position: Generated<number>;
  note: string | null;
}

export interface DailyMealPlanSlotEntryTable {
  id: Generated<string>;
  daily_meal_plan_slot_id: string;
  food_item_id: string | null;
  recipe_id: string | null;
  // in food_item.serving_unit — only used when food_item_id is set
  quantity: ColumnType<string | null, string | number | null | undefined, string | number | null>;
  // used when recipe_id is set (e.g. 0.5 = half a recipe serving) — DEFAULT 1.0
  servings: ColumnType<string | null, string | number | null | undefined, string | number | null>;
  position: Generated<number>;
  note: string | null;
}

export interface MealPlanTable {
  id: Generated<string>;
  name: string;
  description: string | null;
  author_id: string | null;
  is_public: Generated<boolean>;
  is_system: Generated<boolean>;
  num_weeks: Generated<number>; // CHECK (num_weeks BETWEEN 1 AND 4)
  created_at: Generated<string>;
  updated_at: Generated<string>;
}

export interface MealPlanImageTable {
  id: Generated<string>;
  meal_plan_id: string;
  url: string;
  is_thumbnail: Generated<boolean>;
  position: Generated<number>;
}

export interface MealPlanDayTable {
  id: Generated<string>;
  meal_plan_id: string;
  daily_meal_plan_id: string;
  week_number: number; // CHECK (week_number >= 1)
  day_of_week: number; // CHECK (day_of_week BETWEEN 1 AND 7)
  note: string | null;
}

export interface MealPlanAssignmentTable {
  id: Generated<string>;
  meal_plan_id: string;
  user_id: string;
  assigned_by_id: string | null;
  start_date: string | null; // DATE as ISO string
  end_date: string | null;
  note: string | null;
  created_at: Generated<string>;
}

// ── Posts (gym/shop community feed) ───────────────────────────────────────────

export interface PostTable {
  id: Generated<string>;
  business_id: string;
  author_id: string | null;
  content: string;
  created_at: Generated<string>;
  updated_at: Generated<string>;
}

export interface PostImageTable {
  id: Generated<string>;
  post_id: string;
  url: string;
  position: Generated<number>;
}

// ── Database ──────────────────────────────────────────────────────────────────

export interface Database {
  users: UsersTable;
  business: BusinessTable;
  gym: GymTable;
  shop: ShopTable;
  trainer: TrainerTable;
  member: MemberTable;
  employee: EmployeeTable;
  employee_trainer: EmployeeTrainerTable;
  gym_owner: GymOwnerTable;
  shop_owner: ShopOwnerTable;
  shop_vendor: ShopVendorTable;
  gym_membership_type: GymMembershipTypeTable;
  membership: MembershipTable;
  membership_invoice: MembershipInvoiceTable;
  shop_item: ShopItemTable;
  invoice: InvoiceTable;
  invoice_item: InvoiceItemTable;
  notification: NotificationTable;
  exercise: ExerciseTable;
  training: TrainingTable;
  training_image: TrainingImageTable;
  training_set: TrainingSetTable;
  training_set_exercise: TrainingSetExerciseTable;
  training_set_drop: TrainingSetDropTable;
  routine: RoutineTable;
  routine_image: RoutineImageTable;
  routine_training: RoutineTrainingTable;
  training_session: TrainingSessionTable;
  session_set_log: SessionSetLogTable;
  session_drop_log: SessionDropLogTable;
  vitamin: VitaminTable;
  mineral: MineralTable;
  food_item: FoodItemTable;
  food_item_vitamin: FoodItemVitaminTable;
  food_item_mineral: FoodItemMineralTable;
  recipe: RecipeTable;
  recipe_ingredient: RecipeIngredientTable;
  recipe_step: RecipeStepTable;
  recipe_image: RecipeImageTable;
  recipe_video: RecipeVideoTable;
  daily_meal_plan: DailyMealPlanTable;
  daily_meal_plan_slot: DailyMealPlanSlotTable;
  daily_meal_plan_slot_entry: DailyMealPlanSlotEntryTable;
  meal_plan: MealPlanTable;
  meal_plan_image: MealPlanImageTable;
  meal_plan_day: MealPlanDayTable;
  meal_plan_assignment: MealPlanAssignmentTable;
  post: PostTable;
  post_image: PostImageTable;
}

// ── CRUD helpers ──────────────────────────────────────────────────────────────

export type User = Selectable<UsersTable>;
export type UserInsert = Insertable<UsersTable>;
export type UserUpdate = Updateable<UsersTable>;

export type Business = Selectable<BusinessTable>;
export type BusinessInsert = Insertable<BusinessTable>;
export type BusinessUpdate = Updateable<BusinessTable>;

export type Gym = Selectable<GymTable>;
export type GymInsert = Insertable<GymTable>;
export type GymUpdate = Updateable<GymTable>;

export type Shop = Selectable<ShopTable>;
export type ShopInsert = Insertable<ShopTable>;
export type ShopUpdate = Updateable<ShopTable>;

export type Trainer = Selectable<TrainerTable>;
export type TrainerInsert = Insertable<TrainerTable>;
export type TrainerUpdate = Updateable<TrainerTable>;

export type Member = Selectable<MemberTable>;
export type MemberInsert = Insertable<MemberTable>;
export type MemberUpdate = Updateable<MemberTable>;

export type Employee = Selectable<EmployeeTable>;
export type EmployeeInsert = Insertable<EmployeeTable>;
export type EmployeeUpdate = Updateable<EmployeeTable>;

export type EmployeeTrainer = Selectable<EmployeeTrainerTable>;
export type EmployeeTrainerInsert = Insertable<EmployeeTrainerTable>;
export type EmployeeTrainerUpdate = Updateable<EmployeeTrainerTable>;

export type GymOwner = Selectable<GymOwnerTable>;
export type GymOwnerInsert = Insertable<GymOwnerTable>;
export type GymOwnerUpdate = Updateable<GymOwnerTable>;

export type ShopOwner = Selectable<ShopOwnerTable>;
export type ShopOwnerInsert = Insertable<ShopOwnerTable>;
export type ShopOwnerUpdate = Updateable<ShopOwnerTable>;

export type ShopVendor = Selectable<ShopVendorTable>;
export type ShopVendorInsert = Insertable<ShopVendorTable>;
export type ShopVendorUpdate = Updateable<ShopVendorTable>;

export type GymMembershipType = Selectable<GymMembershipTypeTable>;
export type GymMembershipTypeInsert = Insertable<GymMembershipTypeTable>;
export type GymMembershipTypeUpdate = Updateable<GymMembershipTypeTable>;

export type Membership = Selectable<MembershipTable>;
export type MembershipInsert = Insertable<MembershipTable>;
export type MembershipUpdate = Updateable<MembershipTable>;

export type MembershipInvoice = Selectable<MembershipInvoiceTable>;
export type MembershipInvoiceInsert = Insertable<MembershipInvoiceTable>;
export type MembershipInvoiceUpdate = Updateable<MembershipInvoiceTable>;

export type ShopItem = Selectable<ShopItemTable>;
export type ShopItemInsert = Insertable<ShopItemTable>;
export type ShopItemUpdate = Updateable<ShopItemTable>;

export type Invoice = Selectable<InvoiceTable>;
export type InvoiceInsert = Insertable<InvoiceTable>;

export type InvoiceItem = Selectable<InvoiceItemTable>;
export type InvoiceItemInsert = Insertable<InvoiceItemTable>;
export type InvoiceItemUpdate = Updateable<InvoiceItemTable>;

export type Notification = Selectable<NotificationTable>;
export type NotificationInsert = Insertable<NotificationTable>;
export type NotificationUpdate = Updateable<NotificationTable>;

export type Exercise = Selectable<ExerciseTable>;
export type ExerciseInsert = Insertable<ExerciseTable>;
export type ExerciseUpdate = Updateable<ExerciseTable>;

export type Training = Selectable<TrainingTable>;
export type TrainingInsert = Insertable<TrainingTable>;
export type TrainingUpdate = Updateable<TrainingTable>;

export type TrainingImage = Selectable<TrainingImageTable>;
export type TrainingImageInsert = Insertable<TrainingImageTable>;

export type TrainingSet = Selectable<TrainingSetTable>;
export type TrainingSetInsert = Insertable<TrainingSetTable>;
export type TrainingSetUpdate = Updateable<TrainingSetTable>;

export type TrainingSetExercise = Selectable<TrainingSetExerciseTable>;
export type TrainingSetExerciseInsert = Insertable<TrainingSetExerciseTable>;

export type TrainingSetDrop = Selectable<TrainingSetDropTable>;
export type TrainingSetDropInsert = Insertable<TrainingSetDropTable>;

export type Routine = Selectable<RoutineTable>;
export type RoutineInsert = Insertable<RoutineTable>;
export type RoutineUpdate = Updateable<RoutineTable>;

export type RoutineImage = Selectable<RoutineImageTable>;
export type RoutineImageInsert = Insertable<RoutineImageTable>;

export type RoutineTraining = Selectable<RoutineTrainingTable>;
export type RoutineTrainingInsert = Insertable<RoutineTrainingTable>;

export type TrainingSession = Selectable<TrainingSessionTable>;
export type TrainingSessionInsert = Insertable<TrainingSessionTable>;
export type TrainingSessionUpdate = Updateable<TrainingSessionTable>;

export type SessionSetLog = Selectable<SessionSetLogTable>;
export type SessionSetLogInsert = Insertable<SessionSetLogTable>;

export type SessionDropLog = Selectable<SessionDropLogTable>;
export type SessionDropLogInsert = Insertable<SessionDropLogTable>;

export type Vitamin = Selectable<VitaminTable>;
export type VitaminInsert = Insertable<VitaminTable>;
export type VitaminUpdate = Updateable<VitaminTable>;

export type Mineral = Selectable<MineralTable>;
export type MineralInsert = Insertable<MineralTable>;
export type MineralUpdate = Updateable<MineralTable>;

export type FoodItem = Selectable<FoodItemTable>;
export type FoodItemInsert = Insertable<FoodItemTable>;
export type FoodItemUpdate = Updateable<FoodItemTable>;

export type FoodItemVitamin = Selectable<FoodItemVitaminTable>;
export type FoodItemVitaminInsert = Insertable<FoodItemVitaminTable>;

export type FoodItemMineral = Selectable<FoodItemMineralTable>;
export type FoodItemMineralInsert = Insertable<FoodItemMineralTable>;

export type Recipe = Selectable<RecipeTable>;
export type RecipeInsert = Insertable<RecipeTable>;
export type RecipeUpdate = Updateable<RecipeTable>;

export type RecipeIngredient = Selectable<RecipeIngredientTable>;
export type RecipeIngredientInsert = Insertable<RecipeIngredientTable>;

export type RecipeStep = Selectable<RecipeStepTable>;
export type RecipeStepInsert = Insertable<RecipeStepTable>;

export type RecipeImage = Selectable<RecipeImageTable>;
export type RecipeImageInsert = Insertable<RecipeImageTable>;

export type RecipeVideo = Selectable<RecipeVideoTable>;
export type RecipeVideoInsert = Insertable<RecipeVideoTable>;

export type DailyMealPlan = Selectable<DailyMealPlanTable>;
export type DailyMealPlanInsert = Insertable<DailyMealPlanTable>;
export type DailyMealPlanUpdate = Updateable<DailyMealPlanTable>;

export type DailyMealPlanSlot = Selectable<DailyMealPlanSlotTable>;
export type DailyMealPlanSlotInsert = Insertable<DailyMealPlanSlotTable>;

export type DailyMealPlanSlotEntry = Selectable<DailyMealPlanSlotEntryTable>;
export type DailyMealPlanSlotEntryInsert = Insertable<DailyMealPlanSlotEntryTable>;

export type MealPlan = Selectable<MealPlanTable>;
export type MealPlanInsert = Insertable<MealPlanTable>;
export type MealPlanUpdate = Updateable<MealPlanTable>;

export type MealPlanImage = Selectable<MealPlanImageTable>;
export type MealPlanImageInsert = Insertable<MealPlanImageTable>;

export type MealPlanDay = Selectable<MealPlanDayTable>;
export type MealPlanDayInsert = Insertable<MealPlanDayTable>;

export type MealPlanAssignment = Selectable<MealPlanAssignmentTable>;
export type MealPlanAssignmentInsert = Insertable<MealPlanAssignmentTable>;
export type MealPlanAssignmentUpdate = Updateable<MealPlanAssignmentTable>;

export type Post = Selectable<PostTable>;
export type PostInsert = Insertable<PostTable>;
export type PostUpdate = Updateable<PostTable>;

export type PostImage = Selectable<PostImageTable>;
export type PostImageInsert = Insertable<PostImageTable>;

// ── Auth response ─────────────────────────────────────────────────────────────

export interface AuthSession {
  access_token: string;
  refresh_token: string;
  expires_in: number;
  token_type: string;
  user: {
    id: string;
    email: string;
    email_confirmed_at: string | null;
  };
}
