# Audio SFU With mediasoup

## Scope

This module implements the media-side audio SFU only.

It includes:

- mediasoup worker lifecycle
- room router creation
- WebRTC transport creation and connection
- audio producer lifecycle
- audio consumer lifecycle
- active speaker observation

It does not include:

- call invite signaling
- accept or reject signaling
- room admission policy
- media capture in clients

## Folder Structure

```text
media/
└─ sfu-mediasoup/
   ├─ config/
   │  └─ mediasoupConfig.js
   ├─ workers/
   │  └─ workerPool.js
   ├─ routers/
   │  └─ audioRouterRegistry.js
   ├─ transports/
   │  └─ webRtcTransportRegistry.js
   ├─ services/
   │  └─ audioSfuService.js
   ├─ package.json
   └─ index.js
```

## Module Responsibilities

- `config/mediasoupConfig.js`
  - Worker count, port range, Opus audio codec, transport bitrate, and listen IP configuration.
- `workers/workerPool.js`
  - Creates mediasoup workers, balances router creation across them, and respawns workers if they die.
- `routers/audioRouterRegistry.js`
  - Creates one router per room, attaches `AudioLevelObserver`, and tracks peer membership.
- `transports/webRtcTransportRegistry.js`
  - Creates and connects `WebRtcTransport` instances for send and receive directions.
- `services/audioSfuService.js`
  - Orchestrates peers, transports, producers, and consumers without handling signaling.

## Media Flow

1. An external signaling layer admits a peer into a room.
2. The signaling layer calls `joinRoom(roomId, peerId)` on `AudioSfuService`.
3. The SFU returns the room router RTP capabilities.
4. The client requests a send or receive transport.
5. The signaling layer calls `createWebRtcTransport(roomId, peerId, direction)`.
6. The client performs ICE and DTLS negotiation externally.
7. The signaling layer forwards DTLS parameters to `connectWebRtcTransport(...)`.
8. When the client is ready to send audio, the signaling layer calls `produceAudio(...)`.
9. The SFU registers the producer and attaches it to the room audio level observer.
10. Other peers create receive transports and call `consumeAudio(...)`.
11. The SFU creates mediasoup consumers only when the router confirms `canConsume(...)`.
12. When a peer leaves, the signaling layer calls `leaveRoom(...)`, which closes consumers, producers, transports, and eventually the room router when empty.

## Production Notes

- This module is intentionally signaling-agnostic. Keep it behind the signaling service created in `backend/signaling`.
- For clustered deployment, room ownership and session placement must be coordinated outside this module.
- `AudioLevelObserver` is included so the application can expose active speaker state without adding media logic to signaling.
- The codec list is audio-only and pinned to Opus for voice.
