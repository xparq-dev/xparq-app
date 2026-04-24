import { SfuClient } from '../services/sfuClient.js';
import { SessionRegistry } from '../services/sessionRegistry.js';
import { ok, fail } from '../utils/ack.js';

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
      fail(ack, { code: error.code || 'CONNECT_TRANSPORT_FAILED', message: error.message });
    }
  });
}
