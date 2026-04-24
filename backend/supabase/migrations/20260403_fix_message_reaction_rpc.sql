-- Function to safely toggle reactions bypassing authors-only RLS
-- This function allows any chat participant to react to messages in that chat.
-- 
-- Run this in your Supabase SQL Editor: https://supabase.com/dashboard/project/_/sql
--

CREATE OR REPLACE FUNCTION toggle_message_reaction(
  p_message_id BIGINT,
  p_user_id UUID,
  p_reaction TEXT DEFAULT '❤️'
) RETURNS VOID AS $$
DECLARE
  v_metadata JSONB;
  v_sparks TEXT[];
  v_reactions JSONB;
BEGIN
  -- 1. Validate: User must be a participant of the chat this message belongs to
  IF NOT EXISTS (
    SELECT 1 FROM chat_participants cp
    JOIN messages m ON m.chat_id = cp.chat_id
    WHERE m.id = p_message_id AND cp.user_id = p_user_id
  ) THEN
    RAISE EXCEPTION '[XPARQ_AUTH] User is not a participant of this chat.';
  END IF;

  -- 2. Get current metadata
  SELECT metadata INTO v_metadata FROM messages WHERE id = p_message_id;
  v_metadata := COALESCE(v_metadata, '{}'::jsonb);
  
  -- 3. Extract sparks and reactions safely
  -- Ensure 'sparks' is an array and 'reactions' is a map
  v_sparks := COALESCE(ARRAY(SELECT jsonb_array_elements_text(v_metadata->'sparks')), ARRAY[]::TEXT[]);
  v_reactions := COALESCE(v_metadata->'reactions', '{}'::jsonb);

  -- 4. Toggle Logic (Standard for XPARQ)
  IF (v_reactions ? p_user_id::text) THEN
    -- Already reacted: if same emoji, remove it. If different, update it.
    IF (v_reactions->>p_user_id::text = p_reaction) THEN
      v_reactions := v_reactions - p_user_id::text;
      v_sparks := array_remove(v_sparks, p_user_id::text);
    ELSE
      v_reactions := v_reactions || jsonb_build_object(p_user_id::text, p_reaction);
      IF NOT (p_user_id::text = ANY(v_sparks)) THEN
        v_sparks := v_sparks || p_user_id::text;
      END IF;
    END IF;
  ELSE
    -- New reaction
    v_reactions := v_reactions || jsonb_build_object(p_user_id::text, p_reaction);
    IF NOT (p_user_id::text = ANY(v_sparks)) THEN
      v_sparks := v_sparks || p_user_id::text;
    END IF;
  END IF;

  -- 5. Atomic Update
  UPDATE messages 
  SET metadata = jsonb_set(
    jsonb_set(v_metadata, '{sparks}', to_jsonb(v_sparks)),
    '{reactions}', v_reactions
  )
  WHERE id = p_message_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
