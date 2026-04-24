-- supabase/signal_migration_v7.sql
-- Phase 8: Message Deletion (Delete for Me)
ALTER TABLE public.messages
ADD COLUMN IF NOT EXISTS deleted_uids UUID [] DEFAULT '{}'::UUID [];
-- Create function to delete for me
CREATE OR REPLACE FUNCTION delete_message_for_me(p_message_id BIGINT) RETURNS VOID AS $$ BEGIN
UPDATE public.messages
SET deleted_uids = array_append(deleted_uids, auth.uid())
WHERE id = p_message_id
    AND NOT (auth.uid() = ANY(deleted_uids));
END;
$$ LANGUAGE plpgsql;
-- Reload schema for PostgREST
NOTIFY pgrst,
'reload schema';



