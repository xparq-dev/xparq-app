import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:xparq_app/shared/errors/app_exception.dart';
import 'package:xparq_app/features/chat/domain/models/chat_model.dart'
    show ChatModel;
import 'package:xparq_app/features/chat/models/message_model.dart';

class ChatRepository {
  ChatRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<List<MessageModel>> fetchMessages({
    required String currentUserId,
    required String otherUserId,
  }) async {
    try {
      final chatId = await _ensureChatExists(
        currentUserId: currentUserId,
        otherUserId: otherUserId,
      );

      final response = await _client
          .from('messages')
          .select('id, content, sender_id, timestamp, message_type, metadata')
          .eq('chat_id', chatId)
          .order('timestamp', ascending: true);

      final rows = (response as List<dynamic>)
          .map((row) => MessageModel.fromJson(Map<String, dynamic>.from(row)))
          .toList();

      rows.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      return rows;
    } on PostgrestException catch (error) {
      throw _mapPostgrestException(error);
    } catch (error) {
      throw AppException('Failed to load chat messages.', cause: error);
    }
  }

  Stream<List<MessageModel>> watchMessages({
    required String currentUserId,
    required String otherUserId,
  }) {
    final normalizedCurrentUserId = currentUserId.trim();
    final normalizedOtherUserId = otherUserId.trim();

    if (normalizedCurrentUserId.isEmpty || normalizedOtherUserId.isEmpty) {
      return Stream<List<MessageModel>>.value(const <MessageModel>[]);
    }

    final chatId = _buildChatId(
      currentUserId: normalizedCurrentUserId,
      otherUserId: normalizedOtherUserId,
    );

    return _client
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('chat_id', chatId)
        .order('timestamp', ascending: true)
        .map((rows) {
          final messages = rows
              .map((row) => MessageModel.fromJson(row))
              .toList()
            ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
          return messages;
        })
        .handleError((Object error) {
          if (error is PostgrestException) {
            throw _mapPostgrestException(error);
          }

          throw AppException('Realtime chat connection failed.', cause: error);
        });
  }

  Future<MessageModel> sendMessage({
    required String content,
    required String senderId,
    required String otherUserId,
  }) async {
    try {
      final chatId = await _ensureChatExists(
        currentUserId: senderId,
        otherUserId: otherUserId,
      );

      await _client.rpc<void>(
        'send_chat_message_v2',
        params: <String, dynamic>{
          'p_chat_id': chatId,
          'p_sender_id': senderId,
          'p_content': content,
          'p_is_sensitive': false,
          'p_is_offline_relay': false,
          'p_is_spam': false,
          'p_plaintext_preview': content,
          'p_message_type': 'text',
          'p_metadata': const <String, dynamic>{},
          'p_expires_at': null,
        },
      );

      final latestMessage = await _client
          .from('messages')
          .select('id, content, sender_id, timestamp, message_type, metadata')
          .eq('chat_id', chatId)
          .eq('sender_id', senderId)
          .order('timestamp', ascending: false)
          .limit(1)
          .maybeSingle();

      if (latestMessage == null) {
        return MessageModel(
          id: '${chatId}_${DateTime.now().microsecondsSinceEpoch}',
          content: content,
          senderId: senderId,
          timestamp: DateTime.now(),
        );
      }

      return MessageModel.fromJson(latestMessage);
    } on PostgrestException catch (error) {
      throw _mapPostgrestException(error);
    } catch (error) {
      throw AppException('Failed to send the message.', cause: error);
    }
  }

  Future<String> _ensureChatExists({
    required String currentUserId,
    required String otherUserId,
  }) async {
    final normalizedCurrentUserId = currentUserId.trim();
    final normalizedOtherUserId = otherUserId.trim();

    if (normalizedCurrentUserId.isEmpty || normalizedOtherUserId.isEmpty) {
      throw const ValidationException(
        'A recipient is required to open this chat.',
        field: 'otherUserId',
      );
    }

    final chatId = _buildChatId(
      currentUserId: normalizedCurrentUserId,
      otherUserId: normalizedOtherUserId,
    );

    final existingChat =
        await _client.from('chats').select('id').eq('id', chatId).maybeSingle();

    if (existingChat == null) {
      await _client.from('chats').insert(<String, dynamic>{
        'id': chatId,
        'participants': <String>[
          normalizedCurrentUserId,
          normalizedOtherUserId,
        ],
        'created_at': DateTime.now().toUtc().toIso8601String(),
        'is_spam': false,
      });
    }

    return chatId;
  }

  String _buildChatId({
    required String currentUserId,
    required String otherUserId,
  }) {
    return ChatModel.buildChatId(currentUserId, otherUserId);
  }

  AppException _mapPostgrestException(PostgrestException error) {
    if (error.code == '42501') {
      return PermissionException(
        'You do not have permission to access this chat.',
        cause: error,
      );
    }

    if (error.code == 'PGRST205') {
      return const NotFoundException(
        'The chat schema is not available in this environment.',
      );
    }

    if (error.code == 'PGRST116') {
      return const NotFoundException('Chat messages were not found.');
    }

    return AppException(
      error.message.isNotEmpty
          ? error.message
          : 'A database error occurred while processing chat data.',
      cause: error,
    );
  }
}
