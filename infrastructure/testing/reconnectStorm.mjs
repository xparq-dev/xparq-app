import process from 'node:process';

import {
  buildSocket,
  env,
  fetchIcePolicy,
  joinRoom,
  loadTokens,
  numberEnv,
  sleep,
  summarize,
} from './common.mjs';

const callId = env('CALL_ID');
const roomId = env('ROOM_ID');
const concurrency = numberEnv('CONCURRENCY', 1000);

const tokens = (await loadTokens()).slice(0, concurrency);
const sockets = [];
const initialResults = [];
const results = [];

await Promise.all(
  tokens.map(async (token, index) => {
    const socket = buildSocket(token);
    sockets[index] = socket;
    const startedAt = Date.now();

    try {
      await new Promise((resolve, reject) => {
        socket.on('connect', resolve);
        socket.on('connect_error', reject);
      });

      const icePolicy = await fetchIcePolicy({ token, callId, roomId });
      const policyToken = icePolicy.ok ? icePolicy.body.policyToken : null;
      await joinRoom({ socket, roomId, callId, policyToken });
      initialResults.push({
        ok: true,
        latencyMs: Date.now() - startedAt,
        index,
      });
    } catch (error) {
      initialResults.push({
        ok: false,
        latencyMs: Date.now() - startedAt,
        index,
        error: error?.message || String(error),
      });
    }
  }),
);

if (!initialResults.every((row) => row.ok)) {
  summarize('reconnect-storm-initial-join', initialResults);
  sockets.forEach((socket) => socket?.disconnect());
  process.exit(1);
}

console.log(`Joined ${sockets.length} sockets. Triggering reconnect storm...`);
sockets.forEach((socket) => socket.disconnect());
await sleep(500);

await Promise.all(
  tokens.map(async (token, index) => {
    const socket = buildSocket(token);
    sockets[index] = socket;
    const startedAt = Date.now();

    try {
      await new Promise((resolve, reject) => {
        socket.on('connect', resolve);
        socket.on('connect_error', reject);
      });

      const icePolicy = await fetchIcePolicy({ token, callId, roomId });
      const policyToken = icePolicy.ok ? icePolicy.body.policyToken : null;
      await joinRoom({ socket, roomId, callId, policyToken });
      results.push({
        ok: true,
        latencyMs: Date.now() - startedAt,
        index,
      });
    } catch (error) {
      results.push({
        ok: false,
        latencyMs: Date.now() - startedAt,
        index,
        error: error?.message || String(error),
      });
    }
  }),
);

summarize('reconnect-storm', results);
sockets.forEach((socket) => socket.disconnect());
process.exit(results.every((row) => row.ok) ? 0 : 1);
