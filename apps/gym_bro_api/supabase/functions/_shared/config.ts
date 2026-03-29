import { createClient, SupabaseClient } from "jsr:@supabase/supabase-js@2";
import { Database } from "../../types/schema/public.ts";

// APP_SUPABASE_URL / APP_SERVICE_ROLE_KEY are custom vars the local runtime
// won't override — set them via `doppler run -- supabase functions serve`
// to target the prod DB from a local function run.
// Falls back to the auto-injected local values when not set.
const supabaseUrl =
  Deno.env.get("APP_SUPABASE_URL") ?? Deno.env.get("SUPABASE_URL");
const serviceRoleKey =
  Deno.env.get("APP_SERVICE_ROLE_KEY") ??
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

if (!supabaseUrl || !serviceRoleKey) {
  throw new Error("SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY must be set");
}

export const IS_LOCAL = supabaseUrl.includes("127.0.0.1") ||
  supabaseUrl.includes("localhost");

export const ENV = IS_LOCAL ? "local" : "production";

console.log(`[config] targeting ${ENV} DB → ${supabaseUrl}`);

export const db: SupabaseClient<Database> = createClient<Database>(supabaseUrl, serviceRoleKey);
