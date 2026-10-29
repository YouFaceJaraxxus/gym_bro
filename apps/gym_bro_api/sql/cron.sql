-- ── Scheduled jobs (pg_cron + pg_net) ────────────────────────────────────────
-- NOT applied automatically (it isn't in sql/schemas/). Run it by hand once per
-- environment after filling in the two placeholders:
--
--   <FUNCTIONS_URL>  the project's functions base URL, e.g.
--                    https://<project-ref>.supabase.co/functions/v1
--                    (local stack, from inside the db container:
--                    http://host.docker.internal:54321/functions/v1)
--   <CRON_SECRET>    the same value as the CRON_SECRET function secret
--                    (`supabase secrets set CRON_SECRET=...`)
--
-- Every 15 minutes it POSTs to the `jobs` function, which:
--   • marks memberships whose to_date has passed as inactive,
--   • sends `membership_expiring` notifications (7 days ahead, once per membership),
--   • sends `class_reminder` notifications for classes starting within 75 minutes,
--   • tops up class timetables so sessions exist 90 days ahead.
-- The function answers 503 not_configured while CRON_SECRET is unset and 401
-- on a wrong secret. Responses land in net._http_response for debugging:
--   SELECT id, status_code, content FROM net._http_response ORDER BY id DESC LIMIT 5;

CREATE EXTENSION IF NOT EXISTS pg_cron;
CREATE EXTENSION IF NOT EXISTS pg_net;

-- Re-running replaces the job (cron.schedule upserts by name).
SELECT cron.schedule(
  'gym-bro-jobs',
  '*/15 * * * *',
  $$
  SELECT net.http_post(
    url                  := '<FUNCTIONS_URL>/jobs/run',
    headers              := jsonb_build_object(
                              'Content-Type',  'application/json',
                              'x-cron-secret', '<CRON_SECRET>'
                            ),
    body                 := '{}'::jsonb,
    timeout_milliseconds := 30000
  );
  $$
);

-- ── Optional: keep the secret in Vault instead of the job text ───────────────
-- SELECT vault.create_secret('<CRON_SECRET>', 'cron_secret');
-- and use this header value inside the job instead of the literal:
--   (SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name = 'cron_secret')

-- ── Inspect / remove ─────────────────────────────────────────────────────────
-- SELECT * FROM cron.job;
-- SELECT * FROM cron.job_run_details ORDER BY start_time DESC LIMIT 10;
-- SELECT cron.unschedule('gym-bro-jobs');
