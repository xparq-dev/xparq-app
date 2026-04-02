import 'package:xparq_app/core/errors/app_exception.dart';
import 'package:xparq_app/features/chat/models/message_model.dart';
import 'package:xparq_app/features/chat/repositories/chat_repository.dart';

class ChatService {
  const ChatService(this._repository);

  final ChatRepository _repository;

  Future<List<MessageModel>> loadMessages({
    required String currentUserId,
    required String otherUserId,
  }) async {
    try {
      return await _repository.fetchMessages(
        currentUserId: currentUserId,
        otherUserId: otherUserId,
      );
    } on AppException {
      rethrow;
    } catch (error) {
      throw AppException('Unable to load chat history.', cause: error);
    }
  }

  Future<MessageModel> send({
    required String content,
    required String senderId,
    required String otherUserId,
  }) async {
    final normalizedContent = content.trim();
    final normalizedSenderId = senderId.trim();
    final normalizedOtherUserId = otherUserId.trim();

    if (normalizedSenderId.isEmpty) {
      throw const ValidationException(
        'A valid sender is required.',
        field: 'senderId',
      );
    }

    if (normalizedOtherUserId.isEmpty) {
      throw const ValidationException(
        'A recipient is required.',
        field: 'otherUserId',
      );
    }

    if (normalizedContent.isEmpty) {
      throw const ValidationException(
        'Message content cannot be empty.',
        field: 'content',
      );
    }

    if (normalizedContent.length > 2000) {
      throw const ValidationException(
        'Message content cannot exceed 2000 characters.',
        field: 'content',
      );
    }

    try {
      return await _repository.sendMessage(
        content: normalizedContent,
        senderId: normalizedSenderId,
        otherUserId: normalizedOtherUserId,
      );
    } on AppException {
      rethrow;
    } catch (error) {
      throw AppException('Unable to send the message.', cause: error);
    }
  }
}
