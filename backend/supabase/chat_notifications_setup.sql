-- c:\Apps\XPARQ_App\supabase\chat_notifications_setup.sql
--
-- Setup Database Webhook for Signal Chat Notifications.
-- This sends a POST request to our Firebase Function on every new message insertion.

-- 1. Ensure the net extension is enabled (for outgoing HTTP requests)
CREATE EXTENSION IF NOT EXISTS "pg_net" WITH SCHEMA "extensions";

-- 2. Create the notification trigger function
CREATE OR REPLACE FUNCTION public.on_signal_message_inserted_webhook()
RETURNS TRIGGER AS $$
DECLARE
  payload JSONB;
BEGIN
  -- Construct the payload to match the expected format in Firebase Function
  payload := JSONB_BUILD_OBJECT(
    'type', 'INSERT',
    'table', 'messages',
    'schema', 'public',
    'record', ROW_TO_JSON(NEW)
  );

  -- Trigger the HTTP POST request to the Supabase Edge Function
  PERFORM net.http_post(
    url := 'https://fidmehpoyvwdawcldvie.supabase.co/functions/v1/chat-notifications',
    headers := '{"Content-Type": "application/json"}'::JSONB,
    body := payload,
    timeout_milliseconds := 20000
  );

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. Attach the trigger to the messages table
DROP TRIGGER IF EXISTS tr_on_signal_message_inserted ON public.messages;
CREATE TRIGGER tr_on_signal_message_inserted
AFTER INSERT ON public.messages
FOR EACH ROW EXECUTE FUNCTION public.on_signal_message_inserted_webhook();

-- 4. Notify about schema change (optional but good for PostgREST cache)
NOTIFY pgrst, 'reload schema';




