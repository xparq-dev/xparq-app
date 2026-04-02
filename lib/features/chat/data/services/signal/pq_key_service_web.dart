import 'package:flutter/foundation.dart';

class KyberKeyService {
  KyberKeyService._();
  static final KyberKeyService instance = KyberKeyService._();

  Future<void> initializeKeys() async {
    debugPrint('[KyberKeyService] Web Stub: PQ Keys disabled.');
  }

  Future<void> generateKeySet() async {}
  Future<List<int>?> getMyPQIdentitySecret() async => null;
  Future<List<int>?> getMyPQIdentityPublic() async => null;
  Future<List<int>?> getPQOTPreKeySecret(int keyId) async => null;
  Future<Map<String, dynamic>?> fetchPQBundle(String uid) async => null;
}
