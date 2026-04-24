-- =====================================================
-- FIX: Notification Trigger & pg_net Setup
-- =====================================================
-- Run this in Supabase SQL Editor: https://fidmehpoyvwdawcldvie.supabase.co/project/_sql
-- =====================================================

-- 1. Check if pg_net is enabled
SELECT * FROM pg_extension WHERE extname = 'pg_net';

-- If NOT enabled, run this in Supabase Dashboard:
-- Go to: Database > Extensions > Search "pg_net" > Enable

-- 2. Check if trigger exists
SELECT tgname, tgrelid::regclass, proname
FROM pg_trigger
JOIN pg_proc ON pg_trigger.tgfoid = pg_proc.oid
WHERE tgname = 'tr_on_signal_message_inserted';

-- 3. Check if function exists
SELECT proname, prosrc 
FROM pg_proc 
WHERE proname = 'on_signal_message_inserted_webhook';

-- 4. Recreate everything (if needed)
-- =====================================================
-- STEP 1: Enable pg_net (MUST be done in Supabase Dashboard first)
-- =====================================================
-- GO TO: https://fidmehpoyvwdawcldvie.supabase.co/project/_database/extensions
-- Search for "pg_net" and ENABLE it
-- =====================================================

-- STEP 2: Create the function
CREATE OR REPLACE FUNCTION public.on_signal_message_inserted_webhook()
RETURNS TRIGGER AS $$
DECLARE
  request_id bigint;
  payload jsonb;
  url text;
BEGIN
  -- Get recipient user ID (the one who should receive notification)
  -- Assuming chat_participants table links users to chats
  -- Or use the other user in the conversation
  
  -- Construct payload for Edge Function
  payload := jsonb_build_object(
    'type', 'INSERT',
    'table', 'messages',
    'schema', 'public',
    'record', row_to_json(NEW)
  );
  
  url := 'https://fidmehpoyvwdawcldvie.supabase.co/functions/v1/chat-notifications';
  
  -- Make async HTTP request
  SELECT net.http_post(
    url := url,
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZpZG1laHBveXZ3ZGF3Y2xkdml lIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTY5ODc2NTQzOCwiZXhwIjoyMDE0MzQxNDM4fQ.YOUR_SERVICE_ROLE_KEY'
    )::jsonb,
    body := payload,
    timeout_milliseconds := 5000
  ) INTO request_id;
  
  -- Log for debugging (optional)
  RAISE NOTICE 'HTTP request queued with id: %', request_id;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- STEP 3: Create the trigger
DROP TRIGGER IF EXISTS tr_on_signal_message_inserted ON public.messages;

CREATE TRIGGER tr_on_signal_message_inserted
AFTER INSERT ON public.messages
FOR EACH ROW
EXECUTE FUNCTION public.on_signal_message_inserted_webhook();

-- STEP 4: Verify trigger is created
SELECT 
  tgname as trigger_name,
  tgrelid::regclass as table_name,
  proname as function_name
FROM pg_trigger
JOIN pg_proc ON pg_trigger.tgfoid = pg_proc.oid
WHERE tgname = 'tr_on_signal_message_inserted';

-- STEP 5: Test the trigger by inserting a test message
-- Uncomment to test:
-- INSERT INTO messages (id, chat_id, sender_id, content, created_at)
-- VALUES ('test_' || EXTRACT(EPOCH FROM NOW())::text, 'test_chat', 'test_user', 'Test notification', NOW());

-- =====================================================
-- ALTERNATIVE: Use Supabase Realtime instead of pg_net
-- =====================================================
-- If pg_net doesn't work, use Realtime broadcast:
-- 
-- 1. Enable Realtime for messages table:
--    Go to: Database > Replication > Source > messages > Enable
--
-- 2. Client subscribes via:
--    supabase.channel('public:messages').subscribe()
-- =====================================================
