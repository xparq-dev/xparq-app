-- 1. Function to automatically set expires_at when a message is inserted
-- if the chat has a vanishing_duration.
CREATE OR REPLACE FUNCTION public.handle_vanishing_messages_trigger() RETURNS TRIGGER AS $$
DECLARE v_duration INTEGER;
BEGIN
SELECT vanishing_duration INTO v_duration
FROM public.chats
WHERE id = NEW.chat_id;
IF v_duration IS NOT NULL
AND v_duration > 0 THEN NEW.expires_at = NOW() + (v_duration || ' seconds')::INTERVAL;
END IF;
RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
-- 2. Create the trigger
DROP TRIGGER IF EXISTS tr_vanishing_messages ON public.messages;
CREATE TRIGGER tr_vanishing_messages BEFORE
INSERT ON public.messages FOR EACH ROW EXECUTE FUNCTION public.handle_vanishing_messages_trigger();
-- 3. [Optional] If the user wants to delete expired messages via periodic check
-- This requires pg_cron or similar, or just relying on SELECT filtering.
-- For now, we rely on SELECT filtering in the app (already implemented in many Signal-like apps)
-- OR we can add an RPC to clean up.
-- Cleanup function to be called periodically (manually or via cron)
CREATE OR REPLACE FUNCTION public.cleanup_expired_messages() RETURNS VOID AS $$ BEGIN
DELETE FROM public.messages
WHERE expires_at IS NOT NULL
    AND expires_at < NOW();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;



