import { SfuClient } from '../services/sfuClient.js';
import { SessionRegistry } from '../services/sessionRegistry.js';
import { ok, fail } from '../utils/ack.js';

function errorCode(error, fallback) {
  return error.code || (error.message === 'NO_SESSION' ? 'NO_SESSION' : fallback);
}

export function registerProduce(socket, io) {
  socket.on('produce', async ({ transportId, kind, rtpParameters, requestId } = {}, ack) => {
    try {
      const session = SessionRegistry.get(socket.id);
      if (!session) {
        throw new Error('NO_SESSION');
      }

      const { producerId } = await SfuClient.produce({
        roomId: session.roomId,
        peerId: session.peerId,
        transportId,
        kind,
        rtpParameters,
        requestId: requestId || `produce:${session.peerId}:${kind}:${Date.now()}`,
      });

      socket.to(session.roomId).emit('newProducer', { producerId });

      ok(ack, { id: producerId });
    } catch (error) {
      fail(ack, { code: errorCode(error, 'PRODUCE_FAILED'), message: error.message });
    }
  });
}
