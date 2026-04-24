-- supabase/fix_rls_update.sql
-- Add missing RLS UPDATE policies for messages and chats
-- 1. Messages: Allow participants to update messages (mostly for 'read' and 'delivered' status)
DO $$ BEGIN IF NOT EXISTS (
    SELECT 1
    FROM pg_policies
    WHERE tablename = 'messages'
        AND policyname = 'Users can update messages in their chats'
) THEN CREATE POLICY "Users can update messages in their chats" ON public.messages FOR
UPDATE USING (
        EXISTS (
            SELECT 1
            FROM public.chats
            WHERE id = messages.chat_id
                AND auth.uid() = ANY(participants)
        )
    );
END IF;
END $$;
-- 2. Chats: Allow participants to update chat metadata (last_message, last_at, etc.)
DO $$ BEGIN IF NOT EXISTS (
    SELECT 1
    FROM pg_policies
    WHERE tablename = 'chats'
        AND policyname = 'Users can update their chats'
) THEN CREATE POLICY "Users can update their chats" ON public.chats FOR
UPDATE USING (auth.uid() = ANY(participants));
END IF;
END $$;
-- 3. Reload Schema for PostgREST
NOTIFY pgrst,
'reload schema';



