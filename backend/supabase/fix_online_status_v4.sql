-- 1. Enable RLS on profiles (just in case it wasn't enabled)
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
-- 2. Add/Correct UPDATE policy for users to manage their own status
DROP POLICY IF EXISTS "Users can update own profile" ON public.profiles;
CREATE POLICY "Users can update own profile" ON public.profiles FOR
UPDATE USING (auth.uid() = id) WITH CHECK (auth.uid() = id);
-- 3. RESET EVERYONE TO OFFLINE
-- This clears "stuck" indicators and ensures a clean state with the new 5-minute logic.
UPDATE public.profiles
SET is_online = false,
    last_seen = NOW() - INTERVAL '1 hour';
-- 4. Notify PostgREST to reload schema
NOTIFY pgrst,
'reload schema';



