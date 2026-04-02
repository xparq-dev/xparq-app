import 'package:xparq_app/core/errors/app_exception.dart';
import 'package:xparq_app/features/chat_signal/models/signal_event_model.dart';
import 'package:xparq_app/features/chat_signal/repositories/chat_signal_repository.dart';

class SignalService {
  const SignalService(this._repository);

  final ChatSignalRepository _repository;

  Stream<SignalEvent> connect() {
    try {
      return _repository.connect();
    } on AppException {
      rethrow;
    } catch (error) {
      throw AppException('Unable to start the signal listener.', cause: error);
    }
  }

  Future<void> disconnect() async {
    try {
      await _repository.disconnect();
    } on AppException {
      rethrow;
    } catch (error) {
      throw AppException('Unable to stop the signal listener.', cause: error);
    }
  }
}
