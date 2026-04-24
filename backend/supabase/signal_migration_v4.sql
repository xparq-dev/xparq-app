-- Phase 6: Distributed Backup Metadata
-- Adds support for storing IPFS CIDs and backup timestamps.
-- 1. Add columns to public.profiles
ALTER TABLE public.profiles
ADD COLUMN IF NOT EXISTS backup_cid TEXT,
    ADD COLUMN IF NOT EXISTS backup_at TIMESTAMPTZ;
-- 2. Add comment for documentation
COMMENT ON COLUMN public.profiles.backup_cid IS 'The IPFS Content Identifier (CID) for the latest encrypted Signal backup.';
COMMENT ON COLUMN public.profiles.backup_at IS 'The timestamp of the last successful Signal backup.';



