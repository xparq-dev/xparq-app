import {
  CALL_EVENTS,
  createEventEnvelope,
} from "../events/callEvents.js";
import {
  CALL_STATUS,
  createCallSession,
  applyEvent,
} from "../models/callSessionModel.js";

function buildSessionKey(callId) {
  return `call:${callId}:session`;
}

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

export class CallSignalService {
  constructor({
    registry = null,
    sessionTtlSeconds = Number.parseInt(process.env.CALL_SESSION_TTL_SECONDS || '43200', 10),
  } = {}) {
    this.registry = registry;
    this.sessionTtlSeconds = sessionTtlSeconds;
    this.sessions = new Map();
  }

  async invite({ callerId, calleeId }) {
    if (!callerId || !calleeId) {
      throw new Error("callerId and calleeId are required.");
    }
    if (callerId === calleeId) {
      throw new Error("callerId and calleeId must be different.");
    }

    const now = new Date();
    const session = createCallSession({ callerId, calleeId, now });
    session.version = 0;

    await this.#createSessionAtomic(session);
    this.sessions.set(session.call_id, session);

    const event = createEventEnvelope({
      eventType: CALL_EVENTS.CALL_INVITE,
      callId: session.call_id,
      roomId: session.room_id,
      actorId: callerId,
      targetId: calleeId,
      now,
      payload: {
        call_status: session.status,
        version: session.version,
      },
    });

    return {
      session,
      event,
    };
  }

  async accept({ callId, actorId }) {
    return this.#transition({
      callId,
      actorId,
      eventType: CALL_EVENTS.CALL_ACCEPT,
      targetResolver: (session) => session.caller_id,
    });
  }

  async reject({ callId, actorId }) {
    return this.#transition({
      callId,
      actorId,
      eventType: CALL_EVENTS.CALL_REJECT,
      targetResolver: (session) => session.caller_id,
    });
  }

  async joinRoom({ callId, actorId, roomId }) {
    return this.#transition({
      callId,
      actorId,
      roomId,
      eventType: CALL_EVENTS.JOIN_ROOM,
      targetResolver: (session) =>
        actorId === session.caller_id ? session.callee_id : session.caller_id,
    });
  }

  async leaveRoom({ callId, actorId, roomId }) {
    return this.#transition({
      callId,
      actorId,
      roomId,
      eventType: CALL_EVENTS.LEAVE_ROOM,
      targetResolver: (session) =>
        actorId === session.caller_id ? session.callee_id : session.caller_id,
    });
  }

  async closeSession(callId, reason = "cleanup") {
    const session = await this.getSession(callId);
    session.status = CALL_STATUS.ENDED;
    session.closed_reason = reason;
    session.updated_at = new Date().toISOString();
    session.version = (session.version || 0) + 1;

    await this.#setSessionAtomic(callId, session);
    this.sessions.set(callId, session);
    return session;
  }

  async getSession(callId) {
    const cachedSession = this.sessions.get(callId);
    if (cachedSession) {
      return cachedSession;
    }

    if (!this.registry?.client) {
      throw new Error(`Call session ${callId} was not found.`);
    }

    await this.registry.init();
    const raw = await this.registry.client.get(buildSessionKey(callId));
    const session = parseJson(raw);
    if (!session) {
      throw new Error(`Call session ${callId} was not found.`);
    }

    this.sessions.set(callId, session);
    return session;
  }

  async listActiveSessions() {
    if (!this.registry?.client) {
      return Array.from(this.sessions.values()).filter(
        (session) =>
          session.status === CALL_STATUS.INVITED ||
          session.status === CALL_STATUS.ACCEPTED,
      );
    }

    await this.registry.init();

    let cursor = '0';
    const keys = [];
    do {
      const result = await this.registry.client.scan(cursor, {
        MATCH: 'call:*:session',
        COUNT: 100,
      });
      cursor = result.cursor;
      keys.push(...result.keys);
    } while (cursor !== '0');

    if (!keys.length) {
      return [];
    }

    const values = await this.registry.client.mGet(keys);
    return values
      .map((raw) => parseJson(raw))
      .filter(Boolean)
      .filter(
        (session) =>
          session.status === CALL_STATUS.INVITED ||
          session.status === CALL_STATUS.ACCEPTED,
      );
  }

  async #transition({ callId, actorId, roomId, eventType, targetResolver }) {
    if (!callId || !actorId) {
      throw new Error("callId and actorId are required.");
    }

    const session = await this.#mutateSessionAtomic(callId, (currentSession) => {
      if (roomId && roomId !== currentSession.room_id) {
        throw new Error("roomId does not match the active call session.");
      }

      applyEvent(currentSession, eventType, actorId, new Date());
      currentSession.version = (currentSession.version || 0) + 1;
      return currentSession;
    });

    const event = createEventEnvelope({
      eventType,
      callId: session.call_id,
      roomId: session.room_id,
      actorId,
      targetId: targetResolver(session),
      now: new Date(),
      payload: {
        call_status: session.status,
        participant_state: session.participants[actorId].state,
        version: session.version,
      },
    });

    return {
      session,
      event,
    };
  }

  async #createSessionAtomic(session) {
    if (!this.registry?.client) {
      return;
    }

    await this.registry.init();
    const created = await this.registry.client.set(buildSessionKey(session.call_id), JSON.stringify(session), {
      EX: this.sessionTtlSeconds,
      NX: true,
    });

    if (created !== 'OK') {
      throw new Error(`Call session ${session.call_id} already exists.`);
    }
  }

  async #setSessionAtomic(callId, session) {
    if (!this.registry?.client) {
      return;
    }

    await this.registry.init();
    await this.registry.client.setEx(
      buildSessionKey(callId),
      this.sessionTtlSeconds,
      JSON.stringify(session),
    );
  }

  async #mutateSessionAtomic(callId, mutator) {
    if (!this.registry?.client) {
      const session = this.sessions.get(callId);
      if (!session) {
        throw new Error(`Call session ${callId} was not found.`);
      }

      const nextSession = mutator(structuredClone(session));
      this.sessions.set(callId, nextSession);
      return nextSession;
    }

    await this.registry.init();
    const key = buildSessionKey(callId);

    for (let attempt = 0; attempt < 5; attempt += 1) {
      await this.registry.client.watch(key);

      try {
        const raw = await this.registry.client.get(key);
        const session = parseJson(raw);
        if (!session) {
          throw new Error(`Call session ${callId} was not found.`);
        }

        const nextSession = mutator(structuredClone(session));
        nextSession.updated_at = new Date().toISOString();

        const execResult = await this.registry.client
          .multi()
          .setEx(key, this.sessionTtlSeconds, JSON.stringify(nextSession))
          .exec();

        if (execResult) {
          this.sessions.set(callId, nextSession);
          return nextSession;
        }
      } finally {
        await this.registry.client.unwatch();
      }
    }

    throw new Error(`Failed to atomically update call session ${callId}.`);
  }
}
