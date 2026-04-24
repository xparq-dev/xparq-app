# TURN/STUN Infrastructure

## Network Reality

### NAT Types

- Full-cone NAT
  - Once a local endpoint opens a mapping, many remote endpoints can send traffic back through that mapped port.
- Restricted-cone NAT
  - Inbound traffic is allowed only from remote IPs the client has already sent packets to.
- Port-restricted cone NAT
  - Inbound traffic is allowed only from a specific remote IP and port pair the client has already contacted.
- Symmetric NAT
  - The NAT creates a different external mapping per destination. This is the hardest case for peer-to-peer traversal and is common on carrier-grade mobile networks.

### Why STUN Alone Is Insufficient

STUN only tells a client what its public reflexive address looks like from the outside. It does not guarantee that another peer can actually send media back to that address.

STUN fails in common production situations:

- symmetric NAT
- carrier-grade NAT in cellular networks
- enterprise firewalls that block or rewrite UDP
- hotel, airport, and captive-portal networks
- networks that require TCP or TLS fallback

### When TURN Relay Is Required

TURN is required whenever direct ICE connectivity cannot be established reliably enough for live media.

In practice TURN becomes mandatory for:

- mobile-to-mobile calls across different carriers
- users behind enterprise firewalls
- users behind symmetric NAT
- degraded Wi-Fi where UDP is blocked
- cases where only TCP or TLS egress survives

For real-world mobile voice, TURN is not optional infrastructure. STUN is discovery; TURN is the reliability path.

## Infrastructure Folder

```text
infrastructure/
└─ turn/
   ├─ .env.example
   ├─ coturn.conf
   └─ docker-compose.yml
```

## Authentication Strategy

### Development

- Free STUN only
- No relay
- Good for emulator testing, same-LAN experiments, and early ICE diagnostics
- Not good enough for production mobile calling

### Production

- Coturn on a VPS with public IP
- TURN long-term credential auth using a shared secret
- Ephemeral credentials generated server-side from the shared secret

This is preferred over static TURN usernames/passwords because:

- credentials can expire quickly
- secrets are not hardcoded per user
- credential leakage has bounded blast radius
- it aligns with Coturn `use-auth-secret`

## Deployment Model

### Coturn Server

- Public VPS or bare-metal host with a stable public IP
- Docker Compose using Linux host networking
- UDP relay on port `3478`
- TCP relay fallback on port `3478`
- TLS relay on port `5349`
- Relay port range `49160-49200`

### Firewall Requirements

Open inbound:

- `3478/udp`
- `3478/tcp`
- `5349/tcp`
- `49160-49200/udp`
- `49160-49200/tcp`

## mediasoup Integration Boundary

mediasoup itself does not use TURN servers the way browsers or mobile clients do. TURN is used by the client ICE agents to reach the mediasoup `WebRtcTransport`.

The SFU config should therefore expose an ICE server bundle for the signaling layer to return to authenticated clients.

## Free Vs Production Path

### Free Development Path

- STUN: `stun:stun.l.google.com:19302`
- No TURN
- Suitable for:
  - local development
  - same-office testing
  - emulator bring-up

### VPS-Based Production Path

- Coturn on your own VPS
- TURN URLs:
  - `turn:turn.xparq.example.com:3478?transport=udp`
  - `turn:turn.xparq.example.com:3478?transport=tcp`
  - `turns:turn.xparq.example.com:5349?transport=tcp`
- Credentials issued from your backend using the shared secret

### Migration Path

1. Start with free STUN in development.
2. Bring up Coturn on a single VPS with public IP and TLS.
3. Add TURN URLs to the client ICE config while keeping STUN enabled.
4. Generate time-limited TURN credentials from the backend or signaling service.
5. Validate calls over mobile carrier NAT and blocked-UDP networks.
6. Scale to multiple TURN nodes behind DNS or geo routing only after single-node reliability is proven.

## Testing Steps

1. Start Coturn:
   - `cd infrastructure/turn`
   - copy `.env.example` to `.env`
   - fill in public IP, domain, secret, and TLS certificate paths
   - run `docker compose up -d`
2. Confirm listeners on the host:
   - `3478/udp`
   - `3478/tcp`
   - `5349/tcp`
3. Validate relay allocation with a TURN test client or Trickle ICE page using the generated username and credential.
4. Test the following paths:
   - Wi-Fi to Wi-Fi
   - mobile carrier to Wi-Fi
   - mobile carrier to mobile carrier
   - blocked UDP network forcing TCP relay
   - blocked UDP plus enterprise firewall forcing TLS relay
5. Observe:
   - ICE selected candidate pair
   - relay candidate success
   - audio continuity during network changes

## Operations Notes

- Prefer a dedicated subdomain such as `turn.xparq.example.com`.
- Keep TURN and SFU on separate hosts once traffic grows, unless latency and capacity are carefully measured.
- Rotate the shared secret through deployment automation.
- TLS certificates should match the TURN DNS name used by clients.
