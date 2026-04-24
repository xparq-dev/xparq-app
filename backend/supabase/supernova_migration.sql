-- Migration to support Supernova (Story) feature
-- 1. Add pulse_type column to differentiate regular posts from 24h stories
ALTER TABLE public.pulses
ADD COLUMN IF NOT EXISTS pulse_type text DEFAULT 'post';
-- 2. Add a constraint to ensure pulse_type is valid
ALTER TABLE public.pulses
ADD CONSTRAINT pulses_pulse_type_check CHECK (pulse_type IN ('post', 'story'));
-- 3. Create an index to speed up story queries (we often query for stories within the last 24h)
CREATE INDEX IF NOT EXISTS idx_pulses_pulse_type ON public.pulses (pulse_type, created_at);
-- 4. Update the RPC functions to handle pulse_type if needed
-- (The existing decrement/increment functions for spark_count, echo_count, warp_count should work as-is since they operate on pulse_id)



