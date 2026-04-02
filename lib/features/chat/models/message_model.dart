import 'package:flutter/foundation.dart';

@immutable
class MessageModel {
  final String id;
  final String content;
  final String senderId;
  final DateTime timestamp;

  const MessageModel({
    required this.id,
    required this.content,
    required this.senderId,
    required this.timestamp,
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
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'content': content,
      'sender_id': senderId,
      'timestamp': timestamp.toUtc().toIso8601String(),
    };
  }

  MessageModel copyWith({
    String? id,
    String? content,
    String? senderId,
    DateTime? timestamp,
  }) {
    return MessageModel(
      id: id ?? this.id,
      content: content ?? this.content,
      senderId: senderId ?? this.senderId,
      timestamp: timestamp ?? this.timestamp,
    );
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
        other.timestamp == timestamp;
  }

  @override
  int get hashCode => Object.hash(id, content, senderId, timestamp);
}
