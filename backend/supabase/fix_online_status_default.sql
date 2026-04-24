-- Add last_seen column if missing
ALTER TABLE public.profiles
ADD COLUMN IF NOT EXISTS last_seen TIMESTAMPTZ;
-- Fix online status default to false
ALTER TABLE public.profiles
ALTER COLUMN is_online
SET DEFAULT FALSE;
-- Reset all users to offline currently
UPDATE public.profiles
SET is_online = FALSE;
-- Add comments for clarity
COMMENT ON COLUMN public.profiles.is_online IS 'Whether the user is currently using the app. Defaults to false.';
COMMENT ON COLUMN public.profiles.last_seen IS 'The last time the user was active in the app.';



