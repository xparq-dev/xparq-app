# Real-Time Voice Alignment

## Goal

Prepare the existing XPARQ system for real-time voice support without breaking the current mobile app, chat flows, offline flows, or backend messaging behavior.

## Current Structure Summary

### Mobile

- `apps/mobile/lib/features` already contains feature-first modules such as `auth`, `chat`, `offline`, `profile`, `radar`, and `social`.
- `apps/mobile/lib/shared` currently holds shared router, theme, widgets, services, utilities, and sync code.
- `apps/mobile/lib/main.dart` currently performs startup orchestration for Firebase, Supabase, background services, notifications, auth listeners, and app lifecycle handling.
- `apps/mobile/lib/features/chat` already contains a partially layered structure with `data`, `domain`, and `presentation`, but legacy parallel folders also remain in place.

### Backend

- `backend/functions` contains server-side functions for auth, chat, and radar.
- `backend/supabase` contains SQL migrations, realtime setup, and messaging-related database assets.

### Docs

- `docs` already exists and currently stores screenshots, dumps, and generated analysis artifacts.

## Missing Layers For Voice

The repo does not yet have dedicated boundaries for voice-specific concerns:

- No isolated mobile `call` feature.
- No dedicated media layer for capture, encode, playback, or device routing assets.
- No dedicated infrastructure boundary for RTC transport, signaling adapters, or TURN/STUN integration.
- No explicit backend voice boundary for call session orchestration.

## Minimal Additions

The following additions are intentionally minimal and non-breaking:

### Repository Root

- `backend/`
  - Existing. Remains the place for future call session signaling and call lifecycle APIs.
- `media/`
  - New. Reserved for voice/media-related assets and future media pipeline support.
- `infrastructure/`
  - New. Reserved for RTC gateway, signaling adapters, deployment manifests, and environment-specific infra.
- `docs/`
  - Existing. Extended with this architecture note only.

### Mobile App

- `apps/mobile/lib/core/`
  - New placeholder for future app-wide abstractions needed by voice without moving existing shared code yet.
- `apps/mobile/lib/services/`
  - New placeholder for orchestration services that should not live in UI files.
- `apps/mobile/lib/features/call/`
  - New feature boundary for real-time voice UI, controllers, and infrastructure adapters.

## Safe Alignment Rules

To avoid breaking the current app:

- Do not move any existing feature module yet.
- Do not merge voice into `chat`, `offline`, or `chat_signal` yet.
- Do not place signaling logic inside presentation widgets.
- Do not place media capture or device audio routing inside chat UI files.
- Do not change current routers, providers, or startup wiring during scaffolding.

## Recommended Future Ownership

When implementation starts, keep responsibilities separated:

- `apps/mobile/lib/features/call/presentation`
  - Call screens, in-call UI, mute/speaker controls, permission prompts.
- `apps/mobile/lib/features/call/application`
  - Call controller, session orchestration, state coordination.
- `apps/mobile/lib/features/call/infrastructure`
  - WebRTC adapter, signaling client, microphone/speaker device integration.
- `backend`
  - Session creation, participant state, token issuance, and signaling event persistence.
- `media`
  - Media policy, codec notes, audio assets, and processing references.
- `infrastructure`
  - TURN/STUN, relay configuration, deployment, and runtime environment wiring.

## Why This Is Safe

- Existing code paths remain untouched.
- Existing feature folders remain where they are.
- Existing chat signaling and offline transport code remain intact.
- New voice work gets an isolated landing zone instead of being mixed into chat UI or legacy services.
- The current app can continue shipping while voice capability is added incrementally.
