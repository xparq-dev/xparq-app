import { randomUUID } from "crypto";
import { CALL_EVENTS } from "../events/callEvents.js";

export const CALL_STATUS = Object.freeze({
  INVITED: "invited",
  ACCEPTED: "accepted",
  REJECTED: "rejected",
  ENDED: "ended",
});

export const PARTICIPANT_STATE = Object.freeze({
  PENDING: "pending",
  INVITED: "invited",
  ACCEPTED: "accepted",
  JOINED: "joined",
  LEFT: "left",
  REJECTED: "rejected",
});

export function createCallSession({ callerId, calleeId, now = new Date() }) {
  const callId = randomUUID();
  const roomId = `room_${callId}`;
  const isoNow = now.toISOString();

  return {
    call_id: callId,
    room_id: roomId,
    status: CALL_STATUS.INVITED,
    caller_id: callerId,
    callee_id: calleeId,
    created_at: isoNow,
    updated_at: isoNow,
    participants: {
      [callerId]: {
        user_id: callerId,
        role: "caller",
        state: PARTICIPANT_STATE.INVITED,
        joined_at: null,
        left_at: null,
      },
      [calleeId]: {
        user_id: calleeId,
        role: "callee",
        state: PARTICIPANT_STATE.PENDING,
        joined_at: null,
        left_at: null,
      },
    },
  };
}

export function assertParticipant(session, actorId) {
  if (!session.participants[actorId]) {
    throw new Error(`Actor ${actorId} is not part of call ${session.call_id}.`);
  }
}

export function applyEvent(session, eventType, actorId, now = new Date()) {
  assertParticipant(session, actorId);
  const isoNow = now.toISOString();
  const participant = session.participants[actorId];

  switch (eventType) {
    case CALL_EVENTS.CALL_ACCEPT: {
      if (actorId !== session.callee_id) {
        throw new Error("Only the callee can accept an invite.");
      }
      if (session.status !== CALL_STATUS.INVITED) {
        throw new Error("Only invited calls can be accepted.");
      }
      session.status = CALL_STATUS.ACCEPTED;
      participant.state = PARTICIPANT_STATE.ACCEPTED;
      break;
    }

    case CALL_EVENTS.CALL_REJECT: {
      if (actorId !== session.callee_id) {
        throw new Error("Only the callee can reject an invite.");
      }
      if (session.status !== CALL_STATUS.INVITED) {
        throw new Error("Only invited calls can be rejected.");
      }
      session.status = CALL_STATUS.REJECTED;
      participant.state = PARTICIPANT_STATE.REJECTED;
      break;
    }

    case CALL_EVENTS.JOIN_ROOM: {
      if (session.status !== CALL_STATUS.ACCEPTED) {
        throw new Error("Participants can only join an accepted call.");
      }
      participant.state = PARTICIPANT_STATE.JOINED;
      participant.joined_at = participant.joined_at || isoNow;
      participant.left_at = null;
      break;
    }

    case CALL_EVENTS.LEAVE_ROOM: {
      if (
        session.status !== CALL_STATUS.ACCEPTED &&
        session.status !== CALL_STATUS.ENDED
      ) {
        throw new Error("Participants can only leave an active call.");
      }
      participant.state = PARTICIPANT_STATE.LEFT;
      participant.left_at = isoNow;

      const joinedParticipants = Object.values(session.participants).filter(
        (entry) => entry.state === PARTICIPANT_STATE.JOINED,
      );
      if (joinedParticipants.length === 0) {
        session.status = CALL_STATUS.ENDED;
      }
      break;
    }

    default:
      throw new Error(`Unsupported event type: ${eventType}`);
  }

  session.updated_at = isoNow;
  return session;
}

