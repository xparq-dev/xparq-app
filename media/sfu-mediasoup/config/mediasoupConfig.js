const crypto = require("crypto");
const os = require("os");

function toPositiveInt(value, fallback) {
  const parsed = Number.parseInt(value, 10);
  return Number.isInteger(parsed) && parsed > 0 ? parsed : fallback;
}

function parseCsv(value, fallback = []) {
  if (!value) {
    return fallback;
  }

  return value
    .split(",")
    .map((item) => item.trim())
    .filter(Boolean);
}

function buildTurnRestCredential({ username, sharedSecret }) {
  return crypto
    .createHmac("sha1", sharedSecret)
    .update(username)
    .digest("base64");
}

function buildTurnRestUsername({ userId, sessionId, ttlSeconds }) {
  const expiry = Math.floor(Date.now() / 1000) + ttlSeconds;
  return `${expiry}:${userId}:${sessionId}`;
}

const cpuCount = os.cpus().length;
const workerCount = Math.max(
  1,
  Math.min(toPositiveInt(process.env.MEDIASOUP_WORKER_COUNT, cpuCount), cpuCount),
);

const mediasoupConfig = Object.freeze({
  sfu: {
    instanceId:
      process.env.SFU_INSTANCE_ID ||
      `${os.hostname()}-${process.pid}`,
    roomLeaseMs: toPositiveInt(process.env.SFU_ROOM_LEASE_MS, 30000),
    roomLeaseRenewIntervalMs: toPositiveInt(
      process.env.SFU_ROOM_LEASE_RENEW_INTERVAL_MS,
      10000,
    ),
    relayCapPerUser: toPositiveInt(process.env.SFU_RELAY_CAP_PER_USER, 24),
  },
  worker: {
    count: workerCount,
    rtcMinPort: toPositiveInt(process.env.MEDIASOUP_MIN_PORT, 40000),
    rtcMaxPort: toPositiveInt(process.env.MEDIASOUP_MAX_PORT, 49999),
    logLevel: process.env.MEDIASOUP_LOG_LEVEL || "warn",
    logTags: [
      "info",
      "ice",
      "dtls",
      "rtp",
      "rtcp",
      "rtx",
      "bwe",
      "score",
      "simulcast",
      "svc",
      "sctp",
      "message",
    ],
    respawnOnDied: true,
  },
  router: {
    mediaCodecs: [
      {
        kind: "audio",
        mimeType: "audio/opus",
        preferredPayloadType: 111,
        clockRate: 48000,
        channels: 2,
        parameters: {
          useinbandfec: 1,
          minptime: 10,
        },
      },
    ],
    audioLevelObserver: {
      maxEntries: 1,
      threshold: -80,
      interval: 800,
    },
  },
  webRtcTransport: {
    listenIps: [
      {
        ip: process.env.MEDIASOUP_LISTEN_IP || "0.0.0.0",
        announcedIp:
          process.env.MEDIASOUP_ANNOUNCED_IP || undefined,
      },
    ],
    enableUdp: true,
    enableTcp: true,
    preferUdp: true,
    enableSctp: false,
    initialAvailableOutgoingBitrate: toPositiveInt(
      process.env.MEDIASOUP_INITIAL_OUTGOING_BITRATE,
      1000000,
    ),
    minimumAvailableOutgoingBitrate: toPositiveInt(
      process.env.MEDIASOUP_MIN_OUTGOING_BITRATE,
      600000,
    ),
    maxIncomingBitrate: toPositiveInt(
      process.env.MEDIASOUP_MAX_INCOMING_BITRATE,
      1500000,
    ),
    idleTimeoutMs: toPositiveInt(
      process.env.MEDIASOUP_TRANSPORT_IDLE_TIMEOUT_MS,
      45000,
    ),
    cleanupIntervalMs: toPositiveInt(
      process.env.MEDIASOUP_TRANSPORT_SWEEP_INTERVAL_MS,
      5000,
    ),
    heartbeatGraceMs: toPositiveInt(
      process.env.MEDIASOUP_TRANSPORT_HEARTBEAT_GRACE_MS,
      15000,
    ),
  },
  adaptiveQuality: {
    excellentMaxBitrate: toPositiveInt(
      process.env.ADAPTIVE_BITRATE_EXCELLENT_BPS,
      128000,
    ),
    healthyMaxBitrate: toPositiveInt(
      process.env.ADAPTIVE_BITRATE_HEALTHY_BPS,
      96000,
    ),
    degradedMaxBitrate: toPositiveInt(
      process.env.ADAPTIVE_BITRATE_DEGRADED_BPS,
      64000,
    ),
    minimumMaxBitrate: toPositiveInt(
      process.env.ADAPTIVE_BITRATE_MIN_BPS,
      32000,
    ),
    highRttMs: toPositiveInt(process.env.ADAPTIVE_HIGH_RTT_MS, 220),
    highJitterMs: toPositiveInt(process.env.ADAPTIVE_HIGH_JITTER_MS, 45),
    highPacketLoss: Number.parseFloat(
      process.env.ADAPTIVE_HIGH_PACKET_LOSS || "0.08",
    ),
  },
  ice: {
    stunUrls: parseCsv(process.env.WEBRTC_STUN_URLS, [
      "stun:stun.l.google.com:19302",
    ]),
    turnUrls: parseCsv(process.env.WEBRTC_TURN_URLS, []),
    turnAuthMode: (process.env.WEBRTC_TURN_AUTH_MODE || "rest").toLowerCase(),
    turnCredentialTtlSeconds: toPositiveInt(
      process.env.WEBRTC_TURN_CREDENTIAL_TTL_SECONDS,
      3600,
    ),
    turnStaticUsername: process.env.WEBRTC_TURN_STATIC_USERNAME || "",
    turnStaticPassword: process.env.WEBRTC_TURN_STATIC_PASSWORD || "",
    turnSharedSecret: process.env.WEBRTC_TURN_SHARED_SECRET || "",
    relayPolicy: process.env.WEBRTC_ICE_TRANSPORT_POLICY || "all",
  },
});

function buildClientIceServers({
  userId = "anonymous",
  sessionId = "session",
  forceStaticTurnCredentials = false,
} = {}) {
  const iceServers = [];

  if (mediasoupConfig.ice.stunUrls.length > 0) {
    iceServers.push({
      urls: mediasoupConfig.ice.stunUrls,
    });
  }

  if (mediasoupConfig.ice.turnUrls.length === 0) {
    return iceServers;
  }

  const useStaticCredentials =
    forceStaticTurnCredentials ||
    mediasoupConfig.ice.turnAuthMode === "static";

  if (useStaticCredentials) {
    if (
      !mediasoupConfig.ice.turnStaticUsername ||
      !mediasoupConfig.ice.turnStaticPassword
    ) {
      throw new Error(
        "Static TURN credentials are enabled but username/password are missing.",
      );
    }

    iceServers.push({
      urls: mediasoupConfig.ice.turnUrls,
      username: mediasoupConfig.ice.turnStaticUsername,
      credential: mediasoupConfig.ice.turnStaticPassword,
    });

    return iceServers;
  }

  if (!mediasoupConfig.ice.turnSharedSecret) {
    throw new Error(
      "TURN REST credential mode is enabled but WEBRTC_TURN_SHARED_SECRET is missing.",
    );
  }

  const username = buildTurnRestUsername({
    userId,
    sessionId,
    ttlSeconds: mediasoupConfig.ice.turnCredentialTtlSeconds,
  });
  const credential = buildTurnRestCredential({
    username,
    sharedSecret: mediasoupConfig.ice.turnSharedSecret,
  });

  iceServers.push({
    urls: mediasoupConfig.ice.turnUrls,
    username,
    credential,
  });

  return iceServers;
}

module.exports = {
  buildClientIceServers,
  mediasoupConfig,
};
