import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/models/chat_model.dart';

/// Repository responsible for the lifecycle and real-time synchronization
/// of Chat documents and clusters.
class ChatBaseRepository {
  final SupabaseClient _client;

  ChatBaseRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  /// Retrieves or initializes a 1-to-1 chat document between two users.
  ///
  /// Uses a deterministic [chatId] based on the sorted UIDs of both participants.
  Future<ChatModel> getOrCreateChat({
    required String myUid,
    required String otherUid,
  }) async {
    try {
      final chatId = ChatModel.buildChatId(myUid, otherUid);
      final existing = await _client
          .from('chats')
          .select()
          .eq('id', chatId)
          .maybeSingle();

      if (existing == null) {
        final chatData = {
          'id': chatId,
          'participants': [myUid, otherUid],
          'created_at': DateTime.now().toIso8601String(),
          'is_spam': false,
        };
        await _client.from('chats').insert(chatData);
        return ChatModel.fromMap(chatData);
      }
      return ChatModel.fromMap(existing);
    } catch (e) {
      throw Exception('Failed to get or create chat: $e');
    }
  }

  /// Creates a new group chat (Cluster).
  ///
  /// The first participant in [participantUids] is automatically assigned as the administrator.
  Future<ChatModel> createGroupChat({
    required List<String> participantUids,
    required String name,
    String? avatarUrl,
  }) async {
    try {
      final chatId = 'group_${DateTime.now().millisecondsSinceEpoch}';
      final chatData = {
        'id': chatId,
        'participants': participantUids,
        'name': name,
        'group_avatar': avatarUrl,
        'is_group': true,
        'created_at': DateTime.now().toIso8601String(),
        'is_spam': false,
        'admins': participantUids.take(1).toList(),
      };
      await _client.from('chats').insert(chatData);
      return ChatModel.fromMap(chatData);
    } catch (e) {
      throw Exception('Failed to create group cluster: $e');
    }
  }

  /// Provides a real-time stream of non-spam chats for the specified [uid].
  ///
  /// Chats are sorted by the most recent activity ([lastAt] or [createdAt]).
  Stream<List<ChatModel>> watchMyChats(String uid) {
    return _client
        .from('chats')
        .stream(primaryKey: ['id'])
        .map(
          (list) =>
              list
                  .where((data) {
                    final participants = data['participants'] as List;
                    return participants.contains(uid) &&
                        data['is_spam'] == false;
                  })
                  .map((data) => ChatModel.fromMap(data))
                  .toList()
                ..sort(
                  (a, b) => (b.lastAt ?? b.createdAt).compareTo(
                    a.lastAt ?? a.createdAt,
                  ),
                ),
        );
  }

  /// Provides a real-time stream of chats flagged as spam for the specified [uid].
  Stream<List<ChatModel>> watchSpamChats(String uid) {
    return _client
        .from('chats')
        .stream(primaryKey: ['id'])
        .map(
          (list) =>
              list
                  .where((data) {
                    final participants = data['participants'] as List;
                    return participants.contains(uid) &&
                        data['is_spam'] == true;
                  })
                  .map((data) => ChatModel.fromMap(data))
                  .toList()
                ..sort(
                  (a, b) => (b.lastAt ?? b.createdAt).compareTo(
                    a.lastAt ?? a.createdAt,
                  ),
                ),
        );
  }

  /// Accepts a spam chat, effectively moving it to the main Signal list.
  Future<void> acceptChat(String chatId) async {
    try {
      await _client
          .from('chats')
          .update({
            'is_spam': false,
            'accepted_at': DateTime.now().toIso8601String(),
          })
          .eq('id', chatId);
    } catch (e) {
      throw Exception('Failed to accept chat: $e');
    }
  }

  /// Removes a participant from a group chat.
  Future<void> leaveGroup(String chatId, String uid) async {
    try {
      final response = await _client
          .from('chats')
          .select('participants, admins')
          .eq('id', chatId)
          .single();

      final List<String> participants = List<String>.from(
        (response['participants'] as Iterable<dynamic>?) ?? [],
      );
      final List<String> admins = List<String>.from(
        (response['admins'] as Iterable<dynamic>?) ?? [],
      );

      participants.remove(uid);
      admins.remove(uid);

      await _client
          .from('chats')
          .update({'participants': participants, 'admins': admins})
          .eq('id', chatId);
    } catch (e) {
      throw Exception('Failed to leave cluster: $e');
    }
  }

  /// Permanently deletes a chat conversation and all associated messages.
  Future<void> deleteChat(String chatId) async {
    try {
      await _client.from('chats').delete().eq('id', chatId);
    } catch (e) {
      throw Exception('Failed to delete chat: $e');
    }
  }

  /// Permanently deletes a spam chat and records a status delay for the sender.
  Future<void> deleteSpamChat({
    required String chatId,
    required String minorUid,
    required String highRiskSenderUid,
  }) async {
    try {
      await deleteChat(chatId);

      await _client.from('status_delays').upsert({
        'minor_id': minorUid,
        'sender_id': highRiskSenderUid,
        'expires_at': DateTime.now()
            .add(const Duration(hours: 5))
            .toIso8601String(),
      });
    } catch (e) {
      throw Exception('Failed to reject and block spam: $e');
    }
  }
}
