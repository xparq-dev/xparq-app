-- Make account hard-deletes safe across dependent records.
-- This migration removes foreign key blockers and adds a cleanup helper
-- for chat rows that keep participant UUIDs in an array.

ALTER TABLE public.chats
  DROP CONSTRAINT IF EXISTS chats_last_sender_fkey;

ALTER TABLE public.chats
  ADD CONSTRAINT chats_last_sender_fkey
  FOREIGN KEY (last_sender)
  REFERENCES public.profiles(id)
  ON DELETE SET NULL;

ALTER TABLE public.messages
  DROP CONSTRAINT IF EXISTS messages_sender_id_fkey;

ALTER TABLE public.messages
  ADD CONSTRAINT messages_sender_id_fkey
  FOREIGN KEY (sender_id)
  REFERENCES public.profiles(id)
  ON DELETE CASCADE;

DO $$
BEGIN
  IF to_regclass('public.signal_pq_identity_keys') IS NOT NULL THEN
    ALTER TABLE public.signal_pq_identity_keys
      DROP CONSTRAINT IF EXISTS signal_pq_identity_keys_uid_fkey;

    ALTER TABLE public.signal_pq_identity_keys
      ADD CONSTRAINT signal_pq_identity_keys_uid_fkey
      FOREIGN KEY (uid)
      REFERENCES auth.users(id)
      ON DELETE CASCADE;
  END IF;
END $$;

DO $$
BEGIN
  IF to_regclass('public.signal_pq_ot_prekeys') IS NOT NULL THEN
    ALTER TABLE public.signal_pq_ot_prekeys
      DROP CONSTRAINT IF EXISTS signal_pq_ot_prekeys_uid_fkey;

    ALTER TABLE public.signal_pq_ot_prekeys
      ADD CONSTRAINT signal_pq_ot_prekeys_uid_fkey
      FOREIGN KEY (uid)
      REFERENCES auth.users(id)
      ON DELETE CASCADE;
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS profiles_pending_deletion_idx
  ON public.profiles (account_status, deletion_requested_at);

CREATE OR REPLACE FUNCTION public.cleanup_deleted_user_chat_references(p_uid UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE public.chats
  SET
    participants = array_remove(participants, p_uid),
    last_sender = CASE
      WHEN last_sender = p_uid THEN NULL
      ELSE last_sender
    END,
    last_message = CASE
      WHEN last_sender = p_uid THEN NULL
      ELSE last_message
    END,
    last_at = CASE
      WHEN last_sender = p_uid THEN NULL
      ELSE last_at
    END
  WHERE p_uid = ANY(participants) OR last_sender = p_uid;

  DELETE FROM public.chats
  WHERE cardinality(participants) = 0
     OR (COALESCE(is_group, FALSE) = FALSE AND cardinality(participants) < 2);
END;
$$;

REVOKE ALL ON FUNCTION public.cleanup_deleted_user_chat_references(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.cleanup_deleted_user_chat_references(UUID) TO service_role;
