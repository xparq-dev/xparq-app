import process from 'node:process';

import {
  buildSocket,
  env,
  fetchIcePolicy,
  joinRoom,
  loadTokens,
} from './common.mjs';

async function waitForSocket(socket) {
  return new Promise((resolve, reject) => {
    socket.on('connect', resolve);
    socket.on('connect_error', reject);
  });
}

const callId = env('CALL_ID');
const roomId = env('ROOM_ID');
const [token] = await loadTokens();

if (!token) {
  throw new Error('TOKENS_FILE does not contain any usable tokens.');
}

const socket = buildSocket(token);
const startedAt = Date.now();

try {
  await waitForSocket(socket);
  const icePolicy = await fetchIcePolicy({ token, callId, roomId });
  if (!icePolicy.ok) {
    throw new Error(
      `ICE policy request failed with HTTP ${icePolicy.status}: ${JSON.stringify(icePolicy.body)}`,
    );
  }

  const joined = await joinRoom({
    socket,
    roomId,
    callId,
    policyToken: icePolicy.body.policyToken,
  });

  console.log(
    JSON.stringify(
      {
        ok: true,
        latencyMs: Date.now() - startedAt,
        endpoint: socket.io.uri,
        joined,
      },
      null,
      2,
    ),
  );
} catch (error) {
  console.error(
    JSON.stringify(
      {
        ok: false,
        latencyMs: Date.now() - startedAt,
        endpoint: socket.io.uri,
        error: error?.message || String(error),
      },
      null,
      2,
    ),
  );
  process.exitCode = 1;
} finally {
  socket.disconnect();
}
