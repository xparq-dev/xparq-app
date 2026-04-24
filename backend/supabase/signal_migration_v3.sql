-- Phase 3: Post-Quantum Security (Kyber/ML-KEM) Key Storage
-- 1. Kyber Identity Keys
-- These keys are long-lived and used to authenticate the PQ handshake.
CREATE TABLE IF NOT EXISTS public.signal_pq_identity_keys (
    uid UUID PRIMARY KEY REFERENCES auth.users(id),
    public_key TEXT NOT NULL,
    -- Base64 encoded Kyber768 PublicKey (typically ~1184 bytes)
    created_at TIMESTAMPTZ DEFAULT NOW()
);
-- 2. Kyber One-Time PreKeys
-- These keys are consumed during the handshake to provide PQ forward secrecy.
CREATE TABLE IF NOT EXISTS public.signal_pq_ot_prekeys (
    uid UUID REFERENCES auth.users(id),
    key_id INT,
    public_key TEXT NOT NULL,
    -- Base64 encoded Kyber768 PublicKey
    used_at TIMESTAMPTZ,
    PRIMARY KEY (uid, key_id)
);
CREATE INDEX IF NOT EXISTS idx_pq_ot_prekeys_uid_unused ON public.signal_pq_ot_prekeys (uid)
WHERE used_at IS NULL;
-- Enable RLS
ALTER TABLE public.signal_pq_identity_keys ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.signal_pq_ot_prekeys ENABLE ROW LEVEL SECURITY;
-- Security Policies:
-- 1. Anyone can read PQ public keys
CREATE POLICY "Public PQ identity keys are readable by everyone" ON public.signal_pq_identity_keys FOR
SELECT USING (true);
CREATE POLICY "Public PQ OPKs are readable by everyone" ON public.signal_pq_ot_prekeys FOR
SELECT USING (true);
-- 2. Only the owner can manage their own PQ keys
CREATE POLICY "Users can manage their own PQ identity keys" ON public.signal_pq_identity_keys FOR ALL USING (auth.uid() = uid);
CREATE POLICY "Users can manage their own PQ OPKs" ON public.signal_pq_ot_prekeys FOR ALL USING (auth.uid() = uid);



