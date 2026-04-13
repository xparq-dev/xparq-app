import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:xparq_app/shared/enums/age_group.dart';
import 'package:xparq_app/features/chat/domain/models/chat_model.dart';

/// Repository responsible for all signal message operations,
/// including streaming, sending, deleting, and status updates.
class MessageRepository {
  final SupabaseClient _client;
  static const _sendChatMessagePrimaryRpc = 'send_chat_message_v2';
  static const _realtimeMessageWindow = 160;

  MessageRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  /// Provides a real-time stream of messages for a specific [chatId].
  ///
  /// Implements age-based filtering for 'Cadet' users to suppress sensitive content.
  Stream<List<MessageModel>> watchMessages({
    required String chatId,
    required AgeGroup callerAgeGroup,
    required String callerUid,
  }) {
    return _client
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('chat_id', chatId)
        .order('timestamp', ascending: false)
        .limit(_realtimeMessageWindow)
        .map((list) {
          final now = DateTime.now();
          final messages = list.map((data) => MessageModel.fromMap(data)).where(
            (m) {
              if (m.deletedUids.contains(callerUid)) return false;
              if (m.expiresAt != null && m.expiresAt!.isBefore(now)) {
                return false;
              }
              return true;
            },
          ).toList();

          messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));

          if (callerAgeGroup == AgeGroup.cadet) {
            return messages.where((m) => !m.isSensitive).toList();
          }
          return messages;
        });
  }

  /// Internally invokes the database RPC to finalize a message send.
  ///
  /// Supports fallback logic for legacy database schemas.
  Future<void> insertMessageRpc({
    required String chatId,
    required String senderId,
    required String content,
    required bool isSensitive,
    required bool isOfflineRelay,
    required bool isSpam,
    required String plaintextPreview,
    String messageType = 'text',
    Map<String, dynamic>? metadata,
    DateTime? expiresAt,
  }) async {
    final params = <String, dynamic>{
      'p_chat_id': chatId,
      'p_sender_id': senderId,
      'p_is_sensitive': isSensitive,
      'p_is_offline_relay': isOfflineRelay,
      'p_is_spam': isSpam,
      'p_plaintext_preview': plaintextPreview,
    };
    final paramsWithOptional = <String, dynamic>{
      ...params,
      'p_message_type': messageType,
      'p_metadata': metadata ?? const <String, dynamic>{},
      'p_expires_at': expiresAt?.toIso8601String(),
    };

    try {
      await _client.rpc<void>(
        _sendChatMessagePrimaryRpc,
        params: {...paramsWithOptional, 'p_content': content},
      );
    } catch (e) {
      // Fallback or retry logic can be added here if needed for environment parity
      rethrow;
    }
  }

  /// Marks unread messages in a chat as read by the specified [readerUid].
  Future<void> markAsRead(String chatId, String readerUid) async {
    try {
      await _client
          .from('messages')
          .update({'read': true, 'delivered': true})
          .eq('chat_id', chatId)
          .neq('sender_id', readerUid)
          .eq('read', false);
    } catch (e) {
      // Silent fail for non-critical read-state updates
    }
  }

  /// Marks unread messages in a chat as delivered.
  Future<void> markAsDelivered(String chatId, String readerUid) async {
    try {
      await _client
          .from('messages')
          .update({'delivered': true})
          .eq('chat_id', chatId)
          .neq('sender_id', readerUid)
          .eq('delivered', false);
    } catch (e) {
      // Silent fail
    }
  }

  /// Provides a real-time stream of unread counts per chat for the specified [uid].
  Stream<Map<String, int>> watchUnreadCounts(String uid) {
    return _client
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('read', false)
        .map((list) {
          final counts = <String, int>{};
          for (final data in list) {
            final senderId = data['sender_id'] as String;
            if (senderId == uid) continue;
            final chatId = data['chat_id'] as String;
            counts[chatId] = (counts[chatId] ?? 0) + 1;
          }
          return counts;
        });
  }

  /// Retrieves a snapshot of unread counts per chat for the specified [uid].
  Future<Map<String, int>> getUnreadCounts(String uid) async {
    try {
      final response = await _client
          .from('messages')
          .select('chat_id')
          .eq('read', false)
          .neq('sender_id', uid);

      final counts = <String, int>{};
      for (final data in response as List) {
        final chatId = data['chat_id'] as String;
        counts[chatId] = (counts[chatId] ?? 0) + 1;
      }
      return counts;
    } catch (e) {
      return {};
    }
  }

  /// Subscribes to typing status changes for the specified [chatId].
  RealtimeChannel subscribeToTyping({
    required String chatId,
    required bool isGroup,
    required void Function(String uid, bool isTyping) onUserTyping,
  }) {
    final channel = _client.channel('chat_typing:$chatId');

    if (isGroup) {
      channel.onPresenceSync((payload) {
        final presenceState = channel.presenceState();
        for (final presenceObj in presenceState) {
          for (final presence in presenceObj.presences) {
            final p = presence.payload;
            final uid = p['uid'] as String?;
            final isTyping = p['typing'] as bool? ?? false;
            if (uid != null) {
              onUserTyping(uid, isTyping);
            }
          }
        }
      }).subscribe();
    } else {
      channel
          .onBroadcast(
            event: 'typing',
            callback: (payload) {
              final uid = payload['uid'] as String?;
              final isTyping = payload['typing'] as bool? ?? false;
              if (uid != null) {
                onUserTyping(uid, isTyping);
              }
            },
          )
          .subscribe();
    }

    return channel;
  }

  /// Unsubscribes from the given typing [channel].
  void unsubscribeFromTyping(RealtimeChannel? channel) {
    if (channel != null) {
      _client.removeChannel(channel);
    }
  }

  /// Deletes a specific message for all participants.
  Future<void> deleteMessageForEveryone(String messageId) async {
    try {
      await _client
          .from('messages')
          .update({
            'message_type': 'deleted',
            'content': null,
            'content_encrypted': null,
            'metadata': <String, dynamic>{},
            'is_sensitive': false,
          })
          .eq('id', messageId);
    } catch (e) {
      throw Exception('Failed to redact message: $e');
    }
  }

  /// Deletes a specific message for the current user only.
  Future<void> deleteMessageForMe(String messageId) async {
    try {
      await _client.rpc<void>(
        'delete_message_for_me',
        params: {'p_message_id': int.parse(messageId)},
      );
    } catch (e) {
      throw Exception('Failed to remove message locally: $e');
    }
  }

  /// Updates the list of [messageIds] that are pinned within a cluster.
  Future<void> updatePinnedMessages(
    String chatId,
    List<String> messageIds,
  ) async {
    try {
      await _client
          .from('chats')
          .update({'pinned_messages': messageIds})
          .eq('id', chatId);
    } catch (e) {
      throw Exception('Failed to update cluster pins: $e');
    }
  }

  /// Watches for pinned messages within a cluster.
  Stream<List<MessageModel>> watchPinnedMessages(String chatId) {
    return _client
        .from('chats')
        .stream(primaryKey: ['id'])
        .eq('id', chatId)
        .asyncMap((list) async {
          if (list.isEmpty) return [];
          final List<String> pinnedIds = List<String>.from(
            (list.first['pinned_messages'] as Iterable?) ?? [],
          );
          if (pinnedIds.isEmpty) return [];

          final response = await _client
              .from('messages')
              .select()
              .inFilter('id', pinnedIds);

          return (response as List)
              .map((m) => MessageModel.fromMap(m as Map<String, dynamic>))
              .toList();
        });
  }

  /// Toggles a user's 'Spark' (Like/Reaction) on a specific message.
  Future<void> toggleMessageSpark(String messageId, String uid) async {
    try {
      final message = await _client
          .from('messages')
          .select('metadata')
          .eq('id', messageId)
          .single();

      final metadata = Map<String, dynamic>.from(
        message['metadata'] as Map? ?? {},
      );
      final sparks = _normalizeSparks(metadata['sparks']);

      if (sparks.contains(uid)) {
        sparks.remove(uid);
      } else {
        sparks.add(uid);
      }

      metadata['sparks'] = sparks;
      await _client
          .from('messages')
          .update({'metadata': metadata})
          .eq('id', messageId);
    } catch (e) {
      throw Exception('Failed to spark message: $e');
    }
  }

  List<String> _normalizeSparks(dynamic raw) {
    if (raw == null) return [];
    if (raw is List) return List<String>.from(raw.map((e) => e.toString()));
    if (raw is Map) return List<String>.from(raw.keys.map((e) => e.toString()));
    return [];
  }
}
