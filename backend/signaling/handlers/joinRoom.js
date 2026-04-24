import { SfuClient } from '../services/sfuClient.js';
import { SessionRegistry } from '../services/sessionRegistry.js';
import { LoadBalancer } from '../services/loadBalancer.js';
import { ok, fail } from '../utils/ack.js';

function deriveCallId({ callId, roomId }) {
  if (callId) {
    return callId;
  }

  if (roomId?.startsWith('room_')) {
    return roomId.slice(5);
  }

  throw new Error('callId is required when roomId does not use the room_<callId> format.');
}

export function registerJoinRoom(
  socket,
  io,
  {
    registry = SessionRegistry,
    admissionControl,
    circuitBreaker,
    turnPolicyService = null,
    localRegion = process.env.REGION || 'us-east-1',
    localNodeId = process.env.NODE_ID || `node-${process.pid}`,
    loadBalancer = new LoadBalancer(),
  } = {},
) {
  socket.on('joinRoom', async (payload = {}, ack) => {
    try {
      const roomId = payload.roomId;
      const callId = deriveCallId(payload);
      const userId = socket.user.id;
      const peerId = socket.id;
      const requestId = payload.requestId || `join:${callId}:${peerId}:${Date.now()}`;
      const policyToken = typeof payload.policyToken === 'string' ? payload.policyToken : null;

      if (!roomId) {
        throw new Error('roomId is required.');
      }

      if (policyToken && turnPolicyService) {
        turnPolicyService.assertPolicyToken({
          policyToken,
          userId,
          roomId,
          callId,
        });
      }

      const existingRoomState = await registry.readRoomState(roomId);
      if (!circuitBreaker.shouldAllowSession({ isExistingSession: Boolean(existingRoomState) })) {
        const error = new Error('System protection mode is active. New sessions are temporarily blocked.');
        error.code = 'SYSTEM_PROTECTION_MODE';
        error.details = circuitBreaker.getState();
        throw error;
      }

      const runJoin = async () => {
        const roomState = await registry.getOrAssignRoomNode({
          roomId,
          callId,
          localRegion,
          selector: (nodes) => loadBalancer.selectBestNode(nodes) || nodes[0] || {
            nodeId: localNodeId,
            region: localRegion,
          },
        });

        if (roomState.nodeId !== localNodeId) {
          const healthyNodes = await registry.getHealthyNodes();
          const remoteNode = healthyNodes.find(
            (node) => (node.nodeId || node.id) === roomState.nodeId,
          );
          const error = new Error(
            `Room ${roomId} is currently pinned to node ${roomState.nodeId}.`,
          );
          error.code = 'ROOM_PINNED_REMOTE';
          error.details = {
            nodeId: roomState.nodeId,
            region: roomState.region,
            version: roomState.version,
            endpoint:
              roomState.metadata?.signalingEndpoint ||
              remoteNode?.signalingEndpoint ||
              remoteNode?.endpoint ||
              null,
          };
          throw error;
        }

        const data = await SfuClient.joinRoom({
          callId,
          roomId,
          userId,
          peerId,
          requestId,
          metadata: {
            region: localRegion,
            socketId: socket.id,
            reconnect: Boolean(existingRoomState),
          },
        });

        registry.bind(socket.id, {
          userId,
          roomId,
          callId,
          peerId,
          nodeId: roomState.nodeId,
          policyToken,
          joinedAt: Date.now(),
        });

        socket.join(roomId);

        return {
          ...data,
          roomState,
        };
      };

      const result = admissionControl
        ? await admissionControl.scheduleJoin({
            socket,
            roomId,
            isReconnect: Boolean(existingRoomState),
            task: runJoin,
          })
        : await runJoin();

      ok(ack, result);
    } catch (error) {
      fail(ack, {
        code: error.code || 'JOIN_FAILED',
        message: error.message,
        details: error.details,
      });
    }
  });
}
