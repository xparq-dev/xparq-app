const EventEmitter = require("events");
const { mediasoupConfig } = require("../config/mediasoupConfig");
const { WorkerPool } = require("../workers/workerPool");
const { AudioRouterRegistry } = require("../routers/audioRouterRegistry");
const { WebRtcTransportRegistry } = require("../transports/webRtcTransportRegistry");
const { SessionStateService } = require("./sessionStateService");
const { AdaptiveQualityController } = require("./adaptiveQualityController");

class AudioSfuService extends EventEmitter {
  constructor({
    sfuConfig = mediasoupConfig.sfu,
    workerPool = new WorkerPool(),
    routerRegistry,
    transportRegistry = new WebRtcTransportRegistry(),
    stateService = new SessionStateService(),
    qualityController = new AdaptiveQualityController(mediasoupConfig.adaptiveQuality),
  } = {}) {
    super();
    this.sfuConfig = sfuConfig;
    this.workerPool = workerPool;
    this.routerRegistry =
      routerRegistry ||
      new AudioRouterRegistry({
        workerPool: this.workerPool,
      });
    this.transportRegistry = transportRegistry;
    this.stateService = stateService;
    this.qualityController = qualityController;
    this.peers = new Map();
    this.roomSessions = new Map();
    this.producers = new Map();
    this.consumers = new Map();
    this.peerNetworkPolicies = new Map();
    this.inFlightJoinRequests = new Map();
    this.inFlightTransportRequests = new Map();
    this.inFlightProducerRequests = new Map();
    this.roomLeaseRenewHandle = null;
    this.started = false;

    this.#wireInfrastructureEvents();
  }

  async start() {
    if (this.started) {
      return;
    }

    await this.workerPool.init();
    await this.stateService.init();
    this.transportRegistry.start();
    this.#startRoomLeaseRenewer();
    this.started = true;
  }

  async close() {
    this.#stopRoomLeaseRenewer();
    await this.routerRegistry.close();
    this.transportRegistry.close();
    await this.workerPool.close();
    this.peers.clear();
    this.roomSessions.clear();
    this.producers.clear();
    this.consumers.clear();
    this.peerNetworkPolicies.clear();
    this.started = false;
  }

  async joinRoom({
    callId,
    roomId,
    peerId,
    userId,
    requestId,
    metadata = {},
  }) {
    this.#assertStarted();

    if (!callId || !roomId || !peerId || !userId) {
      throw new Error("callId, roomId, peerId, and userId are required.");
    }

    const joinRequestId =
      requestId || `join:${callId}:${roomId}:${peerId}:${userId}`;

    return this.#withSingleFlight(
      this.inFlightJoinRequests,
      joinRequestId,
      async () => {
        const existingPeer = this.peers.get(peerId);
        if (existingPeer && existingPeer.roomId !== roomId) {
          throw new Error(`Peer ${peerId} is already joined to a different room.`);
        }

        const duplicateLocalPeer = Array.from(this.peers.values()).find(
          (candidate) =>
            candidate.roomId === roomId &&
            candidate.userId === userId &&
            candidate.peerId !== peerId,
        );
        if (duplicateLocalPeer) {
          throw new Error(
            `User ${userId} already has an active peer in room ${roomId}.`,
          );
        }

        let room = this.routerRegistry.getRoomIfExists(roomId);
        await this.stateService.claimRoomLease({
          callId,
          roomId,
          workerId: room?.workerId || null,
          leaseMs: this.sfuConfig.roomLeaseMs,
        });

        if (!room) {
          room = await this.routerRegistry.ensureRoom(roomId);
          await this.stateService.claimRoomLease({
            callId,
            roomId,
            workerId: room.workerId,
            leaseMs: this.sfuConfig.roomLeaseMs,
          });
        }

        await this.stateService.bindPeer({
          callId,
          roomId,
          peerId,
          userId,
          requestId: joinRequestId,
          metadata,
        });

        if (!existingPeer) {
          this.peers.set(peerId, {
            callId,
            peerId,
            userId,
            roomId,
            metadata,
            transports: new Set(),
            producers: new Set(),
            consumers: new Set(),
          });
        }

        this.roomSessions.set(roomId, {
          callId,
          roomId,
          workerId: room.workerId,
        });
        this.routerRegistry.addPeer(roomId, peerId);

        return {
          callId,
          roomId,
          peerId,
          userId,
          routerRtpCapabilities: room.router.rtpCapabilities,
          existingProducerIds: Array.from(room.producers).filter(
            (producerId) => this.producers.get(producerId)?.peerId !== peerId,
          ),
          workerId: room.workerId,
        };
      },
    );
  }

  async leaveRoom({ roomId, peerId, reason = null }) {
    this.#assertStarted();

    const peer = this.#getPeer(peerId);
    if (peer.roomId !== roomId) {
      throw new Error(`Peer ${peerId} is not part of room ${roomId}.`);
    }

    await this.#closePeerConsumers(peerId);
    await this.#closePeerProducers(peerId);
    this.transportRegistry.closePeerTransports(peerId);
    this.peers.delete(peerId);
    await this.stateService.markPeerLeft({ peerId, reason });
    await this.stateService.recordRoomHeartbeat({ callId: peer.callId });
    await this.routerRegistry.removePeer(roomId, peerId);

    if (!this.routerRegistry.getRoomIfExists(roomId)) {
      this.roomSessions.delete(roomId);
      await this.stateService.markCallEnded({ callId: peer.callId });
    }
  }

  async createWebRtcTransport({ roomId, peerId, direction, requestId }) {
    this.#assertStarted();
    const transportRequestId =
      requestId || `transport:${peerId}:${direction}`;

    return this.#withSingleFlight(
      this.inFlightTransportRequests,
      transportRequestId,
      async () => {
        const peer = this.#getPeer(peerId);
        if (peer.roomId !== roomId) {
          throw new Error(`Peer ${peerId} is not part of room ${roomId}.`);
        }

        const existingTransport = this.transportRegistry.findActiveTransportByPeer(
          peerId,
          direction,
        );
        if (existingTransport) {
          return this.transportRegistry.describeTransport(
            existingTransport.transport.id,
          );
        }

        const room = this.routerRegistry.getRoom(roomId);
        const transportOptions = await this.transportRegistry.createTransport({
          router: room.router,
          roomId,
          peerId,
          direction,
        });

        try {
          await this.stateService.registerTransport({
            transportId: transportOptions.id,
            callId: peer.callId,
            roomId,
            peerId,
            userId: peer.userId,
            direction,
            requestId: transportRequestId,
            idleTimeoutMs: this.transportRegistry.config.idleTimeoutMs,
          });
        } catch (error) {
          this.transportRegistry.closeTransport(transportOptions.id);

          if (error.code === "23505") {
            const duplicateTransport =
              this.transportRegistry.findActiveTransportByPeer(peerId, direction);
            if (duplicateTransport) {
              return this.transportRegistry.describeTransport(
                duplicateTransport.transport.id,
              );
            }
          }

          throw error;
        }

        peer.transports.add(transportOptions.id);
        return transportOptions;
      },
    );
  }

  async connectWebRtcTransport({ peerId, transportId, dtlsParameters }) {
    this.#assertStarted();
    this.#assertTransportOwnership(peerId, transportId);
    await this.transportRegistry.connectTransport({
      transportId,
      dtlsParameters,
    });
    await this.stateService.markTransportConnected({ transportId });
    await this.stateService.touchPeer({ peerId });
  }

  async heartbeatTransport({ peerId, transportId }) {
    this.#assertStarted();
    this.#assertTransportOwnership(peerId, transportId);
    this.transportRegistry.touchTransport(transportId);
    await this.stateService.touchTransportHeartbeat({ transportId });
    await this.stateService.touchPeer({ peerId });
  }

  async updatePeerNetwork({
    peerId,
    transportId,
    metrics = {},
  }) {
    this.#assertStarted();
    this.#assertTransportOwnership(peerId, transportId);

    const transportRecord = this.transportRegistry.getTransport(transportId);
    const policy = this.qualityController.evaluate(metrics);
    await this.qualityController.applyToTransport(
      transportRecord.transport,
      policy,
    );

    const appliedPolicy = {
      ...policy,
      transportId,
      updatedAt: Date.now(),
    };

    this.peerNetworkPolicies.set(peerId, appliedPolicy);
    await this.stateService.touchTransportHeartbeat({ transportId });
    await this.stateService.touchPeer({ peerId });
    return appliedPolicy;
  }

  async produceAudio({
    roomId,
    peerId,
    transportId,
    requestId,
    kind,
    rtpParameters,
    appData = {},
  }) {
    this.#assertStarted();
    if (kind !== "audio") {
      throw new Error("This SFU only accepts audio producers.");
    }

    const producerRequestId = requestId || `produce:${peerId}:${kind}`;

    return this.#withSingleFlight(
      this.inFlightProducerRequests,
      producerRequestId,
      async () => {
        const peer = this.#getPeer(peerId);
        if (peer.roomId !== roomId) {
          throw new Error(`Peer ${peerId} is not part of room ${roomId}.`);
        }

        const existingProducer = this.#findActiveProducerByPeer(peerId, kind);
        if (existingProducer) {
          return {
            producerId: existingProducer.producer.id,
          };
        }

        const record = this.transportRegistry.getTransport(transportId);
        if (record.peerId !== peerId || record.direction !== "send") {
          throw new Error("A send transport owned by the peer is required.");
        }

        let producer;
        try {
          producer = await record.transport.produce({
            kind,
            rtpParameters,
            appData: {
              ...appData,
              roomId,
              peerId,
              mediaKind: "audio",
            },
          });
        } catch (error) {
          this.emit("producerFailed", {
            roomId,
            peerId,
            transportId,
            error,
          });
          await this.stateService.recordPeerFault({
            peerId,
            reason: "produce_failed",
          });
          throw error;
        }

        try {
          await this.stateService.registerProducer({
            producerId: producer.id,
            callId: peer.callId,
            roomId,
            peerId,
            userId: peer.userId,
            transportId,
            kind,
            requestId: producerRequestId,
          });
        } catch (error) {
          producer.close();

          if (error.code === "23505") {
            const duplicateProducer = this.#findActiveProducerByPeer(peerId, kind);
            if (duplicateProducer) {
              return {
                producerId: duplicateProducer.producer.id,
              };
            }
          }

          throw error;
        }

        producer.on("transportclose", async () => {
          await this.#removeProducer({
            roomId,
            peerId,
            producerId: producer.id,
          });
        });

        producer.on("close", async () => {
          await this.#removeProducer({
            roomId,
            peerId,
            producerId: producer.id,
          });
        });

        peer.producers.add(producer.id);
        this.producers.set(producer.id, {
          producer,
          roomId,
          peerId,
          transportId,
          kind,
        });
        await this.routerRegistry.attachProducer(roomId, producer);
        await this.stateService.touchPeer({ peerId });
        await this.stateService.touchTransportHeartbeat({ transportId });

        return {
          producerId: producer.id,
        };
      },
    );
  }

  async consumeAudio({
    roomId,
    peerId,
    transportId,
    producerId,
    rtpCapabilities,
  }) {
    this.#assertStarted();
    const peer = this.#getPeer(peerId);
    if (peer.roomId !== roomId) {
      throw new Error(`Peer ${peerId} is not part of room ${roomId}.`);
    }

    const producerRecord = this.producers.get(producerId);
    if (!producerRecord) {
      throw new Error(`Producer ${producerId} was not found.`);
    }
    if (producerRecord.roomId !== roomId) {
      throw new Error("Producer belongs to a different room.");
    }
    if (producerRecord.peerId === peerId) {
      throw new Error("A peer cannot consume its own producer.");
    }

    const transportRecord = this.transportRegistry.getTransport(transportId);
    if (transportRecord.peerId !== peerId || transportRecord.direction !== "recv") {
      throw new Error("A recv transport owned by the peer is required.");
    }

    const room = this.routerRegistry.getRoom(roomId);
    if (
      !room.router.canConsume({
        producerId,
        rtpCapabilities,
      })
    ) {
      throw new Error("Router cannot consume the requested audio producer.");
    }

    let consumer;
    try {
      consumer = await transportRecord.transport.consume({
        producerId,
        rtpCapabilities,
        paused: false,
        appData: {
          roomId,
          peerId,
          remotePeerId: producerRecord.peerId,
          mediaKind: "audio",
        },
      });
    } catch (error) {
      this.emit("consumerFailed", {
        roomId,
        peerId,
        transportId,
        producerId,
        error,
      });
      await this.stateService.recordPeerFault({
        peerId,
        reason: "consume_failed",
      });
      throw error;
    }

    consumer.on("transportclose", () => {
      this.#removeConsumer({
        peerId,
        consumerId: consumer.id,
      });
    });

    consumer.on("producerclose", () => {
      this.#removeConsumer({
        peerId,
        consumerId: consumer.id,
      });
    });

    peer.consumers.add(consumer.id);
    this.consumers.set(consumer.id, {
      consumer,
      roomId,
      peerId,
      producerId,
      transportId,
    });
    await this.stateService.touchPeer({ peerId });
    await this.stateService.touchTransportHeartbeat({ transportId });

    return {
      consumerId: consumer.id,
      producerId,
      kind: consumer.kind,
      rtpParameters: consumer.rtpParameters,
      type: consumer.type,
      producerPaused: consumer.producerPaused,
    };
  }

  getRoomSummary(roomId) {
    const room = this.routerRegistry.getRoom(roomId);
    return {
      roomId,
      workerId: room.workerId,
      peerCount: room.peers.size,
      producerCount: room.producers.size,
      rtpCapabilities: room.router.rtpCapabilities,
    };
  }

  getSystemLoad() {
    return {
      rooms: this.roomSessions.size,
      peers: this.peers.size,
      transports: this.transportRegistry.transports.size,
      producers: this.producers.size,
      consumers: this.consumers.size,
    };
  }

  #assertStarted() {
    if (!this.started) {
      throw new Error("Audio SFU service has not been started.");
    }
  }

  #getPeer(peerId) {
    const peer = this.peers.get(peerId);
    if (!peer) {
      throw new Error(`Peer ${peerId} was not found.`);
    }
    return peer;
  }

  #assertTransportOwnership(peerId, transportId) {
    const peer = this.#getPeer(peerId);
    if (!peer.transports.has(transportId)) {
      throw new Error(`Transport ${transportId} is not owned by peer ${peerId}.`);
    }
  }

  async #closePeerProducers(peerId) {
    const peer = this.#getPeer(peerId);
    const producerIds = Array.from(peer.producers);

    for (const producerId of producerIds) {
      const record = this.producers.get(producerId);
      if (record) {
        record.producer.close();
      }
      await this.#removeProducer({
        roomId: peer.roomId,
        peerId,
        producerId,
      });
    }
  }

  async #closePeerConsumers(peerId) {
    const peer = this.#getPeer(peerId);
    const consumerIds = Array.from(peer.consumers);

    for (const consumerId of consumerIds) {
      const record = this.consumers.get(consumerId);
      if (record) {
        record.consumer.close();
      }
      this.#removeConsumer({
        peerId,
        consumerId,
      });
    }
  }

  async #removeProducer({ roomId, peerId, producerId }) {
    const peer = this.peers.get(peerId);
    if (peer) {
      peer.producers.delete(producerId);
    }

    await this.stateService.markProducerClosed({
      producerId,
      reason: "closed",
    });
    this.producers.delete(producerId);
    await this.routerRegistry.detachProducer(roomId, producerId);

    const impactedConsumers = Array.from(this.consumers.entries())
      .filter(([, record]) => record.producerId === producerId)
      .map(([consumerId, record]) => ({
        consumerId,
        peerId: record.peerId,
      }));

    for (const impacted of impactedConsumers) {
      this.#removeConsumer(impacted);
    }
  }

  #removeConsumer({ peerId, consumerId }) {
    const peer = this.peers.get(peerId);
    if (peer) {
      peer.consumers.delete(consumerId);
    }
    this.consumers.delete(consumerId);
  }

  #wireInfrastructureEvents() {
    this.workerPool.on("workerDied", (payload) => {
      this.emit("workerDied", payload);
      this.#runAsyncSideEffect(this.#handleWorkerDied(payload));
    });

    this.routerRegistry.on("activeSpeaker", (payload) => {
      this.emit("activeSpeaker", payload);
    });

    this.routerRegistry.on("silence", (payload) => {
      this.emit("silence", payload);
    });

    this.transportRegistry.on("transportClosed", (payload) => {
      this.emit("transportClosed", payload);
      this.#runAsyncSideEffect(this.#handleTransportClosed(payload));
    });

    this.transportRegistry.on("transportIdleTimeout", (payload) => {
      this.emit("transportIdleTimeout", payload);
      this.#runAsyncSideEffect(this.#handleTransportIdleTimeout(payload));
    });

    this.transportRegistry.on("transportFailed", (payload) => {
      this.emit("transportFailed", payload);
      this.#runAsyncSideEffect(this.#handleTransportFailed(payload));
    });
  }

  async #handleWorkerDied({ workerId }) {
    const roomIds = this.routerRegistry.listRoomIdsByWorker(workerId);

    for (const roomId of roomIds) {
      const roomSession = this.roomSessions.get(roomId);
      const affectedPeers = Array.from(this.peers.values()).filter(
        (peer) => peer.roomId === roomId,
      );

      for (const peer of affectedPeers) {
        await this.stateService.markPeerFailed({
          peerId: peer.peerId,
          reason: "worker_crash",
        });
        this.transportRegistry.closePeerTransports(peer.peerId);
        this.peers.delete(peer.peerId);
      }

      const callId = roomSession?.callId || affectedPeers[0]?.callId;
      if (callId) {
        await this.stateService.markCallFailed({
          callId,
          reason: "worker_crash",
        });
      }

      this.roomSessions.delete(roomId);
      await this.routerRegistry.closeRoom(roomId);
    }
  }

  async #handleTransportClosed({ transportId, peerId }) {
    const peer = this.peers.get(peerId);
    if (!peer) {
      await this.stateService.markTransportClosed({ transportId, reason: "closed" });
      return;
    }

    peer.transports.delete(transportId);
    await this.stateService.markTransportClosed({ transportId, reason: "closed" });

    if (
      peer.transports.size === 0 &&
      peer.producers.size === 0 &&
      peer.consumers.size === 0
    ) {
      await this.leaveRoom({
        roomId: peer.roomId,
        peerId,
        reason: "transport_closed",
      });
    }
  }

  async #handleTransportIdleTimeout({ transportId, peerId }) {
    await this.stateService.markTransportFailed({
      transportId,
      reason: "transport_idle_timeout",
    });

    const peer = this.peers.get(peerId);
    if (!peer) {
      return;
    }

    if (
      peer.transports.size <= 1 &&
      peer.producers.size === 0 &&
      peer.consumers.size === 0
    ) {
      await this.leaveRoom({
        roomId: peer.roomId,
        peerId,
        reason: "transport_idle_timeout",
      });
    }
  }

  async #handleTransportFailed({ transportId, peerId, reason }) {
    await this.stateService.markTransportFailed({
      transportId,
      reason,
    });

    const peer = this.peers.get(peerId);
    if (!peer) {
      return;
    }

    await this.stateService.recordPeerFault({
      peerId,
      reason,
    });
  }

  #findActiveProducerByPeer(peerId, kind) {
    for (const record of this.producers.values()) {
      if (
        record.peerId === peerId &&
        record.kind === kind &&
        record.producer.closed !== true
      ) {
        return record;
      }
    }

    return null;
  }

  #startRoomLeaseRenewer() {
    if (this.roomLeaseRenewHandle) {
      return;
    }

    this.roomLeaseRenewHandle = setInterval(() => {
      this.#runAsyncSideEffect(this.#renewOwnedRooms());
    }, this.sfuConfig.roomLeaseRenewIntervalMs);

    if (typeof this.roomLeaseRenewHandle.unref === "function") {
      this.roomLeaseRenewHandle.unref();
    }
  }

  #stopRoomLeaseRenewer() {
    if (!this.roomLeaseRenewHandle) {
      return;
    }

    clearInterval(this.roomLeaseRenewHandle);
    this.roomLeaseRenewHandle = null;
  }

  async #renewOwnedRooms() {
    for (const roomSession of this.roomSessions.values()) {
      try {
        const room = this.routerRegistry.getRoomIfExists(roomSession.roomId);
        await this.stateService.claimRoomLease({
          callId: roomSession.callId,
          roomId: roomSession.roomId,
          workerId: room?.workerId || roomSession.workerId,
          leaseMs: this.sfuConfig.roomLeaseMs,
        });
      } catch (error) {
        this.emit("roomOwnershipLost", {
          roomId: roomSession.roomId,
          callId: roomSession.callId,
          error,
        });
        if (error.code === "ROOM_OWNED_BY_OTHER_INSTANCE") {
          await this.#releaseRoomLocally(roomSession.roomId);
        }
      }
    }
  }

  async #releaseRoomLocally(roomId) {
    const affectedPeers = Array.from(this.peers.values()).filter(
      (peer) => peer.roomId === roomId,
    );

    for (const peer of affectedPeers) {
      this.transportRegistry.closePeerTransports(peer.peerId);
      this.peers.delete(peer.peerId);
    }

    this.roomSessions.delete(roomId);
    await this.routerRegistry.closeRoom(roomId);
  }

  async #withSingleFlight(map, key, operation) {
    if (map.has(key)) {
      return map.get(key);
    }

    const promise = Promise.resolve()
      .then(operation)
      .finally(() => {
        map.delete(key);
      });

    map.set(key, promise);
    return promise;
  }

  #runAsyncSideEffect(promise) {
    promise.catch((error) => {
      this.emit("stateSyncFailed", { error });
    });
  }
}

module.exports = {
  AudioSfuService,
};
