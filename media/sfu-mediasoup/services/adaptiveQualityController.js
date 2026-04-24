class AdaptiveQualityController {
  constructor(config = {}) {
    this.config = {
      excellentMaxBitrate: config.excellentMaxBitrate || 128000,
      healthyMaxBitrate: config.healthyMaxBitrate || 96000,
      degradedMaxBitrate: config.degradedMaxBitrate || 64000,
      minimumMaxBitrate: config.minimumMaxBitrate || 32000,
      highRttMs: config.highRttMs || 220,
      highJitterMs: config.highJitterMs || 45,
      highPacketLoss: config.highPacketLoss || 0.08,
    };
  }

  evaluate(sample = {}) {
    const packetLoss = Number(sample.packetLoss || 0);
    const rttMs = Number(sample.rttMs || 0);
    const jitterMs = Number(sample.jitterMs || 0);
    const availableBitrate = Number(sample.availableOutgoingBitrate || 0);

    let profile = "healthy";
    let targetBitrate = this.config.healthyMaxBitrate;

    if (
      packetLoss >= this.config.highPacketLoss ||
      rttMs >= this.config.highRttMs ||
      jitterMs >= this.config.highJitterMs
    ) {
      profile = "degraded";
      targetBitrate = this.config.degradedMaxBitrate;
    } else if (
      packetLoss <= 0.02 &&
      rttMs > 0 &&
      rttMs < 120 &&
      jitterMs < 20
    ) {
      profile = "excellent";
      targetBitrate = this.config.excellentMaxBitrate;
    }

    if (availableBitrate > 0) {
      targetBitrate = Math.min(
        targetBitrate,
        Math.max(this.config.minimumMaxBitrate, Math.floor(availableBitrate * 0.85)),
      );
    }

    targetBitrate = Math.max(this.config.minimumMaxBitrate, targetBitrate);

    return {
      profile,
      targetBitrate,
      packetLoss,
      rttMs,
      jitterMs,
      availableBitrate,
    };
  }

  async applyToTransport(transport, policy) {
    if (!transport || !policy?.targetBitrate) {
      return policy;
    }

    if (typeof transport.setMaxIncomingBitrate === "function") {
      await transport.setMaxIncomingBitrate(policy.targetBitrate);
    }

    if (typeof transport.setMaxOutgoingBitrate === "function") {
      await transport.setMaxOutgoingBitrate(policy.targetBitrate);
    }

    if (typeof transport.setMinOutgoingBitrate === "function") {
      await transport.setMinOutgoingBitrate(
        Math.max(16000, Math.floor(policy.targetBitrate / 2)),
      );
    }

    return policy;
  }
}

module.exports = {
  AdaptiveQualityController,
};
