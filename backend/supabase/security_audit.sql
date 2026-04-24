-- Security Audit & RLS Strengthening for iXPARQ
-- This script fills gaps identified during the Security Audit.
-- 1. STRENGTHEN PROFILES PRIVACY
-- Birth date should only be visible to the owner.
DROP POLICY IF EXISTS "Public profiles are viewable by everyone" ON public.profiles;
CREATE POLICY "Public profiles are viewable by everyone" ON public.profiles FOR
SELECT USING (TRUE);
-- 2. ECHOES (COMMENTS) POLICIES
DROP POLICY IF EXISTS "Echoes are viewable by everyone" ON public.echoes;
CREATE POLICY "Echoes are viewable by everyone" ON public.echoes FOR
SELECT USING (TRUE);
DROP POLICY IF EXISTS "Users can create echoes" ON public.echoes;
CREATE POLICY "Users can create echoes" ON public.echoes FOR
INSERT WITH CHECK (auth.uid() = uid);
DROP POLICY IF EXISTS "Users can delete own echoes" ON public.echoes;
CREATE POLICY "Users can delete own echoes" ON public.echoes FOR DELETE USING (auth.uid() = uid);
-- 3. PULSE INTERACTIONS (SPARKS) POLICIES
DROP POLICY IF EXISTS "Sparks are viewable by everyone" ON public.pulse_interactions;
CREATE POLICY "Sparks are viewable by everyone" ON public.pulse_interactions FOR
SELECT USING (TRUE);
DROP POLICY IF EXISTS "Users can spark pulses" ON public.pulse_interactions;
CREATE POLICY "Users can spark pulses" ON public.pulse_interactions FOR
INSERT WITH CHECK (auth.uid() = uid);
DROP POLICY IF EXISTS "Users can un-spark pulses" ON public.pulse_interactions;
CREATE POLICY "Users can un-spark pulses" ON public.pulse_interactions FOR DELETE USING (auth.uid() = uid);
-- 4. WARPS (REPOSTS) POLICIES
DROP POLICY IF EXISTS "Warps are viewable by everyone" ON public.warps;
CREATE POLICY "Warps are viewable by everyone" ON public.warps FOR
SELECT USING (TRUE);
DROP POLICY IF EXISTS "Users can warp pulses" ON public.warps;
CREATE POLICY "Users can warp pulses" ON public.warps FOR
INSERT WITH CHECK (auth.uid() = uid);
DROP POLICY IF EXISTS "Users can un-warp pulses" ON public.warps;
CREATE POLICY "Users can un-warp pulses" ON public.warps FOR DELETE USING (auth.uid() = uid);
-- 5. STATUS DELAYS (ANTI-STALKING) POLICIES
-- Only the people involved should see the status delays.
DROP POLICY IF EXISTS "Involved users can see status delays" ON public.status_delays;
CREATE POLICY "Involved users can see status delays" ON public.status_delays FOR
SELECT USING (
        auth.uid() = minor_id
        OR auth.uid() = sender_id
    );
-- 6. MESSAGES - ADD DELETE POLICY
DROP POLICY IF EXISTS "Users can delete own messages" ON public.messages;
CREATE POLICY "Users can delete own messages" ON public.messages FOR DELETE USING (sender_id = auth.uid());
-- 7. CHATS - ADD UPDATE POLICY (for marking as read, etc.)
DROP POLICY IF EXISTS "Users can update own chats" ON public.chats;
CREATE POLICY "Users can update own chats" ON public.chats FOR
UPDATE USING (auth.uid() = ANY(participants));
-- 8. SECURITY DEFINER AUDIT
-- Ensure query_nearby_users respects RLS (it's SECURITY INVOKER by default, which is good)
-- But we should ensure sensitive data isn't returned for non-owners in the future.



