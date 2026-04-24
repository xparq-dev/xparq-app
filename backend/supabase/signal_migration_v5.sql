-- supabase/signal_migration_v5.sql
-- Phase 5: Multi-Device Sync & Phase 6: Privacy Features
-- 1. Create devices table to track user devices and their Signal Identity Keys
CREATE TABLE IF NOT EXISTS public.devices (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    uid UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    device_id TEXT NOT NULL,
    -- Unique identifier for the device (e.g., UUID or fingerprint)
    device_name TEXT,
    -- Friendly name (e.g., "iPhone 15", "Chrome on Windows")
    identity_key TEXT NOT NULL,
    -- Public Signal Identity Key for this specific device
    push_token TEXT,
    -- For notifications to this specific device
    created_at TIMESTAMPTZ DEFAULT now(),
    last_active_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE(uid, device_id)
);
-- Enable RLS for devices
ALTER TABLE public.devices ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can view their own devices" ON public.devices FOR
SELECT USING (auth.uid() = uid);
CREATE POLICY "Users can manage their own devices" ON public.devices FOR ALL USING (auth.uid() = uid);
CREATE POLICY "Anyone can view identity keys of others for encryption" ON public.devices FOR
SELECT USING (true);
-- 2. Update messages table for Vanishing Messages (Phase 6)
ALTER TABLE public.messages
ADD COLUMN IF NOT EXISTS expires_at TIMESTAMPTZ;
-- 3. Update profiles table to include a 'primary_device_id' if needed
ALTER TABLE public.profiles
ADD COLUMN IF NOT EXISTS primary_device_id TEXT;
-- 4. Indexing for performance
CREATE INDEX IF NOT EXISTS idx_devices_uid ON public.devices(uid);
CREATE INDEX IF NOT EXISTS idx_messages_expires_at ON public.messages(expires_at);
COMMENT ON TABLE public.devices IS 'Stores public keys and metadata for all user devices to support Multi-Device Signal Sync.';



