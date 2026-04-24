import process from 'node:process';

import {
  env,
  fetchIcePolicy,
  loadTokens,
  numberEnv,
  summarize,
} from './common.mjs';

const callId = env('CALL_ID');
const roomId = env('ROOM_ID');
const requestCount = numberEnv('REQUEST_COUNT', 400);
const tokens = await loadTokens();
const results = [];

await Promise.all(
  Array.from({ length: requestCount }, async (_, index) => {
    const token = tokens[index % tokens.length];
    const forwardedFor = `203.0.113.${(index % 200) + 1}`;
    const startedAt = Date.now();
    const response = await fetchIcePolicy({
      token,
      callId,
      roomId,
      transportPolicy: 'relay',
      forwardedFor,
    });

    results.push({
      ok: response.ok,
      latencyMs: Date.now() - startedAt,
      status: response.status,
      forwardedFor,
      blocked: !response.ok,
    });
  }),
);

summarize('forced-turn-attack', results);
process.exit(
  results.some((row) => row.status === 429 || row.blocked) ? 0 : 1,
);
