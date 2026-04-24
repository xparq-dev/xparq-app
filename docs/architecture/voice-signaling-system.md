# Voice Signaling System

## Scope

This design adds signaling for voice calls only.

It intentionally excludes:

- media transport
- codec negotiation
- microphone handling
- speaker routing
- SDP/ICE payload exchange

## Backend Folder Structure

```text
backend/
└─ signaling/
   ├─ controllers/
   │  └─ callController.js
   ├─ services/
   │  └─ callSignalService.js
   ├─ events/
   │  └─ callEvents.js
   ├─ models/
   │  └─ callSessionModel.js
   └─ index.js
```

## Event Schemas

### `call_invite`

Request:

```json
{
  "caller_id": "user_123",
  "callee_id": "user_456"
}
```

Response event:

```json
{
  "event_id": "9f45d8a2-6171-4657-bd2b-5fe6d5d8a37b",
  "event_type": "call_invite",
  "call_id": "2d6b0e84-1b94-4474-87ba-8874c4222c29",
  "room_id": "room_2d6b0e84-1b94-4474-87ba-8874c4222c29",
  "actor_id": "user_123",
  "target_id": "user_456",
  "timestamp": "2026-04-21T09:30:00.000Z",
  "payload": {
    "call_status": "invited"
  }
}
```

### `call_accept`

Request:

```json
{
  "call_id": "2d6b0e84-1b94-4474-87ba-8874c4222c29",
  "actor_id": "user_456"
}
```

Response event:

```json
{
  "event_id": "f41c3ef0-4c3d-4e72-bd53-99e495977dc3",
  "event_type": "call_accept",
  "call_id": "2d6b0e84-1b94-4474-87ba-8874c4222c29",
  "room_id": "room_2d6b0e84-1b94-4474-87ba-8874c4222c29",
  "actor_id": "user_456",
  "target_id": "user_123",
  "timestamp": "2026-04-21T09:30:10.000Z",
  "payload": {
    "call_status": "accepted",
    "participant_state": "accepted"
  }
}
```

### `call_reject`

Request:

```json
{
  "call_id": "2d6b0e84-1b94-4474-87ba-8874c4222c29",
  "actor_id": "user_456"
}
```

Response event:

```json
{
  "event_id": "7faabec3-30ba-4537-a482-3e7d6d909537",
  "event_type": "call_reject",
  "call_id": "2d6b0e84-1b94-4474-87ba-8874c4222c29",
  "room_id": "room_2d6b0e84-1b94-4474-87ba-8874c4222c29",
  "actor_id": "user_456",
  "target_id": "user_123",
  "timestamp": "2026-04-21T09:30:10.000Z",
  "payload": {
    "call_status": "rejected",
    "participant_state": "rejected"
  }
}
```

### `join_room`

Request:

```json
{
  "call_id": "2d6b0e84-1b94-4474-87ba-8874c4222c29",
  "room_id": "room_2d6b0e84-1b94-4474-87ba-8874c4222c29",
  "actor_id": "user_123"
}
```

Response event:

```json
{
  "event_id": "27b6c5d3-3cb0-4f6f-9bfa-50e20f77e9b9",
  "event_type": "join_room",
  "call_id": "2d6b0e84-1b94-4474-87ba-8874c4222c29",
  "room_id": "room_2d6b0e84-1b94-4474-87ba-8874c4222c29",
  "actor_id": "user_123",
  "target_id": "user_456",
  "timestamp": "2026-04-21T09:30:15.000Z",
  "payload": {
    "call_status": "accepted",
    "participant_state": "joined"
  }
}
```

### `leave_room`

Request:

```json
{
  "call_id": "2d6b0e84-1b94-4474-87ba-8874c4222c29",
  "room_id": "room_2d6b0e84-1b94-4474-87ba-8874c4222c29",
  "actor_id": "user_123"
}
```

Response event:

```json
{
  "event_id": "a98e8621-a773-4613-aa9f-93b81802fd28",
  "event_type": "leave_room",
  "call_id": "2d6b0e84-1b94-4474-87ba-8874c4222c29",
  "room_id": "room_2d6b0e84-1b94-4474-87ba-8874c4222c29",
  "actor_id": "user_123",
  "target_id": "user_456",
  "timestamp": "2026-04-21T09:35:00.000Z",
  "payload": {
    "call_status": "ended",
    "participant_state": "left"
  }
}
```

## Flow

1. Caller sends `call_invite`.
2. Server creates a call session and assigns a stable `call_id` and `room_id`.
3. Callee responds with either `call_accept` or `call_reject`.
4. If accepted, both participants can emit `join_room`.
5. Participants emit `leave_room` when exiting.
6. When the last joined participant leaves, the server marks the call as `ended`.

## Minimal Server Endpoints

- `POST /events/call_invite`
- `POST /events/call_accept`
- `POST /events/call_reject`
- `POST /events/join_room`
- `POST /events/leave_room`
- `GET /health`

## Production Notes

- The current implementation uses in-memory storage only to keep the server minimal and isolated.
- For production deployment, replace the in-memory session map with Redis, Firestore, or another shared store.
- Event publication to mobile clients should be handled by a transport adapter outside the signaling service itself.
- Do not add media payloads to these events. Keep signaling state and media negotiation separate.
