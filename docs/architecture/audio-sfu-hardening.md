# Audio SFU Hardening

## Updated Architecture

The mediasoup SFU keeps its existing layers:

- `workers`
- `routers`
- `transports`
- `services`
- `config`

The hardening extends this architecture with a centralized external state layer:

- `services/sessionStateService.js`
  - Owns call-to-room binding
  - Persists active peers
  - Persists transport lifecycle
  - Stores failure and cleanup state in Supabase

## Reliability Fixes

### 1. Centralized Session State

The SFU no longer relies only on in-memory maps for correctness.

Supabase becomes the shared source of truth for:

- `call_id -> room_id`
- active peer per room
- authenticated user bound to peer
- transport ownership and heartbeat state

### 2. Peer Authentication Binding

Each peer join now requires:

- `callId`
- `roomId`
- `peerId`
- `userId`

This guarantees:

- `peerId` is linked to exactly one authenticated `userId`
- one active peer per user per room

### 3. Transport Lifecycle

Each transport now tracks:

- created timestamp
- connected timestamp
- last heartbeat timestamp
- idle timeout
- close or failure reason

The transport registry performs periodic idle sweeps and emits timeout events for automatic cleanup.

### 4. Failure Handling

The SFU now explicitly handles:

- worker crash
- DTLS failure
- ICE failure
- idle transport timeout
- producer failure
- consumer failure

Failures are surfaced as service events and persisted into Supabase status fields.

### 5. Concurrency Control

The SFU now uses two layers of protection:

- local single-flight request collapsing inside the owner instance
- transactional Supabase RPC functions for shared-state registration

This hardens:

- `joinRoom`
- transport creation
- producer creation

against retries and concurrent duplicate requests.

### 6. Multi-Node Ownership

Each room is now protected by a lease-based owner assignment in `sfu_call_rooms`.

- `owner_instance_id`
- `owner_lease_expires_at`
- `revision`

Only the instance holding the active lease may:

- admit peers
- register transports
- register producers

The owner instance renews the lease periodically. If renewal fails, it drops local room state to avoid split-brain behavior.

## Supabase Schema

See:

- `backend/supabase/migrations/20260421_create_sfu_session_state.sql`
- `backend/supabase/migrations/20260421_harden_sfu_concurrency.sql`

Apply order:

1. `20260421_create_sfu_session_state.sql`
2. `20260421_harden_sfu_concurrency.sql`

Core tables:

- `sfu_call_rooms`
- `sfu_peers`
- `sfu_transports`
- `sfu_producers`

Transactional RPC functions:

- `sfu_claim_room_lease`
- `sfu_register_peer`
- `sfu_register_transport`
- `sfu_register_producer`

## Operational Notes

- The signaling layer must provide authenticated `userId` to the SFU service.
- The client should send transport heartbeats on a fixed interval shorter than the server idle timeout.
- A worker crash is treated as a room-level failure, and affected peers are cleaned up.
