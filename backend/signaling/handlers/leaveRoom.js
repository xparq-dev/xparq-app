import { SfuClient } from '../services/sfuClient.js';
import { SessionRegistry } from '../services/sessionRegistry.js';

export function registerLeave(socket) {
  async function cleanup(reason = 'socket_cleanup') {
    const session = SessionRegistry.get(socket.id);
    if (!session) {
      return;
    }

    await SfuClient.leaveRoom({
      roomId: session.roomId,
      peerId: session.peerId,
      reason,
    });

    SessionRegistry.unbind(socket.id);
  }

  socket.on('leaveRoom', async (_, ack) => {
    await cleanup('leave_room');
    ack?.({ ok: true });
  });

  socket.on('disconnect', () => {
    cleanup('disconnect').catch((error) => {
      console.error('[LeaveRoom] Disconnect cleanup failed:', error);
    });
  });
}
