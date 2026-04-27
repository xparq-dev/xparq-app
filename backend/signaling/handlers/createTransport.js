import { SfuClient } from '../services/sfuClient.js';
import { SessionRegistry } from '../services/sessionRegistry.js';
import { ok, fail } from '../utils/ack.js';

function errorCode(error, fallback) {
  return error.code || (error.message === 'NO_SESSION' ? 'NO_SESSION' : fallback);
}

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
      fail(ack, { code: errorCode(error, 'CREATE_TRANSPORT_FAILED'), message: error.message });
    }
  });
}
