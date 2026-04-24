import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:xparq_app/features/auth/models/planet_model.dart';
import 'package:xparq_app/features/auth/providers/auth_providers.dart';
import 'package:xparq_app/features/call/data/services/call_message_service.dart';
import 'package:xparq_app/features/call/data/services/call_signaling_service.dart';
import 'package:xparq_app/features/call/data/services/call_socket_service.dart';
import 'package:xparq_app/features/call/data/services/mediasoup_call_service.dart';
import 'package:xparq_app/features/call/domain/models/call_control_event.dart';
import 'package:xparq_app/features/call/domain/models/call_session.dart';
import 'package:xparq_app/features/call/domain/models/call_status.dart';
import 'package:xparq_app/features/call/domain/models/call_ui_state.dart';

class CallController extends StateNotifier<CallUiState> {
  CallController({
    required CallSignalingService signalingService,
    required CallMessageService callMessageService,
    required CallSocketService callSocketService,
    required MediasoupCallService mediaService,
    required Ref ref,
  })  : _signalingService = signalingService,
        _callMessageService = callMessageService,
        _callSocketService = callSocketService,
        _mediaService = mediaService,
        _ref = ref,
        super(const CallUiState.initial());

  final CallSignalingService _signalingService;
  final CallMessageService _callMessageService;
  final CallSocketService _callSocketService;
  final MediasoupCallService _mediaService;
  final Ref _ref;

  final Set<String> _consumedProducerIds = <String>{};
  final Set<String> _pendingProducerIds = <String>{};
  Timer? _elapsedTimer;
  Timer? _dismissTimer;
  Timer? _transportHeartbeatTimer;
  Completer<void>? _remoteMediaReadyCompleter;
  bool _isConnectingMedia = false;
  bool _isRecoveringConnection = false;
  bool _isShuttingDownMedia = false;
  Map<String, dynamic> _icePolicy = const <String, dynamic>{};

  Future<void> startOutgoing({
    required String chatId,
    required String peerUid,
    required String peerName,
    required String peerAvatarUrl,
  }) async {
    if (state.hasActiveCall) {
      return;
    }

    final me = _currentUserId;
    final myProfile = _currentProfile;
    if (me == null || myProfile == null) {
      throw Exception('Sign in before placing a call');
    }

    state = CallUiState(
      status: CallStatus.calling,
      session: CallSession(
        callId: '',
        roomId: '',
        chatId: chatId,
        callerId: me,
        calleeId: peerUid,
        peerUserId: peerUid,
        peerName: peerName,
        peerAvatarUrl: peerAvatarUrl,
        isIncoming: false,
      ),
      isOverlayVisible: true,
      isSpeakerOn: false,
    );

    try {
      final response = await _signalingService.invite(
        callerId: me,
        calleeId: peerUid,
      );
      final sessionMap = Map<String, dynamic>.from(
        response['session'] as Map? ?? const {},
      );
      final session = CallSession(
        callId: sessionMap['call_id']?.toString() ?? '',
        roomId: sessionMap['room_id']?.toString() ?? '',
        chatId: chatId,
        callerId: me,
        calleeId: peerUid,
        peerUserId: peerUid,
        peerName: peerName,
        peerAvatarUrl: peerAvatarUrl,
        isIncoming: false,
      );

      state = state.copyWith(session: session, isOverlayVisible: true);

      await _callMessageService.sendInvite(
        senderProfile: myProfile,
        chatId: chatId,
        otherUid: peerUid,
        callId: session.callId,
        roomId: session.roomId,
      );
    } catch (error, stackTrace) {
      debugPrint('CALL: startOutgoing failed: $error\n$stackTrace');
      await _failAndAutoDismiss(error.toString());
      rethrow;
    }
  }

  Future<void> acceptIncoming() async {
    final session = state.session;
    final me = _currentUserId;
    final myProfile = _currentProfile;
    if (session == null || me == null || myProfile == null) {
      return;
    }

    final permission = await Permission.microphone.request();
    if (!permission.isGranted) {
      await _failAndAutoDismiss('Microphone permission is required');
      return;
    }

    state = state.copyWith(
      status: CallStatus.connecting,
      hasMicPermission: true,
      clearError: true,
      isOverlayVisible: true,
    );

    try {
      await _signalingService.accept(callId: session.callId, actorId: me);
      await _callMessageService.sendAccept(
        senderProfile: myProfile,
        chatId: session.chatId,
        otherUid: session.peerUserId,
        callId: session.callId,
        roomId: session.roomId,
      );
      await _connectMedia();
    } catch (error, stackTrace) {
      debugPrint('CALL: acceptIncoming failed: $error\n$stackTrace');
      await _failAndAutoDismiss(error.toString());
    }
  }

  Future<void> rejectIncoming() async {
    final session = state.session;
    final me = _currentUserId;
    final myProfile = _currentProfile;
    if (session == null || me == null || myProfile == null) {
      return;
    }

    try {
      await _signalingService.reject(callId: session.callId, actorId: me);
      await _callMessageService.sendReject(
        senderProfile: myProfile,
        chatId: session.chatId,
        otherUid: session.peerUserId,
        callId: session.callId,
        roomId: session.roomId,
      );
      await _endAndAutoDismiss('Call declined');
    } catch (error, stackTrace) {
      debugPrint('CALL: rejectIncoming failed: $error\n$stackTrace');
      await _failAndAutoDismiss(error.toString());
    }
  }

  Future<void> handleControlEvent(CallControlEvent event) async {
    final me = _currentUserId;
    if (me == null) {
      return;
    }

    switch (event.type) {
      case CallControlEventType.invite:
        if (event.targetId != me || state.hasActiveCall) {
          return;
        }
        state = CallUiState(
          status: CallStatus.ringing,
          session: CallSession.fromInviteEvent(event, currentUserId: me),
          isOverlayVisible: true,
        );
        return;

      case CallControlEventType.accept:
        if (state.callId != event.callId ||
            state.status != CallStatus.calling) {
          return;
        }
        state = state.copyWith(
          status: CallStatus.connecting,
          clearError: true,
          isOverlayVisible: true,
        );
        await _connectMedia();
        return;

      case CallControlEventType.reject:
        if (state.callId != event.callId) {
          return;
        }
        await _endAndAutoDismiss('Call declined');
        return;

      case CallControlEventType.end:
        if (state.callId != event.callId) {
          return;
        }
        await _cleanupMediaAndSocket();
        await _endAndAutoDismiss('Call ended');
        return;

      case CallControlEventType.mediaReady:
        if (state.callId != event.callId) {
          return;
        }
        state = state.copyWith(remoteMediaReady: true);
        _remoteMediaReadyCompleter?.complete();
        return;
    }
  }

  Future<void> hangUp() async {
    final session = state.session;
    final me = _currentUserId;
    final myProfile = _currentProfile;
    if (session == null || me == null) {
      dismiss();
      return;
    }

    try {
      if (state.joinedLifecycle) {
        await _signalingService.leaveLifecycle(
          callId: session.callId,
          roomId: session.roomId,
          actorId: me,
        );
      }
    } catch (error) {
      debugPrint('CALL: leaveLifecycle failed: $error');
    }

    try {
      if (myProfile != null) {
        await _callMessageService.sendEnd(
          senderProfile: myProfile,
          chatId: session.chatId,
          otherUid: session.peerUserId,
          callId: session.callId,
          roomId: session.roomId,
        );
      }
    } catch (error) {
      debugPrint('CALL: sendEnd failed: $error');
    }

    await _cleanupMediaAndSocket();
    await _endAndAutoDismiss('Call ended');
  }

  Future<void> toggleMute() async {
    final nextMuted = !state.isMuted;
    await _mediaService.setMuted(nextMuted);
    state = state.copyWith(isMuted: nextMuted);
  }

  Future<void> toggleSpeaker() async {
    final nextSpeakerOn = !state.isSpeakerOn;
    await _mediaService.configureAudioOutput(speakerOn: nextSpeakerOn);
    state = state.copyWith(isSpeakerOn: nextSpeakerOn);
  }

  void dismiss() {
    _dismissTimer?.cancel();
    _stopElapsedTimer();
    state = const CallUiState.initial();
  }

  void reset() {
    unawaited(_cleanupMediaAndSocket());
    dismiss();
  }

  Future<void> _connectMedia() async {
    if (_isConnectingMedia) {
      return;
    }

    final session = state.session;
    final accessToken =
        Supabase.instance.client.auth.currentSession?.accessToken;
    final me = _currentUserId;
    final myProfile = _currentProfile;

    if (session == null ||
        accessToken == null ||
        me == null ||
        myProfile == null) {
      throw Exception('Missing call session or auth token');
    }

    _isConnectingMedia = true;
    _dismissTimer?.cancel();

    try {
      if (!state.joinedLifecycle) {
        await _signalingService.joinLifecycle(
          callId: session.callId,
          roomId: session.roomId,
          actorId: me,
        );
        state = state.copyWith(joinedLifecycle: true);
      }

      await _refreshIcePolicy(session);
      await _callSocketService.connect(accessToken: accessToken);
      _callSocketService.onDisconnect((reason) {
        if (_shouldRecoverConnection) {
          unawaited(_recoverConnection(reason));
        }
      });
      _callSocketService.onNewProducer((producerId) {
        unawaited(_consumeRemoteProducer(producerId));
      });

      final joinData = await _callSocketService.joinRoom(
        roomId: session.roomId,
        callId: session.callId,
        policyToken: _policyToken,
      );
      await _initializeJoinedMedia(
        session: session,
        myProfile: myProfile,
        joinData: joinData,
        waitForRemoteMedia: true,
      );

      state = state.copyWith(
        status: CallStatus.connected,
        connectedAt: DateTime.now(),
        hasMicPermission: true,
        clearError: true,
      );
      _startElapsedTimer();
      _startTransportHeartbeat();
    } catch (error) {
      await _cleanupMediaAndSocket();
      rethrow;
    } finally {
      _isConnectingMedia = false;
    }
  }

  Future<void> _waitForRemoteMediaReady() async {
    if (state.remoteMediaReady) {
      return;
    }

    _remoteMediaReadyCompleter = Completer<void>();
    await _remoteMediaReadyCompleter!.future.timeout(
      const Duration(seconds: 5),
      onTimeout: () {},
    );
  }

  Future<void> _consumeRemoteProducer(String producerId) async {
    if (_consumedProducerIds.contains(producerId)) {
      return;
    }

    final recvTransport = _mediaService.recvTransport;
    if (recvTransport == null) {
      _pendingProducerIds.add(producerId);
      return;
    }

    _pendingProducerIds.remove(producerId);
    _consumedProducerIds.add(producerId);

    try {
      final response = await _callSocketService.consume(
        transportId: recvTransport.id,
        producerId: producerId,
        rtpCapabilities: _mediaService.rtpCapabilitiesMap,
      );
      await _mediaService.consumeRemoteProducer(consumerOptions: response);
      if (state.status != CallStatus.connected) {
        state = state.copyWith(
          status: CallStatus.connected,
          connectedAt: state.connectedAt ?? DateTime.now(),
        );
      }
      state = state.copyWith(remoteAudioAttached: true);
      _startElapsedTimer();
    } catch (error) {
      _consumedProducerIds.remove(producerId);
      debugPrint('CALL: consume failed: $error');
    }
  }

  Future<void> _cleanupMediaAndSocket() async {
    _isShuttingDownMedia = true;
    _stopTransportHeartbeat();
    _stopElapsedTimer();
    _remoteMediaReadyCompleter = null;
    _consumedProducerIds.clear();
    _pendingProducerIds.clear();
    try {
      try {
        await _callSocketService.leaveRoom();
      } catch (_) {}
      _callSocketService.disconnect();
      await _mediaService.dispose();
      await WakelockPlus.disable();
    } finally {
      _isShuttingDownMedia = false;
    }
  }

  void _startElapsedTimer() {
    _elapsedTimer?.cancel();
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final connectedAt = state.connectedAt;
      if (connectedAt == null || state.status != CallStatus.connected) {
        return;
      }
      state = state.copyWith(
        elapsedSeconds: DateTime.now().difference(connectedAt).inSeconds,
      );
    });
  }

  void _stopElapsedTimer() {
    _elapsedTimer?.cancel();
    _elapsedTimer = null;
  }

  Future<void> _endAndAutoDismiss(String message) async {
    state = state.copyWith(
      status: CallStatus.ended,
      errorMessage: message,
      isOverlayVisible: true,
    );
    _dismissTimer?.cancel();
    _dismissTimer = Timer(const Duration(seconds: 2), dismiss);
  }

  Future<void> _failAndAutoDismiss(String message) async {
    state = state.copyWith(
      status: CallStatus.failed,
      errorMessage: message,
      isOverlayVisible: true,
    );
    _dismissTimer?.cancel();
    _dismissTimer = Timer(const Duration(seconds: 3), dismiss);
  }

  String? get _currentUserId => Supabase.instance.client.auth.currentUser?.id;

  PlanetModel? get _currentProfile =>
      _ref.read(planetProfileProvider).valueOrNull;

  bool get _shouldRecoverConnection {
    return !_isShuttingDownMedia &&
        !_isConnectingMedia &&
        !_isRecoveringConnection &&
        state.hasActiveCall &&
        !state.isTerminal;
  }

  String? get _policyToken {
    final rawToken = _icePolicy['policyToken']?.toString();
    if (rawToken == null || rawToken.isEmpty) {
      return null;
    }

    return rawToken;
  }

  Future<void> _refreshIcePolicy(CallSession session) async {
    final response = await _signalingService.fetchIceServers(
      callId: session.callId,
      roomId: session.roomId,
    );

    _icePolicy = Map<String, dynamic>.from(response);
    final iceServers = List<Map<String, dynamic>>.from(
      (_icePolicy['iceServers'] as List? ?? const <dynamic>[])
          .map((entry) => Map<String, dynamic>.from(entry as Map)),
    );

    _mediaService.applyIceConfiguration(
      iceServers: iceServers,
      iceTransportPolicy: _icePolicy['iceTransportPolicy']?.toString(),
      policyToken: _policyToken,
    );
  }

  Future<void> _initializeJoinedMedia({
    required CallSession session,
    required PlanetModel myProfile,
    required Map<String, dynamic> joinData,
    required bool waitForRemoteMedia,
  }) async {
    final routerCapabilities = Map<String, dynamic>.from(
      joinData['routerRtpCapabilities'] as Map? ?? joinData,
    );
    final existingProducerIds = List<String>.from(
      (joinData['existingProducerIds'] as List? ?? const <dynamic>[])
          .map((entry) => entry.toString()),
    );

    await _mediaService.prepareDevice(routerCapabilities);
    await _mediaService.configureAudioOutput(speakerOn: state.isSpeakerOn);

    final recvOptions = await _callSocketService.createTransport(
      'recv',
      policyToken: _policyToken,
    );
    await _mediaService.createRecvTransport(
      transportOptions: recvOptions,
      onConnect: (transportId, dtlsParameters) {
        return _callSocketService.connectTransport(
          transportId: transportId,
          dtlsParameters: dtlsParameters,
          policyToken: _policyToken,
        );
      },
    );

    for (final producerId in _pendingProducerIds.toList()) {
      await _consumeRemoteProducer(producerId);
    }

    for (final producerId in existingProducerIds) {
      await _consumeRemoteProducer(producerId);
    }

    if (!state.localMediaReady) {
      await _callMessageService.sendMediaReady(
        senderProfile: myProfile,
        chatId: session.chatId,
        otherUid: session.peerUserId,
        callId: session.callId,
        roomId: session.roomId,
      );
      state = state.copyWith(localMediaReady: true);
    }

    if (waitForRemoteMedia && existingProducerIds.isEmpty) {
      await _waitForRemoteMediaReady();
    } else if (existingProducerIds.isNotEmpty) {
      state = state.copyWith(remoteMediaReady: true);
    }

    await _mediaService.openMicrophone();

    final sendOptions = await _callSocketService.createTransport(
      'send',
      policyToken: _policyToken,
    );
    await _mediaService.createSendTransport(
      transportOptions: sendOptions,
      onConnect: (transportId, dtlsParameters) {
        return _callSocketService.connectTransport(
          transportId: transportId,
          dtlsParameters: dtlsParameters,
          policyToken: _policyToken,
        );
      },
      onProduce: (transportId, kind, rtpParameters) async {
        final response = await _callSocketService.produce(
          transportId: transportId,
          kind: kind,
          rtpParameters: rtpParameters,
        );
        return response['id']?.toString() ?? '';
      },
    );
    await _mediaService.startProducingAudio();
    await WakelockPlus.enable();
  }

  void _startTransportHeartbeat() {
    _transportHeartbeatTimer?.cancel();
    _transportHeartbeatTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      unawaited(_sendTransportHeartbeat());
    });
  }

  void _stopTransportHeartbeat() {
    _transportHeartbeatTimer?.cancel();
    _transportHeartbeatTimer = null;
  }

  Future<void> _sendTransportHeartbeat() async {
    final transportId = _mediaService.preferredTransportId;
    if (transportId == null ||
        !_callSocketService.isConnected ||
        !_shouldRecoverConnection) {
      return;
    }

    try {
      final metrics = await _mediaService.collectTransportMetrics();
      final response = await _callSocketService.transportHeartbeat(
        transportId: transportId,
        metrics: metrics,
        policyToken: _policyToken,
      );
      final policy = Map<String, dynamic>.from(
        response['policy'] as Map? ?? const {},
      );
      await _mediaService.applyServerPolicy(policy);
    } catch (error, stackTrace) {
      debugPrint('CALL: transportHeartbeat failed: $error\n$stackTrace');
      if (_shouldRecoverConnection) {
        await _recoverConnection('transport_heartbeat_failed');
      }
    }
  }

  Future<void> _recoverConnection(String reason) async {
    final session = state.session;
    final myProfile = _currentProfile;
    final accessToken =
        Supabase.instance.client.auth.currentSession?.accessToken;

    if (!_shouldRecoverConnection ||
        session == null ||
        myProfile == null ||
        accessToken == null) {
      return;
    }

    _isRecoveringConnection = true;
    _stopTransportHeartbeat();

    try {
      state = state.copyWith(
        status: CallStatus.connecting,
        errorMessage: 'Reconnecting call...',
        isOverlayVisible: true,
      );

      _callSocketService.disconnect();
      await _mediaService.dispose();

      for (var attempt = 0; attempt < 5; attempt += 1) {
        try {
          await Future<void>.delayed(
            Duration(
              milliseconds: _callSocketService.computeReconnectDelayMs(attempt),
            ),
          );
          await _refreshIcePolicy(session);
          await _callSocketService.connect(
            accessToken: accessToken,
            forceReconnect: true,
          );
          _callSocketService.onNewProducer((producerId) {
            unawaited(_consumeRemoteProducer(producerId));
          });

          final joinData = await _callSocketService.joinRoom(
            roomId: session.roomId,
            callId: session.callId,
            policyToken: _policyToken,
          );
          await _initializeJoinedMedia(
            session: session,
            myProfile: myProfile,
            joinData: joinData,
            waitForRemoteMedia: false,
          );

          state = state.copyWith(
            status: CallStatus.connected,
            hasMicPermission: true,
            clearError: true,
            connectedAt: state.connectedAt ?? DateTime.now(),
          );
          _startTransportHeartbeat();
          return;
        } catch (error, stackTrace) {
          debugPrint(
            'CALL: recovery attempt ${attempt + 1} after $reason failed: '
            '$error\n$stackTrace',
          );
          if (attempt == 4) {
            rethrow;
          }
        }
      }
    } catch (error, stackTrace) {
      debugPrint('CALL: recovery failed: $error\n$stackTrace');
      await _failAndAutoDismiss('Call reconnect failed');
    } finally {
      _isRecoveringConnection = false;
    }
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    _elapsedTimer?.cancel();
    _transportHeartbeatTimer?.cancel();
    unawaited(_cleanupMediaAndSocket());
    super.dispose();
  }
}
