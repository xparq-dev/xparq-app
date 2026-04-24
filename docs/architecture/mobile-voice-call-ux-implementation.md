# Mobile Voice Call UX/UI Implementation

## 1. Architecture Overview

This repo already has the backend pieces required for voice:

- HTTP call lifecycle signaling in `backend/signaling/index.http.js`
  - `POST /events/call_invite`
  - `POST /events/call_accept`
  - `POST /events/call_reject`
  - `POST /events/join_room`
  - `POST /events/leave_room`
- Socket.IO mediasoup signaling in `backend/signaling/index.js`
  - `joinRoom`
  - `createTransport`
  - `connectTransport`
  - `produce`
  - `consume`
  - `leaveRoom`
- Supabase-backed auth and app state in the Flutter app
- Supabase SFU state tables in:
  - `backend/supabase/migrations/202604211200_create_sfu_session_state.sql`
  - `backend/supabase/migrations/202604211210_harden_sfu_concurrency.sql`

The mobile app does not yet have a real call feature. The current state is:

- `lib/features/call/.gitkeep`
- no WebRTC client code
- no mediasoup client code
- no incoming-call UX
- no active-call route
- no call controller/provider

The best fit is a new isolated `features/call` module that integrates with the existing chat feature without moving or rewriting chat itself.

### Important backend distinction

There are two different "join room" concepts in this codebase:

1. Call lifecycle signaling
   - HTTP `POST /events/join_room`
   - updates the call session state machine
2. SFU media join
   - Socket.IO `joinRoom`
   - attaches the client to mediasoup room state and returns router RTP capabilities

The frontend should call both, in that order, once the user is actually entering the live call.

## 2. Project Scan

### Frontend entry points

- `apps/mobile/lib/main.dart`
  - app bootstrap, Supabase init, notification setup, lifecycle hooks
- `apps/mobile/lib/shared/router/app_router.dart`
  - all app routes and top-level navigation
- `apps/mobile/lib/shared/router/app_shell.dart`
  - bottom-nav shell

### Existing UI screens relevant to calling

- `apps/mobile/lib/features/chat/presentation/screens/chat_list_screen.dart`
  - chat discovery / conversation entry
- `apps/mobile/lib/features/chat/presentation/screens/signal_chat_screen.dart`
  - 1:1 and group conversation screen
- `apps/mobile/lib/features/chat/presentation/widgets/signal_chat_app_bar.dart`
  - current top-right call icon for groups
- `apps/mobile/lib/features/chat/presentation/widgets/mini_profile_popup.dart`
  - current "Call" action launches the phone dialer with `tel:`
- `apps/mobile/lib/features/profile/screens/user_profile_screen.dart`
  - possible secondary call entry point later

### Routing and navigation

- `apps/mobile/lib/shared/router/app_router.dart`
  - best place to add `/call/:callId`
  - current full-screen routes already include chat, settings, profile overlays

### State management

- Riverpod is the app standard
- auth state:
  - `apps/mobile/lib/features/auth/providers/auth_providers.dart`
- chat state:
  - `apps/mobile/lib/features/chat/presentation/providers/chat_providers.dart`
  - `apps/mobile/lib/features/chat/presentation/providers/signal_chat_controller.dart`

### Networking and API patterns

- Supabase direct DB + Realtime streams:
  - `apps/mobile/lib/features/chat/data/repositories/chat_repository.dart`
  - `apps/mobile/lib/features/auth/repositories/supabase_auth_repository.dart`
- central backend HTTP with bearer token:
  - `apps/mobile/lib/shared/constants/app_constants.dart`
  - `apps/mobile/lib/features/profile/repositories/profile_repository.dart`
  - `apps/mobile/lib/features/auth/repositories/supabase_auth_repository.dart`
- background realtime listener:
  - `apps/mobile/lib/features/chat/data/services/background_signal_service.dart`

### Auth integration

- Supabase session is the source of truth
- current user id is already available through:
  - `authRepositoryProvider.currentUser?.id`
- backend Socket.IO auth already expects the Supabase access token:
  - `backend/signaling/middleware/auth.js`

### Existing voice-related backend files

- `backend/signaling/controllers/callController.js`
- `backend/signaling/services/callSignalService.js`
- `backend/signaling/models/callSessionModel.js`
- `backend/signaling/events/callEvents.js`
- `backend/signaling/handlers/joinRoom.js`
- `backend/signaling/handlers/createTransport.js`
- `backend/signaling/handlers/connectTransport.js`
- `backend/signaling/handlers/produce.js`
- `backend/signaling/handlers/consume.js`
- `backend/signaling/handlers/leaveRoom.js`
- `backend/signaling/services/sfuClient.js`

## 3. UX Flow Diagram

```text
Caller
  Chat screen / profile popup
  -> Tap Call
  -> POST /events/call_invite
  -> State: calling
  -> Show Call Entry Screen ("Calling...")
  -> Wait for invite state update from current signaling/state feed
  -> If accepted:
       -> ask mic permission if needed
       -> POST /events/join_room
       -> socket emit joinRoom
       -> setup mediasoup send/recv
       -> State: connecting
       -> State: connected
  -> If rejected / timeout / canceled:
       -> State: ended or failed

Receiver
  Existing app session listens for incoming call state
  -> Incoming Call Screen
  -> Actions: Accept / Reject
  -> Reject:
       -> POST /events/call_reject
       -> State: ended
  -> Accept:
       -> ask mic permission first
       -> POST /events/call_accept
       -> POST /events/join_room
       -> socket emit joinRoom
       -> setup mediasoup send/recv
       -> State: connecting
       -> State: connected

Active Call
  -> mic toggle
  -> connection status
  -> remote audio active indicator
  -> hang up

End Call
  -> socket emit leaveRoom
  -> POST /events/leave_room
  -> close consumer
  -> close producer
  -> close transports
  -> stop local stream
  -> disconnect socket if room-scoped
  -> reset call state to idle
  -> show End / Error screen briefly, then pop route
```

## 4. Screen Design

### A. Call Entry Screen

Purpose:
- started by caller immediately after `call_invite`

UI:
- callee avatar
- callee name
- status text: `Calling...`, `Ringing...`, `Waiting for answer...`
- elapsed timer only after accepted
- cancel button

States:
- `calling`
- `ringing`
- `connecting`

User actions:
- cancel call
- minimize later if you add call persistence

Edge cases:
- callee offline
- invite request fails
- callee rejects
- no answer timeout

### B. Incoming Call Screen

Purpose:
- modal/full-screen interruption when a user receives a call invite

UI:
- caller avatar
- caller name
- "Incoming voice call"
- reject button
- accept button
- optional muted ringtone animation

States:
- `ringing`
- `accepting`
- `permission_required`

User actions:
- accept
- reject

Edge cases:
- mic permission denied
- caller canceled before accept
- duplicate incoming invite while another call is active

### C. Active Call Screen

Purpose:
- once both sides are joining media

UI:
- participant avatar(s)
- display name(s)
- primary status label:
  - `Connecting`
  - `Reconnecting`
  - `Connected`
  - `Poor connection`
- elapsed timer
- mic button
- speaker button
- hang-up button
- remote audio activity pulse

States:
- `connecting`
- `connected`
- `reconnecting`
- `failed`

User actions:
- mute/unmute microphone
- toggle speaker output
- hang up

Edge cases:
- transport creation failure
- DTLS connection failure
- remote left early
- app backgrounding during call

### D. Call End / Error Screen

Purpose:
- terminal state after reject, hangup, timeout, or failure

UI:
- result icon
- result text:
  - `Call ended`
  - `Call declined`
  - `Missed call`
  - `Connection failed`
- dismiss button or auto-close after 1-2 seconds

States:
- `ended`
- `failed`

User actions:
- close
- retry call

Edge cases:
- cleanup partially succeeded
- route popped before async cleanup finished

## 5. Call State Model

```dart
enum CallStatus {
  idle,
  calling,
  ringing,
  connecting,
  connected,
  ended,
  failed,
}
```

Recommended controller state:

```dart
class CallUiState {
  final CallStatus status;
  final String? callId;
  final String? roomId;
  final String? peerUserId;
  final String? peerName;
  final String? peerAvatarUrl;
  final bool isIncoming;
  final bool isMuted;
  final bool isSpeakerOn;
  final bool hasMicPermission;
  final bool isRemoteAudioActive;
  final String? errorMessage;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final String connectionLabel;
}
```

## 6. UI -> Signaling Mapping

| UI action | Lifecycle signaling | SFU signaling |
| --- | --- | --- |
| Caller taps Call | `POST /events/call_invite` | none yet |
| Receiver taps Accept | `POST /events/call_accept` | none yet |
| Receiver taps Reject | `POST /events/call_reject` | none |
| Either side enters live call | `POST /events/join_room` | `joinRoom` |
| Create uplink | none | `createTransport(direction: "send")` |
| Connect uplink | none | `connectTransport` |
| Start microphone | none | `produce(kind: "audio")` |
| Create downlink | none | `createTransport(direction: "recv")` |
| Consume remote audio | none | `consume` |
| Hang up / leave | `POST /events/leave_room` | `leaveRoom` |

### Mediasoup event handling

- after local `produce`, backend emits `newProducer`
- when `newProducer` arrives:
  - ensure recv transport exists
  - call `consume`
  - create remote audio track
  - attach to audio renderer / output sink

## 7. Recommended File Changes

### Modify existing files

- `apps/mobile/lib/main.dart`
  - bootstrap the incoming-call subscription after auth init
- `apps/mobile/lib/shared/router/app_router.dart`
  - add `AppRoutes.callSession`
  - register the full-screen call route
- `apps/mobile/lib/features/chat/presentation/widgets/signal_chat_app_bar.dart`
  - wire the current call icon to the call feature
- `apps/mobile/lib/features/chat/presentation/widgets/mini_profile_popup.dart`
  - replace `tel:` launcher with in-app voice call for app users
- `apps/mobile/pubspec.yaml`
  - add WebRTC, Socket.IO, and mediasoup client dependencies
- `apps/mobile/android/app/src/main/AndroidManifest.xml`
  - add audio permissions
- `apps/mobile/ios/Runner/Info.plist`
  - add microphone usage description
  - add audio background mode if calls must continue while backgrounded

### Create new files

- `apps/mobile/lib/features/call/domain/models/call_status.dart`
- `apps/mobile/lib/features/call/domain/models/call_session.dart`
- `apps/mobile/lib/features/call/data/services/call_signaling_service.dart`
- `apps/mobile/lib/features/call/data/services/call_socket_service.dart`
- `apps/mobile/lib/features/call/data/services/mediasoup_call_service.dart`
- `apps/mobile/lib/features/call/data/services/incoming_call_service.dart`
- `apps/mobile/lib/features/call/presentation/providers/call_providers.dart`
- `apps/mobile/lib/features/call/presentation/providers/call_controller.dart`
- `apps/mobile/lib/features/call/presentation/screens/call_entry_screen.dart`
- `apps/mobile/lib/features/call/presentation/screens/incoming_call_screen.dart`
- `apps/mobile/lib/features/call/presentation/screens/active_call_screen.dart`
- `apps/mobile/lib/features/call/presentation/screens/call_result_screen.dart`
- `apps/mobile/lib/features/call/presentation/screens/call_session_screen.dart`
- `apps/mobile/lib/features/call/presentation/widgets/call_action_bar.dart`
- `apps/mobile/lib/features/call/presentation/widgets/call_status_chip.dart`

## 8. Package and Platform Requirements

Add to `pubspec.yaml`:

- `flutter_webrtc`
- `socket_io_client`
- a Dart mediasoup client package compatible with Flutter
- optional: `wakelock_plus`

Android manifest additions:

- `android.permission.RECORD_AUDIO`
- `android.permission.MODIFY_AUDIO_SETTINGS`

iOS `Info.plist` additions:

- `NSMicrophoneUsageDescription`
- optional `UIBackgroundModes` -> `audio`

## 9. Code Skeletons

### `lib/features/call/domain/models/call_status.dart`

```dart
enum CallStatus {
  idle,
  calling,
  ringing,
  connecting,
  connected,
  ended,
  failed,
}
```

### `lib/features/call/domain/models/call_session.dart`

```dart
class CallSession {
  final String callId;
  final String roomId;
  final String callerId;
  final String calleeId;
  final String peerUserId;
  final bool isIncoming;

  const CallSession({
    required this.callId,
    required this.roomId,
    required this.callerId,
    required this.calleeId,
    required this.peerUserId,
    required this.isIncoming,
  });

  factory CallSession.fromSignalResponse(
    Map<String, dynamic> session,
    String currentUserId,
  ) {
    final callerId = session['caller_id'] as String;
    final calleeId = session['callee_id'] as String;
    return CallSession(
      callId: session['call_id'] as String,
      roomId: session['room_id'] as String,
      callerId: callerId,
      calleeId: calleeId,
      peerUserId: currentUserId == callerId ? calleeId : callerId,
      isIncoming: currentUserId == calleeId,
    );
  }
}
```

### `lib/features/call/data/services/call_signaling_service.dart`

```dart
class CallSignalingService {
  CallSignalingService(this._client, this._supabase);

  final http.Client _client;
  final SupabaseClient _supabase;

  Future<Map<String, dynamic>> invite({
    required String callerId,
    required String calleeId,
  }) async {
    return _post(
      '/events/call_invite',
      body: {
        'caller_id': callerId,
        'callee_id': calleeId,
      },
    );
  }

  Future<Map<String, dynamic>> accept({
    required String callId,
    required String actorId,
  }) => _post('/events/call_accept', body: {
        'call_id': callId,
        'actor_id': actorId,
      });

  Future<Map<String, dynamic>> reject({
    required String callId,
    required String actorId,
  }) => _post('/events/call_reject', body: {
        'call_id': callId,
        'actor_id': actorId,
      });

  Future<Map<String, dynamic>> joinLifecycle({
    required String callId,
    required String roomId,
    required String actorId,
  }) => _post('/events/join_room', body: {
        'call_id': callId,
        'room_id': roomId,
        'actor_id': actorId,
      });

  Future<Map<String, dynamic>> leaveLifecycle({
    required String callId,
    required String roomId,
    required String actorId,
  }) => _post('/events/leave_room', body: {
        'call_id': callId,
        'room_id': roomId,
        'actor_id': actorId,
      });

  Future<Map<String, dynamic>> _post(
    String path, {
    required Map<String, dynamic> body,
  }) async {
    final accessToken = _supabase.auth.currentSession?.accessToken;
    final response = await _client.post(
      Uri.parse('${AppConstants.platformApiBaseUrl}$path'),
      headers: {
        'Content-Type': 'application/json',
        if (accessToken != null) 'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode(body),
    );

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(json['error'] ?? 'Call signaling failed');
    }
    return json;
  }
}
```

### `lib/features/call/data/services/call_socket_service.dart`

```dart
class CallSocketService {
  IO.Socket? _socket;

  Future<void> connect({
    required String socketBaseUrl,
    required String accessToken,
  }) async {
    _socket = IO.io(
      socketBaseUrl,
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .setAuth({'token': accessToken})
          .build(),
    );

    _socket!.connect();
  }

  Future<Map<String, dynamic>> joinRoom(String roomId) =>
      _emitAck('joinRoom', {'roomId': roomId});

  Future<Map<String, dynamic>> createTransport(String direction) =>
      _emitAck('createTransport', {'direction': direction});

  Future<Map<String, dynamic>> connectTransport({
    required String transportId,
    required Map<String, dynamic> dtlsParameters,
  }) => _emitAck('connectTransport', {
        'transportId': transportId,
        'dtlsParameters': dtlsParameters,
      });

  Future<Map<String, dynamic>> produce({
    required String transportId,
    required String kind,
    required Map<String, dynamic> rtpParameters,
  }) => _emitAck('produce', {
        'transportId': transportId,
        'kind': kind,
        'rtpParameters': rtpParameters,
      });

  Future<Map<String, dynamic>> consume({
    required String transportId,
    required String producerId,
    required Map<String, dynamic> rtpCapabilities,
  }) => _emitAck('consume', {
        'transportId': transportId,
        'producerId': producerId,
        'rtpCapabilities': rtpCapabilities,
      });

  Future<void> leaveRoom() async {
    _socket?.emit('leaveRoom');
  }

  void onNewProducer(void Function(String producerId) listener) {
    _socket?.on('newProducer', (data) {
      listener((data as Map<String, dynamic>)['producerId'] as String);
    });
  }

  Future<Map<String, dynamic>> _emitAck(
    String event,
    Map<String, dynamic> payload,
  ) async {
    final completer = Completer<Map<String, dynamic>>();
    _socket?.emitWithAck(event, payload, ack: (response) {
      final map = Map<String, dynamic>.from(response as Map);
      if (map['ok'] == true) {
        completer.complete(Map<String, dynamic>.from(map['data'] as Map));
      } else {
        completer.completeError(
          Exception((map['error'] as Map?)?['message'] ?? '$event failed'),
        );
      }
    });
    return completer.future;
  }
}
```

### `lib/features/call/data/services/mediasoup_call_service.dart`

```dart
class MediasoupCallService {
  Device? _device;
  MediaStream? _localStream;
  dynamic _sendTransport;
  dynamic _recvTransport;
  dynamic _producer;
  final List<dynamic> _consumers = [];

  Future<void> prepareDevice(Map<String, dynamic> routerRtpCapabilities) async {
    // TODO: instantiate the Dart mediasoup Device and load RTP capabilities
  }

  Future<void> openMicrophone() async {
    _localStream = await navigator.mediaDevices.getUserMedia({
      'audio': true,
      'video': false,
    });
  }

  Future<void> createSendTransport({
    required Map<String, dynamic> transportOptions,
    required Future<Map<String, dynamic>> Function(
      String transportId,
      Map<String, dynamic> dtlsParameters,
    ) onConnect,
    required Future<Map<String, dynamic>> Function(
      String transportId,
      String kind,
      Map<String, dynamic> rtpParameters,
    ) onProduce,
  }) async {
    // TODO: create mediasoup send transport and wire onConnect/onProduce
  }

  Future<void> startProducingAudio() async {
    final track = _localStream?.getAudioTracks().firstOrNull;
    if (track == null) throw Exception('No local audio track');
    // TODO: _producer = await _sendTransport.produce(track: track)
  }

  Future<void> createRecvTransport({
    required Map<String, dynamic> transportOptions,
    required Future<Map<String, dynamic>> Function(
      String transportId,
      Map<String, dynamic> dtlsParameters,
    ) onConnect,
  }) async {
    // TODO: create mediasoup recv transport and wire onConnect
  }

  Future<void> consumeRemoteProducer({
    required Map<String, dynamic> consumerOptions,
  }) async {
    // TODO: create mediasoup consumer and attach track to remote audio sink
  }

  Future<void> setMuted(bool muted) async {
    final track = _localStream?.getAudioTracks().firstOrNull;
    if (track != null) track.enabled = !muted;
  }

  Future<void> dispose() async {
    await _producer?.close();
    for (final consumer in _consumers) {
      await consumer.close();
    }
    await _sendTransport?.close();
    await _recvTransport?.close();
    await _localStream?.dispose();
  }
}
```

### `lib/features/call/data/services/incoming_call_service.dart`

```dart
class IncomingCallService {
  IncomingCallService(this._supabase);

  final SupabaseClient _supabase;

  Stream<Map<String, dynamic>> watchIncomingEvents(String userId) {
    // Hook this to the existing Supabase-backed call event/session feed.
    // The backend already uses Supabase for call/SFU state, so the mobile app
    // should subscribe instead of polling.
    throw UnimplementedError();
  }
}
```

### `lib/features/call/presentation/providers/call_controller.dart`

```dart
class CallController extends StateNotifier<CallUiState> {
  CallController(
    this._signaling,
    this._socket,
    this._media,
    this._authRepo,
  ) : super(CallUiState.initial());

  final CallSignalingService _signaling;
  final CallSocketService _socket;
  final MediasoupCallService _media;
  final SupabaseAuthRepository _authRepo;

  Future<void> startOutgoing({
    required String calleeId,
    required String peerName,
    required String peerAvatarUrl,
  }) async {
    final me = _authRepo.currentUser?.id;
    if (me == null) throw Exception('Not signed in');

    state = state.copyWith(
      status: CallStatus.calling,
      peerUserId: calleeId,
      peerName: peerName,
      peerAvatarUrl: peerAvatarUrl,
      isIncoming: false,
    );

    final response = await _signaling.invite(
      callerId: me,
      calleeId: calleeId,
    );

    final session = CallSession.fromSignalResponse(
      Map<String, dynamic>.from(response['session'] as Map),
      me,
    );

    state = state.copyWith(
      callId: session.callId,
      roomId: session.roomId,
    );
  }

  Future<void> acceptIncoming(CallSession session) async {
    // 1. request mic permission
    // 2. POST call_accept
    // 3. join lifecycle room
    // 4. connect socket + mediasoup
  }

  Future<void> connectMedia() async {
    // 1. socket joinRoom
    // 2. load device
    // 3. open mic
    // 4. create send transport
    // 5. produce audio
    // 6. create recv transport
    // 7. consume remote producer
  }

  Future<void> hangUp() async {
    // call leave_room + leaveRoom + full cleanup
  }

  Future<void> toggleMute() async {
    final nextMuted = !state.isMuted;
    await _media.setMuted(nextMuted);
    state = state.copyWith(isMuted: nextMuted);
  }
}
```

### `lib/features/call/presentation/providers/call_providers.dart`

```dart
final callSignalingServiceProvider = Provider<CallSignalingService>((ref) {
  return CallSignalingService(http.Client(), Supabase.instance.client);
});

final callSocketServiceProvider = Provider<CallSocketService>((ref) {
  return CallSocketService();
});

final mediasoupCallServiceProvider = Provider<MediasoupCallService>((ref) {
  return MediasoupCallService();
});

final incomingCallServiceProvider = Provider<IncomingCallService>((ref) {
  return IncomingCallService(Supabase.instance.client);
});

final callControllerProvider =
    StateNotifierProvider<CallController, CallUiState>((ref) {
  return CallController(
    ref.watch(callSignalingServiceProvider),
    ref.watch(callSocketServiceProvider),
    ref.watch(mediasoupCallServiceProvider),
    ref.watch(authRepositoryProvider),
  );
});
```

### `lib/features/call/presentation/screens/call_session_screen.dart`

```dart
class CallSessionScreen extends ConsumerWidget {
  const CallSessionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(callControllerProvider);

    switch (state.status) {
      case CallStatus.calling:
        return const CallEntryScreen();
      case CallStatus.ringing:
        return const IncomingCallScreen();
      case CallStatus.connecting:
      case CallStatus.connected:
        return const ActiveCallScreen();
      case CallStatus.ended:
      case CallStatus.failed:
        return const CallResultScreen();
      case CallStatus.idle:
        return const SizedBox.shrink();
    }
  }
}
```

### `lib/features/call/presentation/screens/call_entry_screen.dart`

```dart
class CallEntryScreen extends ConsumerWidget {
  const CallEntryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(callControllerProvider);
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(radius: 44),
            const SizedBox(height: 16),
            Text(state.peerName ?? 'Calling'),
            const SizedBox(height: 8),
            Text(state.connectionLabel),
            const SizedBox(height: 24),
            FilledButton.tonal(
              onPressed: () => ref.read(callControllerProvider.notifier).hangUp(),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }
}
```

### `lib/features/call/presentation/screens/incoming_call_screen.dart`

```dart
class IncomingCallScreen extends ConsumerWidget {
  const IncomingCallScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(callControllerProvider);
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(radius: 44),
            const SizedBox(height: 16),
            Text(state.peerName ?? 'Incoming call'),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FilledButton.tonal(
                  onPressed: () => ref.read(callControllerProvider.notifier).hangUp(),
                  child: const Text('Reject'),
                ),
                const SizedBox(width: 16),
                FilledButton(
                  onPressed: () {
                    // acceptIncoming(currentSession)
                  },
                  child: const Text('Accept'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
```

### `lib/features/call/presentation/screens/active_call_screen.dart`

```dart
class ActiveCallScreen extends ConsumerWidget {
  const ActiveCallScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(callControllerProvider);
    return Scaffold(
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              children: [
                const SizedBox(height: 48),
                CircleAvatar(radius: 44),
                const SizedBox(height: 16),
                Text(state.peerName ?? 'Voice call'),
                const SizedBox(height: 8),
                Text(state.connectionLabel),
              ],
            ),
            CallActionBar(
              isMuted: state.isMuted,
              isSpeakerOn: state.isSpeakerOn,
              onMute: () => ref.read(callControllerProvider.notifier).toggleMute(),
              onSpeaker: () {},
              onHangUp: () => ref.read(callControllerProvider.notifier).hangUp(),
            ),
          ],
        ),
      ),
    );
  }
}
```

### `lib/features/call/presentation/screens/call_result_screen.dart`

```dart
class CallResultScreen extends ConsumerWidget {
  const CallResultScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(callControllerProvider);
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              state.status == CallStatus.failed ? Icons.error_outline : Icons.call_end,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(state.errorMessage ?? 'Call ended'),
          ],
        ),
      ),
    );
  }
}
```

### `lib/features/call/presentation/widgets/call_action_bar.dart`

```dart
class CallActionBar extends StatelessWidget {
  const CallActionBar({
    super.key,
    required this.isMuted,
    required this.isSpeakerOn,
    required this.onMute,
    required this.onSpeaker,
    required this.onHangUp,
  });

  final bool isMuted;
  final bool isSpeakerOn;
  final VoidCallback onMute;
  final VoidCallback onSpeaker;
  final VoidCallback onHangUp;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          IconButton(
            onPressed: onMute,
            icon: Icon(isMuted ? Icons.mic_off : Icons.mic),
          ),
          IconButton(
            onPressed: onSpeaker,
            icon: Icon(isSpeakerOn ? Icons.volume_up : Icons.hearing),
          ),
          IconButton(
            onPressed: onHangUp,
            icon: const Icon(Icons.call_end),
            color: Colors.red,
          ),
        ],
      ),
    );
  }
}
```

## 10. Existing File Wiring Notes

### `lib/features/chat/presentation/widgets/signal_chat_app_bar.dart`

For private chats:
- add a visible call icon beside the existing menu action
- call `ref.read(callControllerProvider.notifier).startOutgoing(...)`
- then navigate to `AppRoutes.callSession`

For group chats:
- keep the current call icon, but route it into the same feature
- use `chat.participants` for later multi-party support
- first release can still limit to 1:1 if backend room admission is only ready for two users

### `lib/features/chat/presentation/widgets/mini_profile_popup.dart`

Current behavior:
- launches `tel:`

Replace with:
- in-app XPARQ voice call when the profile belongs to an authenticated app user
- keep `tel:` as a fallback only if you intentionally want PSTN contact behavior

### `lib/main.dart`

Add one startup hook:

```dart
ref.read(incomingCallBootstrapProvider);
```

This should:
- subscribe to the current user's incoming call feed
- show the incoming call route if the app is foregrounded
- optionally show a local notification if the app is backgrounded

## 11. Integration Order

1. Add dependencies and platform microphone permissions.
2. Add the `features/call` module and provider/controller skeleton.
3. Add `AppRoutes.callSession` and full-screen route registration.
4. Replace the `tel:` call action in `MiniProfilePopup`.
5. Add a direct call button to `SignalChatAppBar` for private chats.
6. Implement HTTP lifecycle signaling:
   - invite
   - accept
   - reject
   - join_room
   - leave_room
7. Implement Socket.IO auth and SFU events:
   - `joinRoom`
   - `createTransport`
   - `connectTransport`
   - `produce`
   - `consume`
   - `leaveRoom`
8. Implement mediasoup device loading and audio-only transport setup.
9. Subscribe to the existing incoming-call state feed from Supabase.
10. Add cleanup guards for:
   - route pop
   - app pause
   - socket disconnect
   - transport failure
11. Add final UX polish:
   - call timer
   - reconnect label
   - remote audio activity pulse

## 12. Production Notes

- Prioritize audio-only and keep video out of the first release.
- Do not request microphone permission on app startup. Request only when placing or accepting a call.
- Delay `getUserMedia` until the call is accepted to reduce unnecessary capture and battery use.
- Keep call lifecycle signaling idempotent. The backend is already hardened for transport and producer duplication.
- Treat `newProducer` as the canonical signal to start consuming remote audio.
- Always call both leave paths on exit:
  - HTTP `/events/leave_room`
  - Socket.IO `leaveRoom`
- If a call is already active, reject or queue new invites in the controller instead of opening stacked call routes.

## 13. Recommended First Working Slice

Ship in this order:

1. private 1:1 call button from chat
2. outgoing call screen
3. incoming call screen
4. accept/reject signaling
5. mediasoup audio uplink/downlink
6. mute + hangup

Do not start with:

- group calling UX
- call persistence across app restarts
- picture-in-picture
- advanced speaker routing UI
- call history screens

That first slice is enough to reach the stated goal:

- two users can call each other
- works across WiFi and mobile networks
- TURN is used automatically by ICE when direct paths fail
- audio flows end-to-end through mediasoup
