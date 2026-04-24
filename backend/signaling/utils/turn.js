import crypto from 'crypto';

/**
 * Generates temporary TURN credentials for coturn REST API auth.
 * @param {string} userId - The unique user ID
 * @param {number} ttlSeconds - Time to live in seconds (default 60s)
 * @returns {Object} { username, credential }
 */
export function generateTurnCredentials(userId, ttlSeconds = 60) {
  const secret = process.env.TURN_AUTH_SECRET;
  if (!secret) {
    console.warn('[TURN] TURN_AUTH_SECRET not set, returning empty credentials');
    return { username: '', credential: '' };
  }

  const unixTimestamp = Math.floor(Date.now() / 1000) + ttlSeconds;
  const username = `${unixTimestamp}:${userId}`;
  
  const hmac = crypto.createHmac('sha1', secret);
  hmac.update(username);
  const credential = hmac.digest('base64');

  return {
    username,
    credential,
  };
}
