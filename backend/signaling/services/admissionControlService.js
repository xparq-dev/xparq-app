function createError(code, message, details = {}) {
  const error = new Error(message);
  error.code = code;
  error.details = details;
  return error;
}

export class AdmissionControlService {
  constructor({
    registry,
    maxConcurrent = Number.parseInt(process.env.REJOIN_MAX_CONCURRENT || '64', 10),
    maxQueueDepth = Number.parseInt(process.env.REJOIN_MAX_QUEUE_DEPTH || '2000', 10),
    maxPerRoomConcurrent = Number.parseInt(process.env.REJOIN_MAX_PER_ROOM_CONCURRENT || '48', 10),
    userRateLimit = Number.parseInt(process.env.REJOIN_USER_RATE_LIMIT || '12', 10),
    ipRateLimit = Number.parseInt(process.env.REJOIN_IP_RATE_LIMIT || '120', 10),
    rateWindowSeconds = Number.parseInt(process.env.REJOIN_RATE_WINDOW_SECONDS || '10', 10),
    baseJitterMs = Number.parseInt(process.env.REJOIN_JITTER_BASE_MS || '120', 10),
    maxJitterMs = Number.parseInt(process.env.REJOIN_JITTER_MAX_MS || '2500', 10),
    jitterWindowMs = Number.parseInt(process.env.REJOIN_JITTER_WINDOW_MS || '30000', 10),
  }) {
    this.registry = registry;
    this.maxConcurrent = maxConcurrent;
    this.maxQueueDepth = maxQueueDepth;
    this.maxPerRoomConcurrent = maxPerRoomConcurrent;
    this.userRateLimit = userRateLimit;
    this.ipRateLimit = ipRateLimit;
    this.rateWindowSeconds = rateWindowSeconds;
    this.baseJitterMs = baseJitterMs;
    this.maxJitterMs = maxJitterMs;
    this.jitterWindowMs = jitterWindowMs;

    this.queue = [];
    this.activeCount = 0;
    this.perRoomActive = new Map();
    this.drainTimer = null;
  }

  getSnapshot() {
    return {
      queueDepth: this.queue.length,
      activeCount: this.activeCount,
      maxConcurrent: this.maxConcurrent,
    };
  }

  async scheduleJoin({ socket, roomId, isReconnect = false, task }) {
    if (!socket?.user?.id) {
      throw createError('UNAUTHORIZED', 'Authenticated user context is required.');
    }

    await this.#enforceRateLimits(socket, roomId);

    const jitterInfo = isReconnect
      ? await this.registry.consumeReconnectJitter({
          roomId,
          userId: socket.user.id,
          baseDelayMs: this.baseJitterMs,
          maxDelayMs: this.maxJitterMs,
          windowMs: this.jitterWindowMs,
        })
      : { attempts: 0, delayMs: 0 };

    return this.#enqueue({
      roomId,
      readyAt: Date.now() + (jitterInfo.delayMs || 0),
      task,
      metadata: {
        attempts: jitterInfo.attempts || 0,
        enforcedDelayMs: jitterInfo.delayMs || 0,
      },
    });
  }

  async #enforceRateLimits(socket, roomId) {
    const userId = socket.user.id;
    const ipAddress =
      socket.handshake.address ||
      socket.conn?.remoteAddress ||
      socket.request?.socket?.remoteAddress ||
      'unknown';

    const [userLimit, ipLimit] = await Promise.all([
      this.registry.consumeFixedWindowLimit({
        key: `ratelimit:rejoin:user:${userId}:${roomId}`,
        limit: this.userRateLimit,
        windowSeconds: this.rateWindowSeconds,
      }),
      this.registry.consumeFixedWindowLimit({
        key: `ratelimit:rejoin:ip:${ipAddress}`,
        limit: this.ipRateLimit,
        windowSeconds: this.rateWindowSeconds,
      }),
    ]);

    if (!userLimit.allowed) {
      throw createError(
        'REJOIN_RATE_LIMITED',
        'Too many reconnect attempts for this user.',
        { retryAfterSeconds: userLimit.retryAfterSeconds },
      );
    }

    if (!ipLimit.allowed) {
      throw createError(
        'IP_RATE_LIMITED',
        'Reconnect admission is saturated for this network edge.',
        { retryAfterSeconds: ipLimit.retryAfterSeconds },
      );
    }
  }

  #enqueue(entry) {
    if (this.queue.length >= this.maxQueueDepth) {
      throw createError(
        'REJOIN_QUEUE_SATURATED',
        'Reconnect admission queue is full.',
        { retryAfterSeconds: 2 },
      );
    }

    return new Promise((resolve, reject) => {
      this.queue.push({
        ...entry,
        resolve,
        reject,
      });

      this.queue.sort((left, right) => left.readyAt - right.readyAt);
      this.#scheduleDrain();
    });
  }

  #scheduleDrain() {
    if (this.drainTimer) {
      clearTimeout(this.drainTimer);
      this.drainTimer = null;
    }

    const nextReady = this.queue[0];
    if (!nextReady) {
      return;
    }

    const delayMs = Math.max(0, nextReady.readyAt - Date.now());
    this.drainTimer = setTimeout(() => {
      this.drainTimer = null;
      this.#drainQueue().catch((error) => {
        console.error('[Admission] Queue drain failed:', error);
      });
    }, delayMs);

    if (typeof this.drainTimer.unref === 'function') {
      this.drainTimer.unref();
    }
  }

  async #drainQueue() {
    while (this.activeCount < this.maxConcurrent) {
      const now = Date.now();
      const nextIndex = this.queue.findIndex((entry) => {
        if (entry.readyAt > now) {
          return false;
        }

        const roomActive = this.perRoomActive.get(entry.roomId) || 0;
        return roomActive < this.maxPerRoomConcurrent;
      });

      if (nextIndex === -1) {
        break;
      }

      const entry = this.queue.splice(nextIndex, 1)[0];
      const roomActive = this.perRoomActive.get(entry.roomId) || 0;

      this.activeCount += 1;
      this.perRoomActive.set(entry.roomId, roomActive + 1);

      Promise.resolve()
        .then(entry.task)
        .then((result) => {
          entry.resolve({
            ...result,
            admission: entry.metadata,
          });
        })
        .catch((error) => {
          entry.reject(error);
        })
        .finally(() => {
          this.activeCount = Math.max(0, this.activeCount - 1);
          const remainingRoomActive = Math.max(
            0,
            (this.perRoomActive.get(entry.roomId) || 1) - 1,
          );

          if (remainingRoomActive === 0) {
            this.perRoomActive.delete(entry.roomId);
          } else {
            this.perRoomActive.set(entry.roomId, remainingRoomActive);
          }

          this.#scheduleDrain();
        });
    }

    this.#scheduleDrain();
  }
}
