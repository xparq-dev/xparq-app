import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xparq_app/features/auth/models/planet_model.dart';
import 'package:xparq_app/features/auth/providers/auth_providers.dart';
import 'package:xparq_app/features/call/data/services/call_feedback_service.dart';
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

final callFeedbackServiceProvider = Provider<CallFeedbackService>((ref) {
  final service = CallFeedbackService();
  ref.onDispose(() => service.dispose());
  return service;
});

final callControllerProvider =
    StateNotifierProvider<CallController, CallUiState>((ref) {
  return CallController(
    signalingService: ref.watch(callSignalingServiceProvider),
    callMessageService: ref.watch(callMessageServiceProvider),
    callSocketService: ref.watch(callSocketServiceProvider),
    mediaService: ref.watch(mediasoupCallServiceProvider),
    feedbackService: ref.watch(callFeedbackServiceProvider),
    ref: ref,
  );
});

@immutable
class CallPeerPresentation {
  final String displayName;
  final String avatarUrl;

  const CallPeerPresentation({
    required this.displayName,
    required this.avatarUrl,
  });
}

final callPeerPresentationProvider = Provider<CallPeerPresentation>((ref) {
  final state = ref.watch(callControllerProvider);
  final peerUid = state.peerUserId;

  PlanetModel? peerProfile;
  if (peerUid != null && peerUid.isNotEmpty) {
    peerProfile = ref.watch(planetProfileByUidProvider(peerUid)).valueOrNull;
  }

  final hasFreshProfile = peerProfile != null &&
      peerProfile.xparqName != 'Explorer' &&
      peerProfile.xparqName.trim().isNotEmpty;
      
  final displayName = hasFreshProfile 
      ? peerProfile.xparqName.trim()
      : (state.peerName == 'Explorer' ? 'Voice Call' : state.peerName);
      
  final avatarUrl = hasFreshProfile && peerProfile.photoUrl.trim().isNotEmpty
      ? peerProfile.photoUrl.trim()
      : state.peerAvatarUrl.trim();

  return CallPeerPresentation(
    displayName: displayName.isEmpty || displayName == 'Explorer' ? 'Voice Call' : displayName,
    avatarUrl: avatarUrl,
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
