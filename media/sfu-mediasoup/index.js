require('dotenv').config();

const { mediasoupConfig } = require("./config/mediasoupConfig");
const { WorkerPool } = require("./workers/workerPool");
const { AudioRouterRegistry } = require("./routers/audioRouterRegistry");
const { WebRtcTransportRegistry } = require("./transports/webRtcTransportRegistry");
const { AudioSfuService } = require("./services/audioSfuService");
const { SessionStateService } = require("./services/sessionStateService");

async function createAudioSfuService(options = {}) {
  const service = new AudioSfuService(options);
  await service.start();
  return service;
}

if (require.main === module) {
  createAudioSfuService()
    .then(() => {
      console.log("Audio SFU service initialized.");
    })
    .catch((error) => {
      console.error("Failed to initialize Audio SFU service.", error);
      process.exitCode = 1;
    });
}

module.exports = {
  mediasoupConfig,
  WorkerPool,
  AudioRouterRegistry,
  WebRtcTransportRegistry,
  AudioSfuService,
  SessionStateService,
  createAudioSfuService,
};
