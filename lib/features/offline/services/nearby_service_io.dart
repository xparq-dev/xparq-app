import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:nearby_connections/nearby_connections.dart';
import 'offline_chat_database.dart';

class NearbyPeer {
  final String endpointId;
  final String userId;
  final String displayName;
  final bool isAnonymous;
  final DateTime discoveredAt;

  NearbyPeer({
    required this.endpointId,
    required this.userId,
    required this.displayName,
    required this.isAnonymous,
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

  List<NearbyPeer> get peers => _discoveredPeers.values.toList();
  Set<String> get connectedEndpoints => _connectedEndpoints;
  bool get isAdvertising => _isAdvertising;
  bool get isDiscovering => _isDiscovering;

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
      'id': _currentUserId ?? 'unknown',
      'name': _isAnonymous
          ? 'Anonymous'
          : (_effectiveName != null && _effectiveName!.isNotEmpty
                ? _effectiveName
                : 'Explorer'),
      'anon': _isAnonymous,
    };
    return jsonEncode(payload);
  }

  void setCurrentUser(String userId, String effectiveName, bool isAnonymous) {
    if (_currentUserId == userId &&
        _effectiveName == effectiveName &&
        _isAnonymous == isAnonymous) {
      return;
    }

    _currentUserId = userId;
    _effectiveName = effectiveName;
    _isAnonymous = isAnonymous;
    debugPrint(
      "Nearby: User context updated -> ID: $userId, Name: $effectiveName, Anon: $isAnonymous",
    );

    // If we were already running, we need to restart to update the air-broadcast info
    if (_isAdvertising || _isDiscovering) {
      debugPrint("Nearby: Restarting services to reflect user changes...");
      resetAll().then((_) {
        startDiscovery();
        startAdvertising();
      });
    }
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
      final userId = payload['id'] as String? ?? '';
      String name = payload['name'] as String? ?? 'Explorer';
      final isAnonymous = payload['anon'] as bool? ?? false;

      if (isAnonymous) {
        name = 'Anonymous';
      }

      debugPrint(
        "Nearby: Parsed -> userId: '$userId', name: '$name', anon: $isAnonymous",
      );

      // Don't discover ourselves if MAC rotation accidentally surfaces our own ID.
      // We check if BOTH are non-empty to avoid accidental rejection during setup.
      bool isSelf =
          userId.isNotEmpty &&
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
        final senderId = payload['id'] as String;
        final senderName = payload['name'] as String;

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
      final payload = {
        'type': 'chat',
        'senderId': _currentUserId,
        'text': text,
        'timestamp': DateTime.now().toIso8601String(),
      };

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
          final senderId = data['senderId'] as String;
          final text = data['text'] as String;

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

  Future<void> disconnectAll() async {
    await Nearby().stopAllEndpoints();
    _connectedEndpoints.clear();
  }

  Future<void> resetAll() async {
    await stopDiscovery();
    await stopAdvertising();
    await disconnectAll();
    _discoveredPeers.clear();
    _currentUserId = null;
    _effectiveName = null;
    _isAnonymous = false;
    _emitPeers();
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
