import 'package:xparq_app/features/call/domain/models/call_control_event.dart';

class CallSession {
  final String callId;
  final String roomId;
  final String chatId;
  final String callerId;
  final String calleeId;
  final String peerUserId;
  final String peerName;
  final String peerAvatarUrl;
  final bool isIncoming;

  const CallSession({
    required this.callId,
    required this.roomId,
    required this.chatId,
    required this.callerId,
    required this.calleeId,
    required this.peerUserId,
    required this.peerName,
    required this.peerAvatarUrl,
    required this.isIncoming,
  });

  factory CallSession.fromInviteEvent(
    CallControlEvent event, {
    required String currentUserId,
  }) {
    return CallSession(
      callId: event.callId,
      roomId: event.roomId,
      chatId: event.chatId,
      callerId: event.actorId,
      calleeId: event.targetId,
      peerUserId:
          currentUserId == event.actorId ? event.targetId : event.actorId,
      peerName: event.peerName ?? 'Voice Call',
      peerAvatarUrl: event.peerAvatarUrl ?? '',
      isIncoming: currentUserId == event.targetId,
    );
  }
}
