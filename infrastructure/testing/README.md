# Launch Validation Scripts

## Setup

1. Create a token file at `TOKENS_FILE`.
   JSON array and newline-delimited formats are both supported.
2. Export:
   - `API_BASE_URL`
   - `SOCKET_URL`
   - `CALL_ID`
   - `ROOM_ID`
   - `TOKENS_FILE`

## Scripts

- `npm run join-storm`
  Simulates up to 1000 concurrent joins.
- `npm run reconnect-storm`
  Joins the room, disconnects everyone at once, then reconnects them simultaneously.
- `npm run forced-turn`
  Hammers `/api/v1/ice-servers?transportPolicy=relay` with rotating client IPs.

## Failure Drills

- `drills/kill-sfu-node.ps1`
- `drills/kill-signaling-node.ps1`
- `drills/redis-outage.ps1`

Each drill supports `docker` and `k8s` modes through parameters so the same flow can be reused in staging and production-like environments.
