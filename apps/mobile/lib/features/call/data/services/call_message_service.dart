import 'dart:async';
import 'dart:collection';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:xparq_app/features/auth/models/planet_model.dart';
import 'package:xparq_app/features/call/domain/models/call_control_event.dart';
import 'package:xparq_app/features/chat/data/repositories/chat_repository.dart';

class CallMessageService {
  CallMessageService({
    required ChatRepository chatRepository,
    SupabaseClient? supabaseClient,
  })  : _chatRepository = chatRepository,
        _supabase = supabaseClient ?? Supabase.instance.client;

  final ChatRepository _chatRepository;
  final SupabaseClient _supabase;

  Stream<CallControlEvent> watchEvents(String currentUserId) {
    final seenMessageIds = Queue<String>();
    final seenMessageSet = <String>{};
    final cutoff = DateTime.now().subtract(const Duration(minutes: 2));

    return _supabase
        .from('messages')
        .stream(primaryKey: ['id'])
        .order('timestamp')
        .limit(120)
        .asyncExpand((rows) async* {
          for (final row in rows) {
            final messageId = row['id']?.toString();
            if (messageId == null || seenMessageSet.contains(messageId)) {
              continue;
            }

            seenMessageSet.add(messageId);
            seenMessageIds.addLast(messageId);
            while (seenMessageIds.length > 400) {
              seenMessageSet.remove(seenMessageIds.removeFirst());
            }

            final metadata = Map<String, dynamic>.from(
              row['metadata'] as Map? ?? const {},
            );
            final callMap = metadata['xparq_call'];
            if (callMap is! Map) {
              continue;
            }

            final timestamp = row['timestamp'] != null
                ? DateTime.tryParse(row['timestamp'].toString())?.toLocal()
                : null;
            if (timestamp != null && timestamp.isBefore(cutoff)) {
              continue;
            }

            final event = CallControlEvent.fromMap(
              Map<String, dynamic>.from(callMap),
              messageId: messageId,
              senderId: row['sender_id']?.toString(),
            );

            if (!event.involves(currentUserId)) {
              continue;
            }

            if (event.senderId == currentUserId) {
              continue;
            }

            yield event;
          }
        });
  }

  Future<void> sendInvite({
    required PlanetModel senderProfile,
    required String chatId,
    required String otherUid,
    required String callId,
    required String roomId,
  }) {
    return _send(
      senderProfile: senderProfile,
      chatId: chatId,
      otherUid: otherUid,
      plaintext: 'Voice call',
      event: CallControlEvent(
        type: CallControlEventType.invite,
        callId: callId,
        roomId: roomId,
        chatId: chatId,
        actorId: senderProfile.id,
        targetId: otherUid,
        peerName: senderProfile.xparqName,
        peerAvatarUrl: senderProfile.photoUrl,
        sentAt: DateTime.now(),
      ),
    );
  }

  Future<void> sendAccept({
    required PlanetModel senderProfile,
    required String chatId,
    required String otherUid,
    required String callId,
    required String roomId,
  }) {
    return _send(
      senderProfile: senderProfile,
      chatId: chatId,
      otherUid: otherUid,
      plaintext: 'Call accepted',
      event: CallControlEvent(
        type: CallControlEventType.accept,
        callId: callId,
        roomId: roomId,
        chatId: chatId,
        actorId: senderProfile.id,
        targetId: otherUid,
        peerName: senderProfile.xparqName,
        peerAvatarUrl: senderProfile.photoUrl,
        sentAt: DateTime.now(),
      ),
    );
  }

  Future<void> sendReject({
    required PlanetModel senderProfile,
    required String chatId,
    required String otherUid,
    required String callId,
    required String roomId,
  }) {
    return _send(
      senderProfile: senderProfile,
      chatId: chatId,
      otherUid: otherUid,
      plaintext: 'Call declined',
      event: CallControlEvent(
        type: CallControlEventType.reject,
        callId: callId,
        roomId: roomId,
        chatId: chatId,
        actorId: senderProfile.id,
        targetId: otherUid,
        peerName: senderProfile.xparqName,
        peerAvatarUrl: senderProfile.photoUrl,
        sentAt: DateTime.now(),
      ),
    );
  }

  Future<void> sendEnd({
    required PlanetModel senderProfile,
    required String chatId,
    required String otherUid,
    required String callId,
    required String roomId,
  }) {
    return _send(
      senderProfile: senderProfile,
      chatId: chatId,
      otherUid: otherUid,
      plaintext: 'Call ended',
      event: CallControlEvent(
        type: CallControlEventType.end,
        callId: callId,
        roomId: roomId,
        chatId: chatId,
        actorId: senderProfile.id,
        targetId: otherUid,
        peerName: senderProfile.xparqName,
        peerAvatarUrl: senderProfile.photoUrl,
        sentAt: DateTime.now(),
      ),
    );
  }

  Future<void> sendMediaReady({
    required PlanetModel senderProfile,
    required String chatId,
    required String otherUid,
    required String callId,
    required String roomId,
  }) {
    return _send(
      senderProfile: senderProfile,
      chatId: chatId,
      otherUid: otherUid,
      plaintext: 'Audio ready',
      event: CallControlEvent(
        type: CallControlEventType.mediaReady,
        callId: callId,
        roomId: roomId,
        chatId: chatId,
        actorId: senderProfile.id,
        targetId: otherUid,
        peerName: senderProfile.xparqName,
        peerAvatarUrl: senderProfile.photoUrl,
        sentAt: DateTime.now(),
      ),
    );
  }

  Future<void> sendCameraToggled({
    required PlanetModel senderProfile,
    required String chatId,
    required String otherUid,
    required String callId,
    required String roomId,
    required bool isCameraOn,
  }) {
    return _send(
      senderProfile: senderProfile,
      chatId: chatId,
      otherUid: otherUid,
      plaintext: isCameraOn ? 'Camera on' : 'Camera off',
      event: CallControlEvent(
        type: CallControlEventType.cameraToggled,
        callId: callId,
        roomId: roomId,
        chatId: chatId,
        actorId: senderProfile.id,
        targetId: otherUid,
        peerName: senderProfile.xparqName,
        peerAvatarUrl: senderProfile.photoUrl,
        sentAt: DateTime.now(),
      ),
    );
  }

  Future<void> sendCallLog({
    required PlanetModel senderProfile,
    required String chatId,
    required String otherUid,
    required String callId,
    required String roomId,
    required String status,
    required String? duration,
  }) {
    return _chatRepository.sendMessage(
      chatId: chatId,
      senderProfile: senderProfile,
      plaintext: status,
      isSensitive: false,
      otherUid: otherUid,
      messageType: 'call', // This triggers special rendering in MessageBubble
      clientPendingId:
          'call_log_${callId}_${DateTime.now().microsecondsSinceEpoch}',
      metadata: {
        'xparq_call_log': {
          'call_id': callId,
          'room_id': roomId,
          'status': status,
          'duration': duration,
          'timestamp': DateTime.now().toIso8601String(),
        },
      },
    );
  }

  Future<void> _send({
    required PlanetModel senderProfile,
    required String chatId,
    required String otherUid,
    required String plaintext,
    required CallControlEvent event,
  }) {
    return _chatRepository.sendMessage(
      chatId: chatId,
      senderProfile: senderProfile,
      plaintext: plaintext,
      isSensitive: false,
      otherUid: otherUid,
      clientPendingId:
          'call_${event.type.name}_${event.callId}_${DateTime.now().microsecondsSinceEpoch}',
      metadata: {
        'silent': true,
        'xparq_call': event.toMap(),
      },
    );
  }
}
