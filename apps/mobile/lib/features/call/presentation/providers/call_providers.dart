import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xparq_app/features/auth/providers/auth_providers.dart';
import 'package:xparq_app/features/call/data/services/call_message_service.dart';
import 'package:xparq_app/features/call/data/services/call_signaling_service.dart';
import 'package:xparq_app/features/call/data/services/call_socket_service.dart';
import 'package:xparq_app/features/call/data/services/mediasoup_call_service.dart';
import 'package:xparq_app/features/call/domain/models/call_control_event.dart';
import 'package:xparq_app/features/call/domain/models/call_ui_state.dart';
import 'package:xparq_app/features/call/presentation/providers/call_controller.dart';
import 'package:xparq_app/features/chat/presentation/providers/chat_providers.dart';

final callSignalingServiceProvider = Provider<CallSignalingService>((ref) {
  return CallSignalingService();
});

final callMessageServiceProvider = Provider<CallMessageService>((ref) {
  return CallMessageService(
    chatRepository: ref.watch(chatRepositoryProvider),
  );
});

final callSocketServiceProvider = Provider<CallSocketService>((ref) {
  return CallSocketService();
});

final mediasoupCallServiceProvider = Provider<MediasoupCallService>((ref) {
  return MediasoupCallService();
});

final callControllerProvider =
    StateNotifierProvider<CallController, CallUiState>((ref) {
  return CallController(
    signalingService: ref.watch(callSignalingServiceProvider),
    callMessageService: ref.watch(callMessageServiceProvider),
    callSocketService: ref.watch(callSocketServiceProvider),
    mediaService: ref.watch(mediasoupCallServiceProvider),
    ref: ref,
  );
});

final callBootstrapProvider = Provider<void>((ref) {
  final authRepository = ref.watch(authRepositoryProvider);
  final callMessageService = ref.watch(callMessageServiceProvider);
  final controller = ref.read(callControllerProvider.notifier);

  StreamSubscription<CallControlEvent>? eventsSubscription;

  void bindEvents(String? userId) {
    eventsSubscription?.cancel();
    if (userId == null || userId.isEmpty) {
      controller.reset();
      return;
    }

    eventsSubscription = callMessageService.watchEvents(userId).listen((event) {
      unawaited(controller.handleControlEvent(event));
    });
  }

  bindEvents(authRepository.currentUser?.id);

  final authSubscription = authRepository.authStateChanges.listen((authState) {
    bindEvents(authState.session?.user.id);
  });

  ref.onDispose(() {
    authSubscription.cancel();
    eventsSubscription?.cancel();
  });
});
