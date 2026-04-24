import client from 'prom-client';

export const register = new client.Registry();

let initialized = false;

const activeRoomsGauge = new client.Gauge({
  name: 'xparq_active_rooms',
  help: 'Total number of active voice rooms',
  registers: [register],
});

const activePeersGauge = new client.Gauge({
  name: 'xparq_active_peers',
  help: 'Total number of active peers',
  registers: [register],
});

const activeTransportsGauge = new client.Gauge({
  name: 'xparq_active_transports',
  help: 'Total number of active SFU transports',
  registers: [register],
});

const nodeCpuGauge = new client.Gauge({
  name: 'xparq_node_cpu_percent',
  help: 'Estimated CPU utilization percentage for the signaling node',
  registers: [register],
});

const protectionModeGauge = new client.Gauge({
  name: 'xparq_protection_mode',
  help: 'Whether the signaling cluster is in protection mode',
  registers: [register],
});

const joinQueueGauge = new client.Gauge({
  name: 'xparq_rejoin_queue_depth',
  help: 'Current reconnect admission queue depth',
  registers: [register],
});

const healthyNodesGauge = new client.Gauge({
  name: 'xparq_healthy_nodes',
  help: 'Number of healthy signaling nodes discovered via Redis heartbeats',
  registers: [register],
});

const nodeHeartbeatAgeGauge = new client.Gauge({
  name: 'xparq_node_heartbeat_age_ms',
  help: 'Age of the latest known node heartbeat in milliseconds',
  labelNames: ['peer_node_id', 'peer_region'],
  registers: [register],
});

const transportRttGauge = new client.Gauge({
  name: 'xparq_transport_rtt_ms',
  help: 'Latest RTT sample reported by connected clients',
  registers: [register],
});

const transportPacketLossGauge = new client.Gauge({
  name: 'xparq_transport_packet_loss_ratio',
  help: 'Latest packet loss ratio reported by connected clients',
  registers: [register],
});

const transportJitterGauge = new client.Gauge({
  name: 'xparq_transport_jitter_ms',
  help: 'Latest jitter sample reported by connected clients',
  registers: [register],
});

const transportSamplesCounter = new client.Counter({
  name: 'xparq_transport_samples_total',
  help: 'Total number of client transport heartbeat samples processed',
  labelNames: ['status'],
  registers: [register],
});

const turnPolicyCounter = new client.Counter({
  name: 'xparq_turn_policy_requests_total',
  help: 'Total number of TURN policy requests handled by signaling',
  labelNames: ['requested_policy', 'enforced_policy', 'outcome'],
  registers: [register],
});

const turnCredentialsCounter = new client.Counter({
  name: 'xparq_turn_credentials_issued_total',
  help: 'Total number of TURN credentials issued by signaling',
  labelNames: ['outcome'],
  registers: [register],
});

const redisLatencyHistogram = new client.Histogram({
  name: 'xparq_redis_command_latency_ms',
  help: 'Latency of Redis commands executed by the signaling control plane',
  labelNames: ['operation'],
  buckets: [1, 5, 10, 25, 50, 100, 250, 500, 1000],
  registers: [register],
});

export function initializeObservability({ region, nodeId }) {
  if (initialized) {
    return;
  }

  register.setDefaultLabels({
    region,
    node_id: nodeId,
  });
  client.collectDefaultMetrics({ register });
  initialized = true;
}

export function updateControlPlaneMetrics({
  activeRooms = 0,
  activePeers = 0,
  transports = 0,
  queueDepth = 0,
  protectionMode = false,
  cpuPercent = 0,
  healthyNodes = [],
} = {}) {
  activeRoomsGauge.set(activeRooms);
  activePeersGauge.set(activePeers);
  activeTransportsGauge.set(transports);
  joinQueueGauge.set(queueDepth);
  protectionModeGauge.set(protectionMode ? 1 : 0);
  nodeCpuGauge.set(cpuPercent);
  healthyNodesGauge.set(healthyNodes.length);

  nodeHeartbeatAgeGauge.reset();
  for (const node of healthyNodes) {
    const nodeId = node.nodeId || node.id || 'unknown';
    const region = node.region || 'unknown';
    const lastSeenAt = Number(node.lastSeenAt || 0);
    const ageMs = lastSeenAt > 0 ? Math.max(0, Date.now() - lastSeenAt) : 0;

    nodeHeartbeatAgeGauge.labels(nodeId, region).set(ageMs);
  }
}

export function recordTransportHeartbeatSample(sample = {}) {
  const status = sample.metricsMissing ? 'fallback' : 'ok';
  transportSamplesCounter.inc({ status });

  if (Number.isFinite(sample.rttMs)) {
    transportRttGauge.set(Number(sample.rttMs));
  }

  if (Number.isFinite(sample.packetLoss)) {
    transportPacketLossGauge.set(Number(sample.packetLoss));
  }

  if (Number.isFinite(sample.jitterMs)) {
    transportJitterGauge.set(Number(sample.jitterMs));
  }
}

export function recordTurnPolicyDecision({
  requestedPolicy = 'all',
  enforcedPolicy = 'all',
  outcome = 'allowed',
} = {}) {
  turnPolicyCounter.inc({
    requested_policy: requestedPolicy,
    enforced_policy: enforcedPolicy,
    outcome,
  });

  if (outcome === 'issued') {
    turnCredentialsCounter.inc({ outcome: 'issued' });
  } else if (outcome === 'blocked') {
    turnCredentialsCounter.inc({ outcome: 'blocked' });
  }
}

export function observeRedisLatency(operation, durationMs) {
  if (!Number.isFinite(durationMs)) {
    return;
  }

  redisLatencyHistogram.observe({ operation }, durationMs);
}
