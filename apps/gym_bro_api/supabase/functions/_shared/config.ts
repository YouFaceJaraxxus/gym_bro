import { createClient, SupabaseClient } from "jsr:@supabase/supabase-js@2";

const supabaseUrl = Deno.env.get("SUPABASE_URL");
const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

if (!supabaseUrl || !serviceRoleKey) {
  throw new Error("SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY must be set");
}

// When running via `supabase functions serve`, SUPABASE_URL points to the
// local Docker stack. In production it points to the remote instance.
// Both cases are handled transparently — no manual switching needed.
export const IS_LOCAL = supabaseUrl.includes("127.0.0.1") ||
  supabaseUrl.includes("localhost");

export const ENV = IS_LOCAL ? "local" : "production";

export const db: SupabaseClient = createClient(supabaseUrl, serviceRoleKey);
