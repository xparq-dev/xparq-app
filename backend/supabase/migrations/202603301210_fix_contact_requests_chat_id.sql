-- Align contact request storage with the app's chat-driven flow.
--
-- This migration:
-- - adds public.contact_requests.chat_id
-- - backfills chat_id for existing 1:1 requests when the deterministic chat exists
-- - hardens grants so anon cannot read contact requests
-- - adds authenticated RLS policies for requester/target flows
--
-- Production note:
-- `requester_uid` and `target_uid` are legacy TEXT columns in the live table,
-- so policies compare against auth.uid()::text instead of raw UUIDs.

ALTER TABLE public.contact_requests
  ADD COLUMN IF NOT EXISTS chat_id TEXT;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'contact_requests_chat_id_fkey'
      AND conrelid = 'public.contact_requests'::regclass
  ) THEN
    ALTER TABLE public.contact_requests
      ADD CONSTRAINT contact_requests_chat_id_fkey
      FOREIGN KEY (chat_id)
      REFERENCES public.chats(id)
      ON DELETE SET NULL;
  END IF;
END $$;

UPDATE public.contact_requests AS cr
SET chat_id = candidate.chat_id
FROM (
  SELECT
    id,
    CASE
      WHEN requester_uid::text < target_uid::text
        THEN requester_uid::text || '_' || target_uid::text
      ELSE target_uid::text || '_' || requester_uid::text
    END AS chat_id
  FROM public.contact_requests
) AS candidate
WHERE cr.id = candidate.id
  AND cr.chat_id IS NULL
  AND EXISTS (
    SELECT 1
    FROM public.chats AS c
    WHERE c.id = candidate.chat_id
  );

CREATE INDEX IF NOT EXISTS idx_contact_requests_chat_id
  ON public.contact_requests (chat_id);

CREATE INDEX IF NOT EXISTS idx_contact_requests_requester_status
  ON public.contact_requests (requester_uid, status);

CREATE INDEX IF NOT EXISTS idx_contact_requests_target_status
  ON public.contact_requests (target_uid, status);

CREATE INDEX IF NOT EXISTS idx_contact_requests_created_at
  ON public.contact_requests (created_at DESC);

ALTER TABLE public.contact_requests ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'contact_requests'
      AND policyname = 'Users can view related contact requests'
  ) THEN
    CREATE POLICY "Users can view related contact requests"
      ON public.contact_requests
      FOR SELECT
      TO authenticated
      USING (
        auth.uid()::text = requester_uid
        OR auth.uid()::text = target_uid
      );
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'contact_requests'
      AND policyname = 'Users can create their own contact requests'
  ) THEN
    CREATE POLICY "Users can create their own contact requests"
      ON public.contact_requests
      FOR INSERT
      TO authenticated
      WITH CHECK (
        auth.uid()::text = requester_uid
        AND requester_uid <> target_uid
        AND status = 'pending'
        AND responded_at IS NULL
      );
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'contact_requests'
      AND policyname = 'Users can update related contact requests'
  ) THEN
    CREATE POLICY "Users can update related contact requests"
      ON public.contact_requests
      FOR UPDATE
      TO authenticated
      USING (
        auth.uid()::text = requester_uid
        OR auth.uid()::text = target_uid
      )
      WITH CHECK (
        requester_uid <> target_uid
        AND (
          (
            auth.uid()::text = requester_uid
            AND status = 'pending'
            AND responded_at IS NULL
          )
          OR auth.uid()::text = target_uid
        )
      );
  END IF;
END $$;

REVOKE ALL ON TABLE public.contact_requests FROM anon;
GRANT SELECT, INSERT, UPDATE ON TABLE public.contact_requests TO authenticated;

NOTIFY pgrst, 'reload schema';
