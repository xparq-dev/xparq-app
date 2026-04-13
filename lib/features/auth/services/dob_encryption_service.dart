// lib/features/auth/services/dob_encryption_service.dart
//
// Encrypts/decrypts the Date of Birth using AES-256-CBC.
// The encryption key is generated once and stored in Flutter Secure Storage.
// DOB is NEVER stored in plaintext or returned via any API.

import 'dart:convert';
import 'dart:math';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:xparq_app/shared/constants/app_constants.dart';

class DobEncryptionService {
  static const _storage = FlutterSecureStorage();

  /// Retrieve or generate the AES key for DOB encryption.
  static Future<enc.Key> _getOrCreateKey() async {
    String? storedKey = await _storage.read(
      key: AppConstants.dobEncryptionKeyName,
    );
    if (storedKey == null) {
      // Generate a new 256-bit (32-byte) random key
      final random = Random.secure();
      final keyBytes = List<int>.generate(32, (_) => random.nextInt(256));
      storedKey = base64Encode(keyBytes);
      await _storage.write(
        key: AppConstants.dobEncryptionKeyName,
        value: storedKey,
      );
    }
    return enc.Key(base64Decode(storedKey));
  }

  /// Encrypt a [DateTime] DOB to a base64 string.
  /// Format stored: "YYYY-MM-DD" (ISO 8601 date only)
  static Future<String> encrypt(DateTime dob) async {
    final key = await _getOrCreateKey();
    final iv = enc.IV.fromSecureRandom(16);
    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));

    final dobString =
        '${dob.year.toString().padLeft(4, '0')}-'
        '${dob.month.toString().padLeft(2, '0')}-'
        '${dob.day.toString().padLeft(2, '0')}';

    final encrypted = encrypter.encrypt(dobString, iv: iv);
    // Store IV + ciphertext together: base64(iv):base64(ciphertext)
    return '${iv.base64}:${encrypted.base64}';
  }

  /// Decrypt a base64 string back to a [DateTime].
  static Future<DateTime> decrypt(String encryptedDob) async {
    final key = await _getOrCreateKey();
    final parts = encryptedDob.split(':');
    if (parts.length != 2) {
      throw const FormatException('Invalid encrypted DOB format');
    }

    final iv = enc.IV.fromBase64(parts[0]);
    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
    final decrypted = encrypter.decrypt64(parts[1], iv: iv);

    final dateParts = decrypted.split('-');
    return DateTime(
      int.parse(dateParts[0]),
      int.parse(dateParts[1]),
      int.parse(dateParts[2]),
    );
  }
}
