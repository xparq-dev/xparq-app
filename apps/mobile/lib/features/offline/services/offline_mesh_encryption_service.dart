import 'dart:convert';

import 'package:crypto/crypto.dart' as crypto;
import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class OfflineMeshEncryptionService {
  OfflineMeshEncryptionService._();

  static final OfflineMeshEncryptionService instance =
      OfflineMeshEncryptionService._();

  static const _privateKeyStorageKey = 'offline_mesh_x25519_private_key_v1';
  static const _publicKeyStorageKey = 'offline_mesh_x25519_public_key_v1';
  static const _hkdfInfo = 'xparq-offline-mesh-v1';

  final _storage = const FlutterSecureStorage();
  final _x25519 = X25519();
  final _aesGcm = AesGcm.with256bits();
  final _hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);

  Future<void> initializeIdentity() async {
    final hasPrivate = await _storage.containsKey(key: _privateKeyStorageKey);
    final hasPublic = await _storage.containsKey(key: _publicKeyStorageKey);
    if (hasPrivate && hasPublic) return;

    final keyPair = await _x25519.newKeyPair();
    final privateBytes = await keyPair.extractPrivateKeyBytes();
    final publicBytes = (await keyPair.extractPublicKey()).bytes;

    await _storage.write(
      key: _privateKeyStorageKey,
      value: base64Encode(privateBytes),
    );
    await _storage.write(
      key: _publicKeyStorageKey,
      value: base64Encode(publicBytes),
    );
  }

  Future<void> resetIdentity() async {
    await _storage.delete(key: _privateKeyStorageKey);
    await _storage.delete(key: _publicKeyStorageKey);
  }

  Future<String> getPublicKeyBase64() async {
    await initializeIdentity();
    return (await _storage.read(key: _publicKeyStorageKey)) ?? '';
  }

  String fingerprintFromPublicKey(String publicKeyBase64) {
    if (publicKeyBase64.trim().isEmpty) return 'Unavailable';
    final digest = crypto.sha256.convert(base64Decode(publicKeyBase64)).bytes;
    final hex =
        digest.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
    final shortHex = hex.substring(0, 32).toUpperCase();
    final groups = <String>[];
    for (var i = 0; i < shortHex.length; i += 4) {
      groups.add(shortHex.substring(i, i + 4));
    }
    return groups.join(' ');
  }

  Future<Map<String, String>> encryptForRecipient({
    required String plaintext,
    required String recipientPublicKeyBase64,
  }) async {
    await initializeIdentity();
    final myPublicKey = await getPublicKeyBase64();
    final secretKey = await _deriveSharedSecret(recipientPublicKeyBase64);
    final nonce = _aesGcm.newNonce();
    final secretBox = await _aesGcm.encrypt(
      utf8.encode(plaintext),
      secretKey: secretKey,
      nonce: nonce,
    );

    return {
      'ciphertext': base64Encode(secretBox.cipherText),
      'mac': base64Encode(secretBox.mac.bytes),
      'nonce': base64Encode(nonce),
      'senderPublicKey': myPublicKey,
    };
  }

  Future<String> decryptFromSender({
    required String ciphertextBase64,
    required String macBase64,
    required String nonceBase64,
    required String senderPublicKeyBase64,
  }) async {
    await initializeIdentity();
    final secretKey = await _deriveSharedSecret(senderPublicKeyBase64);
    final secretBox = SecretBox(
      base64Decode(ciphertextBase64),
      nonce: base64Decode(nonceBase64),
      mac: Mac(base64Decode(macBase64)),
    );
    final clearBytes = await _aesGcm.decrypt(
      secretBox,
      secretKey: secretKey,
    );
    return utf8.decode(clearBytes);
  }

  Future<SecretKey> _deriveSharedSecret(String remotePublicKeyBase64) async {
    final myKeyPair = await _getMyKeyPair();
    final remotePublicKey = SimplePublicKey(
      base64Decode(remotePublicKeyBase64),
      type: KeyPairType.x25519,
    );

    final sharedSecret = await _x25519.sharedSecretKey(
      keyPair: myKeyPair,
      remotePublicKey: remotePublicKey,
    );

    return _hkdf.deriveKey(
      secretKey: sharedSecret,
      nonce: const <int>[],
      info: utf8.encode(_hkdfInfo),
    );
  }

  Future<SimpleKeyPair> _getMyKeyPair() async {
    await initializeIdentity();
    final privateKey = await _storage.read(key: _privateKeyStorageKey);
    final publicKey = await _storage.read(key: _publicKeyStorageKey);

    return SimpleKeyPairData(
      base64Decode(privateKey ?? ''),
      publicKey: SimplePublicKey(
        base64Decode(publicKey ?? ''),
        type: KeyPairType.x25519,
      ),
      type: KeyPairType.x25519,
    );
  }
}
