import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xparq_app/core/errors/app_exception.dart';
import 'package:xparq_app/features/chat/models/message_model.dart';
import 'package:xparq_app/features/chat/repositories/chat_repository.dart';
import 'package:xparq_app/features/chat/services/chat_service.dart';
import 'package:xparq_app/features/chat/services/signal_service.dart';

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return ChatRepository();
});

final chatServiceProvider = Provider<ChatService>((ref) {
  return ChatService(ref.read(chatRepositoryProvider));
});

final signalServiceProvider = Provider<SignalService>((ref) {
  return SignalService(ref.read(chatRepositoryProvider));
});

@immutable
class ChatRequest {
  const ChatRequest({required this.currentUserId, required this.otherUserId});

  final String currentUserId;
  final String? otherUserId;

  bool get canChat =>
      currentUserId.trim().isNotEmpty &&
      (otherUserId?.trim().isNotEmpty ?? false);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    return other is ChatRequest &&
        other.currentUserId == currentUserId &&
        other.otherUserId == otherUserId;
  }

  @override
  int get hashCode => Object.hash(currentUserId, otherUserId);
}

@immutable
class ChatState {
  final List<MessageModel> messages;
  final bool isLoading;
  final bool isSending;
  final String? errorMessage;

  const ChatState({
    this.messages = const <MessageModel>[],
    this.isLoading = false,
    this.isSending = false,
    this.errorMessage,
  });

  ChatState copyWith({
    List<MessageModel>? messages,
    bool? isLoading,
    bool? isSending,
    String? errorMessage,
    bool clearError = false,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      isSending: isSending ?? this.isSending,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class ChatProvider extends StateNotifier<ChatState> {
  ChatProvider({
    required ChatService chatService,
    required SignalService signalService,
    required ChatRequest request,
  }) : _chatService = chatService,
       _signalService = signalService,
       _request = request,
       super(const ChatState()) {
    _initialize();
    _listenToRealtime();
  }

  final ChatService _chatService;
  final SignalService _signalService;
  final ChatRequest _request;

  StreamSubscription<List<MessageModel>>? _subscription;

  Future<void> _initialize() async {
    if (!_request.canChat) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'A recipient is required to open this chat.',
      );
      return;
    }

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final messages = await _chatService.loadMessages(
        currentUserId: _request.currentUserId,
        otherUserId: _request.otherUserId!,
      );
      update(messages);
    } on AppException catch (error) {
      state = state.copyWith(isLoading: false, errorMessage: error.message);
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Unable to load messages.',
      );
    }
  }

  void _listenToRealtime() {
    if (!_request.canChat) {
      return;
    }

    _subscription?.cancel();
    _subscription = _signalService
        .watchMessages(
          currentUserId: _request.currentUserId,
          otherUserId: _request.otherUserId!,
        )
        .listen(
          update,
          onError: (Object error, StackTrace stackTrace) {
            final message = error is AppException
                ? error.message
                : 'Realtime updates are temporarily unavailable.';

            state = state.copyWith(isLoading: false, errorMessage: message);
          },
        );
  }

  void update(List<MessageModel> messages) {
    state = state.copyWith(
      messages: messages,
      isLoading: false,
      clearError: true,
    );
  }

  Future<bool> sendMessage({required String content}) async {
    state = state.copyWith(isSending: true, clearError: true);

    try {
      final message = await _chatService.send(
        content: content,
        senderId: _request.currentUserId,
        otherUserId: _request.otherUserId ?? '',
      );

      final updatedMessages = List<MessageModel>.from(state.messages);
      if (!updatedMessages.any((item) => item.id == message.id)) {
        updatedMessages.add(message);
        updatedMessages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      }

      state = state.copyWith(
        messages: updatedMessages,
        isSending: false,
        clearError: true,
      );
      return true;
    } on AppException catch (error) {
      state = state.copyWith(isSending: false, errorMessage: error.message);
      return false;
    } catch (_) {
      state = state.copyWith(
        isSending: false,
        errorMessage: 'Unable to send the message.',
      );
      return false;
    }
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

final chatProviderFamily = StateNotifierProvider.autoDispose
    .family<ChatProvider, ChatState, ChatRequest>((ref, request) {
      return ChatProvider(
        chatService: ref.read(chatServiceProvider),
        signalService: ref.read(signalServiceProvider),
        request: request,
      );
    });
