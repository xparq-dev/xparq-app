// lib/features/chat/models/message.dart
//
// Core data model for a single chat message.
// Used across ALL layers: models → repositories → services → providers → UI.
// Do NOT import domain/ or presentation/ layers from this file.

import 'package:flutter/foundation.dart';

// ── Status enum ───────────────────────────────────────────────────────────────

/// Full lifecycle of an outgoing message.
enum MessageStatus {
  /// Optimistic — being transmitted to the server.
  sending,

  /// Server has persisted the message in the database.
  sent,

  /// Recipient device has acknowledged receipt (signal ACK).
  delivered,

  /// Recipient has opened the conversation and read the message.
  seen,

  /// Transmission failed; eligible for manual or automatic retry.
  failed,
}

extension MessageStatusX on MessageStatus {
  /// Serialisable string — used in JSON payloads and SQLite rows.
  String get value => name; // 'sending' | 'sent' | 'delivered' | 'seen' | 'failed'

  /// Deserialise from a raw string; defaults to [MessageStatus.sending].
  static MessageStatus fromString(String? raw) => switch (raw) {
        'sent' => MessageStatus.sent,
        'delivered' => MessageStatus.delivered,
        'seen' => MessageStatus.seen,
        'failed' => MessageStatus.failed,
        _ => MessageStatus.sending,
      };
}

// ── Model ─────────────────────────────────────────────────────────────────────

/// Immutable data model for a chat message.
///
/// Supports three serialisation formats:
///  - [fromJson] / [toJson]  — Supabase REST / Signal broadcast payloads.
///  - [fromMap]  / [toMap]   — SQLite (sqflite) rows.
@immutable
class Message {
  const Message({
    required this.id,
    required this.content,
    required this.senderId,
    required this.receiverId,
    required this.chatId,
    required this.timestamp,
    this.status = MessageStatus.sending,
  });

  final String id;
  final String content;
  final String senderId;
  final String receiverId;
  final String chatId;
  final DateTime timestamp;
  final MessageStatus status;

  // ── Supabase JSON ─────────────────────────────────────────────────────────────

  factory Message.fromJson(Map<String, dynamic> json) => Message(
        id: json['id']?.toString() ?? '',
        content: json['content']?.toString() ?? '',
        senderId:
            json['sender_id']?.toString() ?? json['senderId']?.toString() ?? '',
        receiverId: json['receiver_id']?.toString() ??
            json['receiverId']?.toString() ??
            '',
        chatId:
            json['chat_id']?.toString() ?? json['chatId']?.toString() ?? '',
        timestamp: _parseDateTime(json['timestamp']),
        status: MessageStatusX.fromString(json['status']?.toString()),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'content': content,
        'sender_id': senderId,
        'receiver_id': receiverId,
        'chat_id': chatId,
        'timestamp': timestamp.toUtc().toIso8601String(),
        'status': status.value,
      };

  // ── SQLite Map ────────────────────────────────────────────────────────────────

  factory Message.fromMap(Map<String, dynamic> map) => Message(
        id: map['id']?.toString() ?? '',
        content: map['content']?.toString() ?? '',
        senderId: map['sender_id']?.toString() ?? '',
        receiverId: map['receiver_id']?.toString() ?? '',
        chatId: map['chat_id']?.toString() ?? '',
        // SQLite stores timestamps as milliseconds-since-epoch (INTEGER).
        timestamp: DateTime.fromMillisecondsSinceEpoch(
          (map['timestamp'] as int?) ?? 0,
          isUtc: true,
        ).toLocal(),
        status: MessageStatusX.fromString(map['status']?.toString()),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'content': content,
        'sender_id': senderId,
        'receiver_id': receiverId,
        'chat_id': chatId,
        'timestamp': timestamp.toUtc().millisecondsSinceEpoch,
        'status': status.value,
      };

  // ── Utility ───────────────────────────────────────────────────────────────────

  Message copyWith({
    String? id,
    String? content,
    String? senderId,
    String? receiverId,
    String? chatId,
    DateTime? timestamp,
    MessageStatus? status,
  }) =>
      Message(
        id: id ?? this.id,
        content: content ?? this.content,
        senderId: senderId ?? this.senderId,
        receiverId: receiverId ?? this.receiverId,
        chatId: chatId ?? this.chatId,
        timestamp: timestamp ?? this.timestamp,
        status: status ?? this.status,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Message &&
          other.id == id &&
          other.status == status &&
          other.content == content);

  @override
  int get hashCode => Object.hash(id, status, content);

  @override
  String toString() =>
      'Message(id: $id, status: ${status.value}, snippet: '
      '${content.length > 30 ? '${content.substring(0, 30)}…' : content})';

  // ── Private helpers ───────────────────────────────────────────────────────────

  static DateTime _parseDateTime(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is DateTime) return value.toLocal();
    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value, isUtc: true).toLocal();
    }
    return DateTime.tryParse(value.toString())?.toLocal() ?? DateTime.now();
  }
}
