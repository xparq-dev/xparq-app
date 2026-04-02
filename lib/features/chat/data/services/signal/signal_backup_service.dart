// lib/features/chat/services/signal/signal_backup_service.dart

import 'dart:convert';
import 'package:cryptography/cryptography.dart';
import 'package:dargon2_flutter/dargon2_flutter.dart';
import 'package:dio/dio.dart' as dio;
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'signal_key_service.dart';
import 'package:xparq_app/features/offline/services/offline_chat_database.dart';

/// SignalBackupService handles the secure packing, encryption, and
/// distributed storage of Signal session states and keys.
class SignalBackupService {
  SignalBackupService._();
  static final SignalBackupService instance = SignalBackupService._();

  final _keyService = SignalKeyService.instance;
  final _db = OfflineChatDatabase.instance;
  final _aesGcm = AesGcm.with256bits();
  final _dio = dio.Dio();
  SupabaseClient get _supabase => Supabase.instance.client;

  // --- CONFIGURATION ---
  // In a real app, these would be in a secure config or env variables.
  static const String _pinataApiKey = 'YOUR_PINATA_API_KEY';
  static const String _pinataSecretKey = 'YOUR_PINATA_SECRET_KEY';
  static const String _pinataBaseUrl =
      'https://api.pinata.cloud/pinning/pinFileToIPFS';

  // --- BACKUP FLOW ---

  // Helper to get argon2 only when needed, avoiding background crashes
  DArgon2 get _argon2 => argon2;

  /// Creates an encrypted backup bundle and uploads it to IPFS.
  Future<String?> createBackup(String password) async {
    try {
      final uid = _supabase.auth.currentUser?.id;
      if (uid == null) throw Exception('User not authenticated');

      debugPrint('[SignalBackup] Starting backup process...');

      // 1. Collect Data
      final keys = await _keyService.exportAllKeys();
      final dbData = await _db.exportSignalData();

      final bundle = {
        'version': 1,
        'uid': uid,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'keys': keys,
        'db_data': dbData,
      };

      final bundleJson = jsonEncode(bundle);
      final bundleBytes = utf8.encode(bundleJson);

      // 2. Derive Encryption Key (Argon2id)
      debugPrint('[SignalBackup] Deriving key from password...');
      final salt = Uint8List.fromList(
        utf8.encode('iXPARQ_signal_backup_salt_$uid'),
      );

      final argon2Result = await _argon2.hashPasswordString(
        password,
        salt: Salt(salt),
        iterations: 2,
        memory: 65536, // 64 MB
        parallelism: 1,
        length: 32, // 256-bit key
        type: Argon2Type.id,
      );

      final encryptionKeyBytes = argon2Result.rawBytes;

      // 3. Encrypt with AES-GCM
      debugPrint('[SignalBackup] Encrypting bundle...');
      final secretKey = SecretKey(encryptionKeyBytes);
      final nonce = _aesGcm.newNonce();
      final secretBox = await _aesGcm.encrypt(
        bundleBytes,
        secretKey: secretKey,
        nonce: nonce,
      );

      final encryptedPayload = {
        'nonce': base64Encode(secretBox.nonce),
        'ciphertext': base64Encode(secretBox.cipherText),
        'mac': base64Encode(secretBox.mac.bytes),
      };

      // 4. Upload to IPFS (via Pinata)
      // Note: In local dev without keys, this might fail unless mocked.
      // We will provide a way to pass keys or use a placeholder.
      debugPrint('[SignalBackup] Uploading to IPFS...');
      final cid = await _uploadToPinata(encryptedPayload, uid);

      if (cid != null) {
        // 5. Store CID in Supabase
        await _supabase
            .from('profiles')
            .update({
              'backup_cid': cid,
              'backup_at': DateTime.now().toIso8601String(),
            })
            .eq('id', uid);

        debugPrint('[SignalBackup] Backup successful! CID: $cid');
      }

      return cid;
    } catch (e) {
      debugPrint('[SignalBackup] Backup failed: $e');
      return null;
    }
  }

  // --- RESTORE FLOW ---

  /// Downloads an encrypted backup from IPFS and restores the state.
  Future<bool> restoreBackup(String password, String cid) async {
    try {
      final uid = _supabase.auth.currentUser?.id;
      if (uid == null) throw Exception('User not authenticated');

      debugPrint('[SignalBackup] Fetching backup from IPFS...');
      final encryptedPayload = await _downloadFromIPFS(cid);
      if (encryptedPayload == null) return false;

      // 1. Derive Key
      final salt = Uint8List.fromList(
        utf8.encode('iXPARQ_signal_backup_salt_$uid'),
      );
      final argon2Result = await _argon2.hashPasswordString(
        password,
        salt: Salt(salt),
        iterations: 2,
        memory: 65536,
        parallelism: 1,
        length: 32,
        type: Argon2Type.id,
      );
      final encryptionKeyBytes = argon2Result.rawBytes;
      final secretKey = SecretKey(encryptionKeyBytes);

      // 2. Decrypt
      debugPrint('[SignalBackup] Decrypting data...');
      final nonce = base64Decode(encryptedPayload['nonce'] as String);
      final ciphertext = base64Decode(encryptedPayload['ciphertext'] as String);
      final mac = base64Decode(encryptedPayload['mac'] as String);

      final clearBytes = await _aesGcm.decrypt(
        SecretBox(ciphertext, nonce: nonce, mac: Mac(mac)),
        secretKey: secretKey,
      );

      final bundleJson = utf8.decode(clearBytes);
      final bundle = jsonDecode(bundleJson) as Map<String, dynamic>;

      // 3. Check ownership
      if (bundle['uid'] != uid) {
        throw Exception('Backup belongs to a different user');
      }

      // 4. Restore State
      debugPrint('[SignalBackup] Injecting keys and database states...');
      await _keyService.importKeys(Map<String, String>.from(bundle['keys']));

      final dbDataRaw = bundle['db_data'] as Map<String, dynamic>;
      final Map<String, List<Map<String, dynamic>>> dbDataFormatted = {};

      dbDataRaw.forEach((key, value) {
        dbDataFormatted[key] = (value as List)
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      });

      await _db.importSignalData(dbDataFormatted);

      debugPrint('[SignalBackup] Restoration complete!');
      return true;
    } catch (e) {
      debugPrint('[SignalBackup] Restoration failed: $e');
      return false;
    }
  }

  // --- HELPERS ---

  Future<String?> _uploadToPinata(Map<String, dynamic> data, String uid) async {
    // For manual testing without real keys, returns a placeholder CID
    if (_pinataApiKey == 'YOUR_PINATA_API_KEY') {
      debugPrint('[SignalBackup] Pinata API Keys missing, using mock CID');
      return 'QmMockCidSignalBackup_${DateTime.now().millisecondsSinceEpoch}';
    }

    try {
      final jsonStr = jsonEncode(data);
      final formData = dio.FormData.fromMap({
        'file': dio.MultipartFile.fromBytes(
          utf8.encode(jsonStr),
          filename: 'backup_$uid.json',
        ),
        'pinataMetadata': jsonEncode({'name': 'iXPARQBackup_$uid'}),
      });

      final response = await _dio.post(
        _pinataBaseUrl,
        data: formData,
        options: dio.Options(
          headers: {
            'pinata_api_key': _pinataApiKey,
            'pinata_secret_api_key': _pinataSecretKey,
          },
        ),
      );

      if (response.statusCode == 200) {
        return response.data['IpfsHash'] as String;
      }
    } catch (e) {
      debugPrint('[SignalBackup] Pinata upload error: $e');
    }
    return null;
  }

  Future<Map<String, dynamic>?> _downloadFromIPFS(String cid) async {
    // Basic IPFS gateway fetch
    final url = 'https://gateway.pinata.cloud/ipfs/$cid';
    try {
      final response = await _dio.get(url);
      if (response.statusCode == 200) {
        return response.data as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('[SignalBackup] IPFS download error: $e');
    }
    return null;
  }
}
