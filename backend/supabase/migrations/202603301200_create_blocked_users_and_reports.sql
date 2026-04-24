-- Create block/report moderation tables used by the app.
--
-- This migration is designed to support:
-- - lib/features/block_report/repositories/block_repository.dart
-- - lib/features/block_report/repositories/report_repository.dart
-- - lib/features/block_report/repositories/block_report_repository.dart
--
-- Tables:
-- - public.blocked_users
-- - public.reports

CREATE TABLE IF NOT EXISTS public.blocked_users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  blocker_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  blocked_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  source TEXT NOT NULL DEFAULT 'online',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT blocked_users_unique_pair UNIQUE (blocker_id, blocked_id),
  CONSTRAINT blocked_users_no_self_block CHECK (blocker_id <> blocked_id)
);

CREATE INDEX IF NOT EXISTS idx_blocked_users_blocker_id
  ON public.blocked_users (blocker_id);

CREATE INDEX IF NOT EXISTS idx_blocked_users_blocked_id
  ON public.blocked_users (blocked_id);

CREATE INDEX IF NOT EXISTS idx_blocked_users_created_at
  ON public.blocked_users (created_at DESC);

ALTER TABLE public.blocked_users ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'blocked_users'
      AND policyname = 'Users can view their own blocks'
  ) THEN
    CREATE POLICY "Users can view their own blocks"
      ON public.blocked_users
      FOR SELECT
      USING (auth.uid() = blocker_id);
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'blocked_users'
      AND policyname = 'Users can create their own blocks'
  ) THEN
    CREATE POLICY "Users can create their own blocks"
      ON public.blocked_users
      FOR INSERT
      WITH CHECK (auth.uid() = blocker_id);
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'blocked_users'
      AND policyname = 'Users can delete their own blocks'
  ) THEN
    CREATE POLICY "Users can delete their own blocks"
      ON public.blocked_users
      FOR DELETE
      USING (auth.uid() = blocker_id);
  END IF;
END $$;

REVOKE ALL ON TABLE public.blocked_users FROM anon;
GRANT SELECT, INSERT, DELETE ON TABLE public.blocked_users TO authenticated;

CREATE TABLE IF NOT EXISTS public.reports (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  reporter_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  reported_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  chat_id TEXT REFERENCES public.chats(id) ON DELETE SET NULL,
  reason TEXT NOT NULL,
  detail TEXT,
  status TEXT NOT NULL DEFAULT 'pending',
  context TEXT NOT NULL DEFAULT 'chat',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  reviewed_at TIMESTAMPTZ,
  CONSTRAINT reports_no_self_report CHECK (reporter_id <> reported_id),
  CONSTRAINT reports_reason_not_empty CHECK (char_length(trim(reason)) > 0)
);

CREATE INDEX IF NOT EXISTS idx_reports_reporter_id
  ON public.reports (reporter_id);

CREATE INDEX IF NOT EXISTS idx_reports_reported_id
  ON public.reports (reported_id);

CREATE INDEX IF NOT EXISTS idx_reports_status
  ON public.reports (status);

CREATE INDEX IF NOT EXISTS idx_reports_created_at
  ON public.reports (created_at DESC);

ALTER TABLE public.reports ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'reports'
      AND policyname = 'Users can create their own reports'
  ) THEN
    CREATE POLICY "Users can create their own reports"
      ON public.reports
      FOR INSERT
      WITH CHECK (auth.uid() = reporter_id);
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'reports'
      AND policyname = 'Users can view their own reports'
  ) THEN
    CREATE POLICY "Users can view their own reports"
      ON public.reports
      FOR SELECT
      USING (auth.uid() = reporter_id);
  END IF;
END $$;

REVOKE ALL ON TABLE public.reports FROM anon;
GRANT SELECT, INSERT ON TABLE public.reports TO authenticated;

NOTIFY pgrst, 'reload schema';
