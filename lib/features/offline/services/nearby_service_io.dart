import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:nearby_connections/nearby_connections.dart';
import 'offline_chat_database.dart';
import 'offline_mesh_encryption_service.dart';

class NearbyPeer {
  final String endpointId;
  final String userId;
  final String displayName;
  final bool isAnonymous;
  final String? publicKey;
  final DateTime discoveredAt;

  NearbyPeer({
    required this.endpointId,
    required this.userId,
    required this.displayName,
    required this.isAnonymous,
    this.publicKey,
    required this.discoveredAt,
  });
}

class ConnectionInitiatedEvent {
  final String endpointId;
  final ConnectionInfo connectionInfo;
  ConnectionInitiatedEvent(this.endpointId, this.connectionInfo);
}

class ConnectionResultEvent {
  final String endpointId;
  final Status status;
  ConnectionResultEvent(this.endpointId, this.status);
}

class NearbyService {
  static const String _appMarker = 'xq1';
  static const int _maxRelayHops = 3;
  static const Duration _seenMessageRetention = Duration(minutes: 10);

  // Singleton instance
  static final NearbyService _instance = NearbyService._internal();
  static NearbyService get instance => _instance;

  NearbyService._internal();

  final String _serviceId = 'com.iXPARQ.offline';
  final Strategy _strategy =
      Strategy.P2P_CLUSTER; // Best for a mesh/social network

  // State
  bool _isAdvertising = false;
  bool _isDiscovering = false;
  String? _currentUserId;
  String? _effectiveName;
  bool _isAnonymous = false;
  String? _currentPublicKey;

  // Streams for UI
  final _peersController = StreamController<List<NearbyPeer>>.broadcast();

  /// Returns a stream of discovered peers.
  /// Yields the current cached peers immediately upon subscription.
  Stream<List<NearbyPeer>> get incomingPeersStream async* {
    yield _discoveredPeers.values.toList();
    yield* _peersController.stream;
  }

  // Connection Event Streams
  final _connectionInitiatedController =
      StreamController<ConnectionInitiatedEvent>.broadcast();
  Stream<ConnectionInitiatedEvent> get onConnectionInitiated =>
      _connectionInitiatedController.stream;

  final _connectionResultController =
      StreamController<ConnectionResultEvent>.broadcast();
  Stream<ConnectionResultEvent> get onConnectionResult =>
      _connectionResultController.stream;

  // Handshake Streams
  final _handshakeRequestController =
      StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get onHandshakeRequest =>
      _handshakeRequestController.stream;

  final _handshakeAcceptController = StreamController<String>.broadcast();
  Stream<String> get onHandshakeAccept => _handshakeAcceptController.stream;

  final _disconnectedController = StreamController<String>.broadcast();
  Stream<String> get onDisconnected => _disconnectedController.stream;

  final _messageController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get incomingMessageStream =>
      _messageController.stream;

  // Active Data
  final Map<String, NearbyPeer> _discoveredPeers =
      {}; // userId -> NearbyPeer (Updated to index by userId)
  final Set<String> _connectedEndpoints = {};
  final Map<String, DateTime> _seenMessageIds = {};

  List<NearbyPeer> get peers => _discoveredPeers.values.toList();
  Set<String> get connectedEndpoints => _connectedEndpoints;
  bool get isAdvertising => _isAdvertising;
  bool get isDiscovering => _isDiscovering;
  bool get isMeshActive => _isAdvertising && _isDiscovering;

  /// Returns true if the specific [userId] (UUID) is currently connected
  /// via any of our active endpoints.
  bool isPeerConnected(String userId) {
    final peer = _discoveredPeers[userId];
    if (peer == null) return false;
    return _connectedEndpoints.contains(peer.endpointId);
  }

  /// Prepares the payload to be broadcasted as our 'Endpoint Name'
  String _buildEndpointInfo() {
    final payload = {
      'a': _appMarker,
      'i': _currentUserId ?? 'unknown',
      'n': _isAnonymous
          ? 'Anonymous'
          : (_effectiveName != null && _effectiveName!.isNotEmpty
              ? _effectiveName
              : 'Explorer'),
      'o': _isAnonymous ? 1 : 0,
      'p': _currentPublicKey ?? '',
    };
    return jsonEncode(payload);
  }

  void setCurrentUser(
    String userId,
    String effectiveName,
    bool isAnonymous, {
    String? publicKey,
  }) {
    if (_currentUserId == userId &&
        _effectiveName == effectiveName &&
        _isAnonymous == isAnonymous &&
        _currentPublicKey == publicKey) {
      return;
    }

    _currentUserId = userId;
    _effectiveName = effectiveName;
    _isAnonymous = isAnonymous;
    _currentPublicKey = publicKey;
    debugPrint(
      "Nearby: User context updated -> ID: $userId, Name: $effectiveName, Anon: $isAnonymous",
    );

    // If we were already running, we need to restart to update the air-broadcast info
    if (_isAdvertising || _isDiscovering) {
      debugPrint("Nearby: Restarting services to reflect user changes...");
      restartMesh().then((success) {
        debugPrint("Nearby: Restart after user update -> $success");
      });
    }
  }

  Future<void> _stopRuntimeState() async {
    await stopDiscovery();
    await stopAdvertising();
    await disconnectAll();
    _discoveredPeers.clear();
    _connectedEndpoints.clear();
    _seenMessageIds.clear();
    _emitPeers();
  }

  Future<bool> startMesh() async {
    if (_currentUserId == null || _currentUserId!.isEmpty) {
      debugPrint("Nearby: Cannot start mesh, missing current user id");
      return false;
    }

    final discoveryOk = await startDiscovery();
    final advertisingOk = await startAdvertising();
    return discoveryOk && advertisingOk;
  }

  Future<bool> restartMesh() async {
    await _stopRuntimeState();
    return startMesh();
  }

  /// Starts Broadcasting our presence to others.
  Future<bool> startAdvertising() async {
    if (_isAdvertising) return true;
    if (_currentUserId == null || _currentUserId!.isEmpty) {
      debugPrint("Nearby: Cannot start advertising, userId is null/empty");
      return false;
    }

    try {
      final endpointInfo = _buildEndpointInfo();
      debugPrint(
        "Nearby: Attempting to start advertising with info: $endpointInfo",
      );
      bool success = await Nearby().startAdvertising(
        endpointInfo,
        _strategy,
        onConnectionInitiated: _onConnectionInitiated,
        onConnectionResult: _onConnectionResult,
        onDisconnected: _onDisconnected,
        serviceId: _serviceId,
      );

      _isAdvertising = success;
      debugPrint(
        "Nearby: Advertising status: ${success ? 'ACTIVE' : 'FAILED'}",
      );
      return success;
    } catch (e) {
      if (e.toString().contains('STATUS_ALREADY_ADVERTISING')) {
        _isAdvertising = true;
        debugPrint("Nearby: Advertising already active.");
        return true;
      }
      debugPrint("Nearby: Advertising Exception: $e");
      _isAdvertising = false;
      return false;
    }
  }

  Future<void> stopAdvertising() async {
    debugPrint("Nearby: Stopping advertising...");
    await Nearby().stopAdvertising();
    _isAdvertising = false;
  }

  /// Starts Scanning for others.
  Future<bool> startDiscovery() async {
    if (_isDiscovering) return true;

    try {
      debugPrint("Nearby: Attempting to start discovery...");
      bool success = await Nearby().startDiscovery(
        _currentUserId ?? 'unknown',
        _strategy,
        onEndpointFound: (id, name, serviceId) {
          _handleEndpointFound(id, name);
        },
        onEndpointLost: (id) {
          // Find which user (userId) was associated with this endpointId
          String? userIdToRemove;
          _discoveredPeers.forEach((uid, peer) {
            if (peer.endpointId == id) userIdToRemove = uid;
          });

          if (userIdToRemove != null) {
            _discoveredPeers.remove(userIdToRemove);
            _emitPeers();
            debugPrint("Nearby: [LOST] Endpoint $id (User: $userIdToRemove)");
          }
        },
        serviceId: _serviceId,
      );

      _isDiscovering = success;
      debugPrint("Nearby: Discovery status: ${success ? 'ACTIVE' : 'FAILED'}");
      return success;
    } catch (e) {
      if (e.toString().contains('STATUS_ALREADY_DISCOVERING')) {
        _isDiscovering = true;
        debugPrint("Nearby: Discovery already active.");
        return true;
      }
      debugPrint("Nearby: Discovery Exception: $e");
      _isDiscovering = false;
      return false;
    }
  }

  Future<void> stopDiscovery() async {
    await Nearby().stopDiscovery();
    _isDiscovering = false;
    _discoveredPeers.clear();
    _emitPeers();
  }

  void _handleEndpointFound(String endpointId, String endpointName) {
    debugPrint(
      "Nearby: [_handleEndpointFound] id: $endpointId, name: $endpointName",
    );
    try {
      int startIndex = endpointName.indexOf('{');
      int endIndex = endpointName.lastIndexOf('}');

      if (startIndex == -1 || endIndex == -1) {
        debugPrint("Nearby: [!] No JSON braces found in '$endpointName'");
        return;
      }

      String jsonStr = endpointName.substring(startIndex, endIndex + 1);
      debugPrint("Nearby: Extracted JSON: '$jsonStr'");

      final payload = jsonDecode(jsonStr);
      final marker = '${payload['a'] ?? payload['app'] ?? ''}'.trim();
      if (marker != _appMarker) {
        debugPrint(
          "Nearby: [SKIP] Foreign app marker from $endpointId -> '$marker'",
        );
        return;
      }
      final userId = (payload['i'] ?? payload['id']) as String? ?? '';
      String name = (payload['n'] ?? payload['name']) as String? ?? 'Explorer';
      final anonValue = payload['o'] ?? payload['anon'];
      final isAnonymous = anonValue is bool
          ? anonValue
          : (anonValue is num ? anonValue != 0 : false);
      final publicKey = (payload['p'] ?? payload['pub']) as String?;

      if (isAnonymous) {
        name = 'Anonymous';
      }

      debugPrint(
        "Nearby: Parsed -> userId: '$userId', name: '$name', anon: $isAnonymous",
      );

      // Don't discover ourselves if MAC rotation accidentally surfaces our own ID.
      // We check if BOTH are non-empty to avoid accidental rejection during setup.
      bool isSelf = userId.isNotEmpty &&
          _currentUserId != null &&
          _currentUserId!.isNotEmpty &&
          userId == _currentUserId;

      if (isSelf) {
        debugPrint("Nearby: [SKIP] Self-discovery for ID $userId");
        return;
      }

      final peer = NearbyPeer(
        endpointId: endpointId,
        userId: userId,
        displayName: name,
        isAnonymous: isAnonymous,
        publicKey: publicKey,
        discoveredAt: DateTime.now(),
      );

      _discoveredPeers[userId] = peer;
      debugPrint(
        "Nearby: [SUCCESS] Added/Updated peer $endpointId (User: $userId). Total peers: ${_discoveredPeers.length}",
      );
      _emitPeers();
    } catch (e, stack) {
      debugPrint("Nearby: [ERROR] _handleEndpointFound failed: $e\n$stack");
    }
  }

  void _emitPeers() {
    _peersController.add(_discoveredPeers.values.toList());
  }

  // --- Handshake & Messaging ---

  /// Requests a connection with a discovered peer.
  /// This acts as our "Add Peer" Handshake.
  Future<void> requestConnection(String endpointId) async {
    debugPrint("Nearby: [requestConnection] to $endpointId");
    try {
      await Nearby().requestConnection(
        _buildEndpointInfo(),
        endpointId,
        onConnectionInitiated: (id, info) => _onConnectionInitiated(id, info),
        onConnectionResult: (id, status) => _onConnectionResult(id, status),
        onDisconnected: (id) => _onDisconnected(id),
      );
    } catch (e) {
      debugPrint("Nearby: Request Connection Error: $e");
    }
  }

  void _onConnectionInitiated(
    String endpointId,
    ConnectionInfo connectionInfo,
  ) {
    debugPrint(
      "Nearby: [ON_CONNECTION_INITIATED] id: $endpointId, name: ${connectionInfo.endpointName}",
    );

    // 1. ALWAYS emit to the raw stream (Used by AppShell/OfflineAppShell for notifications)
    _connectionInitiatedController.add(
      ConnectionInitiatedEvent(endpointId, connectionInfo),
    );

    // 2. Parse JSON for specialized Handshake listeners if applicable
    try {
      final String rawName = connectionInfo.endpointName;
      int startIndex = rawName.indexOf('{');
      int endIndex = rawName.lastIndexOf('}');

      if (startIndex != -1 && endIndex != -1) {
        final jsonStr = rawName.substring(startIndex, endIndex + 1);
        final payload = jsonDecode(jsonStr);
        final marker = '${payload['a'] ?? payload['app'] ?? ''}'.trim();
        if (marker != _appMarker) {
          debugPrint(
            "Nearby: [SKIP] Incoming connection from foreign app -> '$marker'",
          );
          return;
        }
        final senderId = (payload['i'] ?? payload['id']) as String;
        final senderName = (payload['n'] ?? payload['name']) as String;

        _handshakeRequestController.add({
          'endpointId': endpointId,
          'senderId': senderId,
          'senderName': senderName,
          'authToken': connectionInfo.authenticationToken,
        });
        debugPrint("Nearby: Handshake Parsed -> $senderName ($senderId)");
      } else {
        debugPrint("Nearby: No JSON found in connection nickname: $rawName");
      }
    } catch (e) {
      debugPrint("Nearby: Handshake payload parse error: $e");
    }
  }

  /// App accepts the connection.
  Future<void> acceptConnection(String endpointId) async {
    try {
      await Nearby().acceptConnection(
        endpointId,
        onPayLoadRecieved: _onPayloadReceived,
        onPayloadTransferUpdate: _onPayloadTransferUpdate,
      );
    } catch (e) {
      debugPrint("Nearby: Accept Connection Error: $e");
    }
  }

  /// App rejects the connection.
  Future<void> rejectConnection(String endpointId) async {
    try {
      await Nearby().rejectConnection(endpointId);
    } catch (e) {
      debugPrint("Nearby: Reject Connection Error: $e");
    }
  }

  void _onConnectionResult(String endpointId, Status status) {
    if (status == Status.CONNECTED) {
      _connectedEndpoints.add(endpointId);
      // We can use this to notify UI that Handshake succeeded
      _handshakeAcceptController.add(endpointId);
    } else {
      _connectedEndpoints.remove(endpointId);
    }
  }

  void _onDisconnected(String endpointId) {
    _connectedEndpoints.remove(endpointId);
    _disconnectedController.add(endpointId);
  }

  /// Sending a text chat message.
  Future<void> sendMessage(String endpointId, String text) async {
    if (!_connectedEndpoints.contains(endpointId)) {
      debugPrint("Nearby: Cannot send message, endpoint not connected.");
      return;
    }

    try {
      final recipientId = _discoveredPeers.values
          .where((peer) => peer.endpointId == endpointId)
          .firstOrNull
          ?.userId;
      final recipientPublicKey = _discoveredPeers.values
          .where((peer) => peer.endpointId == endpointId)
          .firstOrNull
          ?.publicKey;
      if (recipientPublicKey == null || recipientPublicKey.isEmpty) {
        throw Exception('Missing recipient public key for offline mesh chat');
      }
      final messageId = _buildMessageId();
      final encryptedPayload =
          await OfflineMeshEncryptionService.instance.encryptForRecipient(
        plaintext: text,
        recipientPublicKeyBase64: recipientPublicKey,
      );
      final payload = {
        'type': 'chat',
        'messageId': messageId,
        'senderId': _currentUserId,
        'senderPublicKey': encryptedPayload['senderPublicKey'],
        'recipientId': recipientId,
        'ciphertext': encryptedPayload['ciphertext'],
        'mac': encryptedPayload['mac'],
        'nonce': encryptedPayload['nonce'],
        'timestamp': DateTime.now().toIso8601String(),
        'remainingHops': _maxRelayHops,
      };

      _markMessageSeen(messageId);
      final bytes = Uint8List.fromList(utf8.encode(jsonEncode(payload)));
      await Nearby().sendBytesPayload(endpointId, bytes);
    } catch (e) {
      debugPrint("Nearby: Send Message Error: $e");
    }
  }

  /// Receiving a payload (Chat message).
  void _onPayloadReceived(String endpointId, Payload payload) async {
    if (payload.type == PayloadType.BYTES) {
      if (payload.bytes == null) return;
      try {
        final jsonString = utf8.decode(payload.bytes!);
        final data = jsonDecode(jsonString);

        if (data['type'] == 'chat') {
          final messageId = data['messageId'] as String? ??
              '${data['senderId']}_${data['timestamp']}';
          final senderId = data['senderId'] as String;
          final senderPublicKey = data['senderPublicKey'] as String? ?? '';
          final recipientId = data['recipientId'] as String?;
          final remainingHops = (data['remainingHops'] as int?) ?? 0;

          if (_hasSeenMessage(messageId)) {
            debugPrint("Nearby: Skipping duplicate message $messageId");
            return;
          }

          _markMessageSeen(messageId);

          final isForCurrentUser = recipientId == null ||
              recipientId.isEmpty ||
              recipientId == _currentUserId;

          if (!isForCurrentUser) {
            await _relayMessage(
              sourceEndpointId: endpointId,
              data: data,
              remainingHops: remainingHops,
            );
            return;
          }

          final trustedPublicKey =
              await OfflineChatDatabase.instance.getFriendPublicKey(senderId);
          if (trustedPublicKey != null &&
              trustedPublicKey.isNotEmpty &&
              trustedPublicKey != senderPublicKey) {
            debugPrint(
              'Nearby: Sender public key mismatch for trusted peer $senderId',
            );
            return;
          }

          final text =
              await OfflineMeshEncryptionService.instance.decryptFromSender(
            ciphertextBase64: data['ciphertext'] as String? ?? '',
            macBase64: data['mac'] as String? ?? '',
            nonceBase64: data['nonce'] as String? ?? '',
            senderPublicKeyBase64: senderPublicKey,
          );

          // 1. Persist to Database immediately
          final peer = _discoveredPeers[senderId];
          final peerName = (peer?.isAnonymous ?? false)
              ? 'Anonymous'
              : (peer?.displayName ?? 'Explorer');

          await OfflineChatDatabase.instance.insertMessage(
            peerId: senderId,
            peerName: peerName,
            message: text,
            isMe: false,
          );

          // 2. Pass to UI Stream
          _messageController.add({
            'endpointId': endpointId,
            'messageId': messageId,
            'senderId': senderId,
            'text': text,
            'timestamp': data['timestamp'],
          });
        }
      } catch (e) {
        debugPrint("Nearby: Decode payload error: $e");
      }
    }
  }

  void _onPayloadTransferUpdate(
    String endpointId,
    PayloadTransferUpdate update,
  ) {
    // Useful for tracking file upload/download progress later
  }

  Future<void> _relayMessage({
    required String sourceEndpointId,
    required Map<String, dynamic> data,
    required int remainingHops,
  }) async {
    if (remainingHops <= 0) {
      debugPrint("Nearby: Relay hop budget exhausted for ${data['messageId']}");
      return;
    }

    final nextPayload = Map<String, dynamic>.from(data)
      ..['remainingHops'] = remainingHops - 1;

    final bytes = Uint8List.fromList(utf8.encode(jsonEncode(nextPayload)));
    final targetEndpoints = _connectedEndpoints
        .where((endpointId) => endpointId != sourceEndpointId)
        .toList();

    for (final endpointId in targetEndpoints) {
      try {
        await Nearby().sendBytesPayload(endpointId, bytes);
      } catch (e) {
        debugPrint("Nearby: Relay error to $endpointId: $e");
      }
    }
  }

  bool _hasSeenMessage(String messageId) {
    _purgeSeenMessages();
    return _seenMessageIds.containsKey(messageId);
  }

  void _markMessageSeen(String messageId) {
    _purgeSeenMessages();
    _seenMessageIds[messageId] = DateTime.now();
  }

  void _purgeSeenMessages() {
    final cutoff = DateTime.now().subtract(_seenMessageRetention);
    _seenMessageIds.removeWhere((_, seenAt) => seenAt.isBefore(cutoff));
  }

  String _buildMessageId() {
    final senderId = _currentUserId ?? 'unknown';
    return '$senderId-${DateTime.now().microsecondsSinceEpoch}';
  }

  Future<void> disconnectAll() async {
    await Nearby().stopAllEndpoints();
    _connectedEndpoints.clear();
  }

  Future<void> resetAll() async {
    await _stopRuntimeState();
    _currentUserId = null;
    _effectiveName = null;
    _isAnonymous = false;
    _currentPublicKey = null;
    // Auto-purge old messages (3-day rule)
    await OfflineChatDatabase.instance.purgeOldMessages();
  }

  void dispose() {
    resetAll();
    _peersController.close();
    _handshakeRequestController.close();
    _handshakeAcceptController.close();
    _messageController.close();
  }
}
