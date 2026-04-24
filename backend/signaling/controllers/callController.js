import { CALL_EVENTS } from "../events/callEvents.js";

export class CallController {
  constructor({ signalService }) {
    this.signalService = signalService;
  }

  async handleEvent(eventType, body) {
    switch (eventType) {
      case CALL_EVENTS.CALL_INVITE:
        return this.#ok(
          await this.signalService.invite({
            callerId: body.caller_id,
            calleeId: body.callee_id,
          }),
        );

      case CALL_EVENTS.CALL_ACCEPT:
        return this.#ok(
          await this.signalService.accept({
            callId: body.call_id,
            actorId: body.actor_id,
          }),
        );

      case CALL_EVENTS.CALL_REJECT:
        return this.#ok(
          await this.signalService.reject({
            callId: body.call_id,
            actorId: body.actor_id,
          }),
        );

      case CALL_EVENTS.JOIN_ROOM:
        return this.#ok(
          await this.signalService.joinRoom({
            callId: body.call_id,
            actorId: body.actor_id,
            roomId: body.room_id,
          }),
        );

      case CALL_EVENTS.LEAVE_ROOM:
        return this.#ok(
          await this.signalService.leaveRoom({
            callId: body.call_id,
            actorId: body.actor_id,
            roomId: body.room_id,
          }),
        );

      default:
        return this.#error(404, `Unsupported signaling event: ${eventType}`);
    }
  }

  handleHealth() {
    return {
      statusCode: 200,
      body: {
        ok: true,
        active_sessions: this.signalService.listActiveSessions().length,
      },
    };
  }

  #ok({ session, event }) {
    return {
      statusCode: 200,
      body: {
        ok: true,
        session,
        event,
      },
    };
  }

  #error(statusCode, message) {
    return {
      statusCode,
      body: {
        ok: false,
        error: message,
      },
    };
  }
}
