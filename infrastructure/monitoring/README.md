# Monitoring Setup

This directory contains the baseline Prometheus configuration for launch validation.

## Files

- `prometheus.yml`: scrape configuration for signaling and Redis exporter targets
- `alerts.yml`: production alert rules for CPU, packet loss, Redis latency, TURN spikes, protection mode, and stale heartbeats

## Required Targets

- Signaling nodes must expose `GET /metrics`
- Redis should be scraped through `redis_exporter`

## Metrics Covered

- `xparq_transport_rtt_ms`
- `xparq_transport_packet_loss_ratio`
- `xparq_transport_jitter_ms`
- `xparq_turn_policy_requests_total`
- `xparq_turn_credentials_issued_total`
- `xparq_rejoin_queue_depth`
- `xparq_protection_mode`
- `xparq_node_heartbeat_age_ms`
- `xparq_redis_command_latency_ms`
