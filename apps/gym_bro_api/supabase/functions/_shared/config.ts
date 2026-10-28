import { Kysely, PostgresDialect } from "npm:kysely@^0.27";
import pg from "npm:pg@^8";
import { createClient } from "jsr:@supabase/supabase-js@2";
import type { Database } from "../../types/schema/public.ts";

const { Pool } = pg;

// ── Postgres / Kysely ─────────────────────────────────────────────────────────
// POSTGRES_URL is injected by the edge runtime via [edge_runtime.secrets] in
// config.toml — it is always present when this module loads in the container.

const postgresUrl = Deno.env.get("POSTGRES_URL");
if (!postgresUrl) throw new Error("POSTGRES_URL must be set");

const isLocal =
  postgresUrl.includes("127.0.0.1") ||
  postgresUrl.includes("localhost") ||
  postgresUrl.includes("host.docker.internal");

// `supabase secrets set` run from a shell with .env.local sourced also uploads
// config.toml's [edge_runtime.secrets], replacing the hosted POSTGRES_URL with
// the local one. Fail loudly instead of with a confusing getaddrinfo error.
const isHosted = /^https:\/\/[a-z0-9]+\.supabase\.co\/?$/.test(Deno.env.get("SUPABASE_URL") ?? "");
if (isHosted && isLocal) {
  throw new Error(
    "POSTGRES_URL points at a local database but this is a hosted project. It was most likely " +
      "overwritten by `supabase secrets set` run from a shell with .env.local sourced. " +
      "Set it back to the pooler URL from a clean shell.",
  );
}

export const db = new Kysely<Database>({
  dialect: new PostgresDialect({
    pool: new Pool({
      connectionString: postgresUrl,
      ssl: isLocal ? false : { rejectUnauthorized: false },
    }),
  }),
});

// ── Supabase ──────────────────────────────────────────────────────────────────

export const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
export const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY")!;

// Admin client — for auth.admin operations and JWT validation.
// SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY are auto-injected by the runtime.
export const supabaseAdmin = createClient(
  supabaseUrl,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  { auth: { persistSession: false, autoRefreshToken: false } },
);
