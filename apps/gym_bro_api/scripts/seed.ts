// seed.ts — Populates a Gym Bro database with realistic demo content.
//
// Runs OUTSIDE the edge runtime (plain `deno run` on the host), so it talks to
// Postgres and the Auth admin API directly. It works against any database that
// has the migrations applied (local stack, a staging project, CI):
//
//   * Safe to re-run. Every section is guarded ("does this already exist?"),
//     so a second run adds only what is missing, never duplicates, and never
//     touches rows it didn't create. Each section prints `+ N <thing>` or
//     `= <thing> already seeded`, and a summary is printed at the end.
//   * Deterministic. Random choices come from a seeded PRNG (SEED_RANDOM_SEED),
//     so a fresh database always gets the same data. Dates are relative to
//     "now" on purpose, so the demo always looks current.
//
// Usage — normally through the wrapper, which runs the migrations first:
//   cd apps/gym_bro_api && scripts/setup_db.sh
//
// Standalone (database already migrated):
//   cd apps/gym_bro_api
//   export SUPABASE_SERVICE_ROLE_KEY="$(supabase status -o env | grep '^SERVICE_ROLE_KEY=' | cut -d'"' -f2)"
//   export SEED_PASSWORD='<demo password>'
//   deno run --allow-net --allow-env --allow-read --allow-sys scripts/seed.ts
//
// Environment:
//   DB_URL (or POSTGRES_URL)    Postgres connection string. Default: the local
//                               stack, postgresql://postgres:postgres@127.0.0.1:54322/postgres.
//                               SSL is used for any non-local host (same rule
//                               as supabase/functions/_shared/config.ts).
//   SUPABASE_URL                Project URL for the Auth admin API. Default http://127.0.0.1:54321.
//   SUPABASE_SERVICE_ROLE_KEY   Required. Service role key of that project.
//   SEED_PASSWORD               Required. Password of every seeded user (8+ characters).
//   SEED_RESET_PASSWORDS        "1" also resets already-seeded users to SEED_PASSWORD.
//   SEED_RANDOM_SEED            Optional PRNG seed (default "gym-bro-demo").
//
// Note: .env.local's SUPABASE_SERVICE_ROLE_KEY is pulled from Doppler and may
// not match the local instance's JWT secret, so for the local stack always
// source the key from `supabase status` as shown above.
//
// Deliberately NOT seeded:
//   * payment rows — they mirror real Stripe objects (checkout session /
//     payment intent / invoice ids) that the webhook and refund code look up
//     on Stripe; fake ids would break refunds and reconciliation. Seeded
//     orders and invoices are therefore paid "at the counter" or carry no
//     payment record.
//   * device_token rows — push tokens are issued by FCM per physical device;
//     fake ones would only produce failed sends (and be deleted as stale).
//   * admin_audit_log rows — the audit log must only ever record actions that
//     really happened.
//
// Media: personal post photos/videos and chat attachments are real files in
// the private user-media / chat-media buckets, downloaded from picsum.photos
// (and one sample video). Without network access those items are seeded
// without media (captions / text only); a re-run with network adds the
// missing files to personal posts (chat messages keep their text only).
//
// Exercise illustrations are the committed JPEGs in seed_assets/exercises/
// (<exercise-name-slug>.jpg; an exercise without one gets no image), uploaded
// to the public `media` bucket under exercises/illustrations/. image_url is stored relative
// to the Supabase origin (clients prefix their own) with a ?v=<content hash>,
// so a changed image gets a new URL. Re-runs upload changed files and point
// seeded exercises still on a placeholder or an older illustration at the
// current one; an image an author uploaded themselves is left alone.

import { type Insertable, Kysely, PostgresDialect, sql } from "npm:kysely@^0.27";
import pg from "npm:pg@^8";
import { createClient } from "jsr:@supabase/supabase-js@2";
import type {
  BookingStatus,
  Database,
  DailyMealPlanSlotEntryInsert,
  DrinkSubtype,
  FoodItemInsert,
  FoodLogTable,
  FoodSubtype,
  InvoiceStatus,
  MealSlotType,
  MuscleGroup,
  NotificationType,
  OrderStatus,
  PostVisibility,
  ReactionType,
  RepType,
  SessionDropLogInsert,
  SpiceSubtype,
  TrainingSetDropInsert,
  TrainingSetExerciseInsert,
  TrainingSetInsert,
  UserRole,
  WorkoutSetType,
} from "../supabase/types/schema/public.ts";

const { Pool } = pg;

// ── Target ────────────────────────────────────────────────────────────────────

const DEFAULT_DB_URL = "postgresql://postgres:postgres@127.0.0.1:54322/postgres";
const DB_URL = Deno.env.get("DB_URL")?.trim() || Deno.env.get("POSTGRES_URL")?.trim() || DEFAULT_DB_URL;
const SUPABASE_URL = (Deno.env.get("SUPABASE_URL")?.trim() || "http://127.0.0.1:54321").replace(/\/+$/, "");
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")?.trim();
if (!SERVICE_ROLE_KEY) {
  throw new Error(
    "SUPABASE_SERVICE_ROLE_KEY is not set. For the local stack: " +
      `export SUPABASE_SERVICE_ROLE_KEY="$(supabase status -o env | grep '^SERVICE_ROLE_KEY=' | cut -d'"' -f2)"`,
  );
}

// Same rule as supabase/functions/_shared/config.ts: SSL for anything not local.
const isLocalDb = DB_URL.includes("127.0.0.1") || DB_URL.includes("localhost") ||
  DB_URL.includes("host.docker.internal");

function maskUrl(url: string): string {
  try {
    const u = new URL(url);
    if (u.password) u.password = "****";
    return u.toString();
  } catch {
    return url.replace(/(:\/\/[^:@/]+):[^@/]*@/, "$1:****@");
  }
}

console.log(`Seeding database ${maskUrl(DB_URL)} (ssl ${isLocalDb ? "off" : "on"})`);
console.log(`Auth admin API   ${SUPABASE_URL}\n`);

const db = new Kysely<Database>({
  dialect: new PostgresDialect({
    pool: new Pool({ connectionString: DB_URL, ssl: isLocalDb ? false : { rejectUnauthorized: false } }),
  }),
});

const supabaseAdmin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
  auth: { persistSession: false, autoRefreshToken: false },
});

const SEED_PASSWORD = Deno.env.get("SEED_PASSWORD") ?? "";
if (SEED_PASSWORD.length < 8) {
  throw new Error("SEED_PASSWORD is not set (or shorter than 8 characters). It becomes every seeded user's password.");
}
// Existing seeded users keep their password unless this is set; then it is
// reset to SEED_PASSWORD (to rotate a password that leaked).
const RESET_PASSWORDS = Deno.env.get("SEED_RESET_PASSWORDS") === "1";

// ── Deterministic randomness ──────────────────────────────────────────────────
// Every random choice comes from a mulberry32 stream keyed by the global seed
// plus what is being generated (e.g. "checkins|liamoconnor"), so one entity's
// data doesn't change when another section is skipped on a re-run.

const RANDOM_SEED = Deno.env.get("SEED_RANDOM_SEED")?.trim() || "gym-bro-demo";

function hash32(str: string): number {
  let h = 0x811c9dc5; // FNV-1a
  for (let i = 0; i < str.length; i++) {
    h ^= str.charCodeAt(i);
    h = Math.imul(h, 0x01000193);
  }
  return h >>> 0;
}

function mulberry32(seed: number): () => number {
  let a = seed >>> 0;
  return () => {
    a = (a + 0x6d2b79f5) | 0;
    let t = Math.imul(a ^ (a >>> 15), 1 | a);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

type Rng = ReturnType<typeof rngFor>;

function rngFor(...keys: (string | number)[]) {
  const next = mulberry32(hash32([RANDOM_SEED, ...keys].join("|")));
  const shuffle = <T>(arr: readonly T[]): T[] => {
    const a = [...arr];
    for (let i = a.length - 1; i > 0; i--) {
      const j = Math.floor(next() * (i + 1));
      [a[i], a[j]] = [a[j], a[i]];
    }
    return a;
  };
  return {
    next,
    /** Integer in [min, max]. */
    int: (min: number, max: number) => min + Math.floor(next() * (max - min + 1)),
    float: (min: number, max: number) => min + next() * (max - min),
    chance: (p: number) => next() < p,
    pick: <T>(arr: readonly T[]): T => arr[Math.floor(next() * arr.length)],
    shuffle,
    sample: <T>(arr: readonly T[], n: number): T[] => shuffle(arr).slice(0, Math.max(0, n)),
  };
}

// ── Time helpers ──────────────────────────────────────────────────────────────
// Local wall-clock times are resolved in each business's IANA time zone
// (seed_data.json `timezone`), so a 06:30 class is at 06:30 in Brooklyn.

const NOW_MS = Date.now();
const MIN_MS = 60_000;
const HOUR_MS = 60 * MIN_MS;
const DAY_MS = 24 * HOUR_MS;

const iso = (ms: number) => new Date(ms).toISOString();
const pad2 = (n: number) => String(n).padStart(2, "0");
/** Timestamps come back from pg as Date objects even though the types say string. */
const toMs = (v: unknown) => new Date(v as string).getTime();
/** Never in the future (minus a margin) — notifications and logs only happen in the past. */
const clampPast = (ms: number, marginMinutes = 1) => Math.min(ms, NOW_MS - marginMinutes * MIN_MS);
const ymdUtc = (ms: number) => iso(ms).slice(0, 10);
const TODAY_UTC = ymdUtc(NOW_MS);

const zoneFormatters = new Map<string, Intl.DateTimeFormat>();
function zonedParts(ms: number, tz: string) {
  let f = zoneFormatters.get(tz);
  if (!f) {
    f = new Intl.DateTimeFormat("en-US", {
      timeZone: tz,
      hourCycle: "h23",
      year: "numeric",
      month: "2-digit",
      day: "2-digit",
      hour: "2-digit",
      minute: "2-digit",
      second: "2-digit",
    });
    zoneFormatters.set(tz, f);
  }
  const p = Object.fromEntries(f.formatToParts(new Date(ms)).map((x) => [x.type, x.value]));
  return { y: +p.year, m: +p.month, d: +p.day, h: +p.hour % 24, mi: +p.minute, s: +p.second };
}

function tzOffsetMs(ms: number, tz: string): number {
  const whole = Math.floor(ms / 1000) * 1000;
  const p = zonedParts(whole, tz);
  return Date.UTC(p.y, p.m - 1, p.d, p.h, p.mi, p.s) - whole;
}

/** The instant of local wall time `hhmm` on `ymd` in `tz`. */
function zonedTime(ymd: string, hhmm: string, tz: string): number {
  const [y, m, d] = ymd.split("-").map(Number);
  const [h, mi] = hhmm.split(":").map(Number);
  const guess = Date.UTC(y, m - 1, d, h, mi);
  const first = guess - tzOffsetMs(guess, tz);
  return guess - tzOffsetMs(first, tz); // second pass settles DST edges
}

function localYmd(ms: number, tz: string): string {
  const p = zonedParts(ms, tz);
  return `${p.y}-${pad2(p.m)}-${pad2(p.d)}`;
}

function addDays(ymd: string, n: number): string {
  const [y, m, d] = ymd.split("-").map(Number);
  return ymdUtc(Date.UTC(y, m - 1, d + n));
}

function addMonths(ymd: string, n: number): string {
  const [y, m, d] = ymd.split("-").map(Number);
  const first = new Date(Date.UTC(y, m - 1 + n, 1));
  const lastDay = new Date(Date.UTC(first.getUTCFullYear(), first.getUTCMonth() + 1, 0)).getUTCDate();
  return ymdUtc(Date.UTC(first.getUTCFullYear(), first.getUTCMonth(), Math.min(d, lastDay)));
}

/** ISO weekday, 1 = Monday … 7 = Sunday. */
function isoDow(ymd: string): number {
  const [y, m, d] = ymd.split("-").map(Number);
  const dow = new Date(Date.UTC(y, m - 1, d)).getUTCDay();
  return dow === 0 ? 7 : dow;
}

function daysBetween(a: string, b: string): number {
  return Math.round((Date.parse(`${b}T00:00:00Z`) - Date.parse(`${a}T00:00:00Z`)) / DAY_MS);
}

/** Every date from `from` to `to`, inclusive. */
function dateRange(from: string, to: string): string[] {
  const out: string[] = [];
  for (let d = from; d <= to; d = addDays(d, 1)) out.push(d);
  return out;
}

const hhmm = (minutesOfDay: number) => `${pad2(Math.floor(minutesOfDay / 60) % 24)}:${pad2(minutesOfDay % 60)}`;

// ── Reporting ─────────────────────────────────────────────────────────────────

const summary: [string, number][] = [];
function report(label: string, n: number) {
  summary.push([label, n]);
  console.log(n > 0 ? `+ ${n} ${label}` : `= ${label} already seeded`);
}

let notificationsAdded = 0;
let notificationSeq = 0;

type NotificationSeed = {
  type: NotificationType;
  title: string;
  body: string | null;
  metadata: Record<string, unknown>;
};

/**
 * Inserts the same notification for each user, like `_shared/notify.ts` does
 * (same type/title/body/metadata shapes as the API), backdated to when the
 * event happened. Notifications older than two days are mostly already read.
 */
async function addNotification(userIds: (string | null | undefined)[], n: NotificationSeed, atMs: number) {
  const unique = [...new Set(userIds.filter((u): u is string => !!u))];
  if (unique.length === 0) return;
  const createdMs = clampPast(atMs);
  const rng = rngFor("notification-read", n.type, notificationSeq++);
  await db
    .insertInto("notification")
    .values(unique.map((user_id) => ({
      user_id,
      type: n.type,
      title: n.title,
      body: n.body,
      metadata: n.metadata,
      created_at: iso(createdMs),
      is_read: createdMs < NOW_MS - 2 * DAY_MS && rng.chance(0.75),
    })))
    .execute();
  notificationsAdded += unique.length;
}

// ── Image helpers ─────────────────────────────────────────────────────────────
// Deterministic placeholder images — no upload pipeline needed for seed data,
// just stable URLs in the same TEXT columns the app already renders from.

const avatarUrl = (seed: string) =>
  `https://api.dicebear.com/9.x/avataaars/png?seed=${encodeURIComponent(seed)}&size=256`;
const photoUrl = (seed: string, w = 800, h = 600) =>
  `https://picsum.photos/seed/${encodeURIComponent(seed)}/${w}/${h}`;

// A public sample clip (the one Flutter's video_player docs use).
const SAMPLE_VIDEO_URL = "https://flutter.github.io/assets-for-api-docs/assets/videos/butterfly.mp4";

/**
 * Puts a file into a private bucket at a fixed path (idempotent: an existing
 * object is kept). Returns the content type, or null when the download
 * failed (no network) so the caller can seed without the file.
 */
async function seedStorageObject(
  bucket: "user-media" | "chat-media",
  path: string,
  sourceUrl: string,
  contentType: string,
): Promise<{ contentType: string; size: number } | null> {
  const slash = path.lastIndexOf("/");
  const { data: listed } = await supabaseAdmin.storage.from(bucket).list(path.slice(0, slash), {
    search: path.slice(slash + 1),
    limit: 1,
  });
  const found = listed?.find((o) => o.name === path.slice(slash + 1));
  if (found) return { contentType, size: Number(found.metadata?.size ?? 0) };
  try {
    const res = await fetch(sourceUrl, { signal: AbortSignal.timeout(20_000) });
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    const bytes = new Uint8Array(await res.arrayBuffer());
    const { error } = await supabaseAdmin.storage.from(bucket).upload(path, bytes, { contentType, upsert: true });
    if (error) throw new Error(error.message);
    return { contentType, size: bytes.length };
  } catch (err) {
    console.warn(`  ! couldn't fetch ${sourceUrl} for ${bucket}/${path}: ${(err as Error).message}`);
    return null;
  }
}

const ILLUSTRATION_DIR = new URL("./seed_assets/exercises/", import.meta.url);
const ILLUSTRATION_PREFIX = "exercises/illustrations";
const ILLUSTRATION_URL_PREFIX = `/storage/v1/object/public/media/${ILLUSTRATION_PREFIX}/`;

const slugify = (name: string) => name.toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-|-$/g, "");

/** Objects already in media/exercises/illustrations, name → size. */
let illustrationObjects: Map<string, number> | null = null;
let illustrationsUploaded = 0;

/**
 * Uploads the exercise's illustration to the public `media` bucket when it's
 * missing or changed, and returns its origin-relative URL. Null when there's
 * no illustration file for it (or the upload failed).
 */
async function exerciseIllustrationUrl(exerciseName: string): Promise<string | null> {
  const file = `${slugify(exerciseName)}.jpg`;
  let bytes: Uint8Array<ArrayBuffer>;
  try {
    bytes = await Deno.readFile(new URL(file, ILLUSTRATION_DIR));
  } catch (err) {
    if (err instanceof Deno.errors.NotFound) return null;
    throw err;
  }
  if (!illustrationObjects) {
    const { data, error } = await supabaseAdmin.storage.from("media").list(ILLUSTRATION_PREFIX, { limit: 1000 });
    if (error) throw new Error(`listing media/${ILLUSTRATION_PREFIX}: ${error.message}`);
    illustrationObjects = new Map(data.map((o) => [o.name, Number(o.metadata?.size ?? 0)]));
  }
  if (illustrationObjects.get(file) !== bytes.length) {
    const { error } = await supabaseAdmin.storage.from("media")
      .upload(`${ILLUSTRATION_PREFIX}/${file}`, bytes, { contentType: "image/jpeg", upsert: true });
    if (error) {
      console.warn(`  ! couldn't upload media/${ILLUSTRATION_PREFIX}/${file}: ${error.message}`);
      return null;
    }
    illustrationObjects.set(file, bytes.length);
    illustrationsUploaded++;
  }
  const hash = new Uint8Array(await crypto.subtle.digest("SHA-256", bytes));
  const version = [...hash.slice(0, 4)].map((b) => b.toString(16).padStart(2, "0")).join("");
  return `${ILLUSTRATION_URL_PREFIX}${file}?v=${version}`;
}

/** Seeded media key → file (an image from picsum, or the sample video). */
function mediaSource(key: string) {
  if (key.startsWith("video:")) {
    return { name: key.slice(6), ext: "mp4", url: SAMPLE_VIDEO_URL, contentType: "video/mp4", width: 1280, height: 720, durationMs: 7_000 };
  }
  return { name: key, ext: "jpg", url: photoUrl(`gymbro-${key}`, 1080, 1080), contentType: "image/jpeg", width: 1080, height: 1080, durationMs: null };
}

// Reactions people actually use most, weighted.
const REACTION_WEIGHTS: [ReactionType, number][] = [
  ["like", 40], ["love", 14], ["fire", 12], ["strong", 11], ["clap", 8],
  ["celebrate", 5], ["haha", 4], ["wow", 4], ["sad", 1], ["angry", 1],
];
function pickReaction(rng: Rng): ReactionType {
  const total = REACTION_WEIGHTS.reduce((a, [, w]) => a + w, 0);
  let r = rng.next() * total;
  for (const [reaction, w] of REACTION_WEIGHTS) {
    r -= w;
    if (r < 0) return reaction;
  }
  return "like";
}

// ── Seed data ─────────────────────────────────────────────────────────────────

const dataPath = new URL("./seed_data.json", import.meta.url);
const seedData = JSON.parse(await Deno.readTextFile(dataPath));

type SeedBusiness = {
  name: string;
  location: string;
  latitude: number;
  longitude: number;
  type: "gym" | "shop";
  working_hours_from: string;
  working_hours_to: string;
  working_weekdays: number[];
  logo_image_key: string;
  // Seed-only: IANA zone used to place classes/shifts/visits at local times.
  timezone: string;
};
type SeedPersona = {
  username: string;
  email: string;
  first_name: string;
  last_name: string;
  role: UserRole;
  avatar_key: string;
  // Names of the business(es) this persona has a role-join row for — a gym for
  // trainer/member/employee/employee_trainer, a shop for shop_vendor, and
  // potentially several of either for owner. Empty for business-less roles
  // like super_user.
  businesses: string[];
};
type SeedExercise = {
  name: string;
  description: string;
  note: string | null;
  primary_muscles: MuscleGroup[];
  secondary_muscles: MuscleGroup[];
  // Baseline working weight (kg) used to generate realistic training_session
  // logs; null for bodyweight-only movements.
  default_weight_kg: number | null;
};
type SeedTrainingSet = {
  exercise_name: string;
  type: WorkoutSetType;
  position: number;
  sets_count: number;
  rep_range: string;
  rest_seconds: number;
};
type SeedTraining = { name: string; description: string; sets: SeedTrainingSet[] };
type SeedRoutine = {
  name: string;
  description: string;
  schedule_type: "fixed_weeks" | "wildcard";
  num_weeks: number;
  training_names: string[];
};
type SeedFoodItem = {
  name: string;
  brand: string | null;
  // EAN-13 for packaged products (validated below), null for whole foods.
  barcode: string | null;
  type: "food" | "spice" | "drink";
  food_subtype: FoodSubtype | null;
  drink_subtype: DrinkSubtype | null;
  spice_subtype: SpiceSubtype | null;
  serving_unit: "g" | "ml";
  kcal_per_100: number;
  protein_per_100: number;
  carb_per_100: number;
  fat_per_100: number;
  fiber_per_100: number;
};
type SeedMicronutrients = {
  food_item_name: string;
  // vitamin.symbol / mineral.symbol → amount per 100 g/ml in the reference row's default unit.
  vitamins: Record<string, number>;
  minerals: Record<string, number>;
};
type SeedRecipe = {
  name: string;
  description: string;
  servings: number;
  prep_time_minutes: number;
  cook_time_minutes: number;
  ingredients: { food_item_name: string; quantity_g_or_ml: number; note: string | null }[];
  steps: string[];
};
type SeedDailyMealPlan = {
  name: string;
  description: string;
  slots: {
    slot_type: MealSlotType;
    entries: {
      source: "food_item" | "recipe";
      name: string;
      quantity_g_or_ml?: number;
      servings?: number;
    }[];
  }[];
};
type SeedMealPlan = {
  name: string;
  description: string;
  num_weeks: number;
  days: { week_number: number; day_of_week: number; daily_meal_plan_name: string }[];
};
type SeedShopProduct = {
  name: string;
  description: string;
  type: "equipment" | "supplement" | "gift_card";
  price: number;
  quantity: number;
  shop_name: string;
};
type SeedPost = { author_persona_username: string; content: string; has_image: boolean };
type SeedComment = { author: string; body: string; reply_to?: number };
type SeedSocialProfile = {
  bio: string;
  interests: string[];
  is_private?: boolean;
  discoverable?: boolean;
  allow_non_follower_messages?: boolean;
};
type SeedPersonalPost = {
  author: string;
  caption: string;
  media: string[]; // image keys; "video:<key>" for a video
  days_ago: number;
  visibility: PostVisibility;
};
type SeedChatMessage = {
  from: string;
  text?: string;
  image?: string;
  video?: string;
  reply_to?: number;
  reaction?: { by: string; type: ReactionType };
};
type SeedDirectChat = { a: string; b: string; days_ago: number; request?: boolean; messages: SeedChatMessage[] };
type SeedGroupChat = {
  title: string;
  owner: string;
  admins: string[];
  members: string[];
  days_ago: number;
  messages: SeedChatMessage[];
};
type SeedMembershipPlan = {
  type: string;
  start_months_ago: number;
  start_extra_days: number;
  ends_in_days: number; // negative = already expired
  latest_invoice: InvoiceStatus;
};
type SeedUserSettings = {
  username: string;
  push_enabled?: boolean;
  muted_types?: NotificationType[];
  weight_unit?: "kg" | "lb";
  theme_mode?: "system" | "light" | "dark";
  locale?: string | null;
};
type SeedClassTemplate = {
  gym: string;
  title: string;
  description: string;
  location: string;
  capacity: number;
  trainer: string;
  weekdays: number[];
  start: string; // HH:MM local
  duration_minutes: number;
  full_next?: boolean; // next occurrence is fully booked with a waitlist
  cancel_next?: boolean; // next occurrence was cancelled
};
type SeedShiftPattern = {
  username: string;
  gym: string;
  weekdays: number[];
  start: string;
  end: string; // before start = ends the next day
  note: string | null;
};
type SeedDiaryEntry = { source: "food_item" | "recipe"; name: string; amount: number };
type SeedPostThread = { post_starts_with: string; comments: SeedComment[] };
type SeedShopOrder = {
  buyer: string;
  shop: string;
  status: OrderStatus;
  days_ago: number;
  payment_method: "card" | "pay_at_pickup";
  note: string | null;
  items: { name: string; quantity: number }[];
};

const businesses: SeedBusiness[] = seedData.businesses;
const personas: SeedPersona[] = seedData.personas;
const exercises: SeedExercise[] = seedData.exercises;
const trainings: SeedTraining[] = seedData.trainings;
const routines: SeedRoutine[] = seedData.routines;
const foodItems: SeedFoodItem[] = seedData.food_items;
const foodMicronutrients: SeedMicronutrients[] = seedData.food_micronutrients;
const recipes: SeedRecipe[] = seedData.recipes;
const dailyMealPlans: SeedDailyMealPlan[] = seedData.daily_meal_plans;
const mealPlans: SeedMealPlan[] = seedData.meal_plans;
const shopProducts: SeedShopProduct[] = seedData.shop_products;
const posts: SeedPost[] = seedData.posts;
const membershipPlans: Record<string, SeedMembershipPlan> = seedData.membership_plans;
const userSettingsSeeds: SeedUserSettings[] = seedData.user_settings;
const classTemplates: SeedClassTemplate[] = seedData.class_templates;
const shiftPatterns: SeedShiftPattern[] = seedData.shift_patterns;
const routineAssignmentNotes: (string | null)[] = seedData.routine_assignment_notes;
const sessionCommentPool: { coach: string[]; member: string[] } = seedData.session_comments;
const bodyMeasurementNotes: string[] = seedData.body_measurement_notes;
const postCommentThreads: SeedPostThread[] = seedData.post_comment_threads;
const foodDiary: { adhoc_members: string[]; adhoc_meals: Partial<Record<MealSlotType, SeedDiaryEntry[][]>> } =
  seedData.food_diary;
const shopOrders: SeedShopOrder[] = seedData.shop_orders;
const socialProfiles: Record<string, SeedSocialProfile> = seedData.social_profiles;
const socialGraph: {
  friendships: [string, string][];
  pending_friend_requests: [string, string][];
  pending_follow_requests: [string, string][];
  cross_follows: [string, string][];
  blocks: [string, string][];
} = seedData.social_graph;
const personalPosts: SeedPersonalPost[] = seedData.personal_posts;
const personalPostThreads: SeedPostThread[] = seedData.personal_post_threads;
const conversationSeeds: { direct: SeedDirectChat[]; groups: SeedGroupChat[] } = seedData.conversations;

function isValidEan13(code: string): boolean {
  if (!/^\d{13}$/.test(code)) return false;
  const sum = [...code.slice(0, 12)].reduce((s, c, i) => s + Number(c) * (i % 2 ? 3 : 1), 0);
  return (10 - (sum % 10)) % 10 === Number(code[12]);
}
for (const f of foodItems) {
  if (f.barcode && !isValidEan13(f.barcode)) throw new Error(`Invalid EAN-13 barcode for "${f.name}": ${f.barcode}`);
}

// Pure derivations from the persona list — no DB round-trip needed, so these
// are ready before any inserts happen and can be used throughout.
const personaByUsername = new Map(personas.map((p) => [p.username, p]));
const businessByName = new Map(businesses.map((b) => [b.name, b]));
const gymBusinesses = businesses.filter((b) => b.type === "gym");
const memberUsernamesByGym = new Map<string, string[]>();
const trainerUsernamesByGym = new Map<string, string[]>(); // trainers + employee-trainers
const deskStaffUsernamesByGym = new Map<string, string[]>(); // employees + employee-trainers
const ownerUsernameByBusiness = new Map<string, string>();
const ownerUsernamesByBusiness = new Map<string, string[]>();
const vendorUsernamesByShop = new Map<string, string[]>();
const push = (map: Map<string, string[]>, key: string, value: string) =>
  (map.get(key) ?? map.set(key, []).get(key)!).push(value);
for (const p of personas) {
  const homeBusiness = p.businesses[0];
  if (p.role === "member" && homeBusiness) push(memberUsernamesByGym, homeBusiness, p.username);
  if ((p.role === "trainer" || p.role === "employee_trainer") && homeBusiness) {
    push(trainerUsernamesByGym, homeBusiness, p.username);
  }
  if ((p.role === "employee" || p.role === "employee_trainer") && homeBusiness) {
    push(deskStaffUsernamesByGym, homeBusiness, p.username);
  }
  if (p.role === "shop_vendor" && homeBusiness) push(vendorUsernamesByShop, homeBusiness, p.username);
  if (p.role === "owner") {
    for (const b of p.businesses) {
      if (!ownerUsernameByBusiness.has(b)) ownerUsernameByBusiness.set(b, p.username);
      push(ownerUsernamesByBusiness, b, p.username);
    }
  }
}
const fullName = (username: string) => {
  const p = personaByUsername.get(username);
  return p ? `${p.first_name} ${p.last_name}` : "Someone";
};
const tzOf = (businessName: string) => businessByName.get(businessName)?.timezone ?? "America/New_York";

/** Expiry date (YYYY-MM-DD) of a member whose seeded membership has lapsed, else null. */
function lapsedOn(username: string): string | null {
  const plan = membershipPlans[username];
  return plan && plan.ends_in_days < 0 ? addDays(TODAY_UTC, plan.ends_in_days) : null;
}

// ── 1. Businesses ─────────────────────────────────────────────────────────────

const businessIdByName = new Map<string, string>();
const businessTypeByName = new Map<string, "gym" | "shop">();
let added = 0;

for (const b of businesses) {
  const existing = await db.selectFrom("business").select(["id"]).where("name", "=", b.name).executeTakeFirst();
  let id: string;
  if (existing) {
    id = existing.id;
    // Coordinates arrived with migration 000014; fill them in once.
    await db.updateTable("business")
      .set({ latitude: b.latitude, longitude: b.longitude })
      .where("id", "=", id).where("latitude", "is", null).execute();
  } else {
    const row = await db
      .insertInto("business")
      .values({
        name: b.name,
        location: b.location,
        latitude: b.latitude,
        longitude: b.longitude,
        logo: photoUrl(b.logo_image_key, 800, 400),
        working_hours_from: b.working_hours_from,
        working_hours_to: b.working_hours_to,
        working_weekdays: b.working_weekdays,
        type: b.type,
      })
      .returning(["id"])
      .executeTakeFirstOrThrow();
    id = row.id;
    if (b.type === "gym") await db.insertInto("gym").values({ id }).execute();
    else await db.insertInto("shop").values({ id }).execute();
    added++;
  }
  businessIdByName.set(b.name, id);
  businessTypeByName.set(b.name, b.type);
}
report("businesses", added);

// ── 2. Personas (auth users + profile rows + role-join rows) ─────────────────

/** Finds an existing auth user by email, paging through the admin API. */
async function findAuthUserId(email: string): Promise<string | null> {
  const perPage = 1000;
  for (let page = 1; ; page++) {
    const { data, error } = await supabaseAdmin.auth.admin.listUsers({ page, perPage });
    if (error) throw new Error(`Failed to list auth users: ${error.message}`);
    const found = data.users.find((u) => u.email?.toLowerCase() === email.toLowerCase());
    if (found) return found.id;
    if (data.users.length < perPage) return null;
  }
}

const userIdByUsername = new Map<string, string>();
let usersAdded = 0;
let roleRowsAdded = 0;

for (const p of personas) {
  const existingProfile = await db
    .selectFrom("users")
    .select(["id", "auth_id"])
    .where("email", "=", p.email)
    .executeTakeFirst();

  let userId: string;
  if (existingProfile) {
    userId = existingProfile.id;
    if (RESET_PASSWORDS && existingProfile.auth_id) {
      const { error } = await supabaseAdmin.auth.admin.updateUserById(existingProfile.auth_id, {
        password: SEED_PASSWORD,
      });
      if (error) throw new Error(`Failed to reset the password of ${p.email}: ${error.message}`);
      console.log(`  ~ password reset for "${p.username}"`);
    }
  } else {
    let authUserId: string;
    const { data, error } = await supabaseAdmin.auth.admin.createUser({
      email: p.email,
      password: SEED_PASSWORD,
      email_confirm: true,
      user_metadata: { username: p.username, name: p.first_name, last_name: p.last_name },
    });
    if (data.user) {
      authUserId = data.user.id;
    } else if (error?.message.includes("already been registered")) {
      // Left over from a partial run (e.g. auth user created but the profile
      // insert failed afterward) — reuse the existing auth user instead.
      const found = await findAuthUserId(p.email);
      if (!found) throw new Error(`Auth said "${p.email}" is registered but it wasn't found in listUsers()`);
      authUserId = found;
    } else {
      throw new Error(`Failed to create auth user ${p.email}: ${error?.message}`);
    }

    const row = await db
      .insertInto("users")
      .values({
        username: p.username,
        email: p.email,
        name: p.first_name,
        last_name: p.last_name,
        role: p.role,
        avatar_url: avatarUrl(p.avatar_key),
        auth_id: authUserId,
      })
      .returning(["id"])
      .executeTakeFirstOrThrow();
    userId = row.id;
    usersAdded++;
    console.log(`  + user "${p.username}" (${p.role})`);
  }
  userIdByUsername.set(p.username, userId);

  // Role-join rows for every business this persona is tied to (idempotent:
  // only insert — and only notify the business owner — if not already present).
  const roleTable = {
    trainer: "trainer" as const,
    member: "member" as const,
    employee: "employee" as const,
    employee_trainer: "employee_trainer" as const,
  }[p.role as "trainer" | "member" | "employee" | "employee_trainer"];

  for (const businessName of p.businesses) {
    const businessId = businessIdByName.get(businessName);
    const businessType = businessTypeByName.get(businessName);
    if (!businessId || !businessType) {
      console.warn(`  ! unknown business "${businessName}" referenced by persona "${p.username}" — skipping`);
      continue;
    }

    let didInsert = false;
    if (p.role === "owner") {
      if (businessType === "gym") {
        const exists = await db
          .selectFrom("gym_owner")
          .select("id")
          .where("user_id", "=", userId)
          .where("gym_id", "=", businessId)
          .executeTakeFirst();
        if (!exists) {
          await db.insertInto("gym_owner").values({ user_id: userId, gym_id: businessId }).execute();
          didInsert = true;
        }
      } else {
        const exists = await db
          .selectFrom("shop_owner")
          .select("id")
          .where("user_id", "=", userId)
          .where("shop_id", "=", businessId)
          .executeTakeFirst();
        if (!exists) {
          await db.insertInto("shop_owner").values({ user_id: userId, shop_id: businessId }).execute();
          didInsert = true;
        }
      }
    } else if (p.role === "shop_vendor") {
      const exists = await db
        .selectFrom("shop_vendor")
        .select("id")
        .where("user_id", "=", userId)
        .where("shop_id", "=", businessId)
        .executeTakeFirst();
      if (!exists) {
        await db.insertInto("shop_vendor").values({ user_id: userId, shop_id: businessId }).execute();
        didInsert = true;
      }
    } else if (roleTable) {
      const exists = await db
        .selectFrom(roleTable)
        .select("id")
        .where("user_id", "=", userId)
        .where("gym_id", "=", businessId)
        .executeTakeFirst();
      if (!exists) {
        await db.insertInto(roleTable).values({ user_id: userId, gym_id: businessId }).execute();
        didInsert = true;
      }
    }
    if (didInsert) roleRowsAdded++;

    // Notify the business owner the first time someone joins their business.
    if (didInsert && p.role !== "owner") {
      const ownerUsername = ownerUsernameByBusiness.get(businessName);
      const ownerId = ownerUsername ? userIdByUsername.get(ownerUsername) : undefined;
      if (ownerId) {
        const notifType: NotificationType = p.role === "shop_vendor"
          ? "vendor_join"
          : p.role === "member"
          ? "member_join"
          : "employee_join";
        await db
          .insertInto("notification")
          .values({
            user_id: ownerId,
            type: notifType,
            title: `${p.first_name} ${p.last_name} joined ${businessName}`,
            body: null,
            metadata: { user_id: userId, username: p.username, role: p.role },
          })
          .execute();
        notificationsAdded++;
      }
    }
  }
}
report("users", usersAdded);
report("business role rows", roleRowsAdded);

const trainerUsername = personas.find((p) => p.role === "trainer")!.username;
const trainerId = userIdByUsername.get(trainerUsername)!;
const memberUsernames = personas.filter((p) => p.role === "member").map((p) => p.username);
const uid = (username: string) => userIdByUsername.get(username)!;

// ── 3. Exercises ──────────────────────────────────────────────────────────────

const exerciseIdByName = new Map<string, string>();
const exerciseWeightById = new Map<string, number | null>();
added = 0;
let illustrationsLinked = 0;

for (const ex of exercises) {
  const imageUrl = await exerciseIllustrationUrl(ex.name);
  const existing = await db.selectFrom("exercise").select(["id", "image_url", "author_id"])
    .where("name", "=", ex.name).executeTakeFirst();
  if (existing) {
    exerciseIdByName.set(ex.name, existing.id);
    exerciseWeightById.set(existing.id, ex.default_weight_kg);
    // Only seeded rows still showing a picsum placeholder or an older
    // illustration — never an image someone uploaded.
    const current = existing.image_url;
    const replaceable = current === null || current.startsWith("https://picsum.photos/") ||
      current.startsWith(ILLUSTRATION_URL_PREFIX);
    if (imageUrl && current !== imageUrl && replaceable && existing.author_id === trainerId) {
      await db.updateTable("exercise").set({ image_url: imageUrl }).where("id", "=", existing.id).execute();
      illustrationsLinked++;
    }
    continue;
  }
  const row = await db
    .insertInto("exercise")
    .values({
      name: ex.name,
      description: ex.description,
      note: ex.note,
      image_url: imageUrl,
      video_url: null,
      author_id: trainerId,
      primary_muscles: ex.primary_muscles,
      secondary_muscles: ex.secondary_muscles,
      is_public: true,
    })
    .returning(["id"])
    .executeTakeFirstOrThrow();
  exerciseIdByName.set(ex.name, row.id);
  exerciseWeightById.set(row.id, ex.default_weight_kg);
  added++;
}
report("exercises", added);
report("exercise illustration uploads", illustrationsUploaded);
report("existing exercises given their illustration", illustrationsLinked);

// ── 4. Trainings ──────────────────────────────────────────────────────────────

function repCountFromRange(range: string): number {
  const [lo, hi] = range.split("-").map((n) => parseInt(n, 10));
  if (Number.isNaN(hi)) return lo;
  return Math.round((lo + hi) / 2);
}

const trainingIdByName = new Map<string, string>();
added = 0;

for (const t of trainings) {
  const existing = await db.selectFrom("training").select(["id"]).where("name", "=", t.name).executeTakeFirst();
  if (existing) {
    trainingIdByName.set(t.name, existing.id);
    continue;
  }

  const training = await db
    .insertInto("training")
    .values({ name: t.name, description: t.description, notes: null, author_id: trainerId, is_public: true })
    .returning(["id"])
    .executeTakeFirstOrThrow();
  trainingIdByName.set(t.name, training.id);

  await db
    .insertInto("training_image")
    .values({ training_id: training.id, url: photoUrl(`training-${t.name}`, 800, 450), is_thumbnail: true, position: 0 })
    .execute();

  // Group set entries by position — entries sharing a position form one
  // training_set with multiple exercise slots (e.g. a superset pairing).
  const byPosition = new Map<number, SeedTrainingSet[]>();
  for (const s of t.sets) {
    (byPosition.get(s.position) ?? byPosition.set(s.position, []).get(s.position)!).push(s);
  }

  for (const [position, group] of [...byPosition.entries()].sort((a, b) => a[0] - b[0])) {
    const setInsert: TrainingSetInsert = {
      training_id: training.id,
      type: group[0].type,
      position,
      rest_seconds: group[0].rest_seconds,
      note: null,
    };
    const trainingSet = await db.insertInto("training_set").values(setInsert).returning(["id"]).executeTakeFirstOrThrow();

    for (const [i, s] of group.entries()) {
      const exerciseId = exerciseIdByName.get(s.exercise_name);
      if (!exerciseId) {
        console.warn(`  ! unknown exercise "${s.exercise_name}" referenced by training "${t.name}" — skipping`);
        continue;
      }
      const exInsert: TrainingSetExerciseInsert = {
        training_set_id: trainingSet.id,
        exercise_id: exerciseId,
        position: i,
        is_alternating: false,
        rest_between_drops_seconds: null,
        note: null,
      };
      const setExercise = await db
        .insertInto("training_set_exercise")
        .values(exInsert)
        .returning(["id"])
        .executeTakeFirstOrThrow();

      const repCount = repCountFromRange(s.rep_range);
      const dropInserts: TrainingSetDropInsert[] = Array.from({ length: s.sets_count }, (_, dropNumber) => ({
        training_set_exercise_id: setExercise.id,
        drop_number: dropNumber,
        rep_type: "count" as RepType,
        rep_count: repCount,
        weight_kg: null,
        side: "both",
        note: null,
      }));
      await db.insertInto("training_set_drop").values(dropInserts).execute();
    }
  }
  added++;
}
report("trainings", added);

// Reload the full set/exercise/drop structure for every training (regardless
// of whether it was just created or already existed) — training_session
// generation below needs the real ids to log against.
type TrainingSetStructure = {
  trainingSetId: string;
  exercises: {
    exerciseId: string;
    position: number;
    drops: { id: string; dropNumber: number; repType: RepType; repCount: number | null }[];
  }[];
};
const trainingStructureByName = new Map<string, TrainingSetStructure[]>();

for (const t of trainings) {
  const trainingId = trainingIdByName.get(t.name);
  if (!trainingId) continue;

  const sets = await db.selectFrom("training_set").select(["id"]).where("training_id", "=", trainingId).orderBy("position").execute();
  const structure: TrainingSetStructure[] = [];
  for (const s of sets) {
    const setExercises = await db
      .selectFrom("training_set_exercise")
      .select(["id", "exercise_id", "position"])
      .where("training_set_id", "=", s.id)
      .orderBy("position")
      .execute();
    const exercisesWithDrops = [];
    for (const e of setExercises) {
      const drops = await db
        .selectFrom("training_set_drop")
        .select(["id", "drop_number", "rep_type", "rep_count"])
        .where("training_set_exercise_id", "=", e.id)
        .orderBy("drop_number")
        .execute();
      exercisesWithDrops.push({
        exerciseId: e.exercise_id,
        position: e.position,
        drops: drops.map((d) => ({ id: d.id, dropNumber: d.drop_number, repType: d.rep_type, repCount: d.rep_count })),
      });
    }
    structure.push({ trainingSetId: s.id, exercises: exercisesWithDrops });
  }
  trainingStructureByName.set(t.name, structure);
}

// ── 5. Routines ────────────────────────────────────────────────────────────────

const routineIdByName = new Map<string, string>();
added = 0;

for (const r of routines) {
  const existing = await db.selectFrom("routine").select(["id"]).where("name", "=", r.name).executeTakeFirst();
  if (existing) {
    routineIdByName.set(r.name, existing.id);
    continue;
  }

  const routine = await db
    .insertInto("routine")
    .values({
      name: r.name,
      description: r.description,
      notes: null,
      author_id: trainerId,
      is_public: true,
      schedule_type: r.schedule_type,
      num_weeks: r.num_weeks,
    })
    .returning(["id"])
    .executeTakeFirstOrThrow();
  routineIdByName.set(r.name, routine.id);

  await db
    .insertInto("routine_image")
    .values({ routine_id: routine.id, url: photoUrl(`routine-${r.name}`, 800, 450), is_thumbnail: true, position: 0 })
    .execute();

  for (let week = 1; week <= r.num_weeks; week++) {
    for (const [i, trainingName] of r.training_names.entries()) {
      const trainingId = trainingIdByName.get(trainingName);
      if (!trainingId) {
        console.warn(`  ! unknown training "${trainingName}" referenced by routine "${r.name}" — skipping`);
        continue;
      }
      await db
        .insertInto("routine_training")
        .values({
          routine_id: routine.id,
          training_id: trainingId,
          week_number: week,
          day_of_week: (i % 7) + 1,
          position: i,
          note: null,
        })
        .execute();
    }
  }
  added++;
}
report("routines", added);

// ── 6. Food items (+ barcodes) ─────────────────────────────────────────────────

const foodItemIdByName = new Map<string, string>();
const foodItemMacrosByName = new Map<string, SeedFoodItem>();
added = 0;
let barcodesAdded = 0;

for (const f of foodItems) {
  foodItemMacrosByName.set(f.name, f);
  const existing = await db.selectFrom("food_item").select(["id", "barcode"]).where("name", "=", f.name)
    .executeTakeFirst();
  if (existing) {
    foodItemIdByName.set(f.name, existing.id);
    // Backfill barcodes on system items created before they were in the data;
    // never overwrite a barcode someone set.
    if (f.barcode && !existing.barcode) {
      const res = await db.updateTable("food_item").set({ barcode: f.barcode })
        .where("id", "=", existing.id).where("barcode", "is", null).where("is_system", "=", true)
        .executeTakeFirst();
      barcodesAdded += Number(res.numUpdatedRows);
    }
    continue;
  }
  const insert: FoodItemInsert = {
    name: f.name,
    brand: f.brand,
    barcode: f.barcode,
    type: f.type,
    food_subtype: f.food_subtype,
    drink_subtype: f.drink_subtype,
    spice_subtype: f.spice_subtype,
    serving_unit: f.serving_unit,
    kcal_per_100: f.kcal_per_100,
    protein_per_100: f.protein_per_100,
    carb_per_100: f.carb_per_100,
    fat_per_100: f.fat_per_100,
    fiber_per_100: f.fiber_per_100,
    author_id: null,
    is_public: true,
    is_system: true,
  };
  const row = await db.insertInto("food_item").values(insert).returning(["id"]).executeTakeFirstOrThrow();
  foodItemIdByName.set(f.name, row.id);
  added++;
  if (f.barcode) barcodesAdded++;
}
report("food items", added);
report("food item barcodes", barcodesAdded);

// ── 6b. Micronutrients (reference rows come from migration 000012) ────────────

{
  const vitaminIdBySymbol = new Map(
    (await db.selectFrom("vitamin").select(["id", "symbol"]).execute()).map((v) => [v.symbol, v.id]),
  );
  const mineralIdBySymbol = new Map(
    (await db.selectFrom("mineral").select(["id", "symbol"]).execute()).map((m) => [m.symbol, m.id]),
  );
  let vitaminsAdded = 0;
  let mineralsAdded = 0;
  for (const m of foodMicronutrients) {
    const foodItemId = foodItemIdByName.get(m.food_item_name);
    if (!foodItemId) {
      console.warn(`  ! unknown food item "${m.food_item_name}" in food_micronutrients — skipping`);
      continue;
    }
    const vitamins = Object.entries(m.vitamins).flatMap(([symbol, amount]) => {
      const vitamin_id = vitaminIdBySymbol.get(symbol);
      if (!vitamin_id) console.warn(`  ! unknown vitamin symbol "${symbol}" — run the migrations first`);
      return vitamin_id ? [{ food_item_id: foodItemId, vitamin_id, amount_per_100: amount, unit: null }] : [];
    });
    const minerals = Object.entries(m.minerals).flatMap(([symbol, amount]) => {
      const mineral_id = mineralIdBySymbol.get(symbol);
      if (!mineral_id) console.warn(`  ! unknown mineral symbol "${symbol}" — run the migrations first`);
      return mineral_id ? [{ food_item_id: foodItemId, mineral_id, amount_per_100: amount, unit: null }] : [];
    });
    if (vitamins.length) {
      const res = await db.insertInto("food_item_vitamin").values(vitamins)
        .onConflict((oc) => oc.columns(["food_item_id", "vitamin_id"]).doNothing()).executeTakeFirst();
      vitaminsAdded += Number(res.numInsertedOrUpdatedRows ?? 0);
    }
    if (minerals.length) {
      const res = await db.insertInto("food_item_mineral").values(minerals)
        .onConflict((oc) => oc.columns(["food_item_id", "mineral_id"]).doNothing()).executeTakeFirst();
      mineralsAdded += Number(res.numInsertedOrUpdatedRows ?? 0);
    }
  }
  report("food item vitamin values", vitaminsAdded);
  report("food item mineral values", mineralsAdded);
}

// ── 7. Recipes ─────────────────────────────────────────────────────────────────

type RecipeMacros = { kcal: number; protein: number; carb: number; fat: number; fiber: number };
const recipeIdByName = new Map<string, string>();
const recipeMacrosPerServingByName = new Map<string, RecipeMacros>();
added = 0;

for (const r of recipes) {
  const existing = await db.selectFrom("recipe").select(["id"]).where("name", "=", r.name).executeTakeFirst();
  if (existing) {
    recipeIdByName.set(r.name, existing.id);
    // Recompute macros from ingredients so downstream daily-meal-plan totals
    // still work correctly even when the recipe already existed.
  }

  const totals = { kcal: 0, protein: 0, carb: 0, fat: 0, fiber: 0 };
  for (const ing of r.ingredients) {
    const macros = foodItemMacrosByName.get(ing.food_item_name);
    if (!macros) {
      console.warn(`  ! unknown food item "${ing.food_item_name}" referenced by recipe "${r.name}" — skipping ingredient`);
      continue;
    }
    const factor = ing.quantity_g_or_ml / 100;
    totals.kcal += macros.kcal_per_100 * factor;
    totals.protein += macros.protein_per_100 * factor;
    totals.carb += macros.carb_per_100 * factor;
    totals.fat += macros.fat_per_100 * factor;
    totals.fiber += macros.fiber_per_100 * factor;
  }
  const perServing: RecipeMacros = {
    kcal: totals.kcal / r.servings,
    protein: totals.protein / r.servings,
    carb: totals.carb / r.servings,
    fat: totals.fat / r.servings,
    fiber: totals.fiber / r.servings,
  };
  recipeMacrosPerServingByName.set(r.name, perServing);

  if (existing) continue;

  const recipe = await db
    .insertInto("recipe")
    .values({
      name: r.name,
      description: r.description,
      author_id: trainerId,
      servings: r.servings,
      prep_time_minutes: r.prep_time_minutes,
      cook_time_minutes: r.cook_time_minutes,
      kcal_per_serving: perServing.kcal,
      protein_per_serving: perServing.protein,
      carb_per_serving: perServing.carb,
      fat_per_serving: perServing.fat,
      fiber_per_serving: perServing.fiber,
      is_public: true,
      is_system: false,
    })
    .returning(["id"])
    .executeTakeFirstOrThrow();
  recipeIdByName.set(r.name, recipe.id);

  for (const [i, ing] of r.ingredients.entries()) {
    const foodItemId = foodItemIdByName.get(ing.food_item_name);
    if (!foodItemId) continue;
    await db
      .insertInto("recipe_ingredient")
      .values({
        recipe_id: recipe.id,
        food_item_id: foodItemId,
        quantity: ing.quantity_g_or_ml,
        note: ing.note,
        position: i,
      })
      .execute();
  }

  for (const [i, step] of r.steps.entries()) {
    await db
      .insertInto("recipe_step")
      .values({ recipe_id: recipe.id, position: i, instruction: step, image_url: null })
      .execute();
  }

  await db
    .insertInto("recipe_image")
    .values({ recipe_id: recipe.id, url: photoUrl(`recipe-${r.name}`, 800, 600), is_thumbnail: true, position: 0 })
    .execute();

  added++;
}
report("recipes", added);

// ── 8. Daily meal plans ──────────────────────────────────────────────────────

const dailyMealPlanIdByName = new Map<string, string>();
added = 0;

for (const d of dailyMealPlans) {
  const existing = await db.selectFrom("daily_meal_plan").select(["id"]).where("name", "=", d.name).executeTakeFirst();
  if (existing) {
    dailyMealPlanIdByName.set(d.name, existing.id);
    continue;
  }

  const totals = { kcal: 0, protein: 0, carb: 0, fat: 0, fiber: 0 };
  const resolvedSlots = d.slots.map((slot) => ({
    ...slot,
    entries: slot.entries.map((entry) => {
      if (entry.source === "food_item") {
        const macros = foodItemMacrosByName.get(entry.name);
        const qty = entry.quantity_g_or_ml ?? 0;
        if (macros) {
          const factor = qty / 100;
          totals.kcal += macros.kcal_per_100 * factor;
          totals.protein += macros.protein_per_100 * factor;
          totals.carb += macros.carb_per_100 * factor;
          totals.fat += macros.fat_per_100 * factor;
          totals.fiber += macros.fiber_per_100 * factor;
        }
        return { ...entry, foodItemId: foodItemIdByName.get(entry.name) };
      } else {
        const macros = recipeMacrosPerServingByName.get(entry.name);
        const servings = entry.servings ?? 1;
        if (macros) {
          totals.kcal += macros.kcal * servings;
          totals.protein += macros.protein * servings;
          totals.carb += macros.carb * servings;
          totals.fat += macros.fat * servings;
          totals.fiber += macros.fiber * servings;
        }
        return { ...entry, recipeId: recipeIdByName.get(entry.name) };
      }
    }),
  }));

  const plan = await db
    .insertInto("daily_meal_plan")
    .values({
      name: d.name,
      description: d.description,
      author_id: trainerId,
      is_public: true,
      is_system: false,
      kcal_total: totals.kcal,
      protein_total: totals.protein,
      carb_total: totals.carb,
      fat_total: totals.fat,
      fiber_total: totals.fiber,
    })
    .returning(["id"])
    .executeTakeFirstOrThrow();
  dailyMealPlanIdByName.set(d.name, plan.id);

  for (const [slotIndex, slot] of resolvedSlots.entries()) {
    const slotRow = await db
      .insertInto("daily_meal_plan_slot")
      .values({ daily_meal_plan_id: plan.id, slot_type: slot.slot_type, position: slotIndex, note: null })
      .returning(["id"])
      .executeTakeFirstOrThrow();

    for (const [entryIndex, entry] of slot.entries.entries()) {
      const isFood = "foodItemId" in entry;
      if (isFood && !entry.foodItemId) continue;
      if (!isFood && !("recipeId" in entry && entry.recipeId)) continue;

      const insert: DailyMealPlanSlotEntryInsert = {
        daily_meal_plan_slot_id: slotRow.id,
        food_item_id: isFood ? (entry as { foodItemId?: string }).foodItemId ?? null : null,
        recipe_id: !isFood ? (entry as { recipeId?: string }).recipeId ?? null : null,
        quantity: isFood ? entry.quantity_g_or_ml ?? null : null,
        servings: !isFood ? entry.servings ?? 1 : null,
        position: entryIndex,
        note: null,
      };
      await db.insertInto("daily_meal_plan_slot_entry").values(insert).execute();
    }
  }
  added++;
}
report("daily meal plans", added);

// ── 9. Meal plans ─────────────────────────────────────────────────────────────

const mealPlanIdByName = new Map<string, string>();
added = 0;

for (const m of mealPlans) {
  const existing = await db.selectFrom("meal_plan").select(["id"]).where("name", "=", m.name).executeTakeFirst();
  if (existing) {
    mealPlanIdByName.set(m.name, existing.id);
    continue;
  }

  const plan = await db
    .insertInto("meal_plan")
    .values({
      name: m.name,
      description: m.description,
      author_id: trainerId,
      is_public: true,
      is_system: false,
      num_weeks: m.num_weeks,
    })
    .returning(["id"])
    .executeTakeFirstOrThrow();
  mealPlanIdByName.set(m.name, plan.id);

  await db
    .insertInto("meal_plan_image")
    .values({ meal_plan_id: plan.id, url: photoUrl(`mealplan-${m.name}`, 800, 600), is_thumbnail: true, position: 0 })
    .execute();

  for (const day of m.days) {
    const dailyId = dailyMealPlanIdByName.get(day.daily_meal_plan_name);
    if (!dailyId) {
      console.warn(`  ! unknown daily meal plan "${day.daily_meal_plan_name}" referenced by "${m.name}" — skipping day`);
      continue;
    }
    await db
      .insertInto("meal_plan_day")
      .values({
        meal_plan_id: plan.id,
        daily_meal_plan_id: dailyId,
        week_number: day.week_number,
        day_of_week: day.day_of_week,
        note: null,
      })
      .execute();
  }
  added++;
}
report("meal plans", added);

// Assign each meal plan to a member. The plan started three weeks ago so the
// food diary below has planned days to follow.
added = 0;
for (const [i, m] of mealPlans.entries()) {
  const planId = mealPlanIdByName.get(m.name);
  if (!planId) continue;
  const assignee = memberUsernames[i % memberUsernames.length];
  const assigneeId = userIdByUsername.get(assignee);
  if (!assigneeId) continue;
  const existing = await db
    .selectFrom("meal_plan_assignment")
    .select("id")
    .where("meal_plan_id", "=", planId)
    .where("user_id", "=", assigneeId)
    .executeTakeFirst();
  if (existing) continue;
  const startDate = addDays(TODAY_UTC, -21);
  await db
    .insertInto("meal_plan_assignment")
    .values({
      meal_plan_id: planId,
      user_id: assigneeId,
      assigned_by_id: trainerId,
      start_date: startDate,
      end_date: null,
      note: null,
      created_at: iso(Date.parse(`${addDays(startDate, -2)}T18:00:00Z`)),
    })
    .execute();
  added++;
}
report("meal plan assignments", added);

// ── 10. Shop products ─────────────────────────────────────────────────────────

added = 0;
for (const p of shopProducts) {
  const shopId = businessIdByName.get(p.shop_name);
  if (!shopId) {
    console.warn(`  ! unknown shop "${p.shop_name}" referenced by product "${p.name}" — skipping`);
    continue;
  }
  const existing = await db
    .selectFrom("shop_item")
    .select(["id"])
    .where("shop_id", "=", shopId)
    .where("name", "=", p.name)
    .executeTakeFirst();
  if (existing) continue;
  await db
    .insertInto("shop_item")
    .values({
      shop_id: shopId,
      type: p.type,
      name: p.name,
      description: p.description,
      price: p.price,
      quantity: p.quantity,
      is_active: true,
      active_until: null,
      image_url: photoUrl(`product-${p.name}`, 800, 800),
    })
    .execute();
  added++;
}
report("shop products", added);

// ── 11. Posts ──────────────────────────────────────────────────────────────────
// New posts are spread over the last ~4 weeks (oldest first, in data order).

function businessIdForAuthor(username: string): string | null {
  const homeBusiness = personaByUsername.get(username)?.businesses[0];
  return homeBusiness ? businessIdByName.get(homeBusiness) ?? null : null;
}

added = 0;
for (const [i, p] of posts.entries()) {
  const existing = await db
    .selectFrom("post")
    .select(["id"])
    .where("content", "=", p.content)
    .executeTakeFirst();
  if (existing) continue;

  const authorId = userIdByUsername.get(p.author_persona_username);
  if (!authorId) {
    console.warn(`  ! unknown persona "${p.author_persona_username}" referenced by a post — skipping`);
    continue;
  }
  const businessId = businessIdForAuthor(p.author_persona_username);
  if (!businessId) {
    console.warn(`  ! persona "${p.author_persona_username}" has no home business — skipping post`);
    continue;
  }

  const rng = rngFor("post", p.content);
  const createdMs = clampPast(NOW_MS - (posts.length - i) * 25 * HOUR_MS + rng.int(0, 6 * 60) * MIN_MS, 30);
  const post = await db
    .insertInto("post")
    .values({
      business_id: businessId,
      author_id: authorId,
      content: p.content,
      created_at: iso(createdMs),
      updated_at: iso(createdMs),
    })
    .returning(["id"])
    .executeTakeFirstOrThrow();

  if (p.has_image) {
    await db
      .insertInto("post_image")
      .values({ post_id: post.id, url: photoUrl(`post-${post.id}`, 1000, 600), position: 0 })
      .execute();
  }
  added++;
}
report("posts", added);

// ── 12. Membership types, memberships and invoices ────────────────────────────
// Each seeded member gets the plan from seed_data.json `membership_plans`: a
// realistic spread of long-running, expiring-within-a-week and already
// expired memberships, billed monthly from the start date (older invoices
// paid, the latest one paid / unpaid / void per the plan).
//
// Databases seeded by the previous version of this script have every
// membership running from −1 to +2 months with a single unpaid 3-month
// invoice. Such a row is reshaped into its plan ONLY when it is provably
// untouched seed output (exact −1/+2-month shape, that single unpaid 3×
// invoice, no auto-renew/Stripe subscription, no payment rows); anything an
// app user or test changed is left alone. Once reshaped it no longer matches,
// so this runs at most once per row.

const membershipTypeDefs = [
  { name: "Basic", monthly_cost: 29.99 },
  { name: "Premium", monthly_cost: 59.99 },
  { name: "Elite", monthly_cost: 99.99 },
];

type PlannedInvoice = { issuedMs: number; amount: number; status: InvoiceStatus; paidMs: number | null };

function planMembership(username: string, gymName: string, fallbackType: string) {
  const plan: SeedMembershipPlan = membershipPlans[username] ??
    { type: fallbackType, start_months_ago: 2, start_extra_days: 0, ends_in_days: 60, latest_invoice: "paid" };
  const rng = rngFor("membership", username);
  const tz = tzOf(gymName);
  const from = addDays(addMonths(TODAY_UTC, -plan.start_months_ago), -plan.start_extra_days);
  const to = addDays(TODAY_UTC, plan.ends_in_days);
  const monthly = membershipTypeDefs.find((t) => t.name === plan.type)?.monthly_cost ?? 29.99;
  const issueDates: string[] = [];
  for (let k = 0; k < 36; k++) {
    const issue = addMonths(from, k);
    if (issue > TODAY_UTC || issue >= to) break;
    issueDates.push(issue);
  }
  const invoices: PlannedInvoice[] = issueDates.map((date, k) => {
    const issuedMs = clampPast(zonedTime(date, "09:00", tz), 5);
    const status: InvoiceStatus = k === issueDates.length - 1 ? plan.latest_invoice : "paid";
    const paidMs = status === "paid"
      ? Math.max(issuedMs + MIN_MS, clampPast(issuedMs + rng.int(2 * 60, 3 * 24 * 60) * MIN_MS, 2))
      : null;
    return { issuedMs, amount: monthly, status, paidMs };
  });
  return { plan, from, to, isActive: to >= TODAY_UTC, invoices };
}

async function membershipNotifications(
  userId: string,
  membershipId: string,
  gymId: string,
  gymName: string,
  typeName: string,
  planned: ReturnType<typeof planMembership>,
  latestInvoiceId: string | null,
) {
  const latest = planned.invoices.at(-1);
  if (latest && latestInvoiceId) {
    const amount = latest.amount.toFixed(2);
    await addNotification([userId], {
      type: "invoice_issued",
      title: `New invoice from ${gymName}`,
      body: `An invoice of ${amount} was issued for your ${typeName} membership.`,
      metadata: { invoice_id: latestInvoiceId, membership_id: membershipId, gym_id: gymId, amount },
    }, latest.issuedMs);
  }
  // What the jobs cron sends for memberships ending within 7 days (it skips
  // memberships that already have one, so this also prevents a duplicate).
  if (planned.isActive && daysBetween(TODAY_UTC, planned.to) <= 7) {
    await addNotification([userId], {
      type: "membership_expiring",
      title: `Your ${gymName} membership is expiring`,
      body: `Your membership ends on ${planned.to}. Renew it to keep training.`,
      metadata: { membership_id: membershipId, gym_id: gymId, gym_name: gymName, to_date: planned.to },
    }, NOW_MS - rngFor("expiring", userId).int(1, 30) * HOUR_MS);
  }
}

let membershipTypesAdded = 0;
let membershipsAdded = 0;
let membershipsReshaped = 0;
let membershipInvoicesAdded = 0;

for (const gym of gymBusinesses) {
  const gymId = businessIdByName.get(gym.name)!;
  const membershipTypeIdByName = new Map<string, string>();

  for (const t of membershipTypeDefs) {
    const existing = await db
      .selectFrom("gym_membership_type")
      .select(["id"])
      .where("gym_id", "=", gymId)
      .where("name", "=", t.name)
      .executeTakeFirst();
    if (existing) {
      membershipTypeIdByName.set(t.name, existing.id);
      continue;
    }
    const row = await db
      .insertInto("gym_membership_type")
      .values({ name: t.name, monthly_cost: t.monthly_cost, gym_id: gymId, is_active: true })
      .returning(["id"])
      .executeTakeFirstOrThrow();
    membershipTypeIdByName.set(t.name, row.id);
    membershipTypesAdded++;
  }

  const typeNames = [...membershipTypeIdByName.keys()];
  const gymMembers = memberUsernamesByGym.get(gym.name) ?? [];
  for (const [i, username] of gymMembers.entries()) {
    const userId = uid(username);
    const planned = planMembership(username, gym.name, typeNames[i % typeNames.length]);
    const typeId = membershipTypeIdByName.get(planned.plan.type) ?? membershipTypeIdByName.get(typeNames[0])!;
    const invoiceRows = (membershipId: string) =>
      planned.invoices.map((inv) => ({
        membership_id: membershipId,
        membership_type_id: typeId,
        issued_at: iso(inv.issuedMs),
        amount: inv.amount,
        status: inv.status,
        paid_at: inv.paidMs ? iso(inv.paidMs) : null,
      }));

    const existing = await db.selectFrom("membership").select(["id"]).where("user_id", "=", userId).executeTakeFirst();
    if (!existing) {
      const membership = await db
        .insertInto("membership")
        .values({
          user_id: userId,
          current_membership_type_id: typeId,
          from_date: planned.from,
          to_date: planned.to,
          is_active: planned.isActive,
          last_updated_date: iso(planned.invoices[0]?.issuedMs ?? clampPast(NOW_MS)),
        })
        .returning(["id"])
        .executeTakeFirstOrThrow();
      const rows = invoiceRows(membership.id);
      const inserted = rows.length
        ? await db.insertInto("membership_invoice").values(rows).returning(["id"]).execute()
        : [];
      membershipsAdded++;
      membershipInvoicesAdded += inserted.length;
      await membershipNotifications(
        userId, membership.id, gymId, gym.name, planned.plan.type, planned, inserted.at(-1)?.id ?? null,
      );
      continue;
    }

    // Legacy shape check (see the section comment).
    const { rows: [legacy] } = await sql<{ invoice_id: string }>`
      SELECT mi.id AS invoice_id
      FROM membership m
      JOIN gym_membership_type t ON t.id = m.current_membership_type_id
      JOIN membership_invoice mi ON mi.membership_id = m.id
      WHERE m.id = ${existing.id}
        AND t.gym_id = ${gymId}
        AND m.auto_renew = FALSE AND m.stripe_subscription_id IS NULL
        AND (m.to_date - m.from_date) BETWEEN 88 AND 93
        AND mi.status = 'unpaid' AND mi.paid_at IS NULL
        AND mi.amount = round(t.monthly_cost * 3, 2)
        AND (SELECT COUNT(*) FROM membership_invoice x WHERE x.membership_id = m.id) = 1
        AND NOT EXISTS (
          SELECT 1 FROM payment p WHERE p.membership_id = m.id OR p.membership_invoice_id = mi.id
        )
    `.execute(db);
    if (!legacy) continue;

    const rows = invoiceRows(existing.id);
    const latestId = await db.transaction().execute(async (trx) => {
      await trx.updateTable("membership").set({
        current_membership_type_id: typeId,
        from_date: planned.from,
        to_date: planned.to,
        is_active: planned.isActive,
        last_updated_date: iso(clampPast(NOW_MS)),
      }).where("id", "=", existing.id).execute();
      if (rows.length === 0) {
        await trx.deleteFrom("membership_invoice").where("id", "=", legacy.invoice_id).execute();
        return null;
      }
      const [first, ...rest] = rows;
      await trx.updateTable("membership_invoice").set(first).where("id", "=", legacy.invoice_id).execute();
      const inserted = rest.length
        ? await trx.insertInto("membership_invoice").values(rest).returning(["id"]).execute()
        : [];
      // The old seed's "Invoice issued — <type>" notice points at the 3-month
      // invoice that no longer exists; it is replaced by the API-shaped one.
      await trx.deleteFrom("notification")
        .where("user_id", "=", userId)
        .where("type", "=", "invoice_issued")
        .where("title", "like", "Invoice issued — %")
        .where(sql<boolean>`metadata->>'membership_id' = ${existing.id}`)
        .where(sql<boolean>`NOT (metadata ? 'invoice_id')`)
        .execute();
      return inserted.at(-1)?.id ?? legacy.invoice_id;
    });
    membershipsReshaped++;
    membershipInvoicesAdded += Math.max(0, rows.length - 1);
    await membershipNotifications(userId, existing.id, gymId, gym.name, planned.plan.type, planned, latestId);
  }
}
report("membership types", membershipTypesAdded);
report("memberships", membershipsAdded);
if (membershipsReshaped) report("legacy seed memberships reshaped", membershipsReshaped);
report("membership invoices", membershipInvoicesAdded);

// ── 13. Training sessions (logged workout history) ───────────────────────────
// Procedurally generated per member, driven by the trainings/exercises seeded
// above. A member with no sessions gets 4-7 over the last ~4 weeks; a member
// whose latest session is more than 6 days old (e.g. a database seeded a while
// ago) is topped up every few days until yesterday, so the history stays
// current. Neither path ever touches existing sessions.

const allTrainingNames = trainings.map((t) => t.name);
const sessionNotePool = [
  "Felt strong today, hit every rep.",
  "Low energy but pushed through.",
  "New PR on the last set!",
  "Short on time, trimmed the accessory work.",
  "Great pump, form felt clean all session.",
  null,
  null,
  null,
];

function actualWeightKg(rng: Rng, baseWeight: number | null | undefined, progressFactor: number): number | null {
  if (baseWeight === null || baseWeight === undefined) return null;
  const jitter = 1 + (rng.next() * 0.06 - 0.03);
  return Math.round((baseWeight * progressFactor * jitter) / 1.25) * 1.25;
}

async function logTrainingSession(
  rng: Rng,
  userId: string,
  gymName: string,
  day: string,
  progressFactor: number,
): Promise<boolean> {
  const gymTrainers = trainerUsernamesByGym.get(gymName) ?? [];
  const trainingName = rng.pick(allTrainingNames);
  const structure = trainingStructureByName.get(trainingName);
  if (!structure || structure.length === 0) return false;

  const coachUsername = gymTrainers.length && rng.chance(0.5) ? rng.pick(gymTrainers) : null;
  const totalDrops = structure.reduce((sum, s) => sum + s.exercises.reduce((s2, e) => s2 + e.drops.length, 0), 0);
  const durationMinutes = 15 + Math.round(totalDrops * 3.2);
  const startedMs = zonedTime(day, hhmm(rng.int(6 * 60, 20 * 60)), tzOf(gymName));
  if (startedMs + durationMinutes * MIN_MS > NOW_MS - HOUR_MS) return false;

  const session = await db
    .insertInto("training_session")
    .values({
      user_id: userId,
      trainer_id: coachUsername ? uid(coachUsername) : null,
      training_id: trainingIdByName.get(trainingName)!,
      started_at: iso(startedMs),
      ended_at: iso(startedMs + durationMinutes * MIN_MS),
      notes: rng.pick(sessionNotePool),
    })
    .returning(["id"])
    .executeTakeFirstOrThrow();

  const setLogRows = await db
    .insertInto("session_set_log")
    .values(
      structure.flatMap((set) =>
        set.exercises.map((ex) => ({
          session_id: session.id,
          training_set_id: set.trainingSetId,
          exercise_id: null,
          position: ex.position,
          note: null,
        }))
      ),
    )
    .returning(["id", "position", "training_set_id"])
    .execute();

  const dropInserts: SessionDropLogInsert[] = [];
  for (const set of structure) {
    for (const ex of set.exercises) {
      const setLogRow = setLogRows.find((r) => r.training_set_id === set.trainingSetId && r.position === ex.position);
      if (!setLogRow) continue;
      const baseWeight = exerciseWeightById.get(ex.exerciseId);
      for (const drop of ex.drops) {
        const repDelta = rng.int(-1, 1); // vs. planned
        dropInserts.push({
          session_set_log_id: setLogRow.id,
          training_set_drop_id: drop.id,
          drop_number: drop.dropNumber,
          rep_type_actual: drop.repType,
          rep_count_actual: drop.repCount === null ? null : Math.max(1, drop.repCount + repDelta),
          weight_kg_actual: actualWeightKg(rng, baseWeight, progressFactor),
          side: "both",
          note: null,
        });
      }
    }
  }
  if (dropInserts.length) await db.insertInto("session_drop_log").values(dropInserts).execute();
  return true;
}

let sessionsAdded = 0;
for (const gym of gymBusinesses) {
  const tz = gym.timezone;
  const todayLocal = localYmd(NOW_MS, tz);
  for (const username of memberUsernamesByGym.get(gym.name) ?? []) {
    const userId = uid(username);
    const latest = await db
      .selectFrom("training_session")
      .select("started_at")
      .where("user_id", "=", userId)
      .orderBy("started_at", "desc")
      .executeTakeFirst();

    if (!latest) {
      const rng = rngFor("sessions", username);
      const sessionCount = rng.int(4, 7);
      const maxDaysAgo = 3 + (sessionCount - 1) * 4;
      for (let i = 0; i < sessionCount; i++) {
        const daysAgo = Math.max(1, maxDaysAgo - i * 4 - rng.int(0, 1));
        const progressFactor = 0.88 + (1 - daysAgo / maxDaysAgo) * 0.18; // older sessions load lighter
        if (await logTrainingSession(rng, userId, gym.name, addDays(todayLocal, -daysAgo), progressFactor)) {
          sessionsAdded++;
        }
      }
      continue;
    }

    const latestDay = localYmd(toMs(latest.started_at), tz);
    if (daysBetween(latestDay, todayLocal) <= 6) continue;
    const rng = rngFor("sessions-topup", username, latestDay);
    const gap = daysBetween(latestDay, todayLocal);
    for (let day = addDays(latestDay, rng.int(2, 4)); day < todayLocal; day = addDays(day, rng.int(2, 5))) {
      const progressFactor = 1 + (daysBetween(latestDay, day) / gap) * 0.06;
      if (await logTrainingSession(rng, userId, gym.name, day, progressFactor)) sessionsAdded++;
    }
  }
}
report("training sessions", sessionsAdded);

// ── 14. User settings ─────────────────────────────────────────────────────────

added = 0;
for (const s of userSettingsSeeds) {
  const userId = userIdByUsername.get(s.username);
  if (!userId) continue;
  const res = await db
    .insertInto("user_settings")
    .values({
      user_id: userId,
      ...(s.push_enabled !== undefined && { push_enabled: s.push_enabled }),
      ...(s.muted_types && { muted_types: s.muted_types }),
      ...(s.weight_unit && { weight_unit: s.weight_unit }),
      ...(s.theme_mode && { theme_mode: s.theme_mode }),
      locale: s.locale ?? null,
    })
    .onConflict((oc) => oc.column("user_id").doNothing()) // never override a user's own choices
    .executeTakeFirst();
  added += Number(res.numInsertedOrUpdatedRows ?? 0);
}
report("user settings", added);

// ── 15. Classes & bookings ────────────────────────────────────────────────────
// Each template becomes one weekly series per weekday covering the last two
// and the next two weeks. Past classes have attended/no-show bookings and the
// reminder the jobs cron would have sent; upcoming ones have bookings, a
// full one has a waitlist, and one was cancelled (members told via `events`).
// Each template is an open-ended weekly class_series (the API tops the rest
// of its 90 days up on first read). Guard: a gym that already has a series
// with the template's title is skipped.

let classesAdded = 0;
let bookingsAdded = 0;

for (const t of classTemplates) {
  const gymId = businessIdByName.get(t.gym);
  const trainerUserId = userIdByUsername.get(t.trainer);
  if (!gymId || !trainerUserId) {
    console.warn(`  ! class "${t.title}" references unknown gym/trainer — skipping`);
    continue;
  }
  const exists = await db
    .selectFrom("class_series")
    .select("id")
    .where("gym_id", "=", gymId)
    .where("title", "=", t.title)
    .executeTakeFirst();
  if (exists) continue;

  const tz = tzOf(t.gym);
  const todayLocal = localYmd(NOW_MS, tz);
  const seriesStart = addDays(todayLocal, -14);
  const { id: seriesId } = await db.insertInto("class_series").values({
    gym_id: gymId,
    trainer_id: trainerUserId,
    title: t.title,
    description: t.description,
    location: t.location,
    capacity: t.capacity,
    duration_minutes: t.duration_minutes,
    repeat: "weekly",
    weekdays: [...t.weekdays].sort(),
    times: [t.start],
    timezone: tz,
    starts_on: seriesStart,
    ends_on: null,
    generated_until: addDays(todayLocal, 13),
    created_by: trainerUserId,
    created_at: iso(clampPast(zonedTime(seriesStart, t.start, tz) - 7 * DAY_MS, 60)),
  }).returning("id").executeTakeFirstOrThrow();
  const members = (memberUsernamesByGym.get(t.gym) ?? []).map((u) => ({ username: u, id: uid(u) }));

  for (const weekday of t.weekdays) {
    const days = dateRange(addDays(todayLocal, -14), addDays(todayLocal, 13)).filter((d) => isoDow(d) === weekday);
    if (days.length === 0) continue;
    const firstStart = zonedTime(days[0], t.start, tz);
    const seriesCreatedMs = clampPast(firstStart - 7 * DAY_MS, 60);
    const nextIdx = days.findIndex((d) => zonedTime(d, t.start, tz) > NOW_MS);

    const inserted = await db
      .insertInto("gym_class")
      .values(days.map((d) => {
        const startMs = zonedTime(d, t.start, tz);
        return {
          gym_id: gymId,
          trainer_id: trainerUserId,
          title: t.title,
          description: t.description,
          location: t.location,
          starts_at: iso(startMs),
          ends_at: iso(startMs + t.duration_minutes * MIN_MS),
          capacity: t.capacity,
          series_id: seriesId,
          slot_at: iso(startMs),
          cancelled_at: null,
          // The cron reminds an hour before; past classes were already reminded.
          reminder_sent_at: startMs <= NOW_MS ? iso(startMs - HOUR_MS) : null,
          created_by: trainerUserId,
          created_at: iso(seriesCreatedMs),
          updated_at: iso(seriesCreatedMs),
        };
      }))
      .returning(["id", "starts_at"])
      .execute();
    classesAdded += inserted.length;

    for (const [idx, cls] of inserted.entries()) {
      const day = days[idx];
      const startMs = toMs(cls.starts_at);
      const rng = rngFor("class", t.gym, t.title, day);
      const upcoming = startMs > NOW_MS;
      const isFull = !!t.full_next && idx === nextIdx;
      const isCancelled = !!t.cancel_next && idx === nextIdx;
      // Members whose membership lapsed don't book classes after that.
      const eligible = members.filter((m) => {
        const lapsed = lapsedOn(m.username);
        return !lapsed || day <= lapsed;
      });

      const cancelledMs = isCancelled ? clampPast(NOW_MS - rng.int(6, 30) * HOUR_MS, 60) : null;
      // Bookings happen between the series being published and the class
      // (or its cancellation).
      const bookingWindowEnd = Math.min(cancelledMs ?? Infinity, startMs - 30 * MIN_MS, NOW_MS - 10 * MIN_MS);
      const bookingWindowStart = Math.min(Math.max(seriesCreatedMs, startMs - 6 * DAY_MS), bookingWindowEnd);
      const bookedAt = () =>
        Math.round(bookingWindowStart + rng.next() * Math.max(0, bookingWindowEnd - bookingWindowStart));

      type Booking = { user_id: string; status: BookingStatus; created_at: string; updated_at: string };
      const bookings: Booking[] = [];
      if (isFull) {
        const shuffled = rng.shuffle(eligible);
        const seated = shuffled.slice(0, t.capacity);
        const waitlisted = shuffled.slice(t.capacity, t.capacity + 2);
        const seatedTimes = seated.map(bookedAt).sort((a, b) => a - b);
        const lastSeat = seatedTimes.at(-1) ?? bookingWindowStart;
        seated.forEach((m, k) =>
          bookings.push({
            user_id: m.id,
            status: "booked",
            created_at: iso(seatedTimes[k]),
            updated_at: iso(seatedTimes[k]),
          })
        );
        waitlisted.forEach((m, k) => {
          const at = Math.min(lastSeat + (k + 1) * rng.int(20, 300) * MIN_MS, bookingWindowEnd);
          bookings.push({ user_id: m.id, status: "waitlisted", created_at: iso(at), updated_at: iso(at) });
        });
      } else {
        const n = Math.max(1, Math.round(Math.min(t.capacity, eligible.length) * rng.float(0.35, 0.85)));
        for (const m of rng.sample(eligible, n)) {
          const at = bookedAt();
          let status: BookingStatus = upcoming || startMs + t.duration_minutes * MIN_MS > NOW_MS
            ? "booked"
            : rng.chance(0.85)
            ? "attended"
            : "no_show";
          if (!isCancelled && rng.chance(0.07)) status = "cancelled";
          const updated = status === "attended" || status === "no_show"
            ? clampPast(startMs + (t.duration_minutes + rng.int(0, 30)) * MIN_MS)
            : status === "cancelled"
            ? Math.min(at + rng.int(1, 48) * HOUR_MS, bookingWindowEnd)
            : at;
          bookings.push({ user_id: m.id, status, created_at: iso(at), updated_at: iso(updated) });
        }
      }
      if (bookings.length) {
        await db.insertInto("class_booking").values(bookings.map((b) => ({ class_id: cls.id, ...b }))).execute();
        bookingsAdded += bookings.length;
      }

      const meta = { class_id: cls.id, gym_id: gymId, gym_name: t.gym };
      if (isCancelled && cancelledMs) {
        await db.updateTable("gym_class")
          .set({ cancelled_at: iso(cancelledMs), updated_at: iso(cancelledMs) })
          .where("id", "=", cls.id).execute();
        await addNotification(
          bookings.filter((b) => b.status === "booked" || b.status === "waitlisted").map((b) => b.user_id),
          {
            type: "events",
            title: `Class cancelled: ${t.title}`,
            body: `${t.title} at ${t.gym} has been cancelled.`,
            metadata: meta,
          },
          cancelledMs,
        );
      }
      // Reminders for classes in the last three days (older ones would be noise).
      if (!upcoming && startMs >= NOW_MS - 3 * DAY_MS) {
        await addNotification(
          bookings.filter((b) => b.status !== "cancelled" && b.status !== "waitlisted").map((b) => b.user_id),
          {
            type: "class_reminder",
            title: `${t.title} starts in about an hour`,
            body: `Your class at ${t.gym} starts in about an hour. See you there!`,
            metadata: meta,
          },
          startMs - HOUR_MS,
        );
      }
    }
  }
}
report("classes", classesAdded);
report("class bookings", bookingsAdded);

// ── 16. Staff shifts ──────────────────────────────────────────────────────────
// Weekly patterns from seed_data.json, last week through the next two weeks.
// A shift is only inserted when the person has nothing overlapping (same rule
// as the shifts API), which also makes re-runs add nothing.

let shiftsAdded = 0;
for (const p of shiftPatterns) {
  const gymId = businessIdByName.get(p.gym);
  const userId = userIdByUsername.get(p.username);
  if (!gymId || !userId) continue;
  const tz = tzOf(p.gym);
  const todayLocal = localYmd(NOW_MS, tz);
  const ownerId = userIdByUsername.get(ownerUsernameByBusiness.get(p.gym) ?? "") ?? null;
  const rangeStart = zonedTime(addDays(todayLocal, -8), "00:00", tz);
  const rangeEnd = zonedTime(addDays(todayLocal, 15), "00:00", tz);
  const taken = (await db.selectFrom("staff_shift").select(["starts_at", "ends_at"])
    .where("user_id", "=", userId)
    .where("ends_at", ">", iso(rangeStart))
    .where("starts_at", "<", iso(rangeEnd))
    .execute()).map((s) => [toMs(s.starts_at), toMs(s.ends_at)] as const);

  for (const day of dateRange(addDays(todayLocal, -7), addDays(todayLocal, 13))) {
    if (!p.weekdays.includes(isoDow(day))) continue;
    const startMs = zonedTime(day, p.start, tz);
    const endMs = zonedTime(p.end <= p.start ? addDays(day, 1) : day, p.end, tz);
    if (taken.some(([s, e]) => s < endMs && e > startMs)) continue;
    taken.push([startMs, endMs]);

    // Each week's rota is published the Wednesday before (or, for a week
    // whose rota day hasn't come yet, earlier today/yesterday).
    const weekStart = addDays(day, 1 - isoDow(day));
    let publishedMs = zonedTime(addDays(weekStart, -5), "10:00", tz);
    if (publishedMs > NOW_MS - HOUR_MS) publishedMs = NOW_MS - rngFor("rota", p.gym, weekStart).int(2, 30) * HOUR_MS;
    const shift = await db
      .insertInto("staff_shift")
      .values({
        gym_id: gymId,
        user_id: userId,
        starts_at: iso(startMs),
        ends_at: iso(endMs),
        note: p.note,
        created_by: ownerId,
        created_at: iso(publishedMs),
      })
      .returning(["id"])
      .executeTakeFirstOrThrow();
    shiftsAdded++;
    if (startMs > NOW_MS) {
      await addNotification([userId], {
        type: "shift_assigned",
        title: "New shift",
        body: `You've been scheduled for a shift at ${p.gym}.`,
        metadata: { shift_id: shift.id, gym_id: gymId, gym_name: p.gym },
      }, publishedMs);
    }
  }
}
report("staff shifts", shiftsAdded);

// ── 17. Check-ins ─────────────────────────────────────────────────────────────
// Last 30 days: members check in shortly before most of their training
// sessions plus a few extra visits at their usual time of day. Mostly QR scans
// at the desk, some manual. Nothing in the last hour, so a fresh QR scan is
// never inside the API's 30-minute duplicate window.
// Guard: a member with any check-in at their gym before today is skipped.

const HOUR_WEIGHTS: Record<"morning" | "lunch" | "evening", number[]> = {
  //          0  1  2  3  4  5  6  7  8  9 10 11 12 13 14 15 16 17 18 19 20 21 22 23
  morning: [0, 0, 0, 0, 0, 3, 9, 9, 6, 3, 2, 1, 2, 1, 1, 1, 1, 2, 2, 1, 1, 0, 0, 0],
  lunch: [0, 0, 0, 0, 0, 1, 2, 2, 2, 2, 3, 6, 9, 7, 3, 2, 2, 2, 2, 1, 1, 0, 0, 0],
  evening: [0, 0, 0, 0, 0, 1, 1, 2, 1, 1, 1, 1, 2, 1, 1, 2, 4, 8, 9, 8, 5, 2, 1, 0],
};

function weightedHour(rng: Rng, weights: number[], open: number, close: number): number {
  const hours = weights.map((w, h) => (h >= open && h < close ? w : 0));
  const total = hours.reduce((a, b) => a + b, 0);
  let r = rng.next() * total;
  for (let h = 0; h < 24; h++) {
    r -= hours[h];
    if (r < 0) return h;
  }
  return open;
}

let checkInsAdded = 0;
for (const gym of gymBusinesses) {
  const gymId = businessIdByName.get(gym.name)!;
  const tz = gym.timezone;
  const todayLocal = localYmd(NOW_MS, tz);
  const open = parseInt(gym.working_hours_from, 10);
  const close = parseInt(gym.working_hours_to, 10);
  const deskIds = (deskStaffUsernamesByGym.get(gym.name) ?? trainerUsernamesByGym.get(gym.name) ?? []).map(uid);
  if (deskIds.length === 0) continue;

  for (const username of memberUsernamesByGym.get(gym.name) ?? []) {
    const userId = uid(username);
    const already = await db.selectFrom("check_in").select("id")
      .where("user_id", "=", userId)
      .where("gym_id", "=", gymId)
      .where("checked_in_at", "<", iso(zonedTime(todayLocal, "00:00", tz)))
      .executeTakeFirst();
    if (already) continue;

    const rng = rngFor("checkins", username);
    const profile = rng.pick(["morning", "morning", "lunch", "evening", "evening"] as const);
    const extraVisitRate = rng.float(0.12, 0.3);
    const lapsed = lapsedOn(username);

    const sessions = await db.selectFrom("training_session").select("started_at")
      .where("user_id", "=", userId)
      .where("started_at", ">=", iso(NOW_MS - 31 * DAY_MS))
      .orderBy("started_at")
      .execute();
    const sessionStartByDay = new Map<string, number>();
    for (const s of sessions) {
      const startMs = toMs(s.started_at);
      const day = localYmd(startMs, tz);
      if (!sessionStartByDay.has(day)) sessionStartByDay.set(day, startMs);
    }

    const rows = [];
    for (const day of dateRange(addDays(todayLocal, -30), todayLocal)) {
      if (lapsed && day > lapsed) continue;
      let atMs: number;
      const sessionStart = sessionStartByDay.get(day);
      const beforeSession = sessionStart === undefined ? undefined : sessionStart - rng.int(4, 15) * MIN_MS;
      const beforeSessionHour = beforeSession === undefined ? -1 : zonedParts(beforeSession, tz).h;
      if (beforeSession !== undefined && beforeSessionHour >= open && beforeSessionHour < close && rng.chance(0.9)) {
        atMs = beforeSession;
      } else if (rng.chance(extraVisitRate)) {
        atMs = zonedTime(day, hhmm(weightedHour(rng, HOUR_WEIGHTS[profile], open, close) * 60 + rng.int(0, 59)), tz);
      } else {
        continue;
      }
      if (atMs > NOW_MS - HOUR_MS) continue;
      rows.push({
        gym_id: gymId,
        user_id: userId,
        checked_in_at: iso(atMs),
        checked_in_by: rng.pick(deskIds),
        method: rng.chance(0.85) ? "qr" as const : "manual" as const,
      });
    }
    if (rows.length) {
      await db.insertInto("check_in").values(rows).execute();
      checkInsAdded += rows.length;
    }
  }
}
report("check-ins", checkInsAdded);

// ── 18. Body measurements ─────────────────────────────────────────────────────
// Weekly weigh-ins over ~10 weeks for most members, each trending toward a
// goal (cutting, lean gaining or maintaining) with day-to-day noise; some also
// track body-fat % every few weeks. Guard: members with any measurement.

let measurementsAdded = 0;
for (const gym of gymBusinesses) {
  const tz = gym.timezone;
  const todayLocal = localYmd(NOW_MS, tz);
  for (const [i, username] of (memberUsernamesByGym.get(gym.name) ?? []).entries()) {
    const rng = rngFor("body", username);
    if (i > 0 && rng.chance(0.2)) continue; // not everyone weighs in
    const userId = uid(username);
    const any = await db.selectFrom("body_measurement").select("id").where("user_id", "=", userId).executeTakeFirst();
    if (any) continue;

    const goal = rng.pick(["cut", "cut", "gain", "maintain"] as const);
    const perWeek = goal === "cut" ? -rng.float(0.25, 0.6) : goal === "gain" ? rng.float(0.1, 0.3) : rng.float(-0.05, 0.05);
    const tracksFat = rng.chance(0.45);
    const weeks = 10;
    const startWeight = rng.float(56, 96);
    const startFat = rng.float(14, 30);
    const weekday = rng.int(1, 7);
    let lastDay = todayLocal;
    while (isoDow(lastDay) !== weekday) lastDay = addDays(lastDay, -1);

    const rows = [];
    for (let w = weeks - 1; w >= 0; w--) {
      if (w > 0 && rng.chance(0.1)) continue; // missed a week
      const day = addDays(lastDay, -7 * w);
      const elapsed = weeks - 1 - w;
      const weight = startWeight + perWeek * elapsed + rng.float(-0.4, 0.4);
      const fat = tracksFat && elapsed % 3 === 0
        ? Math.max(6, startFat + (goal === "cut" ? -0.18 : goal === "gain" ? 0.04 : 0) * elapsed + rng.float(-0.3, 0.3))
        : null;
      const createdMs = zonedTime(day, hhmm(rng.int(6 * 60 + 30, 8 * 60 + 30)), tz);
      if (createdMs > NOW_MS - 30 * MIN_MS) continue; // this morning's weigh-in hasn't happened yet
      rows.push({
        user_id: userId,
        measured_on: day,
        weight_kg: Math.round(weight * 10) / 10,
        body_fat_pct: fat === null ? null : Math.round(fat * 10) / 10,
        note: rng.chance(0.12) ? rng.pick(bodyMeasurementNotes) : null,
        created_at: iso(createdMs),
      });
    }
    if (rows.length) {
      await db.insertInto("body_measurement").values(rows).execute();
      measurementsAdded += rows.length;
    }
  }
}
report("body measurements", measurementsAdded);

// ── 19. Routine assignments ───────────────────────────────────────────────────
// Gym trainers assign the seeded routines to about half their members (the
// first member of each gym always gets one), with the `training` notification
// the routine-assignments API sends. Guard: per (member, routine).

let routineAssignmentsAdded = 0;
const seededRoutines = routines.filter((r) => routineIdByName.has(r.name));
for (const gym of gymBusinesses) {
  const coaches = trainerUsernamesByGym.get(gym.name) ?? [];
  if (coaches.length === 0 || seededRoutines.length === 0) continue;
  for (const [i, username] of (memberUsernamesByGym.get(gym.name) ?? []).entries()) {
    const rng = rngFor("routine-assignment", username);
    if (i > 0 && !rng.chance(0.55)) continue;
    const routine = rng.pick(seededRoutines);
    const routineId = routineIdByName.get(routine.name)!;
    const userId = uid(username);
    const exists = await db.selectFrom("routine_assignment").select("id")
      .where("user_id", "=", userId).where("routine_id", "=", routineId).executeTakeFirst();
    if (exists) continue;

    const coach = rng.pick(coaches);
    const startDate = addDays(TODAY_UTC, -rng.int(0, 20));
    const createdMs = clampPast(zonedTime(addDays(startDate, -1), hhmm(rng.int(17 * 60, 20 * 60)), gym.timezone), 30);
    const assignment = await db
      .insertInto("routine_assignment")
      .values({
        routine_id: routineId,
        user_id: userId,
        assigned_by_id: uid(coach),
        start_date: startDate,
        end_date: addDays(startDate, routine.num_weeks * 7 - 1),
        note: rng.pick(routineAssignmentNotes),
        created_at: iso(createdMs),
      })
      .returning(["id"])
      .executeTakeFirstOrThrow();
    routineAssignmentsAdded++;
    await addNotification([userId], {
      type: "training",
      title: "New routine assigned",
      body: `${fullName(coach)} assigned you "${routine.name}"`,
      metadata: { routine_id: routineId, routine_assignment_id: assignment.id },
    }, createdMs);
  }
}
report("routine assignments", routineAssignmentsAdded);

// ── 20. Session comments ──────────────────────────────────────────────────────
// A coach comments on one or two recent sessions of about two thirds of the
// members; half the time the member replies. Same notifications as the
// training-sessions API. Guard: members with any comment on their sessions.

let sessionCommentsAdded = 0;
for (const gym of gymBusinesses) {
  const coaches = trainerUsernamesByGym.get(gym.name) ?? [];
  if (coaches.length === 0) continue;
  for (const username of memberUsernamesByGym.get(gym.name) ?? []) {
    const rng = rngFor("session-comments", username);
    if (!rng.chance(0.65)) continue;
    const userId = uid(username);
    const commented = await db.selectFrom("session_comment")
      .innerJoin("training_session", "training_session.id", "session_comment.session_id")
      .select("session_comment.id")
      .where("training_session.user_id", "=", userId)
      .executeTakeFirst();
    if (commented) continue;

    const recent = await db.selectFrom("training_session")
      .select(["id", "trainer_id", "ended_at", "started_at"])
      .where("user_id", "=", userId)
      .where("ended_at", "is not", null)
      .orderBy("started_at", "desc")
      .limit(6)
      .execute();
    for (const s of rng.sample(recent, rng.int(1, 2))) {
      const coachId = s.trainer_id ?? uid(rng.pick(coaches));
      const coachUsername = personas.find((p) => userIdByUsername.get(p.username) === coachId)?.username ?? coaches[0];
      const commentMs = clampPast(toMs(s.ended_at) + rng.int(60, 18 * 60) * MIN_MS, 30);
      const coachBody = rng.pick(sessionCommentPool.coach);
      const comment = await db.insertInto("session_comment")
        .values({ session_id: s.id, author_id: coachId, body: coachBody, created_at: iso(commentMs), updated_at: iso(commentMs) })
        .returning(["id"]).executeTakeFirstOrThrow();
      sessionCommentsAdded++;
      await addNotification([userId], {
        type: "session_comment",
        title: `${fullName(coachUsername)} commented on your session`,
        body: coachBody,
        metadata: { session_id: s.id, comment_id: comment.id },
      }, commentMs);

      if (rng.chance(0.5)) {
        const replyMs = clampPast(commentMs + rng.int(30, 6 * 60) * MIN_MS, 5);
        const replyBody = rng.pick(sessionCommentPool.member);
        const reply = await db.insertInto("session_comment")
          .values({ session_id: s.id, author_id: userId, body: replyBody, created_at: iso(replyMs), updated_at: iso(replyMs) })
          .returning(["id"]).executeTakeFirstOrThrow();
        sessionCommentsAdded++;
        await addNotification([coachId], {
          type: "session_comment",
          title: `${fullName(username)} replied on their session`,
          body: replyBody,
          metadata: { session_id: s.id, comment_id: reply.id },
        }, replyMs);
      }
    }
  }
}
report("session comments", sessionCommentsAdded);

// ── 21. Post reactions & comments ─────────────────────────────────────────────
// Reactions from a share of each business's community (a gym's members and
// staff; for a shop its staff plus the members of gyms with the same owner),
// and the comment threads from seed_data.json (replies via `reply_to`) with
// the notifications the posts API sends. Guards: per post (any reaction / any
// comment).

const seededPosts = await db
  .selectFrom("post")
  .innerJoin("business", "business.id", "post.business_id")
  .select([
    "post.id",
    "post.author_id",
    "post.business_id",
    "post.content",
    "post.created_at",
    "business.name as business_name",
    "business.type as business_type",
  ])
  .where("post.content", "in", posts.map((p) => p.content))
  .execute();

function communityOf(businessName: string, type: "gym" | "shop"): string[] {
  if (type === "gym") {
    return [
      ...(memberUsernamesByGym.get(businessName) ?? []),
      ...(trainerUsernamesByGym.get(businessName) ?? []),
      ...(deskStaffUsernamesByGym.get(businessName) ?? []),
      ...(ownerUsernamesByBusiness.get(businessName) ?? []),
    ];
  }
  const owners = ownerUsernamesByBusiness.get(businessName) ?? [];
  const sisterGyms = gymBusinesses.filter((g) =>
    (ownerUsernamesByBusiness.get(g.name) ?? []).some((o) => owners.includes(o))
  );
  return [
    ...owners,
    ...(vendorUsernamesByShop.get(businessName) ?? []),
    ...sisterGyms.flatMap((g) => memberUsernamesByGym.get(g.name) ?? []),
  ];
}

let likesAdded = 0;
for (const post of seededPosts) {
  const liked = await db.selectFrom("post_reaction").select("user_id").where("post_id", "=", post.id).executeTakeFirst();
  if (liked) continue;
  const rng = rngFor("likes", post.content);
  const community = [...new Set(communityOf(post.business_name, post.business_type))]
    .map(uid).filter((id) => id && id !== post.author_id);
  const postMs = toMs(post.created_at);
  const likers = rng.sample(community, Math.round(community.length * rng.float(0.2, 0.7)));
  if (likers.length === 0) continue;
  await db.insertInto("post_reaction").values(likers.map((user_id) => ({
    post_id: post.id,
    user_id,
    reaction: pickReaction(rng),
    // Most likes come soon after posting.
    created_at: iso(clampPast(postMs + rng.next() ** 2 * Math.max(0, NOW_MS - postMs))),
  }))).onConflict((oc) => oc.columns(["post_id", "user_id"]).doNothing()).execute();
  likesAdded += likers.length;
}
report("post reactions", likesAdded);

/**
 * Inserts a comment thread on a post: `reply_to` points at an earlier comment
 * in the same thread. Sends the same notifications as the API (reply → the
 * parent's author, otherwise/also the post's author) and adds a few comment
 * reactions from `audience`.
 */
async function seedThread(
  post: { id: string; author_id: string | null; business_id: string | null; created_at: unknown },
  thread: SeedPostThread,
  businessName: string | null,
  audience: string[],
): Promise<number> {
  const rng = rngFor("post-thread", thread.post_starts_with);
  let atMs = toMs(post.created_at);
  const ids: string[] = [];
  const authors: string[] = [];
  for (const c of thread.comments) {
    const authorId = userIdByUsername.get(c.author);
    if (!authorId) continue;
    atMs = clampPast(atMs + rng.int(20, 10 * 60) * MIN_MS, 5);
    const parentId = c.reply_to !== undefined ? ids[c.reply_to] ?? null : null;
    const comment = await db.insertInto("post_comment")
      .values({
        post_id: post.id,
        author_id: authorId,
        parent_id: parentId,
        body: c.body,
        created_at: iso(atMs),
        updated_at: iso(atMs),
      })
      .returning(["id"]).executeTakeFirstOrThrow();
    ids.push(comment.id);
    authors.push(authorId);
    const metadata = {
      post_id: post.id,
      business_id: post.business_id,
      business_name: businessName,
      comment_id: comment.id,
      parent_id: parentId,
    };
    const notified = new Set([authorId]);
    const parentAuthor = c.reply_to !== undefined ? authors[c.reply_to] : undefined;
    if (parentAuthor && !notified.has(parentAuthor)) {
      notified.add(parentAuthor);
      await addNotification([parentAuthor], {
        type: "comment_reply",
        title: `${fullName(c.author)} replied to your comment`,
        body: c.body.slice(0, 120),
        metadata,
      }, atMs);
    }
    if (post.author_id && !notified.has(post.author_id)) {
      await addNotification([post.author_id], {
        type: "post_comment",
        title: `${fullName(c.author)} commented on your post`,
        body: c.body.slice(0, 120),
        metadata,
      }, atMs);
    }
    const reactors = rng.sample(audience.filter((id) => id !== authorId), rng.int(0, 4));
    if (reactors.length) {
      await db.insertInto("comment_reaction").values(reactors.map((user_id) => ({
        comment_id: comment.id,
        user_id,
        reaction: pickReaction(rng),
        created_at: iso(clampPast(atMs + rng.int(5, 600) * MIN_MS)),
      }))).execute();
    }
  }
  return ids.length;
}

let postCommentsAdded = 0;
for (const thread of postCommentThreads) {
  const post = seededPosts.find((p) => p.content.startsWith(thread.post_starts_with));
  if (!post) continue;
  const commented = await db.selectFrom("post_comment").select("id").where("post_id", "=", post.id).executeTakeFirst();
  if (commented) continue;
  const audience = [...new Set(communityOf(post.business_name, post.business_type))].map(uid).filter(Boolean);
  postCommentsAdded += await seedThread(post, thread, post.business_name, audience);
}
report("post comments", postCommentsAdded);

// ── 22. Food diary ────────────────────────────────────────────────────────────
// Members with a meal plan log the last 7 days (and today's meals so far)
// mostly following the planned day — resolved exactly like the food-logs API
// (ISO weekday, Monday-based weeks since the assignment start, mod num_weeks)
// — with realistic deviations: skipped items, bigger/smaller portions, an
// extra snack. Days without a planned meal, and a few members without a plan,
// are logged ad hoc. Macros are snapshotted like the API does
// (round2(per_100 × amount / 100) for food, round2(per_serving × servings)
// for recipes; brand appended to the name). Guard: members with any entry in
// the last 7 days.

type FoodRow = {
  id: string;
  name: string;
  brand: string | null;
  kcal_per_100: string;
  protein_per_100: string;
  carb_per_100: string;
  fat_per_100: string;
  fiber_per_100: string;
};
type RecipeRow = {
  id: string;
  name: string;
  kcal_per_serving: string;
  protein_per_serving: string;
  carb_per_serving: string;
  fat_per_serving: string;
  fiber_per_serving: string;
};
type DiaryEntry = {
  food_item_id: string | null;
  recipe_id: string | null;
  name: string;
  amount: number;
  kcal: number;
  protein: number;
  carb: number;
  fat: number;
  fiber: number;
  note: string | null;
};

const round2 = (n: number) => Math.round(n * 100) / 100;
const foodRowById = new Map<string, FoodRow>();
const recipeRowById = new Map<string, RecipeRow>();
async function loadFoodRows(ids: string[]) {
  const missing = ids.filter((id) => !foodRowById.has(id));
  if (missing.length === 0) return;
  const rows = await db.selectFrom("food_item")
    .select(["id", "name", "brand", "kcal_per_100", "protein_per_100", "carb_per_100", "fat_per_100", "fiber_per_100"])
    .where("id", "in", missing).execute();
  for (const r of rows) foodRowById.set(r.id, r);
}
async function loadRecipeRows(ids: string[]) {
  const missing = ids.filter((id) => !recipeRowById.has(id));
  if (missing.length === 0) return;
  const rows = await db.selectFrom("recipe")
    .select(["id", "name", "kcal_per_serving", "protein_per_serving", "carb_per_serving", "fat_per_serving", "fiber_per_serving"])
    .where("id", "in", missing).execute();
  for (const r of rows) recipeRowById.set(r.id, r);
}

function foodSnapshot(f: FoodRow, amount: number, note: string | null = null): DiaryEntry {
  const k = amount / 100;
  return {
    food_item_id: f.id,
    recipe_id: null,
    name: f.brand ? `${f.name} (${f.brand})` : f.name,
    amount,
    kcal: round2(Number(f.kcal_per_100) * k),
    protein: round2(Number(f.protein_per_100) * k),
    carb: round2(Number(f.carb_per_100) * k),
    fat: round2(Number(f.fat_per_100) * k),
    fiber: round2(Number(f.fiber_per_100) * k),
    note,
  };
}
function recipeSnapshot(r: RecipeRow, servings: number, note: string | null = null): DiaryEntry {
  return {
    food_item_id: null,
    recipe_id: r.id,
    name: r.name,
    amount: servings,
    kcal: round2(Number(r.kcal_per_serving) * servings),
    protein: round2(Number(r.protein_per_serving) * servings),
    carb: round2(Number(r.carb_per_serving) * servings),
    fat: round2(Number(r.fat_per_serving) * servings),
    fiber: round2(Number(r.fiber_per_serving) * servings),
    note,
  };
}

/** The planned slots for `date` — the same assignment/week/day resolution as food-logs/index.ts. */
async function plannedDay(userId: string, date: string) {
  const { rows: [a] } = await sql<{ meal_plan_id: string; num_weeks: number; weeks_since: number; iso_dow: number }>`
    SELECT a.meal_plan_id, mp.num_weeks,
           ((date_trunc('week', ${date}::date)::date
             - date_trunc('week', COALESCE(a.start_date, a.created_at::date))::date) / 7) AS weeks_since,
           EXTRACT(ISODOW FROM ${date}::date)::int AS iso_dow
      FROM meal_plan_assignment a
      JOIN meal_plan mp ON mp.id = a.meal_plan_id
     WHERE a.user_id = ${userId}
       AND COALESCE(a.start_date, a.created_at::date) <= ${date}::date
       AND (a.end_date IS NULL OR a.end_date >= ${date}::date)
     ORDER BY COALESCE(a.start_date, a.created_at::date) DESC, a.created_at DESC
     LIMIT 1
  `.execute(db);
  if (!a) return null;
  const weekNumber = (Number(a.weeks_since) % Math.max(1, Number(a.num_weeks))) + 1;
  const day = await db.selectFrom("meal_plan_day").select("daily_meal_plan_id")
    .where("meal_plan_id", "=", a.meal_plan_id)
    .where("week_number", "=", weekNumber)
    .where("day_of_week", "=", Number(a.iso_dow))
    .executeTakeFirst();
  if (!day) return [];
  const entries = await db.selectFrom("daily_meal_plan_slot_entry as e")
    .innerJoin("daily_meal_plan_slot as s", "s.id", "e.daily_meal_plan_slot_id")
    .select(["s.slot_type", "s.position as slot_position", "e.position", "e.food_item_id", "e.recipe_id", "e.quantity", "e.servings", "e.note"])
    .where("s.daily_meal_plan_id", "=", day.daily_meal_plan_id)
    .orderBy("s.position").orderBy("e.position")
    .execute();
  await loadFoodRows(entries.flatMap((e) => (e.food_item_id ? [e.food_item_id] : [])));
  await loadRecipeRows(entries.flatMap((e) => (e.recipe_id ? [e.recipe_id] : [])));
  return entries.flatMap((e) => {
    const food = e.food_item_id ? foodRowById.get(e.food_item_id) : undefined;
    if (food && Number(e.quantity ?? 0) > 0) {
      return [{ slot_type: e.slot_type, entry: foodSnapshot(food, Number(e.quantity), e.note) }];
    }
    const recipe = e.recipe_id ? recipeRowById.get(e.recipe_id) : undefined;
    if (recipe && Number(e.servings ?? 1) > 0) {
      return [{ slot_type: e.slot_type, entry: recipeSnapshot(recipe, Number(e.servings ?? 1), e.note) }];
    }
    return [];
  });
}

await loadFoodRows([...foodItemIdByName.values()]);
await loadRecipeRows([...recipeIdByName.values()]);

function adhocEntry(e: SeedDiaryEntry): DiaryEntry | null {
  if (e.source === "food_item") {
    const id = foodItemIdByName.get(e.name);
    const row = id ? foodRowById.get(id) : undefined;
    return row ? foodSnapshot(row, e.amount) : null;
  }
  const id = recipeIdByName.get(e.name);
  const row = id ? recipeRowById.get(id) : undefined;
  return row ? recipeSnapshot(row, e.amount) : null;
}

function adhocSlot(rng: Rng, slot: MealSlotType) {
  const options = foodDiary.adhoc_meals[slot] ?? [];
  if (options.length === 0) return [];
  return rng.pick(options).flatMap((e) => {
    const entry = adhocEntry(e);
    return entry ? [{ slot_type: slot, entry }] : [];
  });
}

function adhocDay(rng: Rng) {
  return [
    ...(rng.chance(0.9) ? adhocSlot(rng, "breakfast") : []),
    ...(rng.chance(0.95) ? adhocSlot(rng, "lunch") : []),
    ...(rng.chance(0.55) ? adhocSlot(rng, "afternoon_snack") : []),
    ...(rng.chance(0.95) ? adhocSlot(rng, "dinner") : []),
    ...(rng.chance(0.25) ? adhocSlot(rng, "evening_snack") : []),
  ];
}

/** Adjusts a planned entry the way people actually eat: different portions, the odd skip. */
function deviate(rng: Rng, e: DiaryEntry): DiaryEntry | null {
  if (rng.chance(0.07)) return null;
  if (!rng.chance(0.15)) return e;
  if (e.food_item_id) {
    const amount = Math.max(5, Math.round((e.amount * rng.pick([0.75, 0.8, 1.2, 1.25])) / 5) * 5);
    return foodSnapshot(foodRowById.get(e.food_item_id)!, amount, rng.chance(0.3) ? "Eyeballed the portion" : e.note);
  }
  const servings = Math.max(0.5, e.amount + rng.pick([-0.5, 0.5]));
  return recipeSnapshot(recipeRowById.get(e.recipe_id!)!, servings, servings > e.amount ? "Extra helping" : e.note);
}

const SLOT_TIMES: Record<MealSlotType, string> = {
  breakfast: "07:45",
  morning_snack: "10:30",
  lunch: "12:45",
  afternoon_snack: "15:30",
  pre_workout: "16:45",
  post_workout: "18:45",
  dinner: "19:30",
  evening_snack: "21:15",
};

const planAssignees = await db.selectFrom("meal_plan_assignment").select("user_id")
  .where("user_id", "in", memberUsernames.map(uid)).distinct().execute();
const planUserIds = new Set(planAssignees.map((r) => r.user_id));
const diaryUsernames = [
  ...memberUsernames.filter((u) => planUserIds.has(uid(u))),
  ...foodDiary.adhoc_members.filter((u) => userIdByUsername.has(u) && !planUserIds.has(uid(u))),
];

let foodLogsAdded = 0;
for (const username of diaryUsernames) {
  const userId = uid(username);
  const tz = tzOf(personaByUsername.get(username)?.businesses[0] ?? "");
  const todayLocal = localYmd(NOW_MS, tz);
  const recent = await db.selectFrom("food_log").select("id")
    .where("user_id", "=", userId)
    .where("log_date", ">=", addDays(todayLocal, -7))
    .where("log_date", "<=", todayLocal)
    .executeTakeFirst();
  if (recent) continue;

  const rows = [];
  for (const day of dateRange(addDays(todayLocal, -7), todayLocal)) {
    const rng = rngFor("diary", username, day);
    if (day !== todayLocal && rng.chance(0.12)) continue; // forgot to log that day
    const planned = planUserIds.has(userId) ? await plannedDay(userId, day) : null;
    let items = planned && planned.length
      ? planned.flatMap((p) => {
        const e = deviate(rng, p.entry);
        return e ? [{ slot_type: p.slot_type, entry: e }] : [];
      })
      : adhocDay(rng);
    if (planned && planned.length && rng.chance(0.2)) {
      items = [...items, ...adhocSlot(rng, rng.pick(["afternoon_snack", "evening_snack"] as const))];
    }
    for (const [k, item] of items.entries()) {
      const atMs = zonedTime(day, SLOT_TIMES[item.slot_type], tz) + rng.int(0, 25) * MIN_MS + k * 1000;
      if (atMs > NOW_MS - 5 * MIN_MS) continue; // today: only meals already eaten
      rows.push({
        user_id: userId,
        log_date: day,
        slot_type: item.slot_type,
        ...item.entry,
        created_at: iso(atMs),
      });
    }
  }
  if (rows.length) {
    // Generated<Numeric> columns don't accept plain numbers in the generated
    // types (same cast as food-logs/index.ts).
    await db.insertInto("food_log").values(rows as unknown as Insertable<FoodLogTable>[]).execute();
    foodLogsAdded += rows.length;
  }
}
report("food diary entries", foodLogsAdded);

// ── 23. Shop orders ───────────────────────────────────────────────────────────
// Orders from seed_data.json across every status, stored like the orders API
// does: one `invoice` row per order with `invoice_item` unit_price snapshots
// (the trigger keeps invoice.total in sync), stock reserved when the order is
// created and returned when it was cancelled, `purchase_made` to the shop's
// owners and vendors, `order_update` to the buyer for each status change.
// Card orders carry no payment row (see the header) — the card payment's own
// notification (`payment_received`) is therefore not seeded either.
// Guard: per (buyer, shop) — a buyer with any order at that shop is skipped,
// so stock is only ever decremented when the order rows are first created.

const STATUS_COPY: Record<OrderStatus, string> = {
  pending: "is pending",
  paid: "is paid",
  fulfilled: "is complete",
  cancelled: "was cancelled",
};
const money = (n: number) => new Intl.NumberFormat("en-US", { style: "currency", currency: "USD" }).format(n);

let ordersAdded = 0;
const orderGroups = new Map<string, SeedShopOrder[]>();
for (const o of shopOrders) {
  const key = `${o.buyer}|${o.shop}`;
  orderGroups.set(key, [...(orderGroups.get(key) ?? []), o]);
}

for (const [key, group] of orderGroups) {
  const [buyer, shopName] = key.split("|");
  const buyerId = userIdByUsername.get(buyer);
  const shopId = businessIdByName.get(shopName);
  if (!buyerId || !shopId) continue;
  const exists = await db.selectFrom("invoice").select("id")
    .where("user_id", "=", buyerId).where("shop_id", "=", shopId).executeTakeFirst();
  if (exists) continue;

  const tz = tzOf(shopName);
  const todayLocal = localYmd(NOW_MS, tz);
  const shopStaff = [
    ...(ownerUsernamesByBusiness.get(shopName) ?? []),
    ...(vendorUsernamesByShop.get(shopName) ?? []),
  ].map(uid);

  for (const o of group) {
    const rng = rngFor("order", buyer, shopName, o.days_ago, o.status);
    const items = await db.selectFrom("shop_item").select(["id", "name", "price"])
      .where("shop_id", "=", shopId).where("name", "in", o.items.map((i) => i.name)).execute();
    const lines = o.items.flatMap((i) => {
      const item = items.find((x) => x.name === i.name);
      return item ? [{ ...item, quantity: i.quantity }] : [];
    });
    if (lines.length === 0) continue;

    // Orders are placed in the app at any reasonable hour; staff actions
    // (pickup, cancelling) happen while the shop is open.
    const orderDay = addDays(todayLocal, -o.days_ago);
    let createdMs = zonedTime(orderDay, hhmm(rng.int(8 * 60, 21 * 60)), tz);
    if (createdMs > NOW_MS - 30 * MIN_MS) createdMs = NOW_MS - rng.int(30, 180) * MIN_MS;
    const shopOpen = parseInt(businessByName.get(shopName)?.working_hours_from ?? "09", 10);
    const shopClose = parseInt(businessByName.get(shopName)?.working_hours_to ?? "19", 10);
    const staffActionAt = (minDaysLater: number, maxDaysLater: number) => {
      let at = zonedTime(
        addDays(orderDay, rng.int(minDaysLater, maxDaysLater)),
        hhmm(rng.int(shopOpen * 60 + 15, shopClose * 60 - 30)),
        tz,
      );
      if (at <= createdMs) at = createdMs + rng.int(15, 90) * MIN_MS;
      return clampPast(at, 10);
    };
    let paidMs: number | null = null;
    let fulfilledMs: number | null = null;
    let cancelledMs: number | null = null;
    if (o.status === "fulfilled") {
      fulfilledMs = staffActionAt(1, 2);
      // Card: paid at checkout. Pay at pickup: paid at the counter on collection.
      paidMs = o.payment_method === "card" ? clampPast(createdMs + rng.int(1, 3) * MIN_MS, 10) : fulfilledMs;
    } else if (o.status === "paid") {
      paidMs = clampPast(createdMs + rng.int(1, 3) * MIN_MS, 10);
    } else if (o.status === "cancelled") {
      cancelledMs = staffActionAt(0, 1);
    }
    const total = round2(lines.reduce((s, l) => s + Number(l.price) * l.quantity, 0));
    const itemCount = lines.reduce((s, l) => s + l.quantity, 0);

    const orderId = await db.transaction().execute(async (trx) => {
      const order = await trx.insertInto("invoice").values({
        date: localYmd(createdMs, tz),
        user_id: buyerId,
        shop_id: shopId,
        status: o.status,
        payment_method: o.payment_method,
        note: o.note,
        created_at: iso(createdMs),
        paid_at: paidMs ? iso(paidMs) : null,
        fulfilled_at: fulfilledMs ? iso(fulfilledMs) : null,
        cancelled_at: cancelledMs ? iso(cancelledMs) : null,
      }).returning(["id"]).executeTakeFirstOrThrow();
      await trx.insertInto("invoice_item").values(lines.map((l) => ({
        invoice_id: order.id,
        shop_item_id: l.id,
        quantity: l.quantity,
        unit_price: l.price,
      }))).execute();
      // Reserve stock (a cancelled order's stock was returned, so net zero).
      if (o.status !== "cancelled") {
        for (const l of lines) {
          await trx.updateTable("shop_item")
            .set({ quantity: sql<number>`GREATEST(quantity - ${l.quantity}, 0)` })
            .where("id", "=", l.id).execute();
        }
      }
      return order.id;
    });
    ordersAdded++;

    const meta = { order_id: orderId, shop_id: shopId, shop_name: shopName };
    await addNotification(shopStaff, {
      type: "purchase_made",
      title: `New order at ${shopName}`,
      body: `${fullName(buyer)} ordered ${itemCount} item${itemCount === 1 ? "" : "s"} · ${money(total)} (${
        o.payment_method === "card" ? "card" : "pay at pickup"
      }).`,
      metadata: meta,
    }, createdMs);

    const update = async (status: OrderStatus, body: string, atMs: number) =>
      await addNotification([buyerId], {
        type: "order_update",
        title: `Order at ${shopName} ${STATUS_COPY[status]}`,
        body,
        metadata: { order_id: orderId, shop_id: shopId, status, shop_name: shopName },
      }, atMs);
    // Staff marking a pay-at-pickup order paid notifies the buyer; a card
    // payment is confirmed by the payments webhook instead.
    if (paidMs && o.payment_method === "pay_at_pickup") await update("paid", `Total ${money(total)}.`, paidMs);
    if (fulfilledMs) await update("fulfilled", "Thanks for your purchase!", fulfilledMs + 1000);
    if (cancelledMs) await update("cancelled", "The items were returned to the shop.", cancelledMs);
  }
}
report("shop orders", ordersAdded);

// ── 24. Social profiles ───────────────────────────────────────────────────────
// Bios, interests, privacy settings, a coarse home location (~70% of people,
// within a few km of their home business, rounded like the API does) and a
// recent "last active". Guard: users whose bio is already set are skipped.

let profilesAdded = 0;
for (const p of personas) {
  const profile = socialProfiles[p.username];
  const userId = userIdByUsername.get(p.username);
  if (!profile || !userId) continue;
  const current = await db.selectFrom("users").select("bio").where("id", "=", userId).executeTakeFirstOrThrow();
  if (current.bio) continue;
  const rng = rngFor("social-profile", p.username);
  const home = businessByName.get(p.businesses[0] ?? "") ?? businesses[0];
  const sharesLocation = rng.chance(0.7);
  const round2 = (v: number) => Math.round(v * 100) / 100;
  // ~0.06° ≈ 5–7 km of jitter.
  const lat = round2(home.latitude + rng.float(-0.06, 0.06));
  const lng = round2(home.longitude + rng.float(-0.06, 0.06));
  await db.updateTable("users").set({
    bio: profile.bio,
    interests: profile.interests,
    is_private: profile.is_private ?? false,
    discoverable: profile.discoverable ?? true,
    allow_non_follower_messages: profile.allow_non_follower_messages ?? true,
    show_activity_status: rng.chance(0.85),
    last_active_at: iso(clampPast(NOW_MS - rng.int(2, 72 * 60) * MIN_MS)),
    location_lat: sharesLocation ? lat : null,
    location_lng: sharesLocation ? lng : null,
    location_updated_at: sharesLocation ? iso(NOW_MS - rng.int(1, 20) * DAY_MS) : null,
  }).where("id", "=", userId).execute();
  profilesAdded++;
}
report("social profiles", profilesAdded);

// ── 25. Follows, friendships and blocks ───────────────────────────────────────
// Gym communities follow each other (members ↔ members, members → coaches,
// staff ↔ staff), friends follow both ways, a few people follow across
// cities, some requests are still pending (with their notifications) and one
// user blocked another. Guard: skipped once any follow between seeded people exists.

const seededIds = [...userIdByUsername.values()];
const anyFollow = await db.selectFrom("follow").select("follower_id")
  .where("follower_id", "in", seededIds).where("followee_id", "in", seededIds).executeTakeFirst();
let followsAdded = 0;
let friendshipsAdded = 0;
if (!anyFollow) {
  const privateIds = new Set(
    Object.entries(socialProfiles).filter(([, p]) => p.is_private).map(([u]) => u),
  );
  const pairKey = (a: string, b: string) => `${a}>${b}`;
  const pendingFollow = new Set(socialGraph.pending_follow_requests.map(([a, b]) => pairKey(a, b)));
  const blockedPairs = new Set(socialGraph.blocks.flatMap(([a, b]) => [pairKey(a, b), pairKey(b, a)]));
  const follows = new Map<string, { follower: string; followee: string; status: "accepted" | "pending"; atMs: number }>();
  const addFollow = (follower: string, followee: string, status: "accepted" | "pending", atMs: number) => {
    const key = pairKey(follower, followee);
    if (follower === followee || blockedPairs.has(key) || !userIdByUsername.has(follower) || !userIdByUsername.has(followee)) return;
    if (pendingFollow.has(key)) status = "pending";
    const existing = follows.get(key);
    if (!existing || (existing.status === "pending" && status === "accepted" && !pendingFollow.has(key))) {
      follows.set(key, { follower, followee, status, atMs });
    }
  };

  const roleOf = (u: string) => personaByUsername.get(u)!.role;
  for (const gym of gymBusinesses) {
    const community = [...new Set([
      ...(memberUsernamesByGym.get(gym.name) ?? []),
      ...(trainerUsernamesByGym.get(gym.name) ?? []),
      ...(deskStaffUsernamesByGym.get(gym.name) ?? []),
      ...(ownerUsernamesByBusiness.get(gym.name) ?? []),
    ])];
    for (const a of community) {
      for (const b of community) {
        if (a === b) continue;
        const rng = rngFor("follow", a, b);
        const ra = roleOf(a), rb = roleOf(b);
        const coachB = rb === "trainer" || rb === "employee_trainer";
        const p = ra === "member" && rb === "member" ? 0.5
          : ra === "member" && coachB ? 0.85
          : ra === "member" && rb === "owner" ? 0.4
          : ra === "member" ? 0.3
          : rb === "member" ? 0.35
          : 0.75;
        if (!rng.chance(p)) continue;
        // Private accounts accepted most requests; the rest are still pending.
        const status = privateIds.has(b) && !rng.chance(0.7) ? "pending" : "accepted";
        addFollow(a, b, status, NOW_MS - rng.int(15, 120) * DAY_MS);
      }
    }
  }
  for (const [a, b] of socialGraph.cross_follows) addFollow(a, b, "accepted", NOW_MS - rngFor("xf", a, b).int(3, 60) * DAY_MS);
  for (const [a, b] of socialGraph.friendships) {
    const atMs = NOW_MS - rngFor("friends", a, b).int(10, 200) * DAY_MS;
    addFollow(a, b, "accepted", atMs);
    addFollow(b, a, "accepted", atMs);
  }
  for (const [a, b] of socialGraph.pending_follow_requests) {
    addFollow(a, b, "pending", NOW_MS - rngFor("pf", a, b).int(1, 72) * HOUR_MS);
  }

  const rows = [...follows.values()];
  if (rows.length) {
    await db.insertInto("follow").values(rows.map((f) => ({
      follower_id: uid(f.follower),
      followee_id: uid(f.followee),
      status: f.status,
      created_at: iso(f.atMs),
      accepted_at: f.status === "accepted" ? iso(f.atMs + HOUR_MS) : null,
    }))).onConflict((oc) => oc.doNothing()).execute();
    followsAdded = rows.length;
  }
  // Recent follows and every pending request show up in notifications.
  for (const f of rows) {
    if (f.status === "pending") {
      await addNotification([uid(f.followee)], {
        type: "follow_request",
        title: `${fullName(f.follower)} wants to follow you`,
        body: "",
        metadata: { user_id: uid(f.follower) },
      }, f.atMs);
    } else if (f.atMs > NOW_MS - 7 * DAY_MS) {
      await addNotification([uid(f.followee)], {
        type: "follow",
        title: `${fullName(f.follower)} started following you`,
        body: "",
        metadata: { user_id: uid(f.follower) },
      }, f.atMs);
    }
  }

  for (const [a, b] of socialGraph.friendships) {
    if (!userIdByUsername.has(a) || !userIdByUsername.has(b)) continue;
    const atMs = NOW_MS - rngFor("friends", a, b).int(10, 200) * DAY_MS;
    await db.insertInto("friendship").values({
      requester_id: uid(a),
      addressee_id: uid(b),
      status: "accepted",
      created_at: iso(atMs),
      accepted_at: iso(atMs + 3 * HOUR_MS),
    }).onConflict((oc) => oc.doNothing()).execute();
    friendshipsAdded++;
  }
  for (const [a, b] of socialGraph.pending_friend_requests) {
    if (!userIdByUsername.has(a) || !userIdByUsername.has(b)) continue;
    const atMs = NOW_MS - rngFor("pending-friend", a, b).int(2, 96) * HOUR_MS;
    await db.insertInto("friendship").values({
      requester_id: uid(a),
      addressee_id: uid(b),
      status: "pending",
      created_at: iso(atMs),
    }).onConflict((oc) => oc.doNothing()).execute();
    await addNotification([uid(b)], {
      type: "friend_request",
      title: `${fullName(a)} sent you a friend request`,
      body: "",
      metadata: { user_id: uid(a) },
    }, atMs);
    friendshipsAdded++;
  }
  for (const [a, b] of socialGraph.blocks) {
    if (!userIdByUsername.has(a) || !userIdByUsername.has(b)) continue;
    await db.insertInto("user_block").values({ blocker_id: uid(a), blocked_id: uid(b) })
      .onConflict((oc) => oc.doNothing()).execute();
  }
}
report("follows", followsAdded);
report("friendships", friendshipsAdded);

// ── 26. Personal posts ────────────────────────────────────────────────────────
// Photo/video posts on people's own profiles (files in the private user-media
// bucket), reactions from their followers and threaded comments. Guard: per
// post (author + caption).

const acceptedFollowers = async (userId: string) =>
  (await db.selectFrom("follow").select("follower_id").where("followee_id", "=", userId)
    .where("status", "=", "accepted").execute()).map((r) => r.follower_id);

let personalPostsAdded = 0;
let personalMediaAdded = 0;
let personalCommentsAdded = 0;
for (const p of personalPosts) {
  const authorId = userIdByUsername.get(p.author);
  if (!authorId) continue;
  const exists = await db.selectFrom("post").select("id").where("author_id", "=", authorId)
    .where("business_id", "is", null).where("content", "=", p.caption).executeTakeFirst();
  if (exists) {
    // An earlier run without network seeded it without its files.
    const hasMedia = await db.selectFrom("post_image").select("id").where("post_id", "=", exists.id).executeTakeFirst();
    if (hasMedia || p.media.length === 0) continue;
    for (const [i, key] of p.media.entries()) {
      const src = mediaSource(key);
      const path = `${authorId}/seed-${src.name}.${src.ext}`;
      if (!(await seedStorageObject("user-media", path, src.url, src.contentType))) continue;
      await db.insertInto("post_image").values({
        post_id: exists.id,
        url: null,
        storage_path: path,
        position: i,
        media_type: src.contentType.startsWith("video/") ? "video" : "image",
        mime_type: src.contentType,
        width: src.width,
        height: src.height,
        duration_ms: src.durationMs,
      }).execute();
      personalMediaAdded++;
    }
    continue;
  }
  const rng = rngFor("personal-post", p.author, p.caption);
  const createdMs = clampPast(NOW_MS - p.days_ago * DAY_MS, 10);

  const media: { path: string; contentType: string; width: number; height: number; durationMs: number | null }[] = [];
  for (const key of p.media) {
    const src = mediaSource(key);
    const path = `${authorId}/seed-${src.name}.${src.ext}`;
    const stored = await seedStorageObject("user-media", path, src.url, src.contentType);
    if (stored) media.push({ path, contentType: src.contentType, width: src.width, height: src.height, durationMs: src.durationMs });
  }

  const post = await db.transaction().execute(async (trx) => {
    const created = await trx.insertInto("post").values({
      business_id: null,
      author_id: authorId,
      content: p.caption,
      visibility: p.visibility,
      created_at: iso(createdMs),
      updated_at: iso(createdMs),
    }).returning(["id", "author_id", "business_id", "created_at"]).executeTakeFirstOrThrow();
    if (media.length) {
      await trx.insertInto("post_image").values(media.map((m, i) => ({
        post_id: created.id,
        url: null,
        storage_path: m.path,
        position: i,
        media_type: m.contentType.startsWith("video/") ? "video" as const : "image" as const,
        mime_type: m.contentType,
        width: m.width,
        height: m.height,
        duration_ms: m.durationMs,
      }))).execute();
      await trx.insertInto("media_upload").values(media.map((m) => ({
        storage_path: m.path,
        bucket: "user-media" as const,
        uploader_id: authorId,
        mime_type: m.contentType,
        created_at: iso(createdMs),
        claimed_at: iso(createdMs),
      }))).onConflict((oc) => oc.doNothing()).execute();
    }
    return created;
  });
  personalPostsAdded++;
  personalMediaAdded += media.length;

  // Reactions from a share of their followers, most soon after posting.
  const followers = await acceptedFollowers(authorId);
  const reactors = rng.sample(followers, Math.round(followers.length * rng.float(0.35, 0.85)));
  if (reactors.length) {
    await db.insertInto("post_reaction").values(reactors.map((user_id) => ({
      post_id: post.id,
      user_id,
      reaction: pickReaction(rng),
      created_at: iso(clampPast(createdMs + rng.next() ** 2 * Math.max(0, NOW_MS - createdMs))),
    }))).execute();
  }

  const thread = personalPostThreads.find((t) => p.caption.startsWith(t.post_starts_with));
  if (thread) personalCommentsAdded += await seedThread(post, thread, null, [authorId, ...followers]);
}
report("personal posts", personalPostsAdded);
report("personal post photos/videos", personalMediaAdded);
report("personal post comments", personalCommentsAdded);

// ── 27. Chats ─────────────────────────────────────────────────────────────────
// Direct chats (two of them still message requests) and group chats, with
// replies, reactions, photo/video attachments in the private chat-media bucket
// and read state: everyone has read everything except the last message or two
// sent to them. Guard: direct chats by pair, groups by title.

type ChatSeed = {
  kind: "direct" | "group";
  title: string | null;
  owner: string;
  people: { username: string; role: "owner" | "admin" | "member"; status: "active" | "request" }[];
  daysAgo: number;
  messages: SeedChatMessage[];
  directKey: string | null;
};

const chatSeeds: ChatSeed[] = [
  ...conversationSeeds.direct.filter((c) => userIdByUsername.has(c.a) && userIdByUsername.has(c.b)).map((c) => ({
    kind: "direct" as const,
    title: null,
    owner: c.a,
    people: [
      { username: c.a, role: "member" as const, status: "active" as const },
      { username: c.b, role: "member" as const, status: c.request ? "request" as const : "active" as const },
    ],
    daysAgo: c.days_ago,
    messages: c.messages,
    directKey: [uid(c.a), uid(c.b)].sort().join(":"),
  })),
  ...conversationSeeds.groups.map((g) => ({
    kind: "group" as const,
    title: g.title,
    owner: g.owner,
    people: [
      { username: g.owner, role: "owner" as const, status: "active" as const },
      ...g.members.filter((m) => m !== g.owner).map((m) => ({
        username: m,
        role: g.admins.includes(m) ? "admin" as const : "member" as const,
        status: "active" as const,
      })),
    ].filter((p) => userIdByUsername.has(p.username)),
    daysAgo: g.days_ago,
    messages: g.messages,
    directKey: null,
  })),
];

let conversationsAdded = 0;
let chatMessagesAdded = 0;
let chatAttachmentsAdded = 0;
for (const c of chatSeeds) {
  const exists = c.directKey
    ? await db.selectFrom("conversation").select("id").where("direct_key", "=", c.directKey).executeTakeFirst()
    : await db.selectFrom("conversation").select("id").where("kind", "=", "group").where("title", "=", c.title)
      .executeTakeFirst();
  if (exists) continue;

  const rng = rngFor("chat", c.directKey ?? c.title ?? "");
  const startMs = NOW_MS - c.daysAgo * DAY_MS;
  // Spread the messages between the start and (nearly) now.
  const gaps = c.messages.map(() => rng.float(0.2, 1));
  const span = Math.max(HOUR_MS, NOW_MS - 20 * MIN_MS - startMs);
  const totalGap = gaps.reduce((a, b) => a + b, 0) + 0.5;
  let cursor = startMs;
  const times = gaps.map((g) => (cursor += (g / totalGap) * span));

  const conv = await db.insertInto("conversation").values({
    kind: c.kind,
    title: c.title,
    direct_key: c.directKey,
    created_by: uid(c.owner),
    created_at: iso(startMs - 5 * MIN_MS),
    updated_at: iso(startMs - 5 * MIN_MS),
    last_message_at: iso(times.at(-1) ?? startMs),
  }).returning(["id"]).executeTakeFirstOrThrow();
  conversationsAdded++;

  await db.insertInto("conversation_participant").values(c.people.map((p) => ({
    conversation_id: conv.id,
    user_id: uid(p.username),
    role: p.role,
    status: p.status,
    added_by: p.username === c.owner ? null : uid(c.owner),
    joined_at: iso(startMs - 5 * MIN_MS),
  }))).execute();

  if (c.kind === "group") {
    await db.insertInto("message").values({
      conversation_id: conv.id,
      sender_id: uid(c.owner),
      kind: "system",
      metadata: { event: "created", title: c.title },
      created_at: iso(startMs - 4 * MIN_MS),
    }).execute();
  }

  const ids: string[] = [];
  for (const [i, m] of c.messages.entries()) {
    const senderId = uid(m.from);
    const atMs = clampPast(times[i], 2);
    const fileKey = m.image ?? (m.video ? `video:${m.video}` : null);
    let attachment: { path: string; contentType: string; size: number; width: number; height: number; durationMs: number | null; name: string } | null = null;
    if (fileKey) {
      const src = mediaSource(fileKey);
      const path = `${conv.id}/seed-${src.name}.${src.ext}`;
      const stored = await seedStorageObject("chat-media", path, src.url, src.contentType);
      if (stored) {
        attachment = { path, contentType: src.contentType, size: stored.size, width: src.width, height: src.height, durationMs: src.durationMs, name: `${src.name}.${src.ext}` };
      }
    }
    if (!m.text && !attachment) continue;
    const msg = await db.insertInto("message").values({
      conversation_id: conv.id,
      sender_id: senderId,
      kind: attachment ? "media" : "text",
      body: m.text ?? null,
      reply_to_id: m.reply_to !== undefined ? ids[m.reply_to] ?? null : null,
      created_at: iso(atMs),
    }).returning(["id"]).executeTakeFirstOrThrow();
    ids.push(msg.id);
    chatMessagesAdded++;
    if (attachment) {
      await db.insertInto("message_attachment").values({
        message_id: msg.id,
        storage_path: attachment.path,
        mime_type: attachment.contentType,
        size_bytes: attachment.size,
        file_name: attachment.name,
        width: attachment.width,
        height: attachment.height,
        duration_ms: attachment.durationMs,
      }).execute();
      await db.insertInto("media_upload").values({
        storage_path: attachment.path,
        bucket: "chat-media",
        uploader_id: senderId,
        conversation_id: conv.id,
        mime_type: attachment.contentType,
        created_at: iso(atMs),
        claimed_at: iso(atMs),
      }).onConflict((oc) => oc.doNothing()).execute();
      chatAttachmentsAdded++;
    }
    if (m.reaction && userIdByUsername.has(m.reaction.by)) {
      await db.insertInto("message_reaction").values({
        message_id: msg.id,
        user_id: uid(m.reaction.by),
        reaction: m.reaction.type,
        created_at: iso(clampPast(atMs + rng.int(1, 30) * MIN_MS)),
      }).execute();
    }
  }

  // Read state: each person has read up to their own last message, plus
  // everything older than the final one or two messages.
  const finalMs = clampPast(times.at(-1) ?? startMs, 2);
  for (const p of c.people) {
    if (p.status === "request") continue;
    const lastOwn = c.messages.map((m, i) => (m.from === p.username ? times[i] : 0)).reduce((a, b) => Math.max(a, b), 0);
    const caughtUp = rng.chance(0.6) ? finalMs : times.at(-2) ?? finalMs;
    await db.updateTable("conversation_participant")
      .set({ last_read_at: iso(clampPast(Math.max(lastOwn, caughtUp), 2)) })
      .where("conversation_id", "=", conv.id).where("user_id", "=", uid(p.username)).execute();
  }
}
report("conversations", conversationsAdded);
report("chat messages", chatMessagesAdded);
report("chat attachments", chatAttachmentsAdded);

// ── Summary ───────────────────────────────────────────────────────────────────

report("notifications", notificationsAdded);
await db.destroy();

const totalAdded = summary.reduce((s, [, n]) => s + n, 0);
console.log(
  totalAdded === 0
    ? "\nSeed complete: nothing to add, the database was already fully seeded."
    : `\nSeed complete: added ${totalAdded} rows across ${summary.filter(([, n]) => n > 0).length} sections.`,
);
