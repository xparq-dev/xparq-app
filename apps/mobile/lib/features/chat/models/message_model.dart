import 'package:flutter/foundation.dart';

enum MessageType { text, location }

@immutable
class MessageModel {
  final String id;
  final String content;
  final String senderId;
  final DateTime timestamp;
  final MessageType messageType;
  final Map<String, dynamic> metadata;

  const MessageModel({
    required this.id,
    required this.content,
    required this.senderId,
    required this.timestamp,
    this.messageType = MessageType.text,
    this.metadata = const <String, dynamic>{},
  });

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    final rawTimestamp = json['timestamp'];
    final parsedTimestamp = rawTimestamp is DateTime
        ? rawTimestamp
        : DateTime.tryParse(rawTimestamp?.toString() ?? '') ?? DateTime.now();

    return MessageModel(
      id: json['id']?.toString() ?? '',
      content: json['content']?.toString() ?? '',
      senderId:
          json['sender_id']?.toString() ?? json['senderId']?.toString() ?? '',
      timestamp: parsedTimestamp,
      messageType: _parseMessageType(json['message_type']?.toString()),
      metadata: Map<String, dynamic>.from(json['metadata'] as Map? ?? const {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'content': content,
      'sender_id': senderId,
      'timestamp': timestamp.toUtc().toIso8601String(),
      'message_type': messageType.name,
      'metadata': metadata,
    };
  }

  MessageModel copyWith({
    String? id,
    String? content,
    String? senderId,
    DateTime? timestamp,
    MessageType? messageType,
    Map<String, dynamic>? metadata,
  }) {
    return MessageModel(
      id: id ?? this.id,
      content: content ?? this.content,
      senderId: senderId ?? this.senderId,
      timestamp: timestamp ?? this.timestamp,
      messageType: messageType ?? this.messageType,
      metadata: metadata ?? this.metadata,
    );
  }

  static MessageType _parseMessageType(String? value) {
    switch (value) {
      case 'location':
        return MessageType.location;
      default:
        return MessageType.text;
    }
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    return other is MessageModel &&
        other.id == id &&
        other.content == content &&
        other.senderId == senderId &&
        other.timestamp == timestamp &&
        other.messageType == messageType &&
        mapEquals(other.metadata, metadata);
  }

  @override
  int get hashCode =>
      Object.hash(id, content, senderId, timestamp, messageType, metadata);
}
