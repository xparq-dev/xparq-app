enum CallControlEventType {
  invite,
  accept,
  reject,
  end,
  mediaReady,
  cameraToggled,
}

class CallControlEvent {
  final CallControlEventType type;
  final String callId;
  final String roomId;
  final String chatId;
  final String actorId;
  final String targetId;
  final String? peerName;
  final String? peerAvatarUrl;
  final String? messageId;
  final String? senderId;
  final DateTime? sentAt;

  const CallControlEvent({
    required this.type,
    required this.callId,
    required this.roomId,
    required this.chatId,
    required this.actorId,
    required this.targetId,
    this.peerName,
    this.peerAvatarUrl,
    this.messageId,
    this.senderId,
    this.sentAt,
  });

  bool involves(String userId) => actorId == userId || targetId == userId;

  Map<String, dynamic> toMap() {
    return {
      'event': type.name,
      'call_id': callId,
      'room_id': roomId,
      'chat_id': chatId,
      'actor_id': actorId,
      'target_id': targetId,
      if (peerName != null) 'peer_name': peerName,
      if (peerAvatarUrl != null) 'peer_avatar_url': peerAvatarUrl,
      if (sentAt != null) 'sent_at': sentAt!.toIso8601String(),
    };
  }

  factory CallControlEvent.fromMap(
    Map<String, dynamic> map, {
    String? messageId,
    String? senderId,
  }) {
    final rawType = map['event']?.toString() ?? 'invite';
    final type = CallControlEventType.values.firstWhere(
      (value) => value.name == rawType,
      orElse: () => CallControlEventType.invite,
    );

    return CallControlEvent(
      type: type,
      callId: map['call_id']?.toString() ?? '',
      roomId: map['room_id']?.toString() ?? '',
      chatId: map['chat_id']?.toString() ?? '',
      actorId: map['actor_id']?.toString() ?? '',
      targetId: map['target_id']?.toString() ?? '',
      peerName: map['peer_name']?.toString(),
      peerAvatarUrl: map['peer_avatar_url']?.toString(),
      messageId: messageId,
      senderId: senderId,
      sentAt: map['sent_at'] != null
          ? DateTime.tryParse(map['sent_at'].toString())?.toLocal()
          : null,
    );
  }
}
