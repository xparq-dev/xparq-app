import { createClient } from 'redis';
import { createAdapter } from '@socket.io/redis-adapter';

/**
 * Configures the Socket.IO server for horizontal scaling using Redis.
 * @param {Server} io - The Socket.IO server instance
 */
export async function setupScaling(io) {
  const redisUrl = process.env.REDIS_URL;
  if (!redisUrl) {
    console.warn('[SCALING] REDIS_URL not set, running in standalone mode');
    return;
  }

  try {
    const pubClient = createClient({ url: redisUrl });
    const subClient = pubClient.duplicate();

    await Promise.all([pubClient.connect(), subClient.connect()]);

    io.adapter(createAdapter(pubClient, subClient));
    console.log('[SCALING] Redis adapter connected and active');
  } catch (error) {
    console.error('[SCALING] Failed to connect to Redis:', error);
  }
}
