import { SfuClient } from '../services/sfuClient.js';
import { SessionRegistry } from '../services/sessionRegistry.js';
import { ok, fail } from '../utils/ack.js';

export function registerCreateTransport(socket) {
  socket.on('createTransport', async ({ direction, requestId } = {}, ack) => {
    try {
      const session = SessionRegistry.get(socket.id);
      if (!session) {
        throw new Error('NO_SESSION');
      }

      const res = await SfuClient.createWebRtcTransport({
        roomId: session.roomId,
        peerId: session.peerId,
        direction,
        requestId: requestId || `transport:${session.peerId}:${direction}:${Date.now()}`,
      });

      ok(ack, res);
    } catch (error) {
      fail(ack, { code: error.code || 'CREATE_TRANSPORT_FAILED', message: error.message });
    }
  });
}
