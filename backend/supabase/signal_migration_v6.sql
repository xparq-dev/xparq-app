-- supabase/signal_migration_v6.sql
-- Phase 7: Chat Management (Pin, Archive, Silence)
-- 1. Create chat_settings table for per-user chat preferences
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
-- 2. Add message_type and metadata to messages if missing (for legacy support)
DO $$ BEGIN IF NOT EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
        AND table_name = 'messages'
        AND column_name = 'message_type'
) THEN
ALTER TABLE public.messages
ADD COLUMN message_type TEXT DEFAULT 'text';
END IF;
IF NOT EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
        AND table_name = 'messages'
        AND column_name = 'metadata'
) THEN
ALTER TABLE public.messages
ADD COLUMN metadata JSONB DEFAULT '{}'::JSONB;
END IF;
END $$;
-- 3. Utility function to toggle pin
CREATE OR REPLACE FUNCTION toggle_chat_pin(p_chat_id TEXT, p_is_pinned BOOLEAN) RETURNS VOID AS $$ BEGIN
INSERT INTO public.chat_settings (uid, chat_id, is_pinned)
VALUES (auth.uid(), p_chat_id, p_is_pinned) ON CONFLICT (uid, chat_id) DO
UPDATE
SET is_pinned = p_is_pinned,
    updated_at = NOW();
END;
$$ LANGUAGE plpgsql;
-- 4. Utility function to toggle archive
CREATE OR REPLACE FUNCTION toggle_chat_archive(p_chat_id TEXT, p_is_archived BOOLEAN) RETURNS VOID AS $$ BEGIN
INSERT INTO public.chat_settings (uid, chat_id, is_archived)
VALUES (auth.uid(), p_chat_id, p_is_archived) ON CONFLICT (uid, chat_id) DO
UPDATE
SET is_archived = p_is_archived,
    updated_at = NOW();
END;
$$ LANGUAGE plpgsql;
-- 5. Utility function to silence chat
CREATE OR REPLACE FUNCTION silence_chat(p_chat_id TEXT, p_until TIMESTAMPTZ) RETURNS VOID AS $$ BEGIN
INSERT INTO public.chat_settings (uid, chat_id, silenced_until)
VALUES (auth.uid(), p_chat_id, p_until) ON CONFLICT (uid, chat_id) DO
UPDATE
SET silenced_until = p_until,
    updated_at = NOW();
END;
$$ LANGUAGE plpgsql;
-- Reload schema for PostgREST
NOTIFY pgrst,
'reload schema';



