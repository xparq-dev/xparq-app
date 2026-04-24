const EventEmitter = require("events");
const { mediasoupConfig } = require("../config/mediasoupConfig");

class WebRtcTransportRegistry extends EventEmitter {
  constructor(config = mediasoupConfig.webRtcTransport) {
    super();
    this.config = config;
    this.transports = new Map();
    this.monitorHandle = null;
  }

  start() {
    if (this.monitorHandle) {
      return;
    }

    this.monitorHandle = setInterval(() => {
      this.#sweepIdleTransports();
    }, this.config.cleanupIntervalMs);

    if (typeof this.monitorHandle.unref === "function") {
      this.monitorHandle.unref();
    }
  }

  stop() {
    if (!this.monitorHandle) {
      return;
    }
    clearInterval(this.monitorHandle);
    this.monitorHandle = null;
  }

  async createTransport({ router, roomId, peerId, direction }) {
    if (!router) {
      throw new Error("router is required.");
    }
    if (!roomId || !peerId || !direction) {
      throw new Error("roomId, peerId, and direction are required.");
    }

    const transport = await router.createWebRtcTransport({
      listenIps: this.config.listenIps,
      enableUdp: this.config.enableUdp,
      enableTcp: this.config.enableTcp,
      preferUdp: this.config.preferUdp,
      enableSctp: this.config.enableSctp,
      initialAvailableOutgoingBitrate:
        this.config.initialAvailableOutgoingBitrate,
      minimumAvailableOutgoingBitrate:
        this.config.minimumAvailableOutgoingBitrate,
      appData: {
        roomId,
        peerId,
        direction,
      },
    });

    if (this.config.maxIncomingBitrate) {
      await transport.setMaxIncomingBitrate(this.config.maxIncomingBitrate);
    }

    transport.on("dtlsstatechange", (dtlsState) => {
      const record = this.transports.get(transport.id);
      if (record && dtlsState === "connected") {
        record.state = "connected";
        record.connectedAt = Date.now();
        record.lastHeartbeatAt = Date.now();
      }

      this.emit("dtlsStateChanged", {
        transportId: transport.id,
        dtlsState,
        roomId,
        peerId,
        direction,
      });

      if (dtlsState === "closed") {
        transport.close();
      } else if (dtlsState === "failed") {
        this.failTransport(transport.id, "dtls_failed");
      }
    });

    transport.on("icestatechange", (iceState) => {
      const record = this.transports.get(transport.id);
      if (record && (iceState === "connected" || iceState === "completed")) {
        record.lastHeartbeatAt = Date.now();
      }

      this.emit("iceStateChanged", {
        transportId: transport.id,
        iceState,
        roomId,
        peerId,
        direction,
      });

      if (iceState === "failed") {
        this.failTransport(transport.id, "ice_failed");
      }
    });

    transport.on("close", () => {
      const record = this.transports.get(transport.id);
      this.transports.delete(transport.id);
      this.emit("transportClosed", {
        transportId: transport.id,
        roomId,
        peerId,
        direction,
        state: record?.state || "closed",
      });
    });

    const now = Date.now();

    this.transports.set(transport.id, {
      transport,
      roomId,
      peerId,
      direction,
      state: "created",
      createdAt: now,
      connectedAt: null,
      lastHeartbeatAt: now,
      idleTimeoutMs: this.config.idleTimeoutMs,
    });

    return {
      id: transport.id,
      iceParameters: transport.iceParameters,
      iceCandidates: transport.iceCandidates,
      dtlsParameters: transport.dtlsParameters,
    };
  }

  getTransport(transportId) {
    const record = this.transports.get(transportId);
    if (!record) {
      throw new Error(`Transport ${transportId} was not found.`);
    }
    return record;
  }

  findActiveTransportByPeer(peerId, direction) {
    for (const record of this.transports.values()) {
      if (
        record.peerId === peerId &&
        record.direction === direction &&
        record.transport.closed !== true
      ) {
        return record;
      }
    }

    return null;
  }

  describeTransport(transportId) {
    const record = this.getTransport(transportId);
    return {
      id: record.transport.id,
      iceParameters: record.transport.iceParameters,
      iceCandidates: record.transport.iceCandidates,
      dtlsParameters: record.transport.dtlsParameters,
    };
  }

  async connectTransport({ transportId, dtlsParameters }) {
    const record = this.getTransport(transportId);
    await record.transport.connect({ dtlsParameters });
    record.state = "connected";
    record.connectedAt = Date.now();
    record.lastHeartbeatAt = Date.now();
    return record.transport;
  }

  touchTransport(transportId) {
    const record = this.getTransport(transportId);
    record.lastHeartbeatAt = Date.now();
    if (record.state === "created") {
      record.state = "connected";
    }
    return record;
  }

  failTransport(transportId, reason) {
    const record = this.transports.get(transportId);
    if (!record) {
      return;
    }

    this.emit("transportFailed", {
      transportId,
      roomId: record.roomId,
      peerId: record.peerId,
      direction: record.direction,
      reason,
    });
    record.transport.close();
  }

  closeTransport(transportId) {
    const record = this.transports.get(transportId);
    if (!record) {
      return;
    }
    record.transport.close();
  }

  closePeerTransports(peerId) {
    const transportIds = Array.from(this.transports.entries())
      .filter(([, record]) => record.peerId === peerId)
      .map(([transportId]) => transportId);

    for (const transportId of transportIds) {
      this.closeTransport(transportId);
    }
  }

  close() {
    this.stop();
    const transportIds = Array.from(this.transports.keys());
    for (const transportId of transportIds) {
      this.closeTransport(transportId);
    }
  }

  #sweepIdleTransports() {
    const now = Date.now();

    for (const [transportId, record] of this.transports.entries()) {
      const idleForMs = now - record.lastHeartbeatAt;
      const idleThresholdMs = record.idleTimeoutMs + this.config.heartbeatGraceMs;

      if (idleForMs < idleThresholdMs) {
        continue;
      }

      this.emit("transportIdleTimeout", {
        transportId,
        roomId: record.roomId,
        peerId: record.peerId,
        direction: record.direction,
        idleForMs,
      });
      record.transport.close();
    }
  }
}

module.exports = {
  WebRtcTransportRegistry,
};
