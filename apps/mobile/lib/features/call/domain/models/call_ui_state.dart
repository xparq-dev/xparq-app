import 'package:xparq_app/features/call/domain/models/call_session.dart';
import 'package:xparq_app/features/call/domain/models/call_status.dart';

class CallUiState {
  final CallStatus status;
  final CallSession? session;
  final bool isMuted;
  final bool isSpeakerOn;
  final bool isCameraOn;
  final bool joinedLifecycle;
  final bool localMediaReady;
  final bool remoteMediaReady;
  final bool hasMicPermission;
  final bool hasCameraPermission;
  final bool hasCameraPreview;
  final bool remoteAudioAttached;
  final bool isOverlayVisible;
  final bool isPeerCameraOn;
  final bool remoteVideoAttached;
  final String? errorMessage;
  final DateTime? connectedAt;
  final int elapsedSeconds;

  const CallUiState({
    required this.status,
    this.session,
    this.isMuted = false,
    this.isSpeakerOn = false,
    this.isCameraOn = false,
    this.joinedLifecycle = false,
    this.localMediaReady = false,
    this.remoteMediaReady = false,
    this.hasMicPermission = false,
    this.hasCameraPermission = false,
    this.hasCameraPreview = false,
    this.remoteAudioAttached = false,
    this.isOverlayVisible = false,
    this.isPeerCameraOn = false,
    this.remoteVideoAttached = false,
    this.errorMessage,
    this.connectedAt,
    this.elapsedSeconds = 0,
  });

  const CallUiState.initial() : this(status: CallStatus.idle);

  bool get hasActiveCall => status != CallStatus.idle;
  bool get isIncoming => session?.isIncoming ?? false;
  bool get isConnected => status == CallStatus.connected;
  bool get isTerminal =>
      status == CallStatus.ended || status == CallStatus.failed;
  String get peerName => session?.peerName ?? 'Voice Call';
  String get peerAvatarUrl => session?.peerAvatarUrl ?? '';
  String? get callId => session?.callId;
  String? get roomId => session?.roomId;
  String? get chatId => session?.chatId;
  String? get peerUserId => session?.peerUserId;

  String get statusLabel {
    switch (status) {
      case CallStatus.idle:
        return '';
      case CallStatus.calling:
        return 'Calling...';
      case CallStatus.ringing:
        return isIncoming ? 'Incoming voice call' : 'Ringing...';
      case CallStatus.connecting:
        return remoteMediaReady
            ? 'Connecting audio...'
            : 'Waiting for receiver audio...';
      case CallStatus.connected:
        return remoteAudioAttached
            ? 'Connected'
            : 'Connected, syncing audio...';
      case CallStatus.ended:
        return 'Call ended';
      case CallStatus.failed:
        return errorMessage ?? 'Call failed';
    }
  }

  CallUiState copyWith({
    CallStatus? status,
    CallSession? session,
    bool? isMuted,
    bool? isSpeakerOn,
    bool? isCameraOn,
    bool? joinedLifecycle,
    bool? localMediaReady,
    bool? remoteMediaReady,
    bool? hasMicPermission,
    bool? hasCameraPermission,
    bool? hasCameraPreview,
    bool? remoteAudioAttached,
    bool? isOverlayVisible,
    bool? isPeerCameraOn,
    bool? remoteVideoAttached,
    String? errorMessage,
    DateTime? connectedAt,
    int? elapsedSeconds,
    bool clearSession = false,
    bool clearError = false,
  }) {
    return CallUiState(
      status: status ?? this.status,
      session: clearSession ? null : (session ?? this.session),
      isMuted: isMuted ?? this.isMuted,
      isSpeakerOn: isSpeakerOn ?? this.isSpeakerOn,
      isCameraOn: isCameraOn ?? this.isCameraOn,
      joinedLifecycle: joinedLifecycle ?? this.joinedLifecycle,
      localMediaReady: localMediaReady ?? this.localMediaReady,
      remoteMediaReady: remoteMediaReady ?? this.remoteMediaReady,
      hasMicPermission: hasMicPermission ?? this.hasMicPermission,
      hasCameraPermission: hasCameraPermission ?? this.hasCameraPermission,
      hasCameraPreview: hasCameraPreview ?? this.hasCameraPreview,
      remoteAudioAttached: remoteAudioAttached ?? this.remoteAudioAttached,
      isOverlayVisible: isOverlayVisible ?? this.isOverlayVisible,
      isPeerCameraOn: isPeerCameraOn ?? this.isPeerCameraOn,
      remoteVideoAttached: remoteVideoAttached ?? this.remoteVideoAttached,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      connectedAt: connectedAt ?? this.connectedAt,
      elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
    );
  }
}
