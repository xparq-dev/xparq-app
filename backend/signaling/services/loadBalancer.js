/**
 * Load Balancer for SFU Cluster with Admission Control
 */
export class LoadBalancer {
  constructor(config = {}) {
    this.MAX_CPU = config.maxCpu || 85;
    this.MAX_TRANSPORTS = config.maxTransports || 200;
  }

  /**
   * Selects the best SFU node based on load and network metrics.
   * @param {Array} nodes - Array of nodes with their current metrics
   * @returns {Object|null} The selected node or null if all overloaded
   */
  selectBestNode(nodes) {
    if (!nodes || nodes.length === 0) return null;

    const healthyNodes = nodes.filter(n => !this.isOverloaded(n));
    if (healthyNodes.length === 0) return null;

    return healthyNodes.reduce((prev, curr) => {
      return this.calculateScore(curr) < this.calculateScore(prev) ? curr : prev;
    });
  }

  calculateScore(node) {
    // Score components (lower is better)
    const resourceScore = (node.cpu || 0) * 3 + (node.transports || 0) / 10;
    const networkScore = (node.packetLoss || 0) * 50 + (node.rtt || 0) / 5;
    const activityScore = (node.bitrate || 0) / 1000000; // per Mbps

    return resourceScore + networkScore + activityScore;
  }

  isOverloaded(node) {
    return (node.cpu || 0) > this.MAX_CPU || (node.transports || 0) > this.MAX_TRANSPORTS;
  }
}

