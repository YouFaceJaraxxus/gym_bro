// Importing anything that pulls in supabase/functions/_shared/config.ts needs
// the edge runtime's env. Import this module FIRST (before the module under
// test) so config.ts sees harmless placeholders. Nothing here opens a
// connection: the pg Pool and the Supabase client are lazy.
const defaults: Record<string, string> = {
  POSTGRES_URL: "postgresql://postgres:postgres@127.0.0.1:1/unit_tests",
  SUPABASE_URL: "http://127.0.0.1:1",
  SUPABASE_ANON_KEY: "unit-test-anon-key",
  SUPABASE_SERVICE_ROLE_KEY: "unit-test-service-role-key",
};

for (const [k, v] of Object.entries(defaults)) {
  if (!Deno.env.get(k)) Deno.env.set(k, v);
}
