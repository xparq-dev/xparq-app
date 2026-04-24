-- supabase/fix_realtime_messaging_rls.sql
-- Restoration of Real-time Messaging and RLS Security

-- 1. Ensure RLS is enabled on critical tables
ALTER TABLE public.chats ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;

-- 2. CHATS: Policies to allow participants to view their conversations
DO $$ BEGIN IF NOT EXISTS (
    SELECT 1
    FROM pg_policies
    WHERE tablename = 'chats'
        AND policyname = 'Users can view their own chats'
) THEN CREATE POLICY "Users can view their own chats" ON public.chats FOR
SELECT USING (
        auth.uid()::text = ANY(participants::text[])
    );
END IF;
END $$;

-- 3. MESSAGES: Policy to allow participants to read messages in their chats
DO $$ BEGIN IF NOT EXISTS (
    SELECT 1
    FROM pg_policies
    WHERE tablename = 'messages'
        AND policyname = 'Users can read messages in their chats'
) THEN CREATE POLICY "Users can read messages in their chats" ON public.messages FOR
SELECT USING (
        EXISTS (
            SELECT 1
            FROM public.chats
            WHERE chats.id = messages.chat_id
                AND auth.uid()::text = ANY(chats.participants::text[])
        )
    );
END IF;
END $$;

-- 4. MESSAGES: Policy to allow users to send messages to chats they belong to
DO $$ BEGIN IF NOT EXISTS (
    SELECT 1
    FROM pg_policies
    WHERE tablename = 'messages'
        AND policyname = 'Users can send messages to their chats'
) THEN CREATE POLICY "Users can send messages to their chats" ON public.messages FOR
INSERT WITH CHECK (
        auth.uid() = sender_id
        AND EXISTS (
            SELECT 1
            FROM public.chats
            WHERE chats.id = messages.chat_id
                AND auth.uid()::text = ANY(chats.participants::text[])
        )
    );
END IF;
END $$;

-- 5. UPDATE Policies (Success metrics: read/delivered receipts)
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
            WHERE chats.id = messages.chat_id
                AND auth.uid()::text = ANY(chats.participants::text[])
        )
    );
END IF;
END $$;

DO $$ BEGIN IF NOT EXISTS (
    SELECT 1
    FROM pg_policies
    WHERE tablename = 'chats'
        AND policyname = 'Users can update their chats'
) THEN CREATE POLICY "Users can update their chats" ON public.chats FOR
UPDATE USING (
        auth.uid()::text = ANY(participants::text[])
    );
END IF;
END $$;

-- 6. Realtime Publication Setup
-- Ensure common publications exist and include these tables
DO $$ BEGIN IF NOT EXISTS (
    SELECT 1
    FROM pg_publication
    WHERE pubname = 'supabase_realtime'
) THEN CREATE PUBLICATION supabase_realtime;
END IF;
END $$;

-- Safely add tables to publication
-- Use a function to avoid errors if already present
CREATE OR REPLACE FUNCTION add_to_realtime(tbl_name text) RETURNS void AS $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables 
        WHERE pubname = 'supabase_realtime' AND tablename = tbl_name
    ) THEN
        EXECUTE 'ALTER PUBLICATION supabase_realtime ADD TABLE ' || tbl_name;
    END IF;
END;
$$ LANGUAGE plpgsql;

SELECT add_to_realtime('chats');
SELECT add_to_realtime('messages');
DROP FUNCTION add_to_realtime(text);

-- 6. Reset cache and reload
NOTIFY pgrst, 'reload schema';




