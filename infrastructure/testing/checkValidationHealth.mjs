import net from 'node:net';
import process from 'node:process';

import 'dotenv/config';

import { buildSocket, loadTokens, resolveApiOrigin, resolveSocketUrl } from './common.mjs';

function optionalEnv(name, fallback = null) {
  const value = process.env[name];
  return value == null || value === '' ? fallback : value;
}

function parseRedisTarget() {
  const redisUrl = optionalEnv('REDIS_URL');
  if (!redisUrl) {
    return null;
  }

  const url = new URL(redisUrl);
  return {
    host: url.hostname,
    port: Number.parseInt(url.port || '6379', 10),
  };
}

function tcpProbe(host, port, timeoutMs = 3000) {
  return new Promise((resolve) => {
    const socket = new net.Socket();
    const startedAt = Date.now();

    socket.setTimeout(timeoutMs);
    socket.once('connect', () => {
      socket.destroy();
      resolve({
        ok: true,
        latencyMs: Date.now() - startedAt,
      });
    });
    socket.once('timeout', () => {
      socket.destroy();
      resolve({
        ok: false,
        error: 'timeout',
        latencyMs: Date.now() - startedAt,
      });
    });
    socket.once('error', (error) => {
      socket.destroy();
      resolve({
        ok: false,
        error: error.message,
        latencyMs: Date.now() - startedAt,
      });
    });

    socket.connect(port, host);
  });
}

async function httpProbe(url) {
  const startedAt = Date.now();
  try {
    const response = await fetch(url);
    const body = await response.text();
    return {
      ok: response.ok,
      status: response.status,
      latencyMs: Date.now() - startedAt,
      sample: body.slice(0, 200),
    };
  } catch (error) {
    return {
      ok: false,
      error: error.message,
      latencyMs: Date.now() - startedAt,
    };
  }
}

async function socketProbe() {
  try {
    const [token] = await loadTokens();
    if (!token) {
      return {
        ok: false,
        skipped: true,
        reason: 'TOKENS_FILE does not contain any tokens',
      };
    }

    const startedAt = Date.now();
    const socket = buildSocket(token);
    const result = await new Promise((resolve) => {
      socket.on('connect', () => {
        resolve({
          ok: true,
          latencyMs: Date.now() - startedAt,
        });
      });
      socket.on('connect_error', (error) => {
        resolve({
          ok: false,
          error: error.message,
          latencyMs: Date.now() - startedAt,
        });
      });
    });
    socket.disconnect();
    return result;
  } catch (error) {
    return {
      ok: false,
      skipped: true,
      reason: error.message,
    };
  }
}

const apiOrigin = resolveApiOrigin();
const socketUrl = resolveSocketUrl();
const turnHost = optionalEnv('TURN_HOST', optionalEnv('TURN_DOMAIN'));
const redisTarget = parseRedisTarget();

const report = {
  apiOrigin,
  socketUrl,
  probes: {
    health: await httpProbe(`${apiOrigin}/health`),
    metrics: await httpProbe(`${apiOrigin}/metrics`),
    socket: await socketProbe(),
    redis: redisTarget
      ? await tcpProbe(redisTarget.host, redisTarget.port)
      : { ok: false, skipped: true, reason: 'REDIS_URL not set' },
    turn3478: turnHost
      ? await tcpProbe(turnHost, 3478)
      : { ok: false, skipped: true, reason: 'TURN_HOST/TURN_DOMAIN not set' },
    turn5349: turnHost
      ? await tcpProbe(turnHost, 5349)
      : { ok: false, skipped: true, reason: 'TURN_HOST/TURN_DOMAIN not set' },
  },
};

console.log(JSON.stringify(report, null, 2));

const mustPass = ['health', 'metrics', 'socket'];
const failed = mustPass.filter((key) => report.probes[key]?.ok !== true);
if (failed.length > 0) {
  process.exitCode = 1;
}
