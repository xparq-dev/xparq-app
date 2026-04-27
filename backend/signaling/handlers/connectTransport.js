import { SfuClient } from '../services/sfuClient.js';
import { SessionRegistry } from '../services/sessionRegistry.js';
import { ok, fail } from '../utils/ack.js';

function errorCode(error, fallback) {
  return error.code || (error.message === 'NO_SESSION' ? 'NO_SESSION' : fallback);
}

export function registerConnectTransport(socket) {
  socket.on('connectTransport', async ({ transportId, dtlsParameters }, ack) => {
    try {
      const session = SessionRegistry.get(socket.id);
      if (!session) {
        throw new Error('NO_SESSION');
      }

      await SfuClient.connectTransport({
        peerId: session.peerId,
        transportId,
        dtlsParameters,
      });

      await SfuClient.heartbeatTransport({
        peerId: session.peerId,
        transportId,
      });

      ok(ack, { connected: true });
    } catch (error) {
      fail(ack, { code: errorCode(error, 'CONNECT_TRANSPORT_FAILED'), message: error.message });
    }
  });
}
