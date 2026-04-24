// lib/features/social/models/echo_model.dart

// import 'package:cloud_firestore/cloud_firestore.dart'; // Removed for Supabase

/// An Echo is a comment on a Pulse.
/// Stored in: pulses/{pulseId}/echoes/{echoId}
class EchoModel {
  final String id;
  final String uid;
  final String authorName;
  final String authorAvatar;
  final String content;
  final DateTime createdAt;

  EchoModel({
    required this.id,
    required this.uid,
    required this.authorName,
    required this.authorAvatar,
    required this.content,
    required this.createdAt,
  });

  factory EchoModel.fromMap(Map<String, dynamic> data) {
    return EchoModel(
      id: data['id']?.toString() ?? '',
      uid: data['uid'] ?? '',
      authorName:
          data['author_name'] ?? data['author_meta']?['name'] ?? 'Unknown',
      authorAvatar:
          data['author_avatar'] ?? data['author_meta']?['avatar'] ?? '',
      content: data['content'] ?? '',
      createdAt: data['created_at'] != null
          ? DateTime.tryParse(data['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'author_name': authorName,
      'author_avatar': authorAvatar,
      'content': content,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
