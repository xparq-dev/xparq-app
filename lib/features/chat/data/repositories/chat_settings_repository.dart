import 'package:supabase_flutter/supabase_flutter.dart';

/// Repository responsible for user-specific chat preferences and status controls,
/// such as pinning, archiving, and silencing clusters.
class ChatSettingsRepository {
  final SupabaseClient _client;

  ChatSettingsRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  /// Provides a real-time stream of settings for all chats associated with [uid].
  ///
  /// Returned map is keyed by `chat_id`.
  Stream<Map<String, Map<String, dynamic>>> watchChatSettings(String uid) {
    return _client
        .from('chat_settings')
        .stream(primaryKey: ['uid', 'chat_id'])
        .eq('uid', uid)
        .map((list) {
          final settings = <String, Map<String, dynamic>>{};
          for (final data in list) {
            final chatId = data['chat_id'] as String;
            settings[chatId] = data;
          }
          return settings;
        });
  }

  /// Toggles the 'pinned' status of a chat for the current user.
  Future<void> togglePin(String chatId, bool isPinned) async {
    try {
      await _client.rpc<void>(
        'toggle_chat_pin',
        params: {'p_chat_id': chatId, 'p_is_pinned': isPinned},
      );
    } catch (e) {
      throw Exception('Failed to update pin preference: $e');
    }
  }

  /// Toggles the 'archived' status of a chat for the current user.
  Future<void> toggleChatArchive(String chatId, bool isArchived) async {
    try {
      await _client.rpc<void>(
        'toggle_chat_archive',
        params: {'p_chat_id': chatId, 'p_is_archived': isArchived},
      );
    } catch (e) {
      throw Exception('Failed to update archive preference: $e');
    }
  }

  /// Silences notifications for a chat until the specified [until] time.
  Future<void> silenceChat(String chatId, DateTime? until) async {
    try {
      await _client.rpc<void>(
        'silence_chat',
        params: {'p_until': until?.toIso8601String(), 'p_chat_id': chatId},
      );
    } catch (e) {
      throw Exception('Failed to silence cluster: $e');
    }
  }

  /// Updates the vanishing message duration preference for a cluster.
  Future<void> updateVanishingDuration({
    required String chatId,
    required List<String> participants,
    required int? durationSeconds,
  }) async {
    try {
      await _client.from('chats').upsert({
        'id': chatId,
        'participants': participants,
        'vanishing_duration': durationSeconds,
      });
    } catch (e) {
      throw Exception('Failed to update vanishing signal duration: $e');
    }
  }
}
