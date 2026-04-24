import crypto from 'crypto';

import { generateTurnCredentials } from '../utils/turn.js';
import { recordTurnPolicyDecision } from './observabilityService.js';

function getPolicySecret() {
  const secret = process.env.ICE_POLICY_TOKEN_SECRET || process.env.TURN_AUTH_SECRET;
  if (!secret) {
    throw new Error('ICE policy signing requires ICE_POLICY_TOKEN_SECRET or TURN_AUTH_SECRET.');
  }

  return secret;
}

function signPolicyToken(payload) {
  const secret = getPolicySecret();
  const body = Buffer.from(JSON.stringify(payload)).toString('base64url');
  const signature = crypto.createHmac('sha256', secret).update(body).digest('base64url');
  return `${body}.${signature}`;
}

export class TurnPolicyService {
  constructor({
    registry,
    relayWindowSeconds = Number.parseInt(process.env.TURN_RELAY_CAP_WINDOW_SECONDS || '3600', 10),
    relayCapPerUser = Number.parseInt(process.env.TURN_RELAY_CAP_PER_USER || '24', 10),
    relayCapPerIp = Number.parseInt(process.env.TURN_RELAY_CAP_PER_IP || '240', 10),
    relayCredentialTtlSeconds = Number.parseInt(process.env.TURN_CREDENTIAL_TTL_SECONDS || '90', 10),
  }) {
    this.registry = registry;
    this.relayWindowSeconds = relayWindowSeconds;
    this.relayCapPerUser = relayCapPerUser;
    this.relayCapPerIp = relayCapPerIp;
    this.relayCredentialTtlSeconds = relayCredentialTtlSeconds;
  }

  async buildIcePolicy({
    userId,
    roomId = null,
    callId = null,
    requestedPolicy = 'all',
    forceRelay = false,
    ipAddress = null,
    baseIceServers = [],
  }) {
    const allowForcedRelay = requestedPolicy === 'relay' || forceRelay === true;
    const [userRelayCounter, ipRelayCounter] = await Promise.all([
      this.registry.consumeFixedWindowLimit({
        key: `turn:relay:user:${userId}`,
        limit: this.relayCapPerUser,
        windowSeconds: this.relayWindowSeconds,
      }),
      ipAddress
        ? this.registry.consumeFixedWindowLimit({
            key: `turn:relay:ip:${ipAddress}`,
            limit: this.relayCapPerIp,
            windowSeconds: this.relayWindowSeconds,
          })
        : Promise.resolve({
            allowed: true,
            current: 0,
            limit: this.relayCapPerIp,
            retryAfterSeconds: 0,
          }),
    ]);

    const relayAllowed = userRelayCounter.allowed && ipRelayCounter.allowed;
    if (allowForcedRelay && !relayAllowed) {
      recordTurnPolicyDecision({
        requestedPolicy,
        enforcedPolicy: 'all',
        outcome: 'blocked',
      });
      const error = new Error('Forced relay usage exceeded policy limits.');
      error.code = 'FORCED_TURN_BLOCKED';
      error.details = {
        retryAfterSeconds: Math.max(
          userRelayCounter.retryAfterSeconds || 0,
          ipRelayCounter.retryAfterSeconds || 0,
        ),
        blockedBy: !userRelayCounter.allowed ? 'user_quota' : 'ip_quota',
      };
      throw error;
    }

    const turn = relayAllowed
      ? generateTurnCredentials(userId, this.relayCredentialTtlSeconds)
      : { username: '', credential: '' };

    const turnEnabled =
      relayAllowed &&
      Boolean(turn.username) &&
      Boolean(turn.credential) &&
      Boolean(process.env.TURN_DOMAIN);

    const iceServers = [...baseIceServers];
    if (turnEnabled) {
      iceServers.push({
        urls: [
          `turn:${process.env.TURN_DOMAIN}:3478?transport=udp`,
          `turn:${process.env.TURN_DOMAIN}:3478?transport=tcp`,
        ],
        username: turn.username,
        credential: turn.credential,
      });
    }

    const enforcedPolicy = allowForcedRelay && relayAllowed ? 'relay' : 'all';
    const tokenPayload = {
      userId,
      roomId,
      callId,
      enforcedPolicy,
      relayAllowed,
      exp: Math.floor(Date.now() / 1000) + this.relayCredentialTtlSeconds,
    };

    recordTurnPolicyDecision({
      requestedPolicy,
      enforcedPolicy,
      outcome: turnEnabled ? 'issued' : 'allowed',
    });

    return {
      iceServers,
      iceTransportPolicy: enforcedPolicy,
      relayAllowed,
      relayCap: this.relayCapPerUser,
      relayCapPerIp: this.relayCapPerIp,
      relayWindowSeconds: this.relayWindowSeconds,
      relayQuota: {
        user: {
          limit: this.relayCapPerUser,
          remaining: Math.max(this.relayCapPerUser - userRelayCounter.current, 0),
        },
        ip: {
          limit: this.relayCapPerIp,
          remaining: Math.max(this.relayCapPerIp - ipRelayCounter.current, 0),
        },
      },
      policyToken: signPolicyToken(tokenPayload),
    };
  }

  assertPolicyToken({
    policyToken,
    userId,
    roomId = null,
    callId = null,
  }) {
    if (!policyToken) {
      return null;
    }

    const [body, signature] = policyToken.split('.');
    if (!body || !signature) {
      const error = new Error('Malformed ICE policy token.');
      error.code = 'INVALID_POLICY_TOKEN';
      throw error;
    }

    const expectedSignature = crypto
      .createHmac('sha256', getPolicySecret())
      .update(body)
      .digest('base64url');
    if (expectedSignature !== signature) {
      const error = new Error('Invalid ICE policy token signature.');
      error.code = 'INVALID_POLICY_TOKEN';
      throw error;
    }

    const payload = JSON.parse(Buffer.from(body, 'base64url').toString('utf8'));
    if (Number(payload.exp || 0) <= Math.floor(Date.now() / 1000)) {
      const error = new Error('ICE policy token has expired.');
      error.code = 'EXPIRED_POLICY_TOKEN';
      throw error;
    }

    if (payload.userId && payload.userId !== userId) {
      const error = new Error('ICE policy token does not belong to this user.');
      error.code = 'INVALID_POLICY_TOKEN';
      throw error;
    }

    if (roomId && payload.roomId && payload.roomId !== roomId) {
      const error = new Error('ICE policy token does not match the room.');
      error.code = 'INVALID_POLICY_TOKEN';
      throw error;
    }

    if (callId && payload.callId && payload.callId !== callId) {
      const error = new Error('ICE policy token does not match the call.');
      error.code = 'INVALID_POLICY_TOKEN';
      throw error;
    }

    return payload;
  }
}
