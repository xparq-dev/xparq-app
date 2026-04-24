-- Redefine silence_chat to accept an optional p_user_id.
-- This allows background isolates (which may not have an active auth session) 
-- to perform silence actions by passing the UID explicitly.

CREATE OR REPLACE FUNCTION silence_chat(
    p_chat_id TEXT, 
    p_until TIMESTAMPTZ, 
    p_user_id UUID DEFAULT NULL
) 
RETURNS VOID AS $$ 
DECLARE
    v_uid UUID;
BEGIN 
    -- Fallback to auth.uid() if p_user_id is not provided
    v_uid := COALESCE(p_user_id, auth.uid());
    
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'User ID is required for silence_chat action';
    END IF;

    INSERT INTO public.chat_settings (uid, chat_id, silenced_until)
    VALUES (v_uid, p_chat_id, p_until) 
    ON CONFLICT (uid, chat_id) DO UPDATE
    SET silenced_until = p_until,
        updated_at = NOW();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
