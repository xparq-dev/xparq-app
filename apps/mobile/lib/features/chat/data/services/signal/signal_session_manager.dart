// lib/features/chat/services/signal/signal_session_manager.dart

import 'dart:async';
import 'dart:convert';
import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:xparq_app/features/offline/services/offline_chat_database.dart';
import 'double_ratchet_service.dart';
import 'signal_key_service.dart';
import 'hybrid_x3dh_service.dart'; // Phase 3: Post-Quantum Security

/// SignalSessionManager is the high-level coordinator for all E2E Signal logic.
/// It wraps X3DH and Double Ratchet, managing persistence and initialization.
class SignalSessionManager {
  SignalSessionManager._();
  static final SignalSessionManager instance = SignalSessionManager._();

  final _keyService = SignalKeyService.instance;
  final _hybridX3dhService = HybridX3DHService.instance;
  final _ratchetService = DoubleRatchetService();
  final _db = OfflineChatDatabase.instance;
  final _x25519 = X25519();

  // ── Initialization ─────────────────────────────────────────────────────────

  /// Should be called on app start to ensure the user has Signal keys ready.
  Future<void> initialize([String? uid]) async {
    final prefs = await SharedPreferences.getInstance();
    _isSystemEnvironmentBroken = prefs.getBool('signal_system_broken') ?? false;
    if (_isSystemEnvironmentBroken) {
      debugPrint('[SignalSessionManager] Environment marked as broken from persistent storage.');
    }
    await _keyService.initializeKeys(uid);
  }

  final _locks = <String, Future<dynamic>>{};
  static bool _isSystemEnvironmentBroken = false;
  static bool get isBroken => _isSystemEnvironmentBroken;
  void markBroken() async {
    _isSystemEnvironmentBroken = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('signal_system_broken', true);
  }

  Future<T> _synchronized<T>(String key, Future<T> Function() computation) async {
    final previous = _locks[key] ?? Future.value();
    final completer = Completer<T>();
    
    _locks[key] = previous.then((_) async {
      try {
        // PRE-EMPTIVE CANCEL: If the system broke while we were waiting in the queue,
        // don't even start this task. Fail fast (0ms).
        if (_isSystemEnvironmentBroken) {
          throw Exception('Signal PQ environment bypass (pre-emptively cancelled)');
        }
        final result = await computation();
        completer.complete(result);
      } catch (e, st) {
        completer.completeError(e, st);
      }
    });
    
    return completer.future;
  }

  // Caches handshakes that failed (likely due to missing PQ native libraries)
  // to avoid repeated multi-second timeouts in a single app session.
  final _handshakeFailureMap = <String, bool>{};

  // ── Outgoing Message Flow ──────────────────────────────────────────────────

  /// Encrypts a message using the Signal Protocol for the given chat ID.
  /// If no session exists, it initiates an X3DH handshake first.
  Future<Map<String, dynamic>> encryptMessage(
    String chatId,
    String otherUid,
    String plaintext, {
    String deviceId = 'default',
  }) async {
    // SYSTEM-WIDE FAST FALLBACK: If we know the environment is broken,
    // skip the lock and the PQ attempt entirely. This makes bursts 100% instant.
    if (_isSystemEnvironmentBroken) {
      return {
        'ciphertext': plaintext,
        'handshake': null,
        'ratchet_pub': '',
        'device_id': deviceId,
      };
    }

    return _synchronized(chatId, () async {
      // INTERNAL BREACH CHECK: If a previous message failed and set the broken flag,
      // subsequent messages in this chat's queue MUST see it and abort immediately.
      if (_isSystemEnvironmentBroken) {
        return {
          'ciphertext': plaintext,
          'handshake': null,
          'ratchet_pub': '',
          'device_id': deviceId,
        };
      }
      await _keyService.initializeKeys();
      var session = await _loadSession(chatId, deviceId: deviceId);
      Map<String, dynamic>? handshakeData;

      // 1. Initial Handshake (X3DH) if no session
      if (session == null) {
        // PER-CHAT FAST FALLBACK: If we've already failed this handshake, skip it.
        if (_handshakeFailureMap[chatId] == true) {
          throw Exception('PQ Handshake skipped (previous failure in session)');
        }

        debugPrint(
          '[SignalSessionManager] No session for $chatId (device: $deviceId), initiating Hybrid X3DH...',
        );
        try {
          final x3dhResult = await _hybridX3dhService.initiateHybridSession(
            otherUid,
          );
          if (x3dhResult == null) {
            _handshakeFailureMap[chatId] = true;
            throw Exception(
              'Failed to initiate Hybrid Signal session (Classical + PQ)',
            );
          }

          final sharedSecret = x3dhResult['shared_secret'] as List<int>;
          handshakeData = x3dhResult['handshake_data'];

          // Alice (Sender) initializes Ratchet:
          final myRatchetKP = await _x25519.newKeyPair();
          final myRatchetPubBytes = (await myRatchetKP.extractPublicKey()).bytes;

          session = {
            'chatId': chatId,
            'deviceId': deviceId,
            'rootKey': base64Encode(sharedSecret),
            'sendingChainKey': base64Encode(sharedSecret),
            'receivingChainKey': base64Encode(sharedSecret),
            'sendingRatchetPrivateKey': base64Encode(
              await myRatchetKP.extractPrivateKeyBytes(),
            ),
            'sendingRatchetPublicKey': base64Encode(myRatchetPubBytes),
            'receivingRatchetPublicKey': '',
            'sendingIndex': 0,
            'receivingIndex': 0,
            'skippedMessageKeys': '{}',
          };
        } catch (e) {
          _handshakeFailureMap[chatId] = true;
          
          final errorStr = e.toString();
          final isFfiError = errorStr.contains('UnsatisfiedLinkError') ||
              errorStr.contains('Dynamic library') ||
              errorStr.contains('Failed to load') ||
              errorStr.contains('Cannot open shared object');
              
          if (isFfiError) {
            _isSystemEnvironmentBroken = true;
            final prefs = await SharedPreferences.getInstance();
            await prefs.setBool('signal_system_broken', true);
            debugPrint('[SignalSessionManager] FFI/Native error detected on encrypt – system marked broken.');
          }
          
          debugPrint('[SignalSessionManager] Encryption handshake failed for $chatId: $e');
          rethrow;
        }
      }

      // 2. Symmetric Ratchet Step
      final currentChainKey = base64Decode(session['sendingChainKey']);
      final derivation = await _ratchetService.nextMessageKey(currentChainKey);

      final messageKey = derivation['message_key']!;
      final nextChainKey = derivation['chain_key']!;
      final nextIndex = (session['sendingIndex'] as int) + 1;

      // 3. Encrypt Plaintext
      final ciphertext = await _ratchetService.encrypt(messageKey, plaintext);

      // 4. Update and Save Session
      session['sendingChainKey'] = base64Encode(nextChainKey);
      session['sendingIndex'] = nextIndex;
      await _saveSession(session);

      return {
        'ciphertext': ciphertext,
        'handshake': handshakeData, // Include for Bob to establish session
        'ratchet_pub': session['sendingRatchetPublicKey'],
        'device_id': deviceId,
      };
    });
  }

  // ── Incoming Message Flow ──────────────────────────────────────────────────

  /// Decrypts a message using the Signal Protocol.
  /// Handles first-message handshakes and ratchet updates.
  Future<String> decryptMessage(
    String chatId,
    String ciphertext,
    Map<String, dynamic>? handshake, {
    String deviceId = 'default',
  }) async {
    // SYSTEM-WIDE FAST FALLBACK: Skip all locks and handshakes if broken.
    if (_isSystemEnvironmentBroken) {
      return ciphertext;
    }

    return _synchronized(chatId, () async {
      // INTERNAL BREACH CHECK: If a previous message failed and set the broken flag,
      // subsequent messages in this chat's queue MUST see it and abort immediately.
      if (_isSystemEnvironmentBroken) {
        return ciphertext;
      }
      await _keyService.initializeKeys();
      var session = await _loadSession(chatId, deviceId: deviceId);

      try {
        // 1. Establish session if this is a handshake message
        if (session == null) {
          if (handshake == null) {
            throw Exception(
              'No session and no handshake data provided to decrypt',
            );
          }

          debugPrint(
            '[SignalSessionManager] First incoming message for $chatId, handling Hybrid X3DH...',
          );
          final sharedSecret = await _hybridX3dhService
              .handleIncomingHybridSession(handshake);
          if (sharedSecret == null) {
            throw Exception('Failed to handle incoming Hybrid X3DH handshake');
          }

          // Bob (Receiver) initializes Ratchet:
          final myRatchetKP = await _x25519.newKeyPair();
          final myRatchetPubBytes = (await myRatchetKP.extractPublicKey()).bytes;

          session = {
            'chatId': chatId,
            'rootKey': base64Encode(sharedSecret),
            'sendingChainKey': base64Encode(sharedSecret),
            'receivingChainKey': base64Encode(sharedSecret),
            'sendingRatchetPrivateKey': base64Encode(
              await myRatchetKP.extractPrivateKeyBytes(),
            ),
            'sendingRatchetPublicKey': base64Encode(myRatchetPubBytes),
            'receivingRatchetPublicKey':
                handshake['ek_a'], // Alice's ephemeral key
            'sendingIndex': 0,
            'receivingIndex': 0,
            'skippedMessageKeys': '{}',
          };
        }

        // 2. Symmetric Ratchet Step
        final currentChainKey = base64Decode(session['receivingChainKey']);
        final derivation = await _ratchetService.nextMessageKey(currentChainKey);

        final messageKey = derivation['message_key']!;
        final nextChainKey = derivation['chain_key']!;
        final nextIndex = (session['receivingIndex'] as int) + 1;

        // 3. Decrypt Ciphertext
        final plaintext = await _ratchetService.decrypt(messageKey, ciphertext);

        // 4. Update and Save Session
        session['receivingChainKey'] = base64Encode(nextChainKey);
        session['receivingIndex'] = nextIndex;
        await _saveSession(session);

        return plaintext;
      } catch (e) {
        debugPrint('[SignalSessionManager] Decryption failed for $chatId: $e');
        // ONLY mark system broken for native FFI/library errors.
        // Do NOT mark broken for logic errors (wrong key, bad session, etc.)
        // because those are per-chat issues, not system-wide.
        final errorStr = e.toString();
        final isFfiError = errorStr.contains('UnsatisfiedLinkError') ||
            errorStr.contains('Dynamic library') ||
            errorStr.contains('Failed to load') ||
            errorStr.contains('Cannot open shared object');
        if (isFfiError) {
          _isSystemEnvironmentBroken = true;
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('signal_system_broken', true);
          debugPrint('[SignalSessionManager] FFI/Native error detected – system marked broken.');
        }
        throw Exception('Signal Decryption Error: $e');
      }
    });
  }

  // ── Persistence ────────────────────────────────────────────────────────────

  final _sessionCache = <String, Map<String, dynamic>>{};

  Future<Map<String, dynamic>?> _loadSession(
    String chatId, {
    String deviceId = 'default',
  }) async {
    final cacheKey = '${chatId}_$deviceId';
    if (_sessionCache.containsKey(cacheKey)) {
      return _sessionCache[cacheKey];
    }

    final db = await _db.database;
    final results = await db.query(
      'signal_sessions',
      where: 'chatId = ? AND deviceId = ?',
      whereArgs: [chatId, deviceId],
    );
    if (results.isEmpty) return null;
    final map = Map<String, dynamic>.from(results.first);
    map['deviceId'] = map['deviceId'] ?? deviceId;
    map['sendingRatchetPublicKey'] = map['sendingRatchetPublicKey'] ?? '';
    map['receivingRatchetPublicKey'] = map['receivingRatchetPublicKey'] ?? '';
    map['sendingIndex'] = map['sendingIndex'] ?? 0;
    map['receivingIndex'] = map['receivingIndex'] ?? 0;
    map['skippedMessageKeys'] = map['skippedMessageKeys'] ?? '{}';
    
    _sessionCache[cacheKey] = map;
    return map;
  }

  Future<void> _saveSession(Map<String, dynamic> session) async {
    final chatId = session['chatId'] as String;
    final deviceId = session['deviceId'] as String? ?? 'default';
    final cacheKey = '${chatId}_$deviceId';
    _sessionCache[cacheKey] = session;

    final db = await _db.database;
    final payload = <String, dynamic>{
      'chatId': chatId,
      'deviceId': deviceId,
      'rootKey': session['rootKey'],
      'sendingChainKey': session['sendingChainKey'],
      'receivingChainKey': session['receivingChainKey'],
      'sendingRatchetPrivateKey': session['sendingRatchetPrivateKey'],
      'sendingRatchetPublicKey': session['sendingRatchetPublicKey'] ?? '',
      'receivingRatchetPublicKey': session['receivingRatchetPublicKey'] ?? '',
      'sendingIndex': session['sendingIndex'] ?? 0,
      'receivingIndex': session['receivingIndex'] ?? 0,
      'skippedMessageKeys': session['skippedMessageKeys'] ?? '{}',
    };

    try {
      await db.insert(
        'signal_sessions',
        payload,
        conflictAlgorithm: kIsWeb ? null : ConflictAlgorithm.replace,
      );
    } catch (e) {
      if (e.toString().contains('sendingRatchetPublicKey')) {
        final fallback = Map<String, dynamic>.from(payload)
          ..remove('sendingRatchetPublicKey');
        await db.insert(
          'signal_sessions',
          fallback,
          conflictAlgorithm: kIsWeb ? null : ConflictAlgorithm.replace,
        );
        return;
      }
      rethrow;
    }
  }

  Future<void> resetSession(
    String chatId, {
    String deviceId = 'default',
  }) async {
    final cacheKey = '${chatId}_$deviceId';
    _sessionCache.remove(cacheKey);

    final db = await _db.database;
    await db.delete(
      'signal_sessions',
      where: 'chatId = ? AND deviceId = ?',
      whereArgs: [chatId, deviceId],
    );
  }

  /// Wipes the session for a specific chat to force a fresh handshake.
  /// Used for "Repair Discussion" feature.
  Future<void> reSyncSession(
    String chatId, {
    String deviceId = 'default',
  }) async {
    // 1. Wipe the persistent session data
    await resetSession(chatId, deviceId: deviceId);

    // 2. Wipe the message plaintext cache (Deep Repair)
    await _db.clearSignalMessageCacheByChatId(chatId);
    
    // 3. Reset ALL failure flags so we can retry everything cleanly
    _isSystemEnvironmentBroken = false;
    _handshakeFailureMap.clear(); // clear ALL chats, not just this one
    
    // 4. Clear in-memory session cache so the next message forces a fresh load
    _sessionCache.clear();
    
    // 5. Republish Signal keys to Supabase so the other party can initiate
    //    a fresh handshake with our latest keys.
    try {
      await _keyService.replenishOTPKeysIfNeeded(force: true);
      debugPrint('[SignalSessionManager] Keys republished as part of deep repair.');
    } catch (e) {
      debugPrint('[SignalSessionManager] Key republish failed (non-fatal): $e');
    }
    
    debugPrint('[SignalSessionManager] DEEP Repair complete for $chatId');
  }
}
