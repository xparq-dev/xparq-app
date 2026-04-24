// lib/features/chat/services/signal/x3dh_service.dart

import 'dart:convert';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'signal_key_service.dart';

/// X3DHService implements the Extended Triple Diffie-Hellman handshake.
/// It establishes a shared secret between two users while providing
/// mutual authentication and forward secrecy for the handshake itself.
class X3DHService {
  X3DHService._();
  static final X3DHService instance = X3DHService._();

  final _x25519 = X25519();
  final _keyService = SignalKeyService.instance;

  // ── Session Initiation (Alice) ──────────────────────────────────────────────

  /// Initiates a session with Bob by fetching his bundle and performing X3DH.
  /// Returns the initial Shared Secret and the data Bob needs to complete the
  /// handshake (Alice's Identity Key, her Ephemeral Key, and which OPK was used).
  Future<Map<String, dynamic>?> initiateSession(String otherUid) async {
    final bundle = await _keyService.fetchBundle(otherUid);
    if (bundle == null) return null;

    // 1. My Keys
    final myIdentityKP = await _keyService.getMyIdentityKeyPair();
    // Alice generates her ephemeral key pair (EK_A) for X3DH.
    final myEphemeralKP = await _x25519.newKeyPair();
    final myEphemeralPub = await myEphemeralKP.extractPublicKey();

    // 2. Bob's Keys (from bundle)
    final bobIdentityPub = SimplePublicKey(
      base64Decode(bundle['identity_key']),
      type: KeyPairType.x25519,
    );
    final bobSPKPub = SimplePublicKey(
      base64Decode(bundle['signed_prekey']['public_key']),
      type: KeyPairType.x25519,
    );
    final bobOPKPub = bundle['one_time_prekey'] != null
        ? SimplePublicKey(
            base64Decode(bundle['one_time_prekey']['public_key']),
            type: KeyPairType.x25519,
          )
        : null;

    // 3. Perform DH Operations
    // DH1 = DH(IK_A, SPK_B)
    final dh1 = await _x25519.sharedSecretKey(
      keyPair: await _x25519.newKeyPairFromSeed(
        (await myIdentityKP.extractPrivateKeyBytes()),
      ),
      remotePublicKey: bobSPKPub,
    );
    // DH2 = DH(EK_A, IK_B)
    final dh2 = await _x25519.sharedSecretKey(
      keyPair: myEphemeralKP,
      remotePublicKey: bobIdentityPub,
    );
    // DH3 = DH(EK_A, SPK_B)
    final dh3 = await _x25519.sharedSecretKey(
      keyPair: myEphemeralKP,
      remotePublicKey: bobSPKPub,
    );

    SecretKey? dh4;
    if (bobOPKPub != null) {
      // DH4 = DH(EK_A, OPK_B)
      dh4 = await _x25519.sharedSecretKey(
        keyPair: myEphemeralKP,
        remotePublicKey: bobOPKPub,
      );
    }

    // 4. Derive Shared Secret via HKDF
    final sharedSecret = await _deriveInitialSecret(dh1, dh2, dh3, dh4);

    return {
      'shared_secret': sharedSecret,
      'handshake_data': {
        'ik_a': base64Encode((await myIdentityKP.extractPublicKey()).bytes),
        'ek_a': base64Encode(myEphemeralPub.bytes),
        'spk_id_b': bundle['signed_prekey']['id'],
        'opk_id_b': bundle['one_time_prekey']?['id'],
      },
    };
  }

  // ── Handling Incoming Session (Bob) ────────────────────────────────────────

  /// Bob handles the first message from Alice containing handshake data.
  Future<List<int>?> handleIncomingSession(
    Map<String, dynamic> handshakeData,
  ) async {
    try {
      // 1. My Keys
      final myIdentityKP = await _keyService.getMyIdentityKeyPair();
      final spkId = handshakeData['spk_id_b'] as int;
      debugPrint('[X3DHService] Handling handshake with SPK ID: $spkId');

      final mySPKKP = await _keyService.getSignedPreKeyPair(spkId);

      final opkId = handshakeData['opk_id_b'] as int?;
      SimpleKeyPair? myOPKKP;
      if (opkId != null) {
        myOPKKP = await _keyService.getOTPreKeyPair(opkId);
        if (myOPKKP == null) {
          debugPrint('[X3DHService] OPK $opkId not found in local storage.');
        }
      }

      // 2. Alice's Keys (from handshake data)
      final aliceIdentityPub = SimplePublicKey(
        base64Decode(handshakeData['ik_a']),
        type: KeyPairType.x25519,
      );
      final aliceEphemeralPub = SimplePublicKey(
        base64Decode(handshakeData['ek_a']),
        type: KeyPairType.x25519,
      );

      // 3. Perform DH Operations
      // DH1 = DH(SPK_B, IK_A)
      final dh1 = await _x25519.sharedSecretKey(
        keyPair: mySPKKP,
        remotePublicKey: aliceIdentityPub,
      );
      // DH2 = DH(IK_B, EK_A)
      final dh2 = await _x25519.sharedSecretKey(
        keyPair: await _x25519.newKeyPairFromSeed(
          (await myIdentityKP.extractPrivateKeyBytes()),
        ),
        remotePublicKey: aliceEphemeralPub,
      );
      // DH3 = DH(SPK_B, EK_A)
      final dh3 = await _x25519.sharedSecretKey(
        keyPair: mySPKKP,
        remotePublicKey: aliceEphemeralPub,
      );

      SecretKey? dh4;
      if (myOPKKP != null) {
        // DH4 = DH(OPK_B, EK_A)
        dh4 = await _x25519.sharedSecretKey(
          keyPair: myOPKKP,
          remotePublicKey: aliceEphemeralPub,
        );
      }

      // 4. Derive same Shared Secret
      return await _deriveInitialSecret(dh1, dh2, dh3, dh4);
    } catch (e) {
      debugPrint('[X3DHService] Error handling incoming session: $e');
      return null;
    }
  }

  // ── HKDF Derivation ────────────────────────────────────────────────────────

  Future<List<int>> _deriveInitialSecret(
    SecretKey dh1,
    SecretKey dh2,
    SecretKey dh3, [
    SecretKey? dh4,
  ]) async {
    final dh1Bytes = await dh1.extractBytes();
    final dh2Bytes = await dh2.extractBytes();
    final dh3Bytes = await dh3.extractBytes();
    final dh4Bytes = dh4 != null ? await dh4.extractBytes() : <int>[];

    // Combine DH outputs (KDF salt is fixed)
    final combined = BytesBuilder();
    combined.add(dh1Bytes);
    combined.add(dh2Bytes);
    combined.add(dh3Bytes);
    if (dh4Bytes.isNotEmpty) combined.add(dh4Bytes);

    // HKDF-SHA256
    final hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);

    final output = await hkdf.deriveKey(
      secretKey: SecretKey(combined.toBytes()),
      info: utf8.encode('XPARQSignalHandshake'),
    );

    return await output.extractBytes();
  }
}
