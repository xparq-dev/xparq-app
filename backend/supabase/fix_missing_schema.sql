-- supabase/fix_missing_schema.sql
-- Consolidated fix for missing schema elements (PGRST205 and other desyncs)
-- 1. Update public.chats table
ALTER TABLE public.chats
ADD COLUMN IF NOT EXISTS vanishing_duration INTEGER;
-- 2. Update public.messages table
ALTER TABLE public.messages
ADD COLUMN IF NOT EXISTS message_type TEXT DEFAULT 'text',
    ADD COLUMN IF NOT EXISTS metadata JSONB DEFAULT '{}'::JSONB,
    ADD COLUMN IF NOT EXISTS expires_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS deleted_uids UUID [] DEFAULT '{}'::UUID [];
-- 3. Create chat_settings table
CREATE TABLE IF NOT EXISTS public.chat_settings (
    uid UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    chat_id TEXT NOT NULL REFERENCES public.chats(id) ON DELETE CASCADE,
    is_pinned BOOLEAN DEFAULT FALSE,
    is_archived BOOLEAN DEFAULT FALSE,
    silenced_until TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    PRIMARY KEY (uid, chat_id)
);
-- Enable RLS for chat_settings
ALTER TABLE public.chat_settings ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN IF NOT EXISTS (
    SELECT 1
    FROM pg_policies
    WHERE tablename = 'chat_settings'
        AND policyname = 'Users can manage their own chat settings'
) THEN CREATE POLICY "Users can manage their own chat settings" ON public.chat_settings FOR ALL USING (auth.uid() = uid);
END IF;
END $$;
-- 4. Create/Update Utility RPC functions
-- toggle_chat_pin
CREATE OR REPLACE FUNCTION toggle_chat_pin(p_chat_id TEXT, p_is_pinned BOOLEAN) RETURNS VOID AS $$ BEGIN
INSERT INTO public.chat_settings (uid, chat_id, is_pinned)
VALUES (auth.uid(), p_chat_id, p_is_pinned) ON CONFLICT (uid, chat_id) DO
UPDATE
SET is_pinned = p_is_pinned,
    updated_at = NOW();
END;
$$ LANGUAGE plpgsql;
-- toggle_chat_archive
CREATE OR REPLACE FUNCTION toggle_chat_archive(p_chat_id TEXT, p_is_archived BOOLEAN) RETURNS VOID AS $$ BEGIN
INSERT INTO public.chat_settings (uid, chat_id, is_archived)
VALUES (auth.uid(), p_chat_id, p_is_archived) ON CONFLICT (uid, chat_id) DO
UPDATE
SET is_archived = p_is_archived,
    updated_at = NOW();
END;
$$ LANGUAGE plpgsql;
-- silence_chat
CREATE OR REPLACE FUNCTION silence_chat(p_chat_id TEXT, p_until TIMESTAMPTZ) RETURNS VOID AS $$ BEGIN
INSERT INTO public.chat_settings (uid, chat_id, silenced_until)
VALUES (auth.uid(), p_chat_id, p_until) ON CONFLICT (uid, chat_id) DO
UPDATE
SET silenced_until = p_until,
    updated_at = NOW();
END;
$$ LANGUAGE plpgsql;
-- delete_message_for_me
CREATE OR REPLACE FUNCTION delete_message_for_me(p_message_id BIGINT) RETURNS VOID AS $$ BEGIN
UPDATE public.messages
SET deleted_uids = array_append(deleted_uids, auth.uid())
WHERE id = p_message_id
    AND NOT (auth.uid() = ANY(deleted_uids));
END;
$$ LANGUAGE plpgsql;
-- 5. Reload Schema for PostgREST
NOTIFY pgrst,
'reload schema';



