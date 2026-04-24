import 'dart:convert';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'dart:isolate';
import 'package:liboqs/liboqs.dart';
import 'x3dh_service.dart';
import 'pq_key_service.dart';

/// HybridX3DHService upgrades the standard X3DH handshake by incorporating
/// Post-Quantum ML-KEM-768. The final shared secret is derived from:
/// KDF(DH1 || DH2 || DH3 || DH4 || Kyber_Shared_Secret)
class HybridX3DHService {
  HybridX3DHService._();
  static final HybridX3DHService instance = HybridX3DHService._();

  final _x3dh = X3DHService.instance;
  final _kyberKeys = KyberKeyService.instance;
  static const String _algName = 'ML-KEM-768';

  // ── Session Initiation (Alice) ──────────────────────────────────────────────

  /// Initiates a Hybrid session with Bob.
  Future<Map<String, dynamic>?> initiateHybridSession(String otherUid) async {
    // 1. Perform standard X3DH
    // Note: We bypass the internal KDF of X3DHService here to inject Kyber.
    // To minimize refactoring of Phase 2, we will call an exposed raw version
    // or just encapsulate and add to the payload.

    // For this architecture, we will encapsulate a Kyber secret for Bob
    // and send it alongside the standard X3DH payload. The final Hybrid Secret
    // is KDF(Standard_Secret || Kyber_Secret).

    final standardResult = await _x3dh.initiateSession(otherUid);
    if (standardResult == null) return null;

    final standardSecret = standardResult['shared_secret'] as List<int>;
    final handshakeData =
        standardResult['handshake_data'] as Map<String, dynamic>;

    // 2. Perform PQ Encapsulation (Kyber)
    final pqBundle = await _kyberKeys.fetchPQBundle(otherUid);
    if (pqBundle == null) {
      debugPrint(
        '[HybridX3DH] Bob has no PQ keys. Falling back to classical X3DH only.',
      );
      return standardResult; // Graceful fallback
    }

    // Alice encapsulates a secret using Bob's PQ OPK (or Identity Key if OPK missing)
    final remotePubB64 =
        pqBundle['one_time_prekey']?['public_key'] ?? pqBundle['identity_key'];
    final remotePubBytes = base64Decode(remotePubB64);

    // We run Kyber encapsulate in an Isolate because liboqs FFI does heavy lattice
    // math synchronously. Offloading this keeps the UI 60fps buffer clear.
    final isolatePayload = {
      'algName': _algName,
      'remotePubBytes': remotePubBytes,
    };

    final isolatedResult = await Isolate.run(() {
      final kem = KEM.create(isolatePayload['algName'] as String);
      try {
        final encapResult = kem.encapsulate(
          Uint8List.fromList(isolatePayload['remotePubBytes'] as List<int>),
        );
        final result = {
          'ct': encapResult.ciphertext,
          'ss': encapResult.sharedSecret,
        };
        kem.dispose();
        return result;
      } catch (e) {
        kem.dispose();
        return null;
      }
    });

    if (isolatedResult == null) {
      debugPrint('[HybridX3DH] Kyber encapsulate failed in Isolate');
      return standardResult;
    }

    final cipherText = isolatedResult['ct'] as List<int>;
    final sharedSecretPQ = isolatedResult['ss'] as List<int>;

    // 3. Combine output
    final combinedSecret = await _deriveHybridSecret(
      standardSecret,
      sharedSecretPQ,
    );

    // 4. Attach PQ payload to handshake
    handshakeData['pq_ct'] = base64Encode(cipherText);
    handshakeData['pq_opk_id'] = pqBundle['one_time_prekey']?['id'];

    return {'shared_secret': combinedSecret, 'handshake_data': handshakeData};
  }

  // ── Handling Incoming Session (Bob) ────────────────────────────────────────

  /// Bob handles the hybrid handshake from Alice.
  Future<List<int>?> handleIncomingHybridSession(
    Map<String, dynamic> handshakeData,
  ) async {
    // 1. Recover standard X3DH secret
    final standardSecret = await _x3dh.handleIncomingSession(handshakeData);
    if (standardSecret == null) {
      debugPrint('[HybridX3DH] Failed to recover standard X3DH secret.');
      return null;
    }

    final pqCtB64 = handshakeData['pq_ct'] as String?;
    final pqOpkId = handshakeData['pq_opk_id'] as int?;

    // If Alice didn't send PQ data, fallback to classical
    if (pqCtB64 == null) {
      debugPrint('[HybridX3DH] No PQ payload received. Using classical X3DH.');
      return standardSecret;
    }

    // 2. Perform PQ Decapsulation (Kyber)
    List<int>? myPrivBytes;
    if (pqOpkId != null) {
      myPrivBytes = await _kyberKeys.getPQOTPreKeySecret(pqOpkId);
    }
    myPrivBytes ??= await _kyberKeys.getMyPQIdentitySecret();

    if (myPrivBytes == null) {
      debugPrint(
        '[HybridX3DH] Failed to find PQ private key for OPK $pqOpkId (or Identity).',
      );
      return null;
    }

    final isolatePayload = {
      'algName': _algName,
      'pqCtB64': pqCtB64,
      'myPrivBytes': myPrivBytes,
    };

    final sharedSecretPQ = await Isolate.run(() {
      final kem = KEM.create(isolatePayload['algName'] as String);
      try {
        final ss = kem.decapsulate(
          Uint8List.fromList(base64Decode(isolatePayload['pqCtB64'] as String)),
          Uint8List.fromList(isolatePayload['myPrivBytes'] as List<int>),
        );
        kem.dispose();
        return ss;
      } catch (e) {
        kem.dispose();
        return null; // Return null if decap fails
      }
    });

    if (sharedSecretPQ == null) {
      debugPrint('[HybridX3DH] Kyber decapsulate failed in Isolate');
      return null;
    }

    // 3. Combine output
    return await _deriveHybridSecret(standardSecret, sharedSecretPQ);
  }

  // ── HKDF Hybrid Derivation ─────────────────────────────────────────────────

  Future<List<int>> _deriveHybridSecret(
    List<int> standardSecret,
    List<int> pqSecret,
  ) async {
    // HKDF-SHA256 ( Classical || PQ )
    final combined = BytesBuilder();
    combined.add(standardSecret);
    combined.add(pqSecret);

    final hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);

    final output = await hkdf.deriveKey(
      secretKey: SecretKey(combined.toBytes()),
      info: utf8.encode('XPARQSignalHybrid'),
    );

    return await output.extractBytes();
  }
}
