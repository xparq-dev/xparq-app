-- ============================================================
-- Mediasoup SFU session state
-- SAFE / IDEMPOTENT VERSION
-- ============================================================

-- =========================
-- 1. Tables
-- =========================

CREATE TABLE IF NOT EXISTS public.sfu_call_rooms (
  call_id TEXT PRIMARY KEY,
  room_id TEXT NOT NULL UNIQUE,
  worker_id TEXT NULL,
  status TEXT NOT NULL DEFAULT 'active'
    CHECK (status IN ('active', 'ended', 'failed')),
  failure_reason TEXT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  last_seen_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  ended_at TIMESTAMPTZ NULL
);

CREATE TABLE IF NOT EXISTS public.sfu_peers (
  peer_id TEXT PRIMARY KEY,
  call_id TEXT NOT NULL REFERENCES public.sfu_call_rooms(call_id) ON DELETE CASCADE,
  room_id TEXT NOT NULL,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  status TEXT NOT NULL DEFAULT 'joined'
    CHECK (status IN ('joined', 'left', 'failed')),
  failure_reason TEXT NULL,
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  joined_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  last_seen_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  left_at TIMESTAMPTZ NULL,
  CONSTRAINT sfu_peers_room_fk
    FOREIGN KEY (room_id) REFERENCES public.sfu_call_rooms(room_id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS public.sfu_transports (
  transport_id TEXT PRIMARY KEY,
  call_id TEXT NOT NULL REFERENCES public.sfu_call_rooms(call_id) ON DELETE CASCADE,
  room_id TEXT NOT NULL,
  peer_id TEXT NOT NULL REFERENCES public.sfu_peers(peer_id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  direction TEXT NOT NULL CHECK (direction IN ('send', 'recv')),
  status TEXT NOT NULL DEFAULT 'created'
    CHECK (status IN ('created', 'connected', 'closed', 'failed')),
  idle_timeout_ms INTEGER NOT NULL DEFAULT 45000,
  failure_reason TEXT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  connected_at TIMESTAMPTZ NULL,
  last_heartbeat_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  closed_at TIMESTAMPTZ NULL,
  CONSTRAINT sfu_transports_room_fk
    FOREIGN KEY (room_id) REFERENCES public.sfu_call_rooms(room_id) ON DELETE CASCADE
);

-- =========================
-- 2. Indexes
-- =========================

CREATE UNIQUE INDEX IF NOT EXISTS sfu_active_user_per_room_idx
  ON public.sfu_peers(room_id, user_id)
  WHERE left_at IS NULL AND status = 'joined';

CREATE INDEX IF NOT EXISTS sfu_peers_call_id_idx
  ON public.sfu_peers(call_id);

CREATE INDEX IF NOT EXISTS sfu_peers_user_id_idx
  ON public.sfu_peers(user_id);

CREATE INDEX IF NOT EXISTS sfu_transports_peer_id_idx
  ON public.sfu_transports(peer_id);

CREATE INDEX IF NOT EXISTS sfu_transports_room_id_idx
  ON public.sfu_transports(room_id);

CREATE INDEX IF NOT EXISTS sfu_transports_heartbeat_idx
  ON public.sfu_transports(last_heartbeat_at);

-- =========================
-- 3. View
-- =========================

CREATE OR REPLACE VIEW public.sfu_active_peers AS
SELECT *
FROM public.sfu_peers
WHERE left_at IS NULL AND status = 'joined';

-- =========================
-- 4. RLS
-- =========================

ALTER TABLE public.sfu_call_rooms ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sfu_peers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sfu_transports ENABLE ROW LEVEL SECURITY;

-- =========================
-- 5. Policies (SAFE)
-- =========================

DROP POLICY IF EXISTS "Service role manages sfu_call_rooms" ON public.sfu_call_rooms;
CREATE POLICY "Service role manages sfu_call_rooms"
  ON public.sfu_call_rooms
  FOR ALL
  USING (auth.role() = 'service_role')
  WITH CHECK (auth.role() = 'service_role');

DROP POLICY IF EXISTS "Service role manages sfu_peers" ON public.sfu_peers;
CREATE POLICY "Service role manages sfu_peers"
  ON public.sfu_peers
  FOR ALL
  USING (auth.role() = 'service_role')
  WITH CHECK (auth.role() = 'service_role');

DROP POLICY IF EXISTS "Service role manages sfu_transports" ON public.sfu_transports;
CREATE POLICY "Service role manages sfu_transports"
  ON public.sfu_transports
  FOR ALL
  USING (auth.role() = 'service_role')
  WITH CHECK (auth.role() = 'service_role');