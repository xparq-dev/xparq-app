const EventEmitter = require("events");
const { mediasoupConfig } = require("../config/mediasoupConfig");

class AudioRouterRegistry extends EventEmitter {
  constructor({
    workerPool,
    config = mediasoupConfig.router,
  }) {
    super();
    this.workerPool = workerPool;
    this.config = config;
    this.rooms = new Map();
  }

  async ensureRoom(roomId) {
    if (!roomId) {
      throw new Error("roomId is required.");
    }

    const existingRoom = this.rooms.get(roomId);
    if (existingRoom) {
      return existingRoom;
    }

    const worker = this.workerPool.getNextWorker();
    const router = await worker.createRouter({
      mediaCodecs: this.config.mediaCodecs,
    });

    const audioLevelObserver = await router.createAudioLevelObserver(
      this.config.audioLevelObserver,
    );

    const room = {
      roomId,
      router,
      workerId: worker.appData.workerId,
      audioLevelObserver,
      peers: new Set(),
      producers: new Set(),
    };

    audioLevelObserver.on("volumes", (volumes) => {
      this.emit("activeSpeaker", {
        roomId,
        volumes: volumes.map((entry) => ({
          producerId: entry.producer.id,
          peerId: entry.producer.appData.peerId || null,
          volume: entry.volume,
        })),
      });
    });

    audioLevelObserver.on("silence", () => {
      this.emit("silence", { roomId });
    });

    this.rooms.set(roomId, room);
    return room;
  }

  getRoomIfExists(roomId) {
    return this.rooms.get(roomId) || null;
  }

  getRoom(roomId) {
    const room = this.rooms.get(roomId);
    if (!room) {
      throw new Error(`Room ${roomId} was not found.`);
    }
    return room;
  }

  addPeer(roomId, peerId) {
    const room = this.getRoom(roomId);
    room.peers.add(peerId);
    return room;
  }

  async removePeer(roomId, peerId) {
    const room = this.getRoom(roomId);
    room.peers.delete(peerId);

    if (room.peers.size === 0) {
      await this.closeRoom(roomId);
    }
  }

  async attachProducer(roomId, producer) {
    const room = this.getRoom(roomId);
    room.producers.add(producer.id);
    await room.audioLevelObserver.addProducer({ producerId: producer.id });
  }

  async detachProducer(roomId, producerId) {
    const room = this.rooms.get(roomId);
    if (!room) {
      return;
    }

    room.producers.delete(producerId);

    if (typeof room.audioLevelObserver.removeProducer === "function") {
      try {
        await room.audioLevelObserver.removeProducer({ producerId });
      } catch (error) {
        this.emit("observerDetachFailed", {
          roomId,
          producerId,
          error,
        });
      }
    }
  }

  async closeRoom(roomId) {
    const room = this.rooms.get(roomId);
    if (!room) {
      return;
    }

    room.audioLevelObserver.close();
    room.router.close();
    this.rooms.delete(roomId);
  }

  listRoomIdsByWorker(workerId) {
    return Array.from(this.rooms.values())
      .filter((room) => room.workerId === workerId)
      .map((room) => room.roomId);
  }

  async close() {
    const roomIds = Array.from(this.rooms.keys());
    for (const roomId of roomIds) {
      await this.closeRoom(roomId);
    }
  }
}

module.exports = {
  AudioRouterRegistry,
};
