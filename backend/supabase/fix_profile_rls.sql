-- supabase/fix_profile_rls.sql
-- Allow users to update their own profile information (necessary for is_online and last_seen updates)
DO $$ BEGIN IF NOT EXISTS (
    SELECT 1
    FROM pg_policies
    WHERE tablename = 'profiles'
        AND policyname = 'Users can update own profile'
) THEN CREATE POLICY "Users can update own profile" ON public.profiles FOR
UPDATE USING (auth.uid() = id);
END IF;
END $$;
-- Also ensure is_online and last_seen are included in the realtime publication if not already
-- Note: Already a member in您的 environment, so we skip the ALTER PUBLICATION command to avoid errors.
NOTIFY pgrst,
'reload schema';



