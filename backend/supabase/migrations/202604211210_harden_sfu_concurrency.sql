-- ============================================================
-- Mediasoup SFU concurrency and multi-instance hardening
-- ============================================================

DO $$
BEGIN
  IF to_regclass('public.sfu_call_rooms') IS NULL
    OR to_regclass('public.sfu_peers') IS NULL
    OR to_regclass('public.sfu_transports') IS NULL THEN
    RAISE EXCEPTION
      'Base SFU schema is missing. Apply 20260421_create_sfu_session_state.sql before 20260421_harden_sfu_concurrency.sql.';
  END IF;
END;
$$;

ALTER TABLE public.sfu_call_rooms
  ADD COLUMN IF NOT EXISTS owner_instance_id TEXT NULL,
  ADD COLUMN IF NOT EXISTS owner_lease_expires_at TIMESTAMPTZ NULL,
  ADD COLUMN IF NOT EXISTS revision BIGINT NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW();

ALTER TABLE public.sfu_peers
  ADD COLUMN IF NOT EXISTS join_request_id TEXT NULL,
  ADD COLUMN IF NOT EXISTS instance_id TEXT NULL,
  ADD COLUMN IF NOT EXISTS revision BIGINT NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW();

ALTER TABLE public.sfu_transports
  ADD COLUMN IF NOT EXISTS request_id TEXT NULL,
  ADD COLUMN IF NOT EXISTS instance_id TEXT NULL,
  ADD COLUMN IF NOT EXISTS revision BIGINT NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW();

CREATE TABLE IF NOT EXISTS public.sfu_producers (
  producer_id TEXT PRIMARY KEY,
  call_id TEXT NOT NULL REFERENCES public.sfu_call_rooms(call_id) ON DELETE CASCADE,
  room_id TEXT NOT NULL REFERENCES public.sfu_call_rooms(room_id) ON DELETE CASCADE,
  peer_id TEXT NOT NULL REFERENCES public.sfu_peers(peer_id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  transport_id TEXT NOT NULL REFERENCES public.sfu_transports(transport_id) ON DELETE CASCADE,
  kind TEXT NOT NULL CHECK (kind IN ('audio')),
  status TEXT NOT NULL DEFAULT 'active'
    CHECK (status IN ('active', 'closed', 'failed')),
  request_id TEXT NULL,
  instance_id TEXT NULL,
  failure_reason TEXT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  closed_at TIMESTAMPTZ NULL,
  revision BIGINT NOT NULL DEFAULT 0,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE UNIQUE INDEX IF NOT EXISTS sfu_active_transport_per_peer_direction_idx
  ON public.sfu_transports(peer_id, direction)
  WHERE status IN ('created', 'connected');

CREATE INDEX IF NOT EXISTS sfu_transports_request_idx
  ON public.sfu_transports(peer_id, direction, request_id)
  WHERE request_id IS NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS sfu_active_audio_producer_per_peer_idx
  ON public.sfu_producers(peer_id, kind)
  WHERE status = 'active';

CREATE INDEX IF NOT EXISTS sfu_producers_transport_idx
  ON public.sfu_producers(transport_id);

CREATE INDEX IF NOT EXISTS sfu_producers_request_idx
  ON public.sfu_producers(peer_id, kind, request_id)
  WHERE request_id IS NOT NULL;

ALTER TABLE public.sfu_producers ENABLE ROW LEVEL SECURITY;

-- =========================
-- RLS for sfu_producers (SAFE)
-- =========================

ALTER TABLE public.sfu_producers ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Service role manages sfu_producers" ON public.sfu_producers;

CREATE POLICY "Service role manages sfu_producers"
  ON public.sfu_producers
  FOR ALL
  USING (auth.role() = 'service_role')
  WITH CHECK (auth.role() = 'service_role');

CREATE OR REPLACE FUNCTION public.sfu_apply_row_version()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at = NOW();

  IF TG_OP = 'UPDATE' THEN
    NEW.revision = COALESCE(OLD.revision, 0) + 1;
  ELSE
    NEW.revision = COALESCE(NEW.revision, 0);
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS sfu_call_rooms_row_version_trg ON public.sfu_call_rooms;
CREATE TRIGGER sfu_call_rooms_row_version_trg
BEFORE INSERT OR UPDATE ON public.sfu_call_rooms
FOR EACH ROW
EXECUTE FUNCTION public.sfu_apply_row_version();

DROP TRIGGER IF EXISTS sfu_peers_row_version_trg ON public.sfu_peers;
CREATE TRIGGER sfu_peers_row_version_trg
BEFORE INSERT OR UPDATE ON public.sfu_peers
FOR EACH ROW
EXECUTE FUNCTION public.sfu_apply_row_version();

DROP TRIGGER IF EXISTS sfu_transports_row_version_trg ON public.sfu_transports;
CREATE TRIGGER sfu_transports_row_version_trg
BEFORE INSERT OR UPDATE ON public.sfu_transports
FOR EACH ROW
EXECUTE FUNCTION public.sfu_apply_row_version();

DROP TRIGGER IF EXISTS sfu_producers_row_version_trg ON public.sfu_producers;
CREATE TRIGGER sfu_producers_row_version_trg
BEFORE INSERT OR UPDATE ON public.sfu_producers
FOR EACH ROW
EXECUTE FUNCTION public.sfu_apply_row_version();

CREATE OR REPLACE FUNCTION public.sfu_claim_room_lease(
  p_call_id TEXT,
  p_room_id TEXT,
  p_worker_id TEXT,
  p_instance_id TEXT,
  p_lease_seconds INTEGER
)
RETURNS TABLE (
  call_id TEXT,
  room_id TEXT,
  worker_id TEXT,
  owner_instance_id TEXT,
  owner_lease_expires_at TIMESTAMPTZ,
  status TEXT,
  revision BIGINT,
  ownership_status TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_now TIMESTAMPTZ := NOW();
  v_lease_expires TIMESTAMPTZ :=
    NOW() + (GREATEST(COALESCE(p_lease_seconds, 1), 1) * INTERVAL '1 second');
BEGIN
  RETURN QUERY
  WITH claimed AS (
    INSERT INTO public.sfu_call_rooms (
      call_id,
      room_id,
      worker_id,
      owner_instance_id,
      owner_lease_expires_at,
      status,
      failure_reason,
      last_seen_at
    )
    VALUES (
      p_call_id,
      p_room_id,
      p_worker_id,
      p_instance_id,
      v_lease_expires,
      'active',
      NULL,
      v_now
    )
    ON CONFLICT (call_id) DO UPDATE
    SET
      room_id = EXCLUDED.room_id,
      worker_id = COALESCE(EXCLUDED.worker_id, public.sfu_call_rooms.worker_id),
      owner_instance_id = EXCLUDED.owner_instance_id,
      owner_lease_expires_at = EXCLUDED.owner_lease_expires_at,
      status = 'active',
      failure_reason = NULL,
      last_seen_at = v_now
    WHERE public.sfu_call_rooms.room_id = EXCLUDED.room_id
      AND (
        public.sfu_call_rooms.owner_instance_id IS NULL
        OR public.sfu_call_rooms.owner_instance_id = EXCLUDED.owner_instance_id
        OR public.sfu_call_rooms.owner_lease_expires_at <= v_now
        OR public.sfu_call_rooms.status IN ('ended', 'failed')
      )
    RETURNING
      public.sfu_call_rooms.call_id,
      public.sfu_call_rooms.room_id,
      public.sfu_call_rooms.worker_id,
      public.sfu_call_rooms.owner_instance_id,
      public.sfu_call_rooms.owner_lease_expires_at,
      public.sfu_call_rooms.status,
      public.sfu_call_rooms.revision,
      'owned'::TEXT AS ownership_status
  )
  SELECT * FROM claimed
  UNION ALL
  SELECT
    existing.call_id,
    existing.room_id,
    existing.worker_id,
    existing.owner_instance_id,
    existing.owner_lease_expires_at,
    existing.status,
    existing.revision,
    CASE
      WHEN existing.owner_instance_id = p_instance_id THEN 'owned'
      ELSE 'foreign_owner'
    END AS ownership_status
  FROM public.sfu_call_rooms AS existing
  WHERE existing.call_id = p_call_id
    AND NOT EXISTS (SELECT 1 FROM claimed)
  LIMIT 1;
END;
$$;

CREATE OR REPLACE FUNCTION public.sfu_register_peer(
  p_call_id TEXT,
  p_room_id TEXT,
  p_peer_id TEXT,
  p_user_id UUID,
  p_instance_id TEXT,
  p_join_request_id TEXT,
  p_metadata JSONB
)
RETURNS public.sfu_peers
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_result public.sfu_peers;
  v_duplicate public.sfu_peers;
BEGIN
  PERFORM 1
  FROM public.sfu_call_rooms
  WHERE call_id = p_call_id
    AND room_id = p_room_id
    AND owner_instance_id = p_instance_id
    AND owner_lease_expires_at > NOW()
    AND status = 'active';

  IF NOT FOUND THEN
    RAISE EXCEPTION 'room_not_owned'
      USING ERRCODE = 'P0001';
  END IF;

  SELECT *
  INTO v_duplicate
  FROM public.sfu_peers
  WHERE room_id = p_room_id
    AND user_id = p_user_id
    AND peer_id <> p_peer_id
    AND left_at IS NULL
    AND status = 'joined'
  LIMIT 1;

  IF FOUND THEN
    RAISE EXCEPTION 'duplicate_active_user_peer'
      USING ERRCODE = '23505';
  END IF;

  INSERT INTO public.sfu_peers (
    peer_id,
    call_id,
    room_id,
    user_id,
    status,
    failure_reason,
    metadata,
    joined_at,
    last_seen_at,
    left_at,
    join_request_id,
    instance_id
  )
  VALUES (
    p_peer_id,
    p_call_id,
    p_room_id,
    p_user_id,
    'joined',
    NULL,
    COALESCE(p_metadata, '{}'::jsonb),
    NOW(),
    NOW(),
    NULL,
    p_join_request_id,
    p_instance_id
  )
  ON CONFLICT (peer_id) DO UPDATE
  SET
    call_id = EXCLUDED.call_id,
    room_id = EXCLUDED.room_id,
    status = 'joined',
    failure_reason = NULL,
    metadata = EXCLUDED.metadata,
    last_seen_at = NOW(),
    left_at = NULL,
    join_request_id = EXCLUDED.join_request_id,
    instance_id = EXCLUDED.instance_id
  WHERE public.sfu_peers.user_id = EXCLUDED.user_id
    AND public.sfu_peers.room_id = EXCLUDED.room_id
  RETURNING * INTO v_result;

  RETURN v_result;
EXCEPTION
  WHEN unique_violation THEN
    RAISE EXCEPTION 'duplicate_active_user_peer'
      USING ERRCODE = '23505';
END;
$$;

CREATE OR REPLACE FUNCTION public.sfu_register_transport(
  p_transport_id TEXT,
  p_call_id TEXT,
  p_room_id TEXT,
  p_peer_id TEXT,
  p_user_id UUID,
  p_direction TEXT,
  p_instance_id TEXT,
  p_request_id TEXT,
  p_idle_timeout_ms INTEGER
)
RETURNS public.sfu_transports
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_result public.sfu_transports;
  v_existing public.sfu_transports;
BEGIN
  PERFORM 1
  FROM public.sfu_call_rooms
  WHERE call_id = p_call_id
    AND room_id = p_room_id
    AND owner_instance_id = p_instance_id
    AND owner_lease_expires_at > NOW()
    AND status = 'active';

  IF NOT FOUND THEN
    RAISE EXCEPTION 'room_not_owned'
      USING ERRCODE = 'P0001';
  END IF;

  SELECT *
  INTO v_existing
  FROM public.sfu_transports
  WHERE peer_id = p_peer_id
    AND direction = p_direction
    AND status IN ('created', 'connected')
  ORDER BY created_at DESC
  LIMIT 1;

  IF FOUND THEN
    IF p_request_id IS NOT NULL AND v_existing.request_id = p_request_id THEN
      RETURN v_existing;
    END IF;

    RAISE EXCEPTION 'duplicate_active_transport'
      USING ERRCODE = '23505';
  END IF;

  INSERT INTO public.sfu_transports (
    transport_id,
    call_id,
    room_id,
    peer_id,
    user_id,
    direction,
    status,
    idle_timeout_ms,
    failure_reason,
    created_at,
    connected_at,
    last_heartbeat_at,
    closed_at,
    request_id,
    instance_id
  )
  VALUES (
    p_transport_id,
    p_call_id,
    p_room_id,
    p_peer_id,
    p_user_id,
    p_direction,
    'created',
    p_idle_timeout_ms,
    NULL,
    NOW(),
    NULL,
    NOW(),
    NULL,
    p_request_id,
    p_instance_id
  )
  ON CONFLICT (transport_id) DO UPDATE
  SET
    last_heartbeat_at = NOW(),
    failure_reason = NULL
  RETURNING * INTO v_result;

  RETURN v_result;
EXCEPTION
  WHEN unique_violation THEN
    SELECT *
    INTO v_existing
    FROM public.sfu_transports
    WHERE peer_id = p_peer_id
      AND direction = p_direction
      AND status IN ('created', 'connected')
    ORDER BY created_at DESC
    LIMIT 1;

    IF FOUND AND p_request_id IS NOT NULL AND v_existing.request_id = p_request_id THEN
      RETURN v_existing;
    END IF;

    RAISE EXCEPTION 'duplicate_active_transport'
      USING ERRCODE = '23505';
END;
$$;

CREATE OR REPLACE FUNCTION public.sfu_register_producer(
  p_producer_id TEXT,
  p_call_id TEXT,
  p_room_id TEXT,
  p_peer_id TEXT,
  p_user_id UUID,
  p_transport_id TEXT,
  p_kind TEXT,
  p_instance_id TEXT,
  p_request_id TEXT
)
RETURNS public.sfu_producers
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_result public.sfu_producers;
  v_existing public.sfu_producers;
BEGIN
  PERFORM 1
  FROM public.sfu_call_rooms
  WHERE call_id = p_call_id
    AND room_id = p_room_id
    AND owner_instance_id = p_instance_id
    AND owner_lease_expires_at > NOW()
    AND status = 'active';

  IF NOT FOUND THEN
    RAISE EXCEPTION 'room_not_owned'
      USING ERRCODE = 'P0001';
  END IF;

  SELECT *
  INTO v_existing
  FROM public.sfu_producers
  WHERE peer_id = p_peer_id
    AND kind = p_kind
    AND status = 'active'
  ORDER BY created_at DESC
  LIMIT 1;

  IF FOUND THEN
    IF p_request_id IS NOT NULL AND v_existing.request_id = p_request_id THEN
      RETURN v_existing;
    END IF;

    RAISE EXCEPTION 'duplicate_active_producer'
      USING ERRCODE = '23505';
  END IF;

  INSERT INTO public.sfu_producers (
    producer_id,
    call_id,
    room_id,
    peer_id,
    user_id,
    transport_id,
    kind,
    status,
    request_id,
    instance_id,
    failure_reason
  )
  VALUES (
    p_producer_id,
    p_call_id,
    p_room_id,
    p_peer_id,
    p_user_id,
    p_transport_id,
    p_kind,
    'active',
    p_request_id,
    p_instance_id,
    NULL
  )
  ON CONFLICT (producer_id) DO UPDATE
  SET
    failure_reason = NULL
  RETURNING * INTO v_result;

  RETURN v_result;
EXCEPTION
  WHEN unique_violation THEN
    SELECT *
    INTO v_existing
    FROM public.sfu_producers
    WHERE peer_id = p_peer_id
      AND kind = p_kind
      AND status = 'active'
    ORDER BY created_at DESC
    LIMIT 1;

    IF FOUND AND p_request_id IS NOT NULL AND v_existing.request_id = p_request_id THEN
      RETURN v_existing;
    END IF;

    RAISE EXCEPTION 'duplicate_active_producer'
      USING ERRCODE = '23505';
END;
$$;
