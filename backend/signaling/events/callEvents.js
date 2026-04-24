import { randomUUID } from "crypto";

export const CALL_EVENTS = Object.freeze({
  CALL_INVITE: "call_invite",
  CALL_ACCEPT: "call_accept",
  CALL_REJECT: "call_reject",
  JOIN_ROOM: "join_room",
  LEAVE_ROOM: "leave_room",
});

export function createEventEnvelope({
  eventType,
  callId,
  roomId,
  actorId,
  targetId = null,
  payload = {},
  now = new Date(),
}) {
  return {
    event_id: randomUUID(),
    event_type: eventType,
    call_id: callId,
    room_id: roomId,
    actor_id: actorId,
    target_id: targetId,
    timestamp: now.toISOString(),
    payload,
  };
}

