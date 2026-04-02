import 'dart:async';

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
  final dynamic connectionInfo;
  ConnectionInitiatedEvent(this.endpointId, this.connectionInfo);
}

class ConnectionResultEvent {
  final String endpointId;
  final dynamic status;
  ConnectionResultEvent(this.endpointId, this.status);
}

class NearbyService {
  static final NearbyService instance = NearbyService._internal();
  NearbyService._internal();

  final _peersController = StreamController<List<NearbyPeer>>.broadcast();
  final _handshakeAcceptController = StreamController<String>.broadcast();
  final _disconnectedController = StreamController<String>.broadcast();
  final _handshakeRequestController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _connectionInitiatedController =
      StreamController<ConnectionInitiatedEvent>.broadcast();
  final _connectionResultController =
      StreamController<ConnectionResultEvent>.broadcast();
  final _messageController = StreamController<Map<String, dynamic>>.broadcast();

  Stream<List<NearbyPeer>> get incomingPeersStream => _peersController.stream;
  Stream<String> get onHandshakeAccept => _handshakeAcceptController.stream;
  Stream<String> get onDisconnected => _disconnectedController.stream;
  Stream<Map<String, dynamic>> get onHandshakeRequest =>
      _handshakeRequestController.stream;
  Stream<ConnectionInitiatedEvent> get onConnectionInitiated =>
      _connectionInitiatedController.stream;
  Stream<ConnectionResultEvent> get onConnectionResult =>
      _connectionResultController.stream;
  Stream<Map<String, dynamic>> get incomingMessageStream =>
      _messageController.stream;

  List<NearbyPeer> get peers => [];
  Set<String> get connectedEndpoints => {};
  bool get isAdvertising => false;
  bool get isDiscovering => false;

  void setCurrentUser(String userId, String effectiveName, bool isAnonymous) {}

  Future<bool> startAdvertising() async => false;
  Future<void> stopAdvertising() async {}

  Future<bool> startDiscovery() async => false;
  Future<void> stopDiscovery() async {}

  Future<void> requestConnection(String endpointId) async {}
  Future<void> acceptConnection(String endpointId) async {}
  Future<void> rejectConnection(String endpointId) async {}
  Future<void> sendMessage(String endpointId, String text) async {}

  Future<void> disconnectAll() async {}
  Future<void> resetAll() async {}

  bool isPeerConnected(String userId) => false;

  void dispose() {
    _peersController.close();
    _handshakeAcceptController.close();
    _disconnectedController.close();
    _handshakeRequestController.close();
    _connectionInitiatedController.close();
    _connectionResultController.close();
    _messageController.close();
  }
}
