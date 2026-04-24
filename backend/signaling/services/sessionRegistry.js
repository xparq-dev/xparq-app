import { createClient } from 'redis';

import { observeRedisLatency } from './observabilityService.js';

const ROOM_ASSIGN_SCRIPT = `
local key = KEYS[1]
local now = tonumber(ARGV[1])
local ttlSeconds = tonumber(ARGV[2])
local expectedVersion = tonumber(ARGV[3])
local nodeId = ARGV[4]
local region = ARGV[5]
local callId = ARGV[6]
local metadataRaw = ARGV[7]

local raw = redis.call('GET', key)
local current = nil

if raw then
  current = cjson.decode(raw)
  local currentVersion = tonumber(current.version or 0)
  if expectedVersion >= 0 and currentVersion ~= expectedVersion then
    return cjson.encode({
      status = 'version_mismatch',
      state = current
    })
  end
end

local nextVersion = 1
if current then
  nextVersion = tonumber(current.version or 0) + 1
end

local nextState = {
  callId = callId,
  roomId = string.gsub(key, '^room:', ''),
  nodeId = nodeId,
  region = region,
  version = nextVersion,
  updatedAt = now,
  metadata = cjson.decode(metadataRaw)
}

redis.call('SET', key, cjson.encode(nextState), 'EX', ttlSeconds)

return cjson.encode({
  status = current and 'reassigned' or 'created',
  state = nextState
})
`;

const FIXED_WINDOW_SCRIPT = `
local key = KEYS[1]
local limit = tonumber(ARGV[1])
local windowSeconds = tonumber(ARGV[2])

local current = redis.call('INCR', key)
if current == 1 then
  redis.call('EXPIRE', key, windowSeconds)
end

local ttl = redis.call('TTL', key)
return cjson.encode({
  allowed = current <= limit,
  current = current,
  limit = limit,
  retryAfterSeconds = ttl < 0 and windowSeconds or ttl
})
`;

const REJOIN_JITTER_SCRIPT = `
local key = KEYS[1]
local now = tonumber(ARGV[1])
local windowMs = tonumber(ARGV[2])
local baseDelayMs = tonumber(ARGV[3])
local maxDelayMs = tonumber(ARGV[4])

local state = {
  firstSeenAt = now,
  lastSeenAt = now,
  attempts = 0
}

local raw = redis.call('GET', key)
if raw then
  state = cjson.decode(raw)
end

local firstSeenAt = tonumber(state.firstSeenAt or now)
if (now - firstSeenAt) > windowMs then
  firstSeenAt = now
  state.attempts = 0
end

state.firstSeenAt = firstSeenAt
state.lastSeenAt = now
state.attempts = tonumber(state.attempts or 0) + 1

local attemptIndex = math.max(state.attempts - 1, 0)
local rampDelay = math.min(maxDelayMs, attemptIndex * baseDelayMs)
local jitterBucket = ((now + (state.attempts * 1103515245)) % 997)
local jitter = 0
if baseDelayMs > 0 then
  jitter = jitterBucket % baseDelayMs
end

local delayMs = math.min(maxDelayMs, rampDelay + jitter)

redis.call(
  'SET',
  key,
  cjson.encode(state),
  'PX',
  math.max(windowMs, (maxDelayMs * 4))
)

return cjson.encode({
  attempts = state.attempts,
  delayMs = delayMs
})
`;

function parseJson(rawValue, fallback = null) {
  if (!rawValue) {
    return fallback;
  }

  try {
    return JSON.parse(rawValue);
  } catch (error) {
    return fallback;
  }
}

export class SessionRegistryService {
  constructor(redisUrl, config = {}) {
    this.redisUrl = redisUrl || null;
    this.roomStateTtlSeconds = config.roomStateTtlSeconds || 120;
    this.heartbeatTtlSeconds = config.heartbeatTtlSeconds || 15;
    this.nodeId = config.nodeId || process.env.NODE_ID || `node-${process.pid}`;
    this.localSocketSessions = new Map();
    this.localNodeCache = new Map();
    this.client = this.redisUrl ? createClient({ url: this.redisUrl }) : null;
    this.initPromise = null;
  }

  async init() {
    if (!this.client) {
      return null;
    }

    if (this.client.isOpen) {
      return this.client;
    }

    if (!this.initPromise) {
      this.client.on('error', (error) => {
        console.error('[Registry] Redis error:', error);
      });

      this.initPromise = this.client.connect().catch((error) => {
        this.initPromise = null;
        throw error;
      });
    }

    await this.initPromise;
    return this.client;
  }

  async withRedisTiming(operation, callback) {
    const startedAt = Date.now();
    try {
      return await callback();
    } finally {
      observeRedisLatency(operation, Date.now() - startedAt);
    }
  }

  bind(socketId, session) {
    this.localSocketSessions.set(socketId, {
      ...session,
      boundAt: Date.now(),
      lastSeenAt: Date.now(),
    });
  }

  get(socketId) {
    return this.localSocketSessions.get(socketId) || null;
  }

  touch(socketId) {
    const current = this.localSocketSessions.get(socketId);
    if (!current) {
      return null;
    }

    current.lastSeenAt = Date.now();
    this.localSocketSessions.set(socketId, current);
    return current;
  }

  unbind(socketId) {
    const current = this.localSocketSessions.get(socketId) || null;
    this.localSocketSessions.delete(socketId);
    return current;
  }

  async updateNodeHeartbeat(nodeId = this.nodeId, metrics = {}) {
    const payload = {
      nodeId,
      lastSeenAt: Date.now(),
      signalingEndpoint:
        metrics.signalingEndpoint ||
        process.env.SIGNALING_PUBLIC_ENDPOINT ||
        process.env.PUBLIC_SIGNALING_ENDPOINT ||
        null,
      ...metrics,
    };

    this.localNodeCache.set(nodeId, payload);

    if (!this.client) {
      return payload;
    }

    await this.init();

    const heartbeatKey = `node:${nodeId}:heartbeat`;
    await this.withRedisTiming('update_node_heartbeat', async () => {
      await this.client
        .multi()
        .setEx(heartbeatKey, this.heartbeatTtlSeconds, JSON.stringify(payload))
        .sAdd('active_nodes', nodeId)
        .exec();
    });

    return payload;
  }

  async getHealthyNodes() {
    if (!this.client) {
      return Array.from(this.localNodeCache.values());
    }

    await this.init();

    try {
      const nodeIds = await this.withRedisTiming('get_healthy_nodes_members', () =>
        this.client.sMembers('active_nodes'),
      );
      if (!nodeIds.length) {
        return Array.from(this.localNodeCache.values());
      }

      const heartbeatKeys = nodeIds.map((nodeId) => `node:${nodeId}:heartbeat`);
      const rows = await this.withRedisTiming('get_healthy_nodes_values', () =>
        this.client.mGet(heartbeatKeys),
      );
      const healthyNodes = [];
      const staleNodeIds = [];

      nodeIds.forEach((nodeId, index) => {
        const parsed = parseJson(rows[index]);
        if (!parsed) {
          staleNodeIds.push(nodeId);
          return;
        }

        this.localNodeCache.set(nodeId, parsed);
        healthyNodes.push(parsed);
      });

      if (staleNodeIds.length) {
        await this.withRedisTiming('trim_stale_nodes', () =>
          this.client.sRem('active_nodes', ...staleNodeIds),
        );
      }

      return healthyNodes;
    } catch (error) {
      console.warn('[Registry] Falling back to local node cache after Redis read failure.');
      return Array.from(this.localNodeCache.values());
    }
  }

  async readRoomState(roomId) {
    if (!roomId) {
      return null;
    }

    if (!this.client) {
      return null;
    }

    await this.init();
    const raw = await this.withRedisTiming('read_room_state', () =>
      this.client.get(`room:${roomId}`),
    );
    return parseJson(raw);
  }

  async assignRoomNode({
    roomId,
    callId,
    nodeId,
    region,
    expectedVersion = null,
    metadata = {},
  }) {
    if (!roomId || !callId || !nodeId) {
      throw new Error('roomId, callId, and nodeId are required.');
    }

    if (!this.client) {
      return {
        status: 'created',
        state: {
          callId,
          roomId,
          nodeId,
          region,
          version: 1,
          updatedAt: Date.now(),
          metadata,
        },
      };
    }

    await this.init();

    const result = await this.withRedisTiming('assign_room_node', () =>
      this.client.eval(ROOM_ASSIGN_SCRIPT, {
        keys: [`room:${roomId}`],
        arguments: [
          String(Date.now()),
          String(this.roomStateTtlSeconds),
          String(expectedVersion ?? -1),
          nodeId,
          region || '',
          callId,
          JSON.stringify(metadata || {}),
        ],
      }),
    );

    return parseJson(result, { status: 'unknown', state: null });
  }

  async getOrAssignRoomNode({ roomId, callId, localRegion, selector }) {
    if (!roomId || !callId) {
      throw new Error('roomId and callId are required.');
    }

    for (let attempt = 0; attempt < 5; attempt += 1) {
      const currentState = await this.readRoomState(roomId);
      const healthyNodes = await this.getHealthyNodes();
      const healthyNodeIds = new Set(healthyNodes.map((node) => node.nodeId || node.id));

      if (currentState && healthyNodeIds.has(currentState.nodeId)) {
        return currentState;
      }

      const selectedNode = selector
        ? selector(healthyNodes, currentState)
        : healthyNodes[0];

      if (!selectedNode) {
        throw new Error('No healthy SFU nodes available.');
      }

      const nodeId = selectedNode.nodeId || selectedNode.id;
      const assignment = await this.assignRoomNode({
        roomId,
        callId,
        nodeId,
        region: selectedNode.region || localRegion,
        expectedVersion: currentState?.version ?? null,
        metadata: {
          previousNodeId: currentState?.nodeId || null,
          signalingEndpoint:
            selectedNode.signalingEndpoint ||
            selectedNode.endpoint ||
            null,
        },
      });

      if (assignment.status !== 'version_mismatch' && assignment.state) {
        return assignment.state;
      }
    }

    throw new Error(`Failed to atomically assign room ${roomId} after multiple retries.`);
  }

  async clearRoom(roomId) {
    if (!roomId || !this.client) {
      return;
    }

    await this.init();
    await this.withRedisTiming('clear_room_state', () =>
      this.client.del(`room:${roomId}`),
    );
  }

  async consumeFixedWindowLimit({ key, limit, windowSeconds }) {
    if (!key || !limit || !windowSeconds) {
      throw new Error('key, limit, and windowSeconds are required.');
    }

    if (!this.client) {
      return {
        allowed: true,
        current: 0,
        limit,
        retryAfterSeconds: 0,
      };
    }

    await this.init();

    const result = await this.withRedisTiming('fixed_window_limit', () =>
      this.client.eval(FIXED_WINDOW_SCRIPT, {
        keys: [key],
        arguments: [String(limit), String(windowSeconds)],
      }),
    );

    return parseJson(result, {
      allowed: true,
      current: 0,
      limit,
      retryAfterSeconds: 0,
    });
  }

  async consumeReconnectJitter({
    roomId,
    userId,
    baseDelayMs,
    maxDelayMs,
    windowMs,
  }) {
    if (!roomId || !userId) {
      return { attempts: 0, delayMs: 0 };
    }

    if (!this.client) {
      return { attempts: 1, delayMs: 0 };
    }

    await this.init();

    const result = await this.withRedisTiming('rejoin_jitter', () =>
      this.client.eval(REJOIN_JITTER_SCRIPT, {
        keys: [`rejoin:${roomId}:${userId}`],
        arguments: [
          String(Date.now()),
          String(windowMs),
          String(baseDelayMs),
          String(maxDelayMs),
        ],
      }),
    );

    return parseJson(result, { attempts: 1, delayMs: 0 });
  }
}

export const SessionRegistry = new SessionRegistryService(process.env.REDIS_URL, {
  nodeId: process.env.NODE_ID,
  roomStateTtlSeconds: Number.parseInt(process.env.ROOM_STATE_TTL_SECONDS || '120', 10),
  heartbeatTtlSeconds: Number.parseInt(process.env.NODE_HEARTBEAT_TTL_SECONDS || '15', 10),
});
