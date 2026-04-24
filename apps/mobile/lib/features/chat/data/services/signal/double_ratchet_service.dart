import 'dart:convert';
import 'package:cryptography/cryptography.dart';

/// DoubleRatchetService implements the Signal Double Ratchet algorithm.
/// It ensures that every message has a unique key and provides
/// both Forward Secrecy and Post-Compromise Security.
class DoubleRatchetService {
  final _x25519 = X25519();
  final _hmac = Hmac.sha256();

  // ── Types ──────────────────────────────────────────────────────────────────

  // Chain Key: Used to derive message keys
  // Root Key: Used to derive new Chain Keys during DH ratchet steps

  // ── Ratchet Logic ──────────────────────────────────────────────────────────

  /// Derives the next Chain Key and a Message Key from the current Chain Key.
  /// (Symmetric Ratchet step)
  Future<Map<String, List<int>>> nextMessageKey(List<int> chainKey) async {
    // Message Key = HMAC(ChainKey, 0x01)
    // Next Chain Key = HMAC(ChainKey, 0x02)
    final messageKey = await _hmac.calculateMac([
      0x01,
    ], secretKey: SecretKey(chainKey));
    final nextChainKey = await _hmac.calculateMac([
      0x02,
    ], secretKey: SecretKey(chainKey));

    return {'message_key': messageKey.bytes, 'chain_key': nextChainKey.bytes};
  }

  /// Performs a DH Ratchet step to derive a new Root Key and Chain Key.
  /// (Diffie-Hellman Ratchet step)
  Future<Map<String, List<int>>> dhRatchetStep({
    required List<int> rootKey,
    required SimpleKeyPair myRatchetKeyPair,
    required SimplePublicKey remoteRatchetPublicKey,
  }) async {
    // 1. Compute DH shared secret
    final dhOutput = await _x25519.sharedSecretKey(
      keyPair: myRatchetKeyPair,
      remotePublicKey: remoteRatchetPublicKey,
    );
    final dhBytes = await dhOutput.extractBytes();

    // 2. KDF (HKDF-SHA256)
    // RootKey acts as the HKDF Salt, dhBytes as the IKM
    final hkdf = Hkdf(
      hmac: _hmac,
      outputLength: 64, // 32 for new Root Key, 32 for new Chain Key
    );

    final derived = await hkdf.deriveKey(
      secretKey: SecretKey(dhBytes),
      nonce: rootKey,
      info: utf8.encode('iXPARQSignalRatchet'),
    );
    final derivedBytes = await derived.extractBytes();

    return {
      'root_key': derivedBytes.sublist(0, 32),
      'chain_key': derivedBytes.sublist(32, 64),
    };
  }

  // ── Encryption/Decryption ──────────────────────────────────────────────────

  Future<String> encrypt(List<int> messageKey, String plaintext) async {
    // Use AES-256-GCM or CBC for message encryption
    // Here we use the existing AES-256-CBC logic via the 'encrypt' package
    // but with the per-message key from the ratchet.

    final aes = AesCbc.with256bits(macAlgorithm: MacAlgorithm.empty);
    final nonce = aes.newNonce();

    final secretBox = await aes.encrypt(
      utf8.encode(plaintext),
      secretKey: SecretKey(messageKey),
      nonce: nonce,
    );

    // Format: base64(nonce) + ":" + base64(ciphertext)
    return '${base64Encode(nonce)}:${base64Encode(secretBox.cipherText)}';
  }

  Future<String> decrypt(List<int> messageKey, String encrypted) async {
    final parts = encrypted.split(':');
    if (parts.length != 2) throw Exception('Invalid encrypted format');

    final nonce = base64Decode(parts[0]);
    final cipherText = base64Decode(parts[1]);

    final aes = AesCbc.with256bits(macAlgorithm: MacAlgorithm.empty);
    final decrypted = await aes.decrypt(
      SecretBox(cipherText, nonce: nonce, mac: Mac.empty),
      secretKey: SecretKey(messageKey),
    );

    return utf8.decode(decrypted);
  }
}
