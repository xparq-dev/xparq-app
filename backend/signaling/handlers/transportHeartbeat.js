import { SfuClient } from '../services/sfuClient.js';
import { recordTransportHeartbeatSample } from '../services/observabilityService.js';
import { SessionRegistry } from '../services/sessionRegistry.js';
import { ok, fail } from '../utils/ack.js';

export function registerTransportHeartbeat(socket) {
  socket.on('transportHeartbeat', async ({ transportId, metrics } = {}, ack) => {
    try {
      const session = SessionRegistry.get(socket.id);
      if (!session) {
        throw new Error('NO_SESSION');
      }

      const normalizedMetrics = {
        metricsMissing: metrics?.metricsMissing === true,
        rttMs: Number.isFinite(Number(metrics?.rttMs))
          ? Number(metrics.rttMs)
          : 250,
        packetLoss: Number.isFinite(Number(metrics?.packetLoss))
          ? Number(metrics.packetLoss)
          : 0.08,
        jitterMs: Number.isFinite(Number(metrics?.jitterMs))
          ? Number(metrics.jitterMs)
          : 45,
        availableOutgoingBitrate: Number.isFinite(Number(metrics?.availableOutgoingBitrate))
          ? Number(metrics.availableOutgoingBitrate)
          : 0,
      };
      recordTransportHeartbeatSample(normalizedMetrics);

      const policy = await SfuClient.updatePeerNetwork({
        peerId: session.peerId,
        transportId,
        metrics: normalizedMetrics,
      });

      ok(ack, { policy });
    } catch (error) {
      fail(ack, {
        code: error.code || 'TRANSPORT_HEARTBEAT_FAILED',
        message: error.message,
      });
    }
  });
}
