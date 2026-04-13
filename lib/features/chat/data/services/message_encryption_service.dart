// lib/features/chat/data/services/message_encryption_service.dart

import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:xparq_app/shared/constants/app_constants.dart';
import 'package:xparq_app/shared/services/device_service.dart';
import 'package:xparq_app/features/auth/repositories/devices_repository.dart';
import 'package:xparq_app/features/chat/data/services/signal/signal_session_manager.dart';

/// MessageEncryptionService acts as a bridge between legacy encryption
/// and the new Signal Protocol (Phase 2).
class MessageEncryptionService {
  MessageEncryptionService._();

  static const int _maxLocalPlainCache = 500;
  static final Map<String, String> _localPlainCache = <String, String>{};
  static const int _maxPendingPlainCache = 200;
  static final Map<String, String> _pendingPlainCache = <String, String>{};
  static const int _maxSignalCipherPlainCache = 500;
  static final Map<String, String> _signalCipherPlainCache = <String, String>{};

  // Device Cache to reduce latency on send
  static final Map<String, List<Map<String, dynamic>>> _deviceCache = {};
  static final Map<String, DateTime> _deviceCacheExpiry = {};
  static const Duration _deviceCacheTTL = Duration(minutes: 5);

  static void _rememberPlaintext(String ciphertext, String plaintext) {
    if (ciphertext.trim().isEmpty || plaintext.trim().isEmpty) return;
    if (_localPlainCache.length >= _maxLocalPlainCache) {
      final firstKey = _localPlainCache.keys.first;
      _localPlainCache.remove(firstKey);
    }
    _localPlainCache[ciphertext] = plaintext;
  }

  static void _rememberSignalCiphertextPlaintext(
    String signalCiphertext,
    String plaintext,
  ) {
    if (signalCiphertext.trim().isEmpty || plaintext.trim().isEmpty) return;
    if (_signalCipherPlainCache.length >= _maxSignalCipherPlainCache) {
      final firstKey = _signalCipherPlainCache.keys.first;
      _signalCipherPlainCache.remove(firstKey);
    }
    _signalCipherPlainCache[signalCiphertext] = plaintext;
  }

  static void rememberPendingPlaintext(String pendingId, String plaintext) {
    if (pendingId.trim().isEmpty || plaintext.trim().isEmpty) return;
    if (_pendingPlainCache.length >= _maxPendingPlainCache) {
      final firstKey = _pendingPlainCache.keys.first;
      _pendingPlainCache.remove(firstKey);
    }
    _pendingPlainCache[pendingId] = plaintext;
  }

  static String? readPendingPlaintext(String pendingId) {
    if (pendingId.trim().isEmpty) return null;
    return _pendingPlainCache[pendingId];
  }

  /// Clears in-memory caches for a specific message.
  /// Used after an edit or recall to ensure the UI doesn't show stale plaintext.
  static void forgetMetadata({String? pendingId, String? ciphertext}) {
    if (pendingId != null) {
      _pendingPlainCache.remove(pendingId);
    }
    if (ciphertext != null) {
      _localPlainCache.remove(ciphertext);
      
      // Also try to reach into the v2/v3 inner-payload cache if applicable
      try {
        if (ciphertext.startsWith('{') && ciphertext.endsWith('}')) {
          final data = jsonDecode(ciphertext);
          if (data is Map) {
             if (data['v'] == 3) {
               final targets = data['targets'] as Map?;
               targets?.values.forEach((v) {
                 if (v is Map && v['ciphertext'] != null) {
                   _signalCipherPlainCache.remove(v['ciphertext']);
                 }
               });
             } else if (data['v'] == 2) {
               _signalCipherPlainCache.remove(data['ciphertext']);
             }
          }
        }
      } catch (_) {}
    }
  }

  static void rememberCiphertextPlaintext(String ciphertext, String plaintext) {
    _rememberPlaintext(ciphertext, plaintext);
  }

  static String? resolveOutgoingPlaintext({
    required String ciphertext,
    String? pendingId,
  }) {
    if (pendingId != null && pendingId.trim().isNotEmpty) {
      final pending = _pendingPlainCache[pendingId];
      if (pending != null) return pending;
    }

    final direct = _localPlainCache[ciphertext];
    if (direct != null) return direct;

    if (!ciphertext.startsWith('{') || !ciphertext.endsWith('}')) {
      return null;
    }

    try {
      final data = jsonDecode(ciphertext);
      if (data is Map && data['v'] == 2) {
        final innerCipher = data['ciphertext'];
        if (innerCipher is String) {
          return _signalCipherPlainCache[innerCipher];
        }
      }
    } catch (_) {}

    return null;
  }

  // ── Key Derivation (Legacy v1) ─────────────────────────────────────────────

  static enc.Key _deriveKey(String chatId) {
    final secretBytes = utf8.encode(AppConstants.chatMasterSecret);
    final chatIdBytes = utf8.encode(chatId);
    final hmac = Hmac(sha256, secretBytes);
    final hmacDigest = hmac.convert(chatIdBytes);
    return enc.Key(Uint8List.fromList(hmacDigest.bytes));
  }

  // ── Encrypt (Signal v2) ───────────────────────────────────────────────────

  /// Encrypts plaintext for the given chat using the Signal Protocol (v2).
  /// Multi-device sync: Encrypts for all devices of the recipient and
  /// all OTHER devices of the sender.
  static Future<String> encrypt(
    String plaintext,
    String chatId,
    String otherUid,
  ) async {
    if (plaintext.trim().isEmpty) return plaintext;

    try {
      final devicesRepo = DevicesRepository();
      final myUid = Supabase.instance.client.auth.currentUser?.id;

      // 1. Fetch devices for both recipient and sender (with caching)
      List<Map<String, dynamic>> recipientDevices;
      final now = DateTime.now();

      if (_deviceCache.containsKey(otherUid) &&
          _deviceCacheExpiry[otherUid]!.isAfter(now)) {
        recipientDevices = _deviceCache[otherUid]!;
      } else {
        recipientDevices = await devicesRepo.getUserDevices(otherUid);
        _deviceCache[otherUid] = recipientDevices;
        _deviceCacheExpiry[otherUid] = now.add(_deviceCacheTTL);
      }

      List<Map<String, dynamic>> myOtherDevices;
      const myCacheKey = 'self_others';
      if (_deviceCache.containsKey(myCacheKey) &&
          _deviceCacheExpiry[myCacheKey]!.isAfter(now)) {
        myOtherDevices = _deviceCache[myCacheKey]!;
      } else {
        myOtherDevices = await devicesRepo.getMyOtherDevices();
        _deviceCache[myCacheKey] = myOtherDevices;
        _deviceCacheExpiry[myCacheKey] = now.add(_deviceCacheTTL);
      }

      final targetDevices = [
        ...recipientDevices.map(
          (d) => {'uid': otherUid, 'deviceId': d['device_id']},
        ),
        ...myOtherDevices.map(
          (d) => {'uid': myUid, 'deviceId': d['device_id']},
        ),
      ];

      // If no other devices found (and no recipient devices?),
      // fallback to 'default' to stay compatible with existing logic.
      if (targetDevices.isEmpty) {
        targetDevices.add({'uid': otherUid, 'deviceId': 'default'});
      }

      final Map<String, dynamic> multiDevicePayload = {};

      for (final target in targetDevices) {
        final targetUid = target['uid'] as String;
        final targetDeviceId = target['deviceId'] as String;

        // Note: For encryption, we still use the same chatId (uid1:uid2)
        // but we index it by deviceId in SignalSessionManager.
        final result = await SignalSessionManager.instance.encryptMessage(
          chatId,
          targetUid,
          plaintext,
          deviceId: targetDeviceId,
        );

        multiDevicePayload[targetDeviceId] = {
          'ciphertext': result['ciphertext'],
          'handshake': result['handshake'],
          'ratchet_pub': result['ratchet_pub'],
        };
      }

      final payload = jsonEncode({
        'v': 3, // Version 3 for multi-device support
        'targets': multiDevicePayload,
      });

      _rememberPlaintext(payload, plaintext);
      return payload;
    } catch (e) {
      debugPrint(
        '[SignalBridge] Multi-device encryption failed, falling back to v1: $e',
      );
      final legacy = _encryptLegacy(plaintext, chatId);
      _rememberPlaintext(legacy, plaintext);
      return legacy;
    }
  }

  static String _encryptLegacy(String plaintext, String chatId) {
    final key = _deriveKey(chatId);
    final iv = enc.IV.fromSecureRandom(16);
    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
    final encrypted = encrypter.encrypt(plaintext, iv: iv);
    return '${iv.base64}:${encrypted.base64}';
  }

  // ── Decrypt (v2 + v1 Support) ──────────────────────────────────────────────

  /// Decrypts content using high-level logic (Signal v2 -> Legacy v1 fallback).
  static Future<String> decrypt(String ciphertext, String chatId) async {
    if (ciphertext.trim().isEmpty) return ciphertext;
    final cached = _localPlainCache[ciphertext];
    if (cached != null) return cached;

    try {
      // 1. Try Signal v3 (Multi-Device)
      if (ciphertext.startsWith('{') && ciphertext.endsWith('}')) {
        final data = jsonDecode(ciphertext);

        // Multi-device version (v3)
        if (data is Map && data['v'] == 3) {
          final targets = data['targets'] as Map<String, dynamic>?;
          if (targets == null) throw Exception('Malformed v3 payload');

          final myDeviceId = await DeviceService.instance.getDeviceId();

          // Find the payload targeted for THIS device
          Map<String, dynamic>? myPayload = targets[myDeviceId];

          // Fallback 1: 'default' payload (from older or single-device senders)
          myPayload ??= targets['default'];

          // Fallback 2: If there's only ONE target slot and deviceId mismatched,
          // it's likely the same device with a slightly different ID. Use it.
          if (myPayload == null && targets.length == 1) {
            myPayload = targets.values.first as Map<String, dynamic>?;
            debugPrint('[MessageEncryptionService] deviceId mismatch – using only available target as fallback.');
          }

          if (myPayload == null) {
            return '🔒 ข้อความถูกเข้ารหัสสำหรับอุปกรณ์อื่น กด "Repair Discussion" แล้วให้เพื่อนส่งข้อความใหม่';
          }

          final innerCipher = myPayload['ciphertext'] as String?;
          final handshake = myPayload['handshake'] as Map<String, dynamic>?;

          if (innerCipher != null && innerCipher.isNotEmpty) {
            final localKnown = _signalCipherPlainCache[innerCipher];
            if (localKnown != null) {
              _rememberPlaintext(ciphertext, localKnown);
              return localKnown;
            }
          }

          String plaintext;
          try {
            plaintext = await SignalSessionManager.instance.decryptMessage(
              chatId,
              innerCipher!,
              handshake,
              deviceId: myDeviceId,
            );
          } catch (_) {
            await SignalSessionManager.instance.resetSession(
              chatId,
              deviceId: myDeviceId,
            );
            plaintext = await SignalSessionManager.instance.decryptMessage(
              chatId,
              innerCipher!,
              handshake,
              deviceId: myDeviceId,
            );
          }

          if (innerCipher.isNotEmpty) {
            _rememberSignalCiphertextPlaintext(innerCipher, plaintext);
          }
          _rememberPlaintext(ciphertext, plaintext);
          return plaintext;
        }

        // Support Legacy Signal v2 (Single Device)
        if (data is Map && data['v'] == 2) {
          final innerCipher = data['ciphertext'] as String?;
          final handshake = data['handshake'] as Map<String, dynamic>?;

          String plaintext;
          try {
            plaintext = await SignalSessionManager.instance.decryptMessage(
              chatId,
              innerCipher!,
              handshake,
              deviceId: 'default',
            );
          } catch (_) {
            await SignalSessionManager.instance.resetSession(
              chatId,
              deviceId: 'default',
            );
            plaintext = await SignalSessionManager.instance.decryptMessage(
              chatId,
              innerCipher!,
              handshake,
              deviceId: 'default',
            );
          }
          if (innerCipher.isNotEmpty) {
            _rememberSignalCiphertextPlaintext(innerCipher, plaintext);
          }
          _rememberPlaintext(ciphertext, plaintext);
          return plaintext;
        }
      }

      // 2. Fallback to Legacy v1
      final plaintext = _decryptLegacy(ciphertext, chatId);
      if (plaintext != ciphertext) {
        _rememberPlaintext(ciphertext, plaintext);
      }
      return plaintext;
    } catch (e) {
      debugPrint(
        '[MessageEncryptionService] Decryption failed for Chat $chatId: $e',
      );

      // If all fails, avoid leaking raw v2/v3 payload JSON in UI.
      if (ciphertext.startsWith('{') && ciphertext.endsWith('}')) {
        return '🔒 Encrypted message (Sync Error). Tap menu and select "Repair Discussion" to fix.';
      }
      return '🔒 รูปแบบข้อความไม่รู้จัก';
    }
  }

  static String _decryptLegacy(String ciphertext, String chatId) {
    try {
      final parts = ciphertext.split(':');
      if (parts.length != 2) return ciphertext;
      final key = _deriveKey(chatId);
      final iv = enc.IV(Uint8List.fromList(base64Decode(parts[0])));
      final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
      return encrypter.decrypt64(parts[1], iv: iv);
    } catch (_) {
      return ciphertext;
    }
  }

  // ── Decrypt List (Batch Optimization) ──────────────────────────────────────

  static Future<List<String>> decryptList(
    List<String> ciphertexts,
    String chatId,
  ) async {
    // Decrypting Signal messages involves state updates (Double Ratchet),
    // so batching must be sequential.
    final list = <String>[];
    for (final c in ciphertexts) {
      list.add(await decrypt(c, chatId));
    }
    return list;
  }
}
