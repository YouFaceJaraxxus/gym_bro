-- ── Lock down direct table access ─────────────────────────────────────────────
-- Clients only ever talk to the edge functions, which connect as the table
-- owner and do their own authorization. PostgREST (/rest/v1) and GraphQL run as
-- the `anon` / `authenticated` roles, so we:
--   1. enable RLS on every public table with no policies (deny by default), and
--   2. revoke the default table/sequence/function grants from those roles.
-- The table owner (postgres) and service_role bypass RLS, so the edge functions
-- and the seed script keep working unchanged.

DO $$
DECLARE
  t record;
BEGIN
  FOR t IN
    SELECT tablename FROM pg_tables WHERE schemaname = 'public'
  LOOP
    EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY', t.tablename);
  END LOOP;
END $$;

REVOKE ALL ON ALL TABLES    IN SCHEMA public FROM anon, authenticated;
REVOKE ALL ON ALL SEQUENCES IN SCHEMA public FROM anon, authenticated;
REVOKE ALL ON ALL FUNCTIONS IN SCHEMA public FROM anon, authenticated;

-- Tables created later by postgres don't get the grants back.
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public REVOKE ALL ON TABLES    FROM anon, authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public REVOKE ALL ON SEQUENCES FROM anon, authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public REVOKE ALL ON FUNCTIONS FROM anon, authenticated;

-- Any table added after this migration must also run:
--   ALTER TABLE public.<name> ENABLE ROW LEVEL SECURITY;

-- ── Membership invoice status ─────────────────────────────────────────────────

DO $$ BEGIN
  CREATE TYPE invoice_status AS ENUM ('unpaid', 'paid', 'void');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

ALTER TABLE membership_invoice
  ADD COLUMN IF NOT EXISTS status  invoice_status NOT NULL DEFAULT 'unpaid',
  ADD COLUMN IF NOT EXISTS paid_at TIMESTAMPTZ;

CREATE INDEX IF NOT EXISTS membership_invoice_status_idx ON membership_invoice (status);
