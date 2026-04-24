import { SfuClient } from '../services/sfuClient.js';
import { SessionRegistry } from '../services/sessionRegistry.js';
import { ok, fail } from '../utils/ack.js';

export function registerConsume(socket) {
  socket.on('consume', async ({ transportId, producerId, rtpCapabilities } = {}, ack) => {
    try {
      const session = SessionRegistry.get(socket.id);
      if (!session) {
        throw new Error('NO_SESSION');
      }

      const res = await SfuClient.consume({
        roomId: session.roomId,
        peerId: session.peerId,
        transportId,
        producerId,
        rtpCapabilities,
      });

      ok(ack, res);
    } catch (error) {
      fail(ack, { code: error.code || 'CONSUME_FAILED', message: error.message });
    }
  });
}
