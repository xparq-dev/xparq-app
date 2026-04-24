function toInt(value, fallback) {
  const parsed = Number.parseInt(value, 10);
  return Number.isFinite(parsed) ? parsed : fallback;
}

function toBool(value) {
  return /^(1|true|yes|on)$/i.test(String(value || '').trim());
}

export class CircuitBreakerService {
  constructor({
    registry,
    overloadCpu = toInt(process.env.CIRCUIT_BREAKER_CPU_THRESHOLD || '85', 85),
    overloadQueueDepth = toInt(process.env.CIRCUIT_BREAKER_QUEUE_THRESHOLD || '1200', 1200),
    overloadTransports = toInt(process.env.CIRCUIT_BREAKER_TRANSPORT_THRESHOLD || '800', 800),
    recoveryCooldownMs = toInt(process.env.CIRCUIT_BREAKER_RECOVERY_MS || '15000', 15000),
    disableProtection = toBool(process.env.DISABLE_PROTECTION),
  }) {
    this.registry = registry;
    this.overloadCpu = overloadCpu;
    this.overloadQueueDepth = overloadQueueDepth;
    this.overloadTransports = overloadTransports;
    this.recoveryCooldownMs = recoveryCooldownMs;
    this.disableProtection = disableProtection;
    this.state = {
      protectionMode: false,
      reason: this.disableProtection ? 'disabled' : 'healthy',
      updatedAt: Date.now(),
    };
  }

  getState() {
    return {
      ...this.state,
      disabled: this.disableProtection,
    };
  }

  shouldAllowSession({ isExistingSession }) {
    if (this.disableProtection) {
      return true;
    }

    if (!this.state.protectionMode) {
      return true;
    }

    return Boolean(isExistingSession);
  }

  async evaluate({ queueDepth, localNodeMetrics = {} }) {
    if (this.disableProtection) {
      this.state = {
        protectionMode: false,
        reason: 'disabled',
        updatedAt: Date.now(),
      };
      return this.getState();
    }

    const healthyNodes = await this.registry.getHealthyNodes();
    const overloadedNodes = healthyNodes.filter((node) => this.#isNodeOverloaded(node));
    const allNodesOverloaded =
      healthyNodes.length > 0 && overloadedNodes.length === healthyNodes.length;

    const shouldProtect =
      queueDepth >= this.overloadQueueDepth ||
      this.#isNodeOverloaded(localNodeMetrics) ||
      healthyNodes.length === 0 ||
      allNodesOverloaded;

    const now = Date.now();
    if (shouldProtect) {
      this.state = {
        protectionMode: true,
        reason: this.#resolveReason({ queueDepth, healthyNodes, allNodesOverloaded, localNodeMetrics }),
        updatedAt: now,
      };
      return this.getState();
    }

    if (
      this.state.protectionMode &&
      now - this.state.updatedAt < this.recoveryCooldownMs
    ) {
      return this.getState();
    }

    this.state = {
      protectionMode: false,
      reason: 'healthy',
      updatedAt: now,
    };
    return this.getState();
  }

  #isNodeOverloaded(node = {}) {
    return (
      (node.cpu || 0) >= this.overloadCpu ||
      (node.transports || 0) >= this.overloadTransports ||
      node.protectionMode === true
    );
  }

  #resolveReason({ queueDepth, healthyNodes, allNodesOverloaded, localNodeMetrics }) {
    if (queueDepth >= this.overloadQueueDepth) {
      return 'join_queue_saturated';
    }

    if ((localNodeMetrics.transports || 0) >= this.overloadTransports) {
      return 'local_transport_pressure';
    }

    if ((localNodeMetrics.cpu || 0) >= this.overloadCpu) {
      return 'local_cpu_pressure';
    }

    if (healthyNodes.length === 0) {
      return 'no_healthy_nodes';
    }

    if (allNodesOverloaded) {
      return 'cluster_overloaded';
    }

    return 'healthy';
  }
}
