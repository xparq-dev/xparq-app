-- Schedule daily purge of accounts that stayed in pending_deletion past the grace period.
-- Based on Supabase Cron + pg_net + Vault:
-- https://supabase.com/docs/guides/functions/schedule-functions
-- https://supabase.com/docs/guides/database/extensions/pg_net
--
-- Run this after:
-- 1. Deploying the account-lifecycle Edge Function
-- 2. Setting a strong ACCOUNT_PURGE_ADMIN_TOKEN secret in the function
-- 3. Storing the same values in Vault with the statements below

CREATE EXTENSION IF NOT EXISTS pg_cron;
CREATE EXTENSION IF NOT EXISTS pg_net;

-- Vault is optional.
-- Some Supabase/local Postgres environments do not expose the `vault` extension
-- for SQL installation, which causes:
--   ERROR: extension "vault" is not available
--
-- If your environment already has Vault, you can store secrets there and use the
-- "Vault-backed job" block below.
--
-- Example:
-- SELECT vault.create_secret('https://YOUR_PROJECT_REF.supabase.co', 'project_url');
-- SELECT vault.create_secret('YOUR_SUPABASE_ANON_KEY', 'project_anon_key');
-- SELECT vault.create_secret('YOUR_ACCOUNT_PURGE_ADMIN_TOKEN', 'account_purge_admin_token');
--
-- If Vault is unavailable, use the "Direct-value job" block instead and replace
-- the placeholders before running it.

-- Optional: remove an older job before recreating it.
DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM cron.job
    WHERE jobname = 'daily-account-purge'
  ) THEN
    PERFORM cron.unschedule('daily-account-purge');
  END IF;
END $$;

-- Option A: Vault-backed job
-- Uncomment only if `vault.decrypted_secrets` is available in your environment.
--
-- SELECT cron.schedule(
--   'daily-account-purge',
--   '15 3 * * *',
--   $$
--   SELECT
--     net.http_post(
--       url:=(
--         SELECT decrypted_secret
--         FROM vault.decrypted_secrets
--         WHERE name = 'project_url'
--       ) || '/functions/v1/account-lifecycle',
--       headers:=jsonb_build_object(
--         'Content-Type', 'application/json',
--         'apikey', (
--           SELECT decrypted_secret
--           FROM vault.decrypted_secrets
--           WHERE name = 'project_anon_key'
--         ),
--         'Authorization', 'Bearer ' || (
--           SELECT decrypted_secret
--           FROM vault.decrypted_secrets
--           WHERE name = 'project_anon_key'
--         ),
--         'x-account-admin-token', (
--           SELECT decrypted_secret
--           FROM vault.decrypted_secrets
--           WHERE name = 'account_purge_admin_token'
--         )
--       ),
--       body:='{"action":"purge_pending","graceDays":30,"limit":100}'::jsonb
--     ) AS request_id;
--   $$
-- );

-- Option B: Direct-value job
-- Replace the placeholders below, then run this block if Vault is unavailable.
SELECT cron.schedule(
  'daily-account-purge',
  '15 3 * * *',
  $$
  SELECT
    net.http_post(
      url:='https://fidmehpoyvwdawcldvie.supabase.co/functions/v1/account-lifecycle',
      headers:=jsonb_build_object(
        'Content-Type', 'application/json',
        'apikey', 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZpZG1laHBveXZ3ZGF3Y2xkdmllIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzIwODkwMDMsImV4cCI6MjA4NzY2NTAwM30.t_jJN5HfcSETflbmqIjvELLQ-3tJedklTYA35ZzDtlU',
        'Authorization', 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZpZG1laHBveXZ3ZGF3Y2xkdmllIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzIwODkwMDMsImV4cCI6MjA4NzY2NTAwM30.t_jJN5HfcSETflbmqIjvELLQ-3tJedklTYA35ZzDtlU',
        'x-account-admin-token', 'YOUR_ACCOUNT_PURGE_ADMIN_TOKEN'
      ),
      body:='{"action":"purge_pending","graceDays":30,"limit":100}'::jsonb
    ) AS request_id;
  $$
);
