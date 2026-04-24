const EventEmitter = require("events");
const mediasoup = require("mediasoup");
const { mediasoupConfig } = require("../config/mediasoupConfig");

class WorkerPool extends EventEmitter {
  constructor(config = mediasoupConfig.worker) {
    super();
    this.config = config;
    this.workers = [];
    this.nextWorkerIndex = 0;
    this.initialized = false;
    this.closing = false;
  }

  async init() {
    if (this.initialized) {
      return this.workers;
    }

    for (let index = 0; index < this.config.count; index += 1) {
      const worker = await this.#spawnWorker(index);
      this.workers.push(worker);
    }

    this.initialized = true;
    return this.workers;
  }

  getNextWorker() {
    if (!this.initialized || this.workers.length === 0) {
      throw new Error("Worker pool is not initialized.");
    }

    const worker = this.workers[this.nextWorkerIndex % this.workers.length];
    this.nextWorkerIndex = (this.nextWorkerIndex + 1) % this.workers.length;
    return worker;
  }

  async close() {
    this.closing = true;

    for (const worker of this.workers) {
      await worker.close();
    }

    this.workers = [];
    this.initialized = false;
  }

  getWorkerById(workerId) {
    return this.workers.find((worker) => worker.appData.workerId === workerId) || null;
  }

  async #spawnWorker(index) {
    const worker = await mediasoup.createWorker({
      rtcMinPort: this.config.rtcMinPort,
      rtcMaxPort: this.config.rtcMaxPort,
      logLevel: this.config.logLevel,
      logTags: this.config.logTags,
    });

    worker.appData = {
      workerId: `worker-${index}`,
      poolIndex: index,
    };

    worker.on("died", async () => {
      this.emit("workerDied", {
        workerId: worker.appData.workerId,
        poolIndex: index,
      });

      if (!this.closing && this.config.respawnOnDied) {
        try {
          const replacement = await this.#spawnWorker(index);
          const existingIndex = this.workers.findIndex(
            (candidate) => candidate.appData.poolIndex === index,
          );

          if (existingIndex >= 0) {
            this.workers[existingIndex] = replacement;
          } else {
            this.workers.push(replacement);
          }

          this.emit("workerRespawned", {
            previousWorkerId: worker.appData.workerId,
            workerId: replacement.appData.workerId,
            poolIndex: index,
          });
        } catch (error) {
          this.emit("workerRespawnFailed", {
            poolIndex: index,
            error,
          });
        }
      }
    });

    return worker;
  }
}

module.exports = {
  WorkerPool,
};
