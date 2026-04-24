import fs from 'node:fs/promises';
import process from 'node:process';

import 'dotenv/config';
import { io } from 'socket.io-client';

export function env(name, fallback = undefined) {
  const value = process.env[name];
  if (value == null || value === '') {
    if (fallback !== undefined) {
      return fallback;
    }

    throw new Error(`Missing required environment variable: ${name}`);
  }

  return value;
}

export function numberEnv(name, fallback) {
  const value = process.env[name];
  if (value == null || value === '') {
    return fallback;
  }

  const parsed = Number.parseInt(value, 10);
  if (!Number.isFinite(parsed)) {
    throw new Error(`Environment variable ${name} must be an integer.`);
  }

  return parsed;
}

export async function loadTokens() {
  const filePath = env('TOKENS_FILE');
  const raw = await fs.readFile(filePath, 'utf8');
  const trimmed = raw.trim();
  if (!trimmed) {
    return [];
  }

  if (trimmed.startsWith('[')) {
    const rows = JSON.parse(trimmed);
    return rows.map((row) => {
      if (typeof row === 'string') {
        return row;
      }

      return row.token;
    });
  }

  return trimmed
    .split(/\r?\n/)
    .map((line) => line.trim())
    .filter(Boolean);
}

export function buildSocket(token) {
  return io(resolveSocketUrl(), {
    transports: ['websocket'],
    forceNew: true,
    multiplex: false,
    reconnection: false,
    auth: { token },
  });
}

export function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

export async function fetchIcePolicy({
  token,
  callId,
  roomId,
  transportPolicy = 'all',
  forwardedFor = null,
}) {
  const url = new URL('/api/v1/ice-servers', resolveApiOrigin());
  url.searchParams.set('callId', callId);
  url.searchParams.set('roomId', roomId);
  url.searchParams.set('transportPolicy', transportPolicy);

  const response = await fetch(url, {
    headers: {
      Authorization: `Bearer ${token}`,
      ...(forwardedFor ? { 'X-Forwarded-For': forwardedFor } : {}),
    },
  });

  const body = await response.json().catch(() => ({}));
  return {
    ok: response.ok,
    status: response.status,
    body,
  };
}

export async function joinRoom({
  socket,
  roomId,
  callId,
  policyToken = null,
}) {
  return new Promise((resolve, reject) => {
    socket.emit(
      'joinRoom',
      {
        roomId,
        callId,
        ...(policyToken ? { policyToken } : {}),
      },
      (ack) => {
        const payload = ack && typeof ack === 'object' ? ack : {};
        if (payload.ok === true) {
          resolve(payload.data ?? {});
          return;
        }

        reject(payload.error ?? new Error('joinRoom failed'));
      },
    );
  });
}

export function summarize(label, rows) {
  const successCount = rows.filter((row) => row.ok).length;
  const failureCount = rows.length - successCount;
  const latencies = rows
    .map((row) => row.latencyMs)
    .filter((value) => Number.isFinite(value))
    .sort((left, right) => left - right);

  const p95Index = latencies.length
    ? Math.min(latencies.length - 1, Math.floor(latencies.length * 0.95))
    : -1;

  console.log(
    JSON.stringify(
      {
        label,
        total: rows.length,
        successCount,
        failureCount,
        p95LatencyMs: p95Index >= 0 ? latencies[p95Index] : null,
      },
      null,
      2,
    ),
  );
}

export function resolveApiOrigin() {
  const rawValue = env('API_BASE_URL');
  const normalized = rawValue.replace(/\/+$/, '');
  const withoutApiSuffix = normalized.replace(/\/api\/v1$/i, '');
  const url = new URL(withoutApiSuffix);

  return url.toString().replace(/\/+$/, '');
}

export function resolveSocketUrl() {
  const explicitSocketUrl = process.env.SOCKET_URL;
  if (explicitSocketUrl && explicitSocketUrl.trim() !== '') {
    return explicitSocketUrl.trim().replace(/\/+$/, '');
  }

  return resolveApiOrigin();
}
