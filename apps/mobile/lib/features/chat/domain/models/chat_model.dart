// lib/features/chat/models/chat_model.dart
// ... (comments)

DateTime _parseServerDateTime(dynamic value) {
  if (value == null) return DateTime.now();
  return DateTime.parse(value.toString()).toLocal();
}

class ChatModel {
  final String chatId;
  final List<String> participants;
  final String lastMessage;
  final String lastSenderId;
  final DateTime? lastAt;
  final DateTime createdAt;
  final bool isSensitive;
  final bool isSpam;
  final bool isGroup;
  final String? name;
  final String? groupAvatar;
  final int unreadCount;
  final int? vanishingDuration; // Seconds, null if disabled
  final bool isPinned;
  final bool isArchived;
  final DateTime? silencedUntil;
  final List<String> admins;
  final List<String> pinnedMessages;
  final Map<String, dynamic> metadata;

  const ChatModel({
    required this.chatId,
    required this.participants,
    this.lastMessage = '',
    this.lastSenderId = '',
    this.lastAt,
    required this.createdAt,
    this.isSensitive = false,
    this.isSpam = false,
    this.isGroup = false,
    this.name,
    this.groupAvatar,
    this.unreadCount = 0,
    this.vanishingDuration,
    this.isPinned = false,
    this.isArchived = false,
    this.silencedUntil,
    this.admins = const [],
    this.pinnedMessages = const [],
    this.metadata = const {},
  });

  /// Generate a deterministic chat ID from two UIDs (sorted).
  static String buildChatId(String uid1, String uid2) {
    final sorted = [uid1, uid2]..sort();
    return '${sorted[0]}_${sorted[1]}';
  }

  factory ChatModel.fromMap(Map<String, dynamic> data) {
    return ChatModel(
      chatId: data['id'] ?? '',
      participants: List<String>.from(data['participants'] ?? []),
      lastMessage: data['last_message'] ?? '',
      lastSenderId: data['last_sender'] ?? '',
      lastAt: data['last_at'] != null
          ? _parseServerDateTime(data['last_at'])
          : null,
      createdAt: _parseServerDateTime(data['created_at']),
      isSensitive: data['is_sensitive'] ?? false,
      isSpam: data['is_spam'] ?? false,
      isGroup: data['is_group'] ?? false,
      name: data['name'],
      groupAvatar: data['group_avatar'],
      unreadCount: data['unread_count'] ?? 0,
      vanishingDuration: data['vanishing_duration'],
      isPinned: data['is_pinned'] ?? false,
      isArchived: data['is_archived'] ?? false,
      silencedUntil: data['silenced_until'] != null
          ? _parseServerDateTime(data['silenced_until'])
          : null,
      admins: List<String>.from(data['admins'] ?? []),
      pinnedMessages: List<String>.from(data['pinned_messages'] ?? []),
      metadata: Map<String, dynamic>.from(data['metadata'] ?? {}),
    );
  }

  Map<String, dynamic> toMap() => {
    'participants': participants,
    'last_message': lastMessage,
    'last_sender': lastSenderId,
    'last_at': lastAt?.toIso8601String(),
    'created_at': createdAt.toIso8601String(),
    'is_sensitive': isSensitive,
    'is_spam': isSpam,
    'is_group': isGroup,
    'name': name,
    'group_avatar': groupAvatar,
    'unread_count': unreadCount,
    'vanishing_duration': vanishingDuration,
    'is_pinned': isPinned,
    'is_archived': isArchived,
    'silenced_until': silencedUntil?.toIso8601String(),
    'admins': admins,
    'pinned_messages': pinnedMessages,
    'metadata': metadata,
  };

  /// Compatibility getters for UI layers that expect these names.
  String get groupName => name ?? 'Cluster';
  String get groupIcon => groupAvatar ?? '';

  ChatModel copyWith({
    String? chatId,
    List<String>? participants,
    String? lastMessage,
    String? lastSenderId,
    DateTime? lastAt,
    DateTime? createdAt,
    bool? isSensitive,
    bool? isSpam,
    bool? isGroup,
    String? name,
    String? groupAvatar,
    int? unreadCount,
    int? vanishingDuration,
    bool? isPinned,
    bool? isArchived,
    DateTime? silencedUntil,
    List<String>? admins,
    List<String>? pinnedMessages,
    Map<String, dynamic>? metadata,
  }) {
    return ChatModel(
      chatId: chatId ?? this.chatId,
      participants: participants ?? this.participants,
      lastMessage: lastMessage ?? this.lastMessage,
      lastSenderId: lastSenderId ?? this.lastSenderId,
      lastAt: lastAt ?? this.lastAt,
      createdAt: createdAt ?? this.createdAt,
      isSensitive: isSensitive ?? this.isSensitive,
      isSpam: isSpam ?? this.isSpam,
      isGroup: isGroup ?? this.isGroup,
      name: name ?? this.name,
      groupAvatar: groupAvatar ?? this.groupAvatar,
      unreadCount: unreadCount ?? this.unreadCount,
      vanishingDuration: vanishingDuration ?? this.vanishingDuration,
      isPinned: isPinned ?? this.isPinned,
      isArchived: isArchived ?? this.isArchived,
      silencedUntil: silencedUntil ?? this.silencedUntil,
      admins: admins ?? this.admins,
      pinnedMessages: pinnedMessages ?? this.pinnedMessages,
      metadata: metadata ?? this.metadata,
    );
  }
}

/// Type of message — enables special card rendering in the chat UI.
enum MessageType { text, contactRequest, contactCard, image, video, sticker, deleted }

class MessageModel {
  final String messageId;
  final String senderUid;
  final String content; // AES-256 encrypted on client before sending
  final DateTime timestamp;
  final bool isSensitive; // NSFW flag
  final bool delivered;
  final bool read;
  final bool isOfflineRelay;
  final bool isSpam;
  final MessageType messageType;
  final Map<String, dynamic> metadata; // Payload for special messages
  final DateTime? expiresAt; // For vanishing messages
  final List<String> deletedUids;
  final String?
  decryptedContent; // Populated by provider after batch decryption

  const MessageModel({
    required this.messageId,
    required this.senderUid,
    required this.content,
    required this.timestamp,
    this.isSensitive = false,
    this.delivered = false,
    this.read = false,
    this.isOfflineRelay = false,
    this.isSpam = false,
    this.messageType = MessageType.text,
    this.metadata = const {},
    this.expiresAt,
    this.deletedUids = const [],
    this.decryptedContent,
  });

  // Echo (Reply) Getters
  String? get replyToId => metadata['reply_to_id']?.toString();
  String? get replyToSenderId => metadata['reply_to_sender_id']?.toString();
  String? get replyToName => metadata['reply_to_name']?.toString();
  String? get replyToPreview => metadata['reply_to_preview']?.toString();
  Map<String, String> get reactions => Map<String, String>.from(metadata['reactions'] ?? {});
  List<String> get mentions => List<String>.from(metadata['mentions'] ?? []);

  factory MessageModel.fromMap(Map<String, dynamic> data) {
    return MessageModel(
      messageId: data['id']?.toString() ?? '',
      senderUid: data['sender_id'] ?? '',
      content: data['content'] ?? data['content_encrypted'] ?? '',
      timestamp: _parseServerDateTime(data['timestamp']),
      isSensitive: data['is_sensitive'] ?? false,
      delivered: data['delivered'] ?? false,
      read: data['read'] ?? false,
      isOfflineRelay: data['is_offline_relay'] ?? false,
      isSpam: data['is_spam'] ?? false,
      messageType: _parseMessageType(data['message_type'] as String?),
      metadata: Map<String, dynamic>.from(data['metadata'] as Map? ?? {}),
      expiresAt: data['expires_at'] != null
          ? _parseServerDateTime(data['expires_at'])
          : null,
      deletedUids: List<String>.from(data['deleted_uids'] ?? []),
    );
  }

  MessageModel copyWith({
    String? messageId,
    String? senderUid,
    String? content,
    DateTime? timestamp,
    bool? isSensitive,
    bool? delivered,
    bool? read,
    bool? isOfflineRelay,
    bool? isSpam,
    MessageType? messageType,
    Map<String, dynamic>? metadata,
    DateTime? expiresAt,
    List<String>? deletedUids,
    String? decryptedContent,
  }) {
    return MessageModel(
      messageId: messageId ?? this.messageId,
      senderUid: senderUid ?? this.senderUid,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      isSensitive: isSensitive ?? this.isSensitive,
      delivered: delivered ?? this.delivered,
      read: read ?? this.read,
      isOfflineRelay: isOfflineRelay ?? this.isOfflineRelay,
      isSpam: isSpam ?? this.isSpam,
      messageType: messageType ?? this.messageType,
      metadata: metadata ?? this.metadata,
      expiresAt: expiresAt ?? this.expiresAt,
      deletedUids: deletedUids ?? this.deletedUids,
      decryptedContent: decryptedContent ?? this.decryptedContent,
    );
  }

  static MessageType _parseMessageType(String? v) {
    switch (v) {
      case 'contactRequest':
        return MessageType.contactRequest;
      case 'contactCard':
        return MessageType.contactCard;
      case 'image':
        return MessageType.image;
      case 'video':
        return MessageType.video;
      case 'sticker':
        return MessageType.sticker;
      case 'deleted':
        return MessageType.deleted;
      default:
        return MessageType.text;
    }
  }

  Map<String, dynamic> toMap() => {
    'sender_id': senderUid,
    'content': content,
    'timestamp': timestamp.toIso8601String(),
    'is_sensitive': isSensitive,
    'delivered': delivered,
    'read': read,
    'is_offline_relay': isOfflineRelay,
    'is_spam': isSpam,
    'message_type': messageType.name,
    'metadata': metadata,
    'expires_at': expiresAt?.toIso8601String(),
    'deleted_uids': deletedUids,
  };
}
