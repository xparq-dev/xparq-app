import 'package:xparq_app/features/chat/models/message_model.dart';
import 'package:xparq_app/features/chat/repositories/chat_repository.dart';

class SignalService {
  SignalService(this._repository);

  final ChatRepository _repository;

  Stream<List<MessageModel>>? _messagesStream;

  Stream<List<MessageModel>> watchMessages({
    required String currentUserId,
    required String otherUserId,
  }) {
    return _messagesStream ??= _repository
        .watchMessages(currentUserId: currentUserId, otherUserId: otherUserId)
        .asBroadcastStream();
  }
}
