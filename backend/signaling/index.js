import 'dotenv/config';
import cors from 'cors';
import express from 'express';
import http from 'http';
import os from 'os';

import { rateLimit } from 'express-rate-limit';
import { createClient } from '@supabase/supabase-js';
import { Server } from 'socket.io';

import { ICE_SERVERS } from './config.js';
import { CallController } from './controllers/callController.js';
import { registerConnectTransport } from './handlers/connectTransport.js';
import { registerConsume } from './handlers/consume.js';
import { registerCreateTransport } from './handlers/createTransport.js';
import { registerJoinRoom } from './handlers/joinRoom.js';
import { registerLeave } from './handlers/leaveRoom.js';
import { registerProduce } from './handlers/produce.js';
import { registerTransportHeartbeat } from './handlers/transportHeartbeat.js';
import { authMiddleware } from './middleware/auth.js';
import { AdmissionControlService } from './services/admissionControlService.js';
import { CallSignalService } from './services/callSignalService.js';
import { CircuitBreakerService } from './services/circuitBreakerService.js';
import { LoadBalancer } from './services/loadBalancer.js';
import {
  initializeObservability,
  register,
  updateControlPlaneMetrics,
} from './services/observabilityService.js';
import { SessionRegistry } from './services/sessionRegistry.js';
import { SfuClient } from './services/sfuClient.js';
import { TurnPolicyService } from './services/turnPolicyService.js';
import { setupScaling } from './utils/scaling.js';

const REGION = process.env.REGION || 'us-east-1';
const NODE_ID = process.env.NODE_ID || `node-${os.hostname()}-${process.pid}`;
const startTime = Date.now();

initializeObservability({ region: REGION, nodeId: NODE_ID });

const app = express();
app.set('trust proxy', 1);
app.use(cors());
app.use(express.json());

const limiter = rateLimit({
  windowMs: 60 * 1000,
  max: 100,
  standardHeaders: true,
  legacyHeaders: false,
});
app.use(limiter);

const supabase = createClient(process.env.SUPABASE_URL, process.env.SUPABASE_ANON_KEY);
const httpAuthMiddleware = async (req, res, next) => {
  const token = req.headers.authorization?.split(' ')[1];
  if (!token) {
    return res.status(401).json({ ok: false, error: 'MISSING_TOKEN' });
  }

  const { data, error } = await supabase.auth.getUser(token);
  if (error || !data?.user) {
    return res.status(401).json({ ok: false, error: 'UNAUTHORIZED' });
  }

  req.user = data.user;
  return next();
};

await SessionRegistry.init().catch((error) => {
  console.warn('[Registry] Redis initialization failed; continuing with local-only state.', error.message);
});

const loadBalancer = new LoadBalancer();
const admissionControl = new AdmissionControlService({ registry: SessionRegistry });
const circuitBreaker = new CircuitBreakerService({ registry: SessionRegistry });
const turnPolicyService = new TurnPolicyService({ registry: SessionRegistry });
const signalService = new CallSignalService({ registry: SessionRegistry });
const controller = new CallController({ signalService });

const server = http.createServer(app);
const io = new Server(server, {
  cors: { origin: '*' },
  transports: ['websocket'],
});

await setupScaling(io);

function estimateCpuPercent() {
  const loadAverage = os.loadavg?.()[0] || 0;
  const cores = os.cpus()?.length || 1;
  return Math.min(100, Math.round((loadAverage / Math.max(cores, 1)) * 100));
}

async function refreshControlPlaneMetrics() {
  let activeSessions = [];
  let systemLoad = {
    rooms: 0,
    peers: 0,
    transports: 0,
    producers: 0,
    consumers: 0,
  };
  let healthyNodes = [];

  try {
    activeSessions = await signalService.listActiveSessions();
  } catch (error) {
    console.warn('[Metrics] Failed to enumerate active sessions:', error.message);
  }

  try {
    systemLoad = await SfuClient.getSystemLoad();
  } catch (error) {
    // The SFU is lazily started. Keeping zeroes here avoids failing health checks.
  }

  try {
    healthyNodes = await SessionRegistry.getHealthyNodes();
  } catch (error) {
    console.warn('[Metrics] Failed to enumerate healthy nodes:', error.message);
  }

  const admissionSnapshot = admissionControl.getSnapshot();
  const cpuPercent = estimateCpuPercent();
  const protectionState = await circuitBreaker.evaluate({
    queueDepth: admissionSnapshot.queueDepth,
    localNodeMetrics: {
      cpu: cpuPercent,
      transports: systemLoad.transports,
      protectionMode: circuitBreaker.getState().protectionMode,
    },
  });

  updateControlPlaneMetrics({
    activeRooms: systemLoad.rooms || activeSessions.length || 0,
    activePeers: systemLoad.peers || 0,
    transports: systemLoad.transports || 0,
    queueDepth: admissionSnapshot.queueDepth,
    protectionMode: protectionState.protectionMode,
    cpuPercent,
    healthyNodes,
  });

  await SessionRegistry.updateNodeHeartbeat(NODE_ID, {
    nodeId: NODE_ID,
    region: REGION,
    cpu: cpuPercent,
    transports: systemLoad.transports,
    rooms: systemLoad.rooms,
    peers: systemLoad.peers,
    queueDepth: admissionSnapshot.queueDepth,
    activeJoinOps: admissionSnapshot.activeCount,
    protectionMode: protectionState.protectionMode,
    signalingEndpoint:
      process.env.SIGNALING_PUBLIC_ENDPOINT ||
      process.env.PUBLIC_SIGNALING_ENDPOINT ||
      null,
  }).catch((error) => {
    console.warn('[Heartbeat] Failed to publish node heartbeat:', error.message);
  });

  return {
    activeSessions,
    systemLoad,
    protectionState,
    admissionSnapshot,
  };
}

app.get('/metrics', async (req, res) => {
  await refreshControlPlaneMetrics();
  res.set('Content-Type', register.contentType);
  res.end(await register.metrics());
});

app.get('/health', async (req, res) => {
  const runtime = await refreshControlPlaneMetrics();
  res.status(200).json({
    ok: true,
    uptime: Math.floor((Date.now() - startTime) / 1000),
    active_sessions: runtime.activeSessions.length,
    protection_mode: runtime.protectionState,
    admission: runtime.admissionSnapshot,
    sfu: runtime.systemLoad,
  });
});

app.get('/api/v1/ice-servers', httpAuthMiddleware, async (req, res) => {
  try {
    const requestedPolicy = String(req.query.transportPolicy || 'all').toLowerCase();
    const forceRelay = requestedPolicy === 'relay';
    const policy = await turnPolicyService.buildIcePolicy({
      userId: req.user.id,
      roomId: typeof req.query.roomId === 'string' ? req.query.roomId : null,
      callId: typeof req.query.callId === 'string' ? req.query.callId : null,
      requestedPolicy,
      forceRelay,
      ipAddress: req.ip,
      baseIceServers: ICE_SERVERS,
    });

    res.json({ ok: true, ...policy });
  } catch (error) {
    res.status(429).json({
      ok: false,
      error: error.code || 'ICE_POLICY_BLOCKED',
      message: error.message,
      details: error.details,
    });
  }
});

app.post('/api/v1/events/:type', httpAuthMiddleware, async (req, res) => {
  try {
    const eventType = req.params.type;
    const protectionState = circuitBreaker.getState();

    if (eventType === 'call_invite' && protectionState.protectionMode) {
      return res.status(503).json({
        ok: false,
        error: 'SYSTEM_PROTECTION_MODE',
        details: protectionState,
      });
    }

    const result = await controller.handleEvent(eventType, req.body);
    return res.status(result.statusCode).json(result.body);
  } catch (error) {
    return res.status(400).json({
      ok: false,
      error: error.code || 'SIGNALING_EVENT_FAILED',
      message: error.message,
    });
  }
});

app.post('/events/:type', httpAuthMiddleware, async (req, res) => {
  try {
    const result = await controller.handleEvent(req.params.type, req.body);
    return res.status(result.statusCode).json(result.body);
  } catch (error) {
    return res.status(400).json({
      ok: false,
      error: error.code || 'SIGNALING_EVENT_FAILED',
      message: error.message,
    });
  }
});

io.use(authMiddleware);

io.on('connection', (socket) => {
  console.log(`[Socket] New connection: ${socket.id} (user: ${socket.user?.id})`);

  registerJoinRoom(socket, io, {
    admissionControl,
    circuitBreaker,
    turnPolicyService,
    localRegion: REGION,
    localNodeId: NODE_ID,
    loadBalancer,
  });
  registerCreateTransport(socket);
  registerConnectTransport(socket);
  registerProduce(socket, io);
  registerConsume(socket);
  registerTransportHeartbeat(socket);
  registerLeave(socket);

  socket.on('disconnect', () => {
    console.log(`[Socket] Disconnected: ${socket.id}`);
  });
});

setInterval(() => {
  refreshControlPlaneMetrics().catch((error) => {
    console.error('[Heartbeat] Failed to refresh control-plane metrics:', error);
  });
}, 5000);

setInterval(async () => {
  console.log('[CLEANUP] Running periodic session reconciliation...');
  try {
    const activeSessions = await signalService.listActiveSessions();
    for (const session of activeSessions) {
      const createdAt = Date.parse(session.created_at || 0);
      if (createdAt && Date.now() - createdAt > 6 * 3600 * 1000) {
        console.warn(`[CHAOS] Cleaning up zombie session: ${session.call_id}`);
        await signalService.closeSession(session.call_id, 'stale_cleanup');
      }
    }

    if (global.gc) {
      global.gc();
    }
  } catch (error) {
    console.error('[CLEANUP] Error during session reconciliation:', error);
  }
}, 10 * 60 * 1000);

const PORT = process.env.PORT || 8080;
server.listen(PORT, '0.0.0.0', () => {
  console.log(`Signaling server running on http://0.0.0.0:${PORT}`);
});
