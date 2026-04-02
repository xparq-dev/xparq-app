import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xparq_app/core/errors/app_exception.dart';
import 'package:xparq_app/features/chat_signal/models/signal_event_model.dart';
import 'package:xparq_app/features/chat_signal/repositories/chat_signal_repository.dart';
import 'package:xparq_app/features/chat_signal/services/signal_service.dart';

final chatSignalRepositoryProvider = Provider<ChatSignalRepository>((ref) {
  return ChatSignalRepository();
});

final chatSignalServiceProvider = Provider<SignalService>((ref) {
  return SignalService(ref.read(chatSignalRepositoryProvider));
});

enum ChatSignalStatus { initial, connecting, connected, disconnected, error }

@immutable
class ChatState {
  final ChatSignalStatus status;
  final List<SignalEvent> events;
  final String? errorMessage;

  const ChatState({
    this.status = ChatSignalStatus.initial,
    this.events = const <SignalEvent>[],
    this.errorMessage,
  });

  ChatState copyWith({
    ChatSignalStatus? status,
    List<SignalEvent>? events,
    String? errorMessage,
    bool clearError = false,
  }) {
    return ChatState(
      status: status ?? this.status,
      events: events ?? this.events,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class ChatProvider extends StateNotifier<ChatState> {
  ChatProvider(this._signalService) : super(const ChatState()) {
    connect();
  }

  final SignalService _signalService;

  StreamSubscription<SignalEvent>? _subscription;

  Future<void> connect() async {
    if (state.status == ChatSignalStatus.connecting ||
        state.status == ChatSignalStatus.connected) {
      return;
    }

    state = state.copyWith(
      status: ChatSignalStatus.connecting,
      clearError: true,
    );

    try {
      await _subscription?.cancel();
      _subscription = _signalService.connect().listen(
        pushEvent,
        onError: (Object error, StackTrace stackTrace) {
          final message = error is AppException
              ? error.message
              : 'Realtime signal connection failed.';

          state = state.copyWith(
            status: ChatSignalStatus.error,
            errorMessage: message,
          );
        },
      );

      state = state.copyWith(
        status: ChatSignalStatus.connected,
        clearError: true,
      );
    } on AppException catch (error) {
      state = state.copyWith(
        status: ChatSignalStatus.error,
        errorMessage: error.message,
      );
    } catch (_) {
      state = state.copyWith(
        status: ChatSignalStatus.error,
        errorMessage: 'Unable to connect to realtime signals.',
      );
    }
  }

  void pushEvent(SignalEvent event) {
    final updatedEvents = <SignalEvent>[event, ...state.events];

    state = state.copyWith(
      status: ChatSignalStatus.connected,
      events: updatedEvents,
      clearError: true,
    );
  }

  Future<void> disconnect() async {
    try {
      await _subscription?.cancel();
      _subscription = null;
      await _signalService.disconnect();

      state = state.copyWith(
        status: ChatSignalStatus.disconnected,
        clearError: true,
      );
    } on AppException catch (error) {
      state = state.copyWith(
        status: ChatSignalStatus.error,
        errorMessage: error.message,
      );
    } catch (_) {
      state = state.copyWith(
        status: ChatSignalStatus.error,
        errorMessage: 'Unable to disconnect from realtime signals.',
      );
    }
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    unawaited(_signalService.disconnect());
    super.dispose();
  }
}

final chatSignalProvider =
    StateNotifierProvider.autoDispose<ChatProvider, ChatState>((ref) {
      return ChatProvider(ref.read(chatSignalServiceProvider));
    });
