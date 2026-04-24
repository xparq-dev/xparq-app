-- ============================================================
-- Create the `devices` table for multi-device Signal support
-- SAFE / IDEMPOTENT VERSION (can run multiple times)
-- ============================================================

-- 1. Table
CREATE TABLE IF NOT EXISTS public.devices (
  uid            UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  device_id      TEXT NOT NULL,
  identity_key   TEXT NOT NULL,
  last_active_at TIMESTAMPTZ DEFAULT NOW(),
  PRIMARY KEY (uid, device_id)
);

-- 2. Enable RLS (safe)
ALTER TABLE public.devices ENABLE ROW LEVEL SECURITY;

-- ============================================================
-- 3. Policies (SAFE: drop first, then recreate)
-- ============================================================

DROP POLICY IF EXISTS "Users can read own devices" ON public.devices;
CREATE POLICY "Users can read own devices"
  ON public.devices FOR SELECT
  USING (auth.uid() = uid);

DROP POLICY IF EXISTS "Users can upsert own devices" ON public.devices;
CREATE POLICY "Users can upsert own devices"
  ON public.devices FOR INSERT
  WITH CHECK (auth.uid() = uid);

DROP POLICY IF EXISTS "Users can update own devices" ON public.devices;
CREATE POLICY "Users can update own devices"
  ON public.devices FOR UPDATE
  USING (auth.uid() = uid);

DROP POLICY IF EXISTS "Users can delete own devices" ON public.devices;
CREATE POLICY "Users can delete own devices"
  ON public.devices FOR DELETE
  USING (auth.uid() = uid);

DROP POLICY IF EXISTS "Users can read others device identity keys" ON public.devices;
CREATE POLICY "Users can read others device identity keys"
  ON public.devices FOR SELECT
  USING (true);

-- ============================================================
-- 4. Index (already safe)
-- ============================================================

CREATE INDEX IF NOT EXISTS devices_uid_idx ON public.devices(uid);