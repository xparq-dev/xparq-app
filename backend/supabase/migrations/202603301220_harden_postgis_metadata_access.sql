-- Harden PostGIS metadata exposure in the public schema.
--
-- Why:
-- - As of 2026-03-30, the following PostGIS metadata endpoints were readable
--   through the Supabase REST API using the project's publishable/anon key:
--   - public.spatial_ref_sys
--   - public.geometry_columns
--   - public.geography_columns
-- - Supabase recommends enabling RLS for tables in exposed schemas, but these
--   objects are PostGIS-managed metadata objects. For extension-managed objects,
--   the safer short-term mitigation is to revoke direct API access from
--   browser-facing roles instead of forcing RLS onto extension internals.
--
-- Notes:
-- - This migration intentionally keeps access for elevated roles such as
--   service_role/postgres untouched.
-- - Long-term, the cleaner fix is to install PostGIS into a dedicated
--   non-exposed schema instead of public.

DO $$
BEGIN
  IF to_regclass('public.spatial_ref_sys') IS NOT NULL THEN
    REVOKE ALL ON TABLE public.spatial_ref_sys FROM anon, authenticated;
  END IF;
END $$;

DO $$
BEGIN
  IF to_regclass('public.geometry_columns') IS NOT NULL THEN
    REVOKE ALL ON TABLE public.geometry_columns FROM anon, authenticated;
  END IF;
END $$;

DO $$
BEGIN
  IF to_regclass('public.geography_columns') IS NOT NULL THEN
    REVOKE ALL ON TABLE public.geography_columns FROM anon, authenticated;
  END IF;
END $$;

NOTIFY pgrst, 'reload schema';
