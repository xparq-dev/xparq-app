-- supabase/enable_realtime.sql
-- Enable Realtime Replication for missing tables
-- 1. Create the publication if it doesn't exist
DO $$ BEGIN IF NOT EXISTS (
    SELECT 1
    FROM pg_publication
    WHERE pubname = 'supabase_realtime'
) THEN CREATE PUBLICATION supabase_realtime;
END IF;
END $$;
-- 2. Add tables to the publication (only if not already a member)
DO $$
DECLARE t text;
tables_to_add text [] := ARRAY [
        'profiles', 'pulses', 'echoes', 'pulse_interactions', 
        'orbits', 'chats', 'messages', 'chat_settings', 
        'contact_requests', 'status_delays'
    ];
BEGIN FOREACH t IN ARRAY tables_to_add LOOP -- Check if table is already in the publication
IF NOT EXISTS (
    SELECT 1
    FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
        AND schemaname = 'public'
        AND tablename = t
) THEN EXECUTE format(
    'ALTER PUBLICATION supabase_realtime ADD TABLE public.%I',
    t
);
END IF;
END LOOP;
END $$;
-- 3. Reload Schema for PostgREST
NOTIFY pgrst,
'reload schema';



