import 'dart:convert';
import 'dart:math';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:crypto/crypto.dart';
import 'package:xparq_app/core/constants/app_constants.dart';

class DobEncryptionService {
  static const _storage = FlutterSecureStorage();

  static const _version = 'v1';

  /// 🔐 Retrieve or generate AES key
  static Future<enc.Key> _getOrCreateKey() async {
    String? storedKey =
        await _storage.read(key: AppConstants.dobEncryptionKeyName);

    if (storedKey == null) {
      final random = Random.secure();
      final keyBytes =
          List<int>.generate(32, (_) => random.nextInt(256));
      storedKey = base64Encode(keyBytes);

      await _storage.write(
        key: AppConstants.dobEncryptionKeyName,
        value: storedKey,
      );
    }

    return enc.Key(base64Decode(storedKey));
  }

  /// 🔐 Encrypt DOB → versioned + authenticated
  static Future<String> encrypt(DateTime dob) async {
    final key = await _getOrCreateKey();

    final iv = enc.IV.fromSecureRandom(16);
    final encrypter =
        enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));

    final dobString =
        '${dob.year.toString().padLeft(4, '0')}-'
        '${dob.month.toString().padLeft(2, '0')}-'
        '${dob.day.toString().padLeft(2, '0')}';

    final encrypted = encrypter.encrypt(dobString, iv: iv);

    // 🔐 HMAC (integrity protection)
    final hmac = Hmac(sha256, key.bytes);
    final mac = hmac.convert(
      utf8.encode('${iv.base64}:${encrypted.base64}'),
    );

    // 🔥 versioned format
    return '$_version:${iv.base64}:${encrypted.base64}:${base64Encode(mac.bytes)}';
  }

  /// 🔐 Safe decrypt (with integrity check)
  static Future<DateTime> decrypt(String encryptedDob) async {
    try {
      final key = await _getOrCreateKey();

      final parts = encryptedDob.split(':');

      if (parts.length != 4) {
        throw const FormatException('Invalid encrypted DOB format');
      }

      final version = parts[0];
      if (version != _version) {
        throw const FormatException('Unsupported encryption version');
      }

      final ivBase64 = parts[1];
      final cipherBase64 = parts[2];
      final macBase64 = parts[3];

      // 🔐 verify HMAC
      final hmac = Hmac(sha256, key.bytes);
      final expectedMac = hmac.convert(
        utf8.encode('$ivBase64:$cipherBase64'),
      );

      if (base64Encode(expectedMac.bytes) != macBase64) {
        throw const FormatException('Data integrity check failed');
      }

      final iv = enc.IV.fromBase64(ivBase64);
      final encrypter =
          enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));

      final decrypted =
          encrypter.decrypt64(cipherBase64, iv: iv);

      final dateParts = decrypted.split('-');

      return DateTime(
        int.parse(dateParts[0]),
        int.parse(dateParts[1]),
        int.parse(dateParts[2]),
      );
    } catch (e) {
      throw FormatException('Failed to decrypt DOB: $e');
    }
  }
}