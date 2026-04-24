import 'package:flutter/foundation.dart';

class HybridX3DHService {
  HybridX3DHService._();
  static final HybridX3DHService instance = HybridX3DHService._();

  Future<Map<String, dynamic>?> initiateHybridSession(String otherUid) async {
    debugPrint('[HybridX3DHService] Web Stub: Hybrid handshake disabled.');
    return null;
  }

  Future<List<int>?> handleIncomingHybridSession(
    Map<String, dynamic> handshakeData,
  ) async {
    return null;
  }

  Future<void> initialize() async {}
}
