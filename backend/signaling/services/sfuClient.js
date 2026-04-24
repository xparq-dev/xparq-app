// backend/signaling/services/sfuClient.js
import { createAudioSfuService } from '../../../media/sfu-mediasoup/index.js';

let sfu;
export async function getSfu() {
  if (!sfu) sfu = await createAudioSfuService();
  return sfu;
}

// contract กลาง (อย่าให้ handler เรียก sfu ตรง ๆ)
export const SfuClient = {
  async joinRoom({ callId, roomId, userId, peerId, requestId, metadata }) {
    const sfu = await getSfu();
    return sfu.joinRoom({ callId, roomId, userId, peerId, requestId, metadata });
  },

  async createWebRtcTransport({ roomId, peerId, direction, requestId }) {
    const sfu = await getSfu();
    return sfu.createWebRtcTransport({ roomId, peerId, direction, requestId });
  },

  async connectTransport({ peerId, transportId, dtlsParameters }) {
    const sfu = await getSfu();
    return sfu.connectWebRtcTransport({ peerId, transportId, dtlsParameters });
  },

  async heartbeatTransport({ peerId, transportId }) {
    const sfu = await getSfu();
    return sfu.heartbeatTransport({ peerId, transportId });
  },

  async updatePeerNetwork({ peerId, transportId, metrics }) {
    const sfu = await getSfu();
    return sfu.updatePeerNetwork({ peerId, transportId, metrics });
  },

  async produce({ roomId, peerId, transportId, kind, rtpParameters, requestId }) {
    const sfu = await getSfu();
    return sfu.produceAudio({ roomId, peerId, transportId, kind, rtpParameters, requestId });
  },

  async consume({ roomId, peerId, transportId, producerId, rtpCapabilities }) {
    const sfu = await getSfu();
    return sfu.consumeAudio({ roomId, peerId, transportId, producerId, rtpCapabilities });
  },

  async leaveRoom({ roomId, peerId, reason }) {
    const sfu = await getSfu();
    return sfu.leaveRoom({ roomId, peerId, reason });
  },

  async getSystemLoad() {
    const sfu = await getSfu();
    return sfu.getSystemLoad();
  },
};
