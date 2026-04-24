// backend/signaling/middleware/auth.js
import { createClient } from '@supabase/supabase-js';

const supabase = createClient(process.env.SUPABASE_URL, process.env.SUPABASE_ANON_KEY);

export async function authMiddleware(socket, next) {
  try {
    const token = socket.handshake.auth?.token;
    if (!token) throw new Error('NO_TOKEN');

    const { data, error } = await supabase.auth.getUser(token);
    if (error || !data?.user) throw new Error('INVALID_TOKEN');

    socket.user = { id: data.user.id, email: data.user.email };
    next();
  } catch (e) {
    next(new Error('UNAUTHORIZED'));
  }
}