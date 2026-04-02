import 'dart:convert';
import 'dart:isolate';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:liboqs/liboqs.dart';

/// KyberKeyService handles Post-Quantum key generation and storage
/// using ML-KEM-768 (formerly Kyber768).
class KyberKeyService {
  KyberKeyService._();
  static final KyberKeyService instance = KyberKeyService._();

  SupabaseClient get _supabase => Supabase.instance.client;
  final _storage = const FlutterSecureStorage();

  static const String _pqIdentityKeyName = 'pq_identity_key';
  static const String _pqOpkPrefix = 'pq_opk_';

  static const String _algName = 'ML-KEM-768';

  // ── Initialization ─────────────────────────────────────────────────────────

  /// Ensures PQ Identity and One-Time Prekeys exist locally and on the server.
  Future<void> initializeKeys() async {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) return;

    try {
      // 1. Identity Key
      var identityPriv = await _storage.read(key: _pqIdentityKeyName);
      if (identityPriv == null) {
        debugPrint('[KyberKeyService] Generating PQ Identity Key...');
        final kem = KEM.create(_algName);
        final keyPair = kem.generateKeyPair();

        // Save private key locally
        await _storage.write(
          key: _pqIdentityKeyName,
          value: base64Encode(keyPair.secretKey),
        );

        // Purge old PQ keys from previous installations
        await _supabase.from('signal_pq_identity_keys').delete().eq('uid', uid);
        await _supabase.from('signal_pq_ot_prekeys').delete().eq('uid', uid);

        // Upload public key to Supabase
        await _supabase.from('signal_pq_identity_keys').upsert({
          'uid': uid,
          'public_key': base64Encode(keyPair.publicKey),
          'created_at': DateTime.now().toIso8601String(),
        });

        // Save public key locally for quick access
        await _storage.write(
          key: '${_pqIdentityKeyName}_pub',
          value: base64Encode(keyPair.publicKey),
        );

        kem.dispose();
      }

      // 2. One-Time PreKeys (OPKs)
      // Check how many we have uploaded. If < 50, replenish.
      final countRes = await _supabase
          .from('signal_pq_ot_prekeys')
          .select('key_id')
          .eq('uid', uid)
          .isFilter('used_at', null)
          .count(CountOption.exact);

      final unusedCount = countRes.count;
      if (unusedCount < 50) {
        debugPrint(
          '[KyberKeyService] Replenishing PQ OPKs. Current unused: $unusedCount',
        );
        await _replenishPQOPKs(uid, 100 - unusedCount);
      }
    } catch (e) {
      debugPrint('[KyberKeyService] Initialization failed: $e');
    }
  }

  Future<void> _replenishPQOPKs(String uid, int amountToGenerate) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;

    // Use Isolate to prevent UI freeze during heavy ML-KEM generation
    debugPrint('[KyberKeyService] Spawning Isolate to generate $amountToGenerate OPKs...');
    final generatedKeys = await Isolate.run(() {
      final kem = KEM.create(_algName);
      final results = <({int keyId, Uint8List privBytes, Uint8List pubBytes})>[];

      for (int i = 0; i < amountToGenerate; i++) {
        final keyId = timestamp + i;
        final keyPair = kem.generateKeyPair();
        results.add((
          keyId: keyId,
          privBytes: keyPair.secretKey,
          pubBytes: keyPair.publicKey,
        ));
      }
      kem.dispose();
      return results;
    });

    debugPrint('[KyberKeyService] Isolate finished. Saving to local storage & Supabase...');
    final List<Map<String, dynamic>> opkBatch = [];

    for (final key in generatedKeys) {
      // Store private key securely
      await _storage.write(
        key: '$_pqOpkPrefix${key.keyId}',
        value: base64Encode(key.privBytes),
      );

      opkBatch.add({
        'uid': uid,
        'key_id': key.keyId,
        'public_key': base64Encode(key.pubBytes),
        'used_at': null,
      });
    }

    if (opkBatch.isNotEmpty) {
      await _supabase.from('signal_pq_ot_prekeys').upsert(opkBatch);
    }
  }

  // ── Retrieval (Local) ──────────────────────────────────────────────────────

  Future<List<int>?> getMyPQIdentitySecret() async {
    final b64 = await _storage.read(key: _pqIdentityKeyName);
    return b64 != null ? base64Decode(b64) : null;
  }

  Future<List<int>?> getMyPQIdentityPublic() async {
    final b64 = await _storage.read(key: '${_pqIdentityKeyName}_pub');
    return b64 != null ? base64Decode(b64) : null;
  }

  Future<List<int>?> getPQOTPreKeySecret(int keyId) async {
    final b64 = await _storage.read(key: '$_pqOpkPrefix$keyId');
    return b64 != null ? base64Decode(b64) : null;
  }

  // ── Retrieval (Remote Bundle) ──────────────────────────────────────────────

  /// Fetches Bob's PQ bundle: Identity Key + 1 OPK
  Future<Map<String, dynamic>?> fetchPQBundle(String uid) async {
    try {
      final identityRes = await _supabase
          .from('signal_pq_identity_keys')
          .select('public_key')
          .eq('uid', uid)
          .maybeSingle();

      if (identityRes == null) return null;

      // Fetch one unused OPK
      final opkRes = await _supabase
          .from('signal_pq_ot_prekeys')
          .select('key_id, public_key')
          .eq('uid', uid)
          .isFilter('used_at', null)
          .limit(1)
          .maybeSingle();

      if (opkRes != null) {
        // Mark OPK as used
        await _supabase
            .from('signal_pq_ot_prekeys')
            .update({'used_at': DateTime.now().toIso8601String()})
            .match({'uid': uid, 'key_id': opkRes['key_id'] as int});
      }

      return {
        'identity_key': identityRes['public_key'], // Base64
        'one_time_prekey': opkRes != null
            ? {
                'id': opkRes['key_id'],
                'public_key': opkRes['public_key'], // Base64
              }
            : null,
      };
    } catch (e) {
      debugPrint('[KyberKeyService] fetchPQBundle error: $e');
      return null;
    }
  }
}
