-- =====================================================
-- CHECK: Realtime & Notification Setup
-- Run in: https://fidmehpoyvwdawcldvie.supabase.co/project/_sql
-- =====================================================

-- 1. Check if Realtime is enabled for messages table
SELECT 
  schemaname,
  tablename,
  rowsecurity
FROM pg_tables 
WHERE tablename = 'messages';

-- 2. Check RLS policies on messages
SELECT 
  schemaname,
  tablename,
  policyname,
  permissive,
  roles,
  cmd,
  qual,
  with_check
FROM pg_policies 
WHERE tablename = 'messages';

-- 3. Check if pg_net is installed
SELECT * FROM pg_extension WHERE extname = 'pg_net';

-- 4. Check if trigger exists
SELECT 
  tgname as trigger_name,
  tgrelid::regclass as table_name
FROM pg_trigger
WHERE tgname = 'tr_on_signal_message_inserted';

-- 5. Enable Realtime for messages table (if not enabled)
-- Run this in Supabase Dashboard, not here:
-- ALTER PUBLICATION supabase_realtime ADD TABLE public.messages;

-- 6. Create RLS policy for authenticated users to read messages
-- (if not exists)
CREATE POLICY "Authenticated users can read messages"
ON public.messages
FOR SELECT
TO authenticated
USING (true);

-- 7. Grant necessary permissions
GRANT SELECT ON public.messages TO authenticated;
GRANT USAGE ON SCHEMA public TO authenticated;

-- 8. Verify publication exists
SELECT 
  pubname,
  puballtables
FROM pg_publication 
WHERE pubname = 'supabase_realtime';

-- 9. Check what tables are in the publication
SELECT 
  schemaname,
  tablename
FROM pg_publication_tables 
WHERE pubname = 'supabase_realtime';

-- =====================================================
-- FIX: Enable Realtime if not enabled
-- =====================================================
-- If supabase_realtime publication doesn't exist:
-- CREATE PUBLICATION supabase_realtime;

-- If messages table not in publication:
-- ALTER PUBLICATION supabase_realtime ADD TABLE public.messages;
-- =====================================================
