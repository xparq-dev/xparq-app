const { createClient } = require("@supabase/supabase-js");
const { getSfuSupabaseConfig } = require("../config/supabaseConfig");
const { mediasoupConfig } = require("../config/mediasoupConfig");

class SessionStateService {
  constructor({
    client = null,
    configProvider = getSfuSupabaseConfig,
    instanceId = mediasoupConfig.sfu.instanceId,
  } = {}) {
    this.client = client;
    this.configProvider = configProvider;
    this.instanceId = instanceId;
    this.initialized = Boolean(client);
  }

  async init() {
    if (this.initialized) {
      return;
    }

    const config = this.configProvider();
    this.client = createClient(config.url, config.serviceRoleKey, {
      auth: {
        autoRefreshToken: false,
        persistSession: false,
      },
    });

    this.initialized = true;
  }

  async claimRoomLease({ callId, roomId, workerId, leaseMs }) {
    this.#assertInitialized();
    this.#assertRequired({ callId, roomId, leaseMs }, ["callId", "roomId", "leaseMs"]);

    const row = await this.#rpcSingle("sfu_claim_room_lease", {
      p_call_id: callId,
      p_room_id: roomId,
      p_worker_id: workerId || null,
      p_instance_id: this.instanceId,
      p_lease_seconds: Math.floor(leaseMs / 1000), // แปลง ms → seconds
    });

    if (row.ownership_status !== "owned") {
      const error = new Error(
        `Room ${roomId} is owned by instance ${row.owner_instance_id}.`,
      );
      error.code = "ROOM_OWNED_BY_OTHER_INSTANCE";
      error.ownerInstanceId = row.owner_instance_id;
      error.callId = callId;
      error.roomId = roomId;
      throw error;
    }

    return row;
  }

  async bindPeer({
    callId,
    roomId,
    peerId,
    userId,
    requestId,
    metadata = {},
  }) {
    this.#assertInitialized();
    this.#assertRequired(
      { callId, roomId, peerId, userId },
      ["callId", "roomId", "peerId", "userId"],
    );

    return this.#rpcSingle("sfu_register_peer", {
      p_call_id: callId,
      p_room_id: roomId,
      p_peer_id: peerId,
      p_user_id: userId,
      p_instance_id: this.instanceId,
      p_join_request_id: requestId || null,
      p_metadata: metadata,
    });
  }

  async registerTransport({
    transportId,
    callId,
    roomId,
    peerId,
    userId,
    direction,
    requestId,
    idleTimeoutMs,
  }) {
    this.#assertInitialized();
    this.#assertRequired(
      { transportId, callId, roomId, peerId, userId, direction },
      ["transportId", "callId", "roomId", "peerId", "userId", "direction"],
    );

    return this.#rpcSingle("sfu_register_transport", {
      p_transport_id: transportId,
      p_call_id: callId,
      p_room_id: roomId,
      p_peer_id: peerId,
      p_user_id: userId,
      p_direction: direction,
      p_instance_id: this.instanceId,
      p_request_id: requestId || null,
      p_idle_timeout_ms: idleTimeoutMs,
    });
  }

  async registerProducer({
    producerId,
    callId,
    roomId,
    peerId,
    userId,
    transportId,
    kind,
    requestId,
  }) {
    this.#assertInitialized();
    this.#assertRequired(
      {
        producerId,
        callId,
        roomId,
        peerId,
        userId,
        transportId,
        kind,
      },
      [
        "producerId",
        "callId",
        "roomId",
        "peerId",
        "userId",
        "transportId",
        "kind",
      ],
    );

    return this.#rpcSingle("sfu_register_producer", {
      p_producer_id: producerId,
      p_call_id: callId,
      p_room_id: roomId,
      p_peer_id: peerId,
      p_user_id: userId,
      p_transport_id: transportId,
      p_kind: kind,
      p_instance_id: this.instanceId,
      p_request_id: requestId || null,
    });
  }

  async markTransportConnected({ transportId }) {
    this.#assertInitialized();
    this.#assertRequired({ transportId }, ["transportId"]);

    await this.#update("sfu_transports", {
      status: "connected",
      connected_at: new Date().toISOString(),
      last_heartbeat_at: new Date().toISOString(),
      failure_reason: null,
    }, {
      column: "transport_id",
      value: transportId,
    });
  }

  async touchTransportHeartbeat({ transportId }) {
    this.#assertInitialized();
    this.#assertRequired({ transportId }, ["transportId"]);

    await this.#update("sfu_transports", {
      status: "connected",
      last_heartbeat_at: new Date().toISOString(),
    }, {
      column: "transport_id",
      value: transportId,
    });
  }

  async markTransportClosed({ transportId, reason = null }) {
    this.#assertInitialized();
    this.#assertRequired({ transportId }, ["transportId"]);

    await this.#update("sfu_transports", {
      status: "closed",
      closed_at: new Date().toISOString(),
      failure_reason: reason,
    }, {
      column: "transport_id",
      value: transportId,
    });
  }

  async markTransportFailed({ transportId, reason }) {
    this.#assertInitialized();
    this.#assertRequired({ transportId, reason }, ["transportId", "reason"]);

    await this.#update("sfu_transports", {
      status: "failed",
      closed_at: new Date().toISOString(),
      failure_reason: reason,
    }, {
      column: "transport_id",
      value: transportId,
    });
  }

  async markProducerClosed({ producerId, reason = null }) {
    this.#assertInitialized();
    this.#assertRequired({ producerId }, ["producerId"]);

    await this.#update("sfu_producers", {
      status: "closed",
      closed_at: new Date().toISOString(),
      failure_reason: reason,
    }, {
      column: "producer_id",
      value: producerId,
    });
  }

  async markProducerFailed({ producerId, reason }) {
    this.#assertInitialized();
    this.#assertRequired({ producerId, reason }, ["producerId", "reason"]);

    await this.#update("sfu_producers", {
      status: "failed",
      closed_at: new Date().toISOString(),
      failure_reason: reason,
    }, {
      column: "producer_id",
      value: producerId,
    });
  }

  async markPeerLeft({ peerId, reason = null }) {
    this.#assertInitialized();
    this.#assertRequired({ peerId }, ["peerId"]);

    await this.#update("sfu_peers", {
      status: "left",
      left_at: new Date().toISOString(),
      failure_reason: reason,
    }, {
      column: "peer_id",
      value: peerId,
    });
  }

  async markPeerFailed({ peerId, reason }) {
    this.#assertInitialized();
    this.#assertRequired({ peerId, reason }, ["peerId", "reason"]);

    await this.#update("sfu_peers", {
      status: "failed",
      left_at: new Date().toISOString(),
      failure_reason: reason,
    }, {
      column: "peer_id",
      value: peerId,
    });
  }

  async recordPeerFault({ peerId, reason }) {
    this.#assertInitialized();
    this.#assertRequired({ peerId, reason }, ["peerId", "reason"]);

    await this.#update("sfu_peers", {
      failure_reason: reason,
      last_seen_at: new Date().toISOString(),
    }, {
      column: "peer_id",
      value: peerId,
    });
  }

  async markCallFailed({ callId, reason }) {
    this.#assertInitialized();
    this.#assertRequired({ callId, reason }, ["callId", "reason"]);

    await this.#update("sfu_call_rooms", {
      status: "failed",
      ended_at: new Date().toISOString(),
      failure_reason: reason,
      last_seen_at: new Date().toISOString(),
    }, {
      column: "call_id",
      value: callId,
    });
  }

  async markCallEnded({ callId }) {
    this.#assertInitialized();
    this.#assertRequired({ callId }, ["callId"]);

    await this.#update("sfu_call_rooms", {
      status: "ended",
      ended_at: new Date().toISOString(),
      last_seen_at: new Date().toISOString(),
    }, {
      column: "call_id",
      value: callId,
    });
  }

  async touchPeer({ peerId }) {
    this.#assertInitialized();
    this.#assertRequired({ peerId }, ["peerId"]);

    await this.#update("sfu_peers", {
      last_seen_at: new Date().toISOString(),
    }, {
      column: "peer_id",
      value: peerId,
    });
  }

  async recordRoomHeartbeat({ callId }) {
    this.#assertInitialized();
    this.#assertRequired({ callId }, ["callId"]);

    await this.#update("sfu_call_rooms", {
      last_seen_at: new Date().toISOString(),
    }, {
      column: "call_id",
      value: callId,
    });
  }

  async getCallRoom(callId) {
    this.#assertInitialized();
    return this.#selectSingle("sfu_call_rooms", {
      column: "call_id",
      value: callId,
    });
  }

  async #selectSingle(table, filter, allowView = false) {
    const query = this.client.from(table).select("*").eq(filter.column, filter.value);

    for (const extraFilter of filter.extraFilters || []) {
      query.eq(extraFilter.column, extraFilter.value);
    }

    const selector = allowView ? query.maybeSingle() : query.maybeSingle();
    const { data, error } = await selector;
    if (error) {
      throw error;
    }
    return data;
  }

  async #rpcSingle(fnName, payload) {
    const { data, error } = await this.client.rpc(fnName, payload);

    if (error) {
      throw error;
    }

    if (Array.isArray(data)) {
      return data[0] || null;
    }

    return data;
  }

  async #upsert(table, payload) {
    const { error } = await this.client
      .from(table)
      .upsert(payload);

    if (error) {
      throw error;
    }
  }

  async #update(table, payload, filter) {
    const { error } = await this.client
      .from(table)
      .update(payload)
      .eq(filter.column, filter.value);

    if (error) {
      throw error;
    }
  }

  #assertInitialized() {
    if (!this.initialized || !this.client) {
      throw new Error("SessionStateService is not initialized.");
    }
  }

  #assertRequired(source, keys) {
    for (const key of keys) {
      if (!source[key]) {
        throw new Error(`${key} is required.`);
      }
    }
  }
}

module.exports = {
  SessionStateService,
};
