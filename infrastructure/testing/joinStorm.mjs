import process from 'node:process';

import {
  buildSocket,
  env,
  fetchIcePolicy,
  joinRoom,
  loadTokens,
  numberEnv,
  summarize,
} from './common.mjs';

// ==============================
// CONFIG (ผ่าน ENV)
// ==============================

const callId = env('CALL_ID');
const roomId = env('ROOM_ID');

const concurrency = numberEnv('CONCURRENCY', 50);
const holdMs = numberEnv('HOLD_MS', 30000);
const jitterMaxMs = numberEnv('JITTER_MS', 2000);

// 👉 timeout กัน hang
const connectTimeoutMs = numberEnv('CONNECT_TIMEOUT_MS', 8000);
const joinTimeoutMs = numberEnv('JOIN_TIMEOUT_MS', 8000);

// 👉 จำกัด parallel (กัน CPU spike ฝั่ง client)
const maxParallel = numberEnv('MAX_PARALLEL', 20);

// 👉 retry join (เบื้องต้น)
const maxRetries = numberEnv('MAX_RETRIES', 1);

// ==============================
// UTILS
// ==============================

function sleep(ms) {
  return new Promise((r) => setTimeout(r, ms));
}

function withTimeout(promise, ms, label) {
  return Promise.race([
    promise,
    new Promise((_, reject) =>
      setTimeout(() => reject(new Error(`${label}_TIMEOUT`)), ms)
    ),
  ]);
}

// percentile helper
function percentile(arr, p) {
  if (!arr.length) return 0;
  const sorted = [...arr].sort((a, b) => a - b);
  const idx = Math.floor((p / 100) * sorted.length);
  return sorted[idx];
}

// ==============================
// LOAD TOKENS
// ==============================

const tokens = (await loadTokens()).slice(0, concurrency);

// ==============================
// STATE
// ==============================

const sockets = [];
const results = [];
const joinLatencies = [];

// ==============================
// WORKER FUNCTION
// ==============================

async function runOne(token, index) {
  const jitter = Math.floor(Math.random() * jitterMaxMs);
  await sleep(jitter);

  const socket = buildSocket(token);
  sockets.push(socket);

  const startedAt = Date.now();

  try {
    // CONNECT
    await withTimeout(
      new Promise((resolve, reject) => {
        socket.on('connect', resolve);
        socket.on('connect_error', reject);
      }),
      connectTimeoutMs,
      'CONNECT'
    );

    // ICE
    const icePolicy = await fetchIcePolicy({ token, callId, roomId });
    const policyToken = icePolicy.ok ? icePolicy.body.policyToken : null;

    // JOIN (retry)
    let joined = false;
    let attempt = 0;

    while (!joined && attempt <= maxRetries) {
      try {
        await withTimeout(
          joinRoom({ socket, roomId, callId, policyToken }),
          joinTimeoutMs,
          'JOIN'
        );
        joined = true;
      } catch (err) {
        attempt++;
        if (attempt > maxRetries) throw err;
        await sleep(500 + Math.random() * 1000); // jitter retry
      }
    }

    const joinLatency = Date.now() - startedAt;
    joinLatencies.push(joinLatency);

    // HOLD SESSION
    await sleep(holdMs);

    results.push({
      ok: true,
      latencyMs: joinLatency, // 👈 ใช้ join latency จริง
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
}

// ==============================
// RUN WITH PARALLEL LIMIT
// ==============================

const queue = [...tokens];
const workers = [];

for (let i = 0; i < Math.min(maxParallel, queue.length); i++) {
  workers.push(
    (async function worker() {
      while (queue.length) {
        const token = queue.shift();
        const index = tokens.indexOf(token);
        await runOne(token, index);
      }
    })()
  );
}

await Promise.all(workers);

// ==============================
// SUMMARY
// ==============================

summarize('join-storm', results);

// 👉 เพิ่ม percentile ลึก
console.log('\nDetailed Latency Stats:');
console.log({
  p50: percentile(joinLatencies, 50),
  p90: percentile(joinLatencies, 90),
  p95: percentile(joinLatencies, 95),
  p99: percentile(joinLatencies, 99),
});

// ==============================
// CLEANUP
// ==============================

sockets.forEach((socket) => {
  try {
    socket.disconnect();
  } catch {}
});

process.exit(results.every((row) => row.ok) ? 0 : 1);