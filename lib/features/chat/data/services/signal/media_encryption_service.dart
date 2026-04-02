// lib/features/chat/services/signal/media_encryption_service.dart

import 'dart:io';
import 'dart:math';
import 'dart:isolate';
import 'package:cryptography/cryptography.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class MediaEncryptionService {
  MediaEncryptionService._();
  static final instance = MediaEncryptionService._();

  /// Generates a random 32-byte key for media encryption
  List<int> generateMediaKey() {
    final random = Random.secure();
    return List<int>.generate(32, (_) => random.nextInt(256));
  }

  /// Encrypts a file using AES-256-GCM.
  /// Returns the path to the newly created encrypted file.
  /// The operation runs in an Isolate to prevent blocking the UI.
  Future<File> encryptFile(File inputFile, List<int> keyBytes) async {
    final tempDir = await getTemporaryDirectory();
    final ext = p.extension(inputFile.path);
    final outputFileName =
        'encrypted_${DateTime.now().millisecondsSinceEpoch}$ext.enc';
    final outputPath = p.join(tempDir.path, outputFileName);

    return await Isolate.run(() async {
      final inputBytes = await inputFile.readAsBytes();

      final cipher = AesGcm.with256bits();
      final secretKey = SecretKey(keyBytes);
      final nonce = cipher.newNonce();

      final secretBox = await cipher.encrypt(
        inputBytes,
        secretKey: secretKey,
        nonce: nonce,
      );

      // We prefix the ciphertext with the 12-byte nonce
      final combinedBytes = [
        ...nonce,
        ...secretBox.cipherText,
        ...secretBox.mac.bytes,
      ];

      final outputFile = File(outputPath);
      await outputFile.writeAsBytes(combinedBytes);

      return outputFile;
    });
  }

  /// Decrypts an encrypted file using the provided media key.
  /// Returns the path to the decrypted temporary file.
  Future<File> decryptFile(
    File encryptedFile,
    List<int> keyBytes,
    String originalExtension,
  ) async {
    final tempDir = await getTemporaryDirectory();
    final outputFileName =
        'decrypted_${DateTime.now().millisecondsSinceEpoch}$originalExtension';
    final outputPath = p.join(tempDir.path, outputFileName);

    return await Isolate.run(() async {
      final encryptedBytes = await encryptedFile.readAsBytes();

      if (encryptedBytes.length < 28) {
        // 12 (nonce) + 16 (mac)
        throw Exception('File is too small to be a valid encrypted payload');
      }

      final cipher = AesGcm.with256bits();
      final secretKey = SecretKey(keyBytes);

      // Extract nonce, ciphertext, and mac
      final nonce = encryptedBytes.sublist(0, 12);
      final macBytes = encryptedBytes.sublist(encryptedBytes.length - 16);
      final ciphertext = encryptedBytes.sublist(12, encryptedBytes.length - 16);

      final secretBox = SecretBox(ciphertext, nonce: nonce, mac: Mac(macBytes));

      final decryptedBytes = await cipher.decrypt(
        secretBox,
        secretKey: secretKey,
      );

      final outputFile = File(outputPath);
      await outputFile.writeAsBytes(decryptedBytes);

      return outputFile;
    });
  }
}
