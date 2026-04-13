// lib/features/chat/services/signal/signal_key_service.dart

import 'dart:convert';
import 'dart:isolate';
import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:xparq_app/shared/services/device_service.dart';
import 'package:xparq_app/features/auth/repositories/devices_repository.dart';
import 'package:xparq_app/features/offline/services/offline_chat_database.dart';

/// SignalKeyService handles the generation, storage, and publication of
/// Curve25519 (X25519) and Ed25519 keys required for the Signal Protocol.
///
/// Private keys are stored securely using `flutter_secure_storage`.
/// Public keys are published to the Supabase backend.
class SignalKeyService {
  SignalKeyService._();
  static final SignalKeyService instance = SignalKeyService._();

  final _storage = const FlutterSecureStorage();
  SupabaseClient get _supabase => Supabase.instance.client;

  // Algorithms
  final _x25519 = X25519();
  final _ed25519 = Ed25519();

  // Storage Keys
  static const _kIdentityPriv = 'signal_identity_private_key';
  static const _kIdentityPub = 'signal_identity_public_key';
  static const _kIdentityKeyVersion = 'signal_identity_key_version';
  static const _kSigningPriv = 'signal_signing_private_key';
  static const _kSigningPub = 'signal_signing_public_key';
  static const _kSignedPreKeyPriv = 'signal_signed_prekey_private_';
  static const _kSignedPreKeyPub = 'signal_signed_prekey_public_';
  static const _kLastSignedPreKeyId = 'signal_last_signed_prekey_id';
  static const _currentIdentityKeyVersion = '2';

  // ── Initialization ─────────────────────────────────────────────────────────

  /// Checks if the user has an identity key. If not, generates and publishes
  /// a full set of initial keys (Identity, Signed PreKey, and 100 One-Time PreKeys).
  Future<void> initializeKeys([String? uidArg]) async {
    final uid = uidArg ?? _supabase.auth.currentUser?.id;
    if (uid == null) return;

    // Detect if this is a fresh install (since iOS KeyChain survives uninstalls)
    final prefs = await SharedPreferences.getInstance();
    final isFirstRun = prefs.getBool('is_first_run_after_install_$uid') ?? true;
    if (isFirstRun) {
      debugPrint(
        '[SignalKeyService] Fresh install detected. Wiping survivor KeyChain data.',
      );
      await _storage.deleteAll();
      await DeviceService.instance.clearCache();
      await DevicesRepository().deleteAllUserDevices();
      await prefs.setBool('is_first_run_after_install_$uid', false);
    }

    final hasIdentity = await _storage.containsKey(key: _kIdentityPriv);
    final identityVersion = await _storage.read(key: _kIdentityKeyVersion);
    if (!hasIdentity || identityVersion != _currentIdentityKeyVersion) {
      debugPrint('[SignalKeyService] First time initialization for user: $uid');
      await _generateAndPublishFullSet(uid);
    } else {
      debugPrint('[SignalKeyService] Keys already initialized.');
    }

    // Always ensure the device is registered in the devices table (Phase 5)
    try {
      await DevicesRepository().registerCurrentDevice();
    } catch (e) {
      debugPrint('[SignalKeyService] Failed to register device: $e');
    }
  }

  // ── Key Generation & Publication ───────────────────────────────────────────

  Future<void> _generateAndPublishFullSet(String uid) async {
    await OfflineChatDatabase.instance.clearSignalSessions();

    // X3DH requires a Curve25519 identity key for DH.
    final identityKeyPair = await _x25519.newKeyPair();
    final identityPub = await identityKeyPair.extractPublicKey();
    final identityPriv = await identityKeyPair.extractPrivateKeyBytes();

    // Keep a separate Ed25519 signing key for SPK signatures.
    final signingKeyPair = await _ed25519.newKeyPair();
    final signingPub = await signingKeyPair.extractPublicKey();
    final signingPriv = await signingKeyPair.extractPrivateKeyBytes();

    // 2. Initial Signed PreKey (SPK)
    final now = DateTime.now();
    final spkId = now.millisecondsSinceEpoch;
    final spkKeyPair = await _x25519.newKeyPair();
    final spkPub = await spkKeyPair.extractPublicKey();
    final spkPriv = await spkKeyPair.extractPrivateKeyBytes();

    // Sign SPK public key with the dedicated signing key.
    final signature = await _ed25519.sign(
      spkPub.bytes,
      keyPair: signingKeyPair,
    );

    // 3. One-Time PreKeys (OPK) - Generate 100
    final opks = <Map<String, dynamic>>[];
    final opkPrivates = <int, List<int>>{};
    final opkBaseId = now.microsecondsSinceEpoch;

    final isolateData = await Isolate.run(() async {
      final x25519 = X25519();
      final results = <({int keyId, List<int> pubBytes, List<int> privBytes})>[];
      for (var i = 1; i <= 100; i++) {
        final keyPair = await x25519.newKeyPair();
        final pub = await keyPair.extractPublicKey();
        final priv = await keyPair.extractPrivateKeyBytes();
        results.add((keyId: opkBaseId + i, pubBytes: pub.bytes, privBytes: priv));
      }
      return results;
    });

    for (final res in isolateData) {
      opks.add({
        'uid': uid,
        'key_id': res.keyId,
        'public_key': base64Encode(res.pubBytes),
      });
      opkPrivates[res.keyId] = res.privBytes;
    }

    // --- Save Privates Locally ---
    await _storage.write(
      key: _kIdentityPriv,
      value: base64Encode(identityPriv),
    );
    await _storage.write(
      key: _kIdentityPub,
      value: base64Encode(identityPub.bytes),
    );
    await _storage.write(key: _kSigningPriv, value: base64Encode(signingPriv));
    await _storage.write(
      key: _kSigningPub,
      value: base64Encode(signingPub.bytes),
    );
    await _storage.write(
      key: _kIdentityKeyVersion,
      value: _currentIdentityKeyVersion,
    );

    await _storage.write(
      key: '$_kSignedPreKeyPriv$spkId',
      value: base64Encode(spkPriv),
    );
    await _storage.write(
      key: '$_kSignedPreKeyPub$spkId',
      value: base64Encode(spkPub.bytes),
    );
    await _storage.write(key: _kLastSignedPreKeyId, value: spkId.toString());

    for (var entry in opkPrivates.entries) {
      await _storage.write(
        key: 'signal_opk_private_${entry.key}',
        value: base64Encode(entry.value),
      );
    }

    // --- Publish Publics to Supabase ---
    // Purge old keys from previous installations/sessions to prevent
    // senders from picking a stale prekey that we no longer have private keys for.
    await _supabase.from('signal_identity_keys').delete().eq('uid', uid);
    await _supabase.from('signal_signed_prekeys').delete().eq('uid', uid);
    await _supabase.from('signal_ot_prekeys').delete().eq('uid', uid);

    await _supabase.from('signal_identity_keys').upsert({
      'uid': uid,
      'public_key': base64Encode(identityPub.bytes),
    });

    await _supabase.from('signal_signed_prekeys').upsert({
      'uid': uid,
      'key_id': spkId,
      'public_key': base64Encode(spkPub.bytes),
      'signature': base64Encode(signature.bytes),
      'created_at': now.toIso8601String(),
    });

    await _supabase.from('signal_ot_prekeys').upsert(opks);

    debugPrint('[SignalKeyService] Published initial keys to Supabase.');
  }

  // ── Retrieval ──────────────────────────────────────────────────────────────

  /// Fetches the "Signal Bundle" for a recipient from Supabase.
  /// Needed to initiate an X3DH handshake.
  Future<Map<String, dynamic>?> fetchBundle(String otherUid) async {
    try {
      // 1. Identity Key
      final identityRes = await _supabase
          .from('signal_identity_keys')
          .select('public_key')
          .eq('uid', otherUid)
          .maybeSingle();
      if (identityRes == null) return null;

      // 2. Current Signed PreKey (latest one)
      final spkRes = await _supabase
          .from('signal_signed_prekeys')
          .select('key_id, public_key, signature')
          .eq('uid', otherUid)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();
      if (spkRes == null) return null;

      // 3. One-Time PreKey (grab one and mark as used if possible, or just select)
      // Note: In a production environment, this should be done via RPC to ensure atomicity
      final opkRes = await _supabase
          .from('signal_ot_prekeys')
          .select('key_id, public_key')
          .eq('uid', otherUid)
          .isFilter('used_at', null)
          .limit(1)
          .maybeSingle();

      if (opkRes != null) {
        try {
          await _supabase
              .from('signal_ot_prekeys')
              .update({'used_at': DateTime.now().toIso8601String()})
              .match({'uid': otherUid, 'key_id': opkRes['key_id'] as int});
        } catch (_) {
          // Best-effort only. Read access must not fail if OPK consumption
          // update is blocked by RLS or concurrent use.
        }
      }

      return {
        'uid': otherUid,
        'identity_key': identityRes['public_key'],
        'signed_prekey': {
          'id': spkRes['key_id'],
          'public_key': spkRes['public_key'],
          'signature': spkRes['signature'],
        },
        'one_time_prekey': opkRes != null
            ? {'id': opkRes['key_id'], 'public_key': opkRes['public_key']}
            : null,
      };
    } catch (e) {
      debugPrint('[SignalKeyService] Error fetching bundle: $e');
      return null;
    }
  }

  // ── Getters for Local Keys ─────────────────────────────────────────────────

  Future<SimpleKeyPair> getMyIdentityKeyPair() async {
    final privB64 = await _storage.read(key: _kIdentityPriv);
    if (privB64 == null) throw Exception('No Identity Key found');

    final privBytes = base64Decode(privB64);
    return _x25519.newKeyPairFromSeed(privBytes);
  }

  Future<SimpleKeyPair> getSignedPreKeyPair(int id) async {
    final privB64 = await _storage.read(key: '$_kSignedPreKeyPriv$id');
    if (privB64 == null) throw Exception('No Signed PreKey found for ID $id');

    final privBytes = base64Decode(privB64);
    return SimpleKeyPairData(
      privBytes,
      publicKey: SimplePublicKey(
        base64Decode(await _storage.read(key: '$_kSignedPreKeyPub$id') ?? ''),
        type: KeyPairType.x25519,
      ),
      type: KeyPairType.x25519,
    );
  }

  Future<SimpleKeyPair?> getOTPreKeyPair(int id) async {
    final privB64 = await _storage.read(key: 'signal_opk_private_$id');
    if (privB64 == null) return null;

    final privBytes = base64Decode(privB64);
    // Note: We don't store public OPKs locally individually, but we can re-derive it
    final kp = await _x25519.newKeyPairFromSeed(privBytes);
    return kp;
  }

  Future<String> getIdentityPublicKey() async {
    final pubB64 = await _storage.read(key: _kIdentityPub);
    if (pubB64 != null) return pubB64;

    // Fallback: Extract from key pair if not explicitly stored as pub string
    final kp = await getMyIdentityKeyPair();
    final pubBytes = (await kp.extractPublicKey()).bytes;
    return base64Encode(pubBytes);
  }

  /// Exports all relevant Signal keys for backup.
  Future<Map<String, String>> exportAllKeys() async {
    final all = await _storage.readAll();
    final signalKeys = <String, String>{};
    for (final entry in all.entries) {
      if (entry.key.startsWith('signal_') || entry.key.startsWith('pq_')) {
        signalKeys[entry.key] = entry.value;
      }
    }
    return signalKeys;
  }

  /// Imports and overwrites keys from a backup.
  Future<void> importKeys(Map<String, String> keys) async {
    for (final entry in keys.entries) {
      await _storage.write(key: entry.key, value: entry.value);
    }
  }

  // ── OPK Replenishment ──────────────────────────────────────────────────────

  /// Checks the remaining OPK count in Supabase and replenishes if running low.
  /// If [force] is true, it also republishes a fresh Signed PreKey (SPK)
  /// which is required for "Repair Discussion" to work correctly.
  Future<void> replenishOTPKeysIfNeeded({bool force = false}) async {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) return;

    try {
      // Count remaining unused OPKs
      final remaining = await _supabase
          .from('signal_ot_prekeys')
          .select('key_id')
          .eq('uid', uid)
          .isFilter('used_at', null);

      final remainingCount = (remaining as List).length;
      debugPrint('[SignalKeyService] OPK remaining: $remainingCount');

      final bool needsReplenish = force || remainingCount < 20;

      if (!needsReplenish) return;

      debugPrint('[SignalKeyService] Replenishing OPKs (force=$force, remaining=$remainingCount)...');

      // If force = true (Repair Discussion), also publish a new Signed PreKey
      // so the other party can start a fresh handshake with us.
      if (force) {
        await _republishSignedPreKey(uid);
      }

      // Generate 50 new OPKs
      final now = DateTime.now();
      final opkBaseId = now.microsecondsSinceEpoch;
      final opks = <Map<String, dynamic>>[];
      final opkPrivates = <int, List<int>>{};

      final isolateData = await Isolate.run(() async {
        final x25519 = X25519();
        final results = <({int keyId, List<int> pubBytes, List<int> privBytes})>[];
        for (var i = 1; i <= 50; i++) {
          final keyPair = await x25519.newKeyPair();
          final pub = await keyPair.extractPublicKey();
          final priv = await keyPair.extractPrivateKeyBytes();
          results.add((keyId: opkBaseId + i, pubBytes: pub.bytes, privBytes: priv));
        }
        return results;
      });

      for (final res in isolateData) {
        opks.add({
          'uid': uid,
          'key_id': res.keyId,
          'public_key': base64Encode(res.pubBytes),
        });
        opkPrivates[res.keyId] = res.privBytes;
      }

      // Save private keys locally
      for (final entry in opkPrivates.entries) {
        await _storage.write(
          key: 'signal_opk_private_${entry.key}',
          value: base64Encode(entry.value),
        );
      }

      // Publish to Supabase
      await _supabase.from('signal_ot_prekeys').upsert(opks);
      debugPrint('[SignalKeyService] Replenished ${opks.length} new OPKs.');
    } catch (e) {
      debugPrint('[SignalKeyService] OPK replenishment failed: $e');
    }
  }

  /// Publishes a brand new Signed PreKey to Supabase.
  /// This is required during "Repair Discussion" so the other party can
  /// initiate a fresh X3DH handshake with a valid, current SPK.
  Future<void> _republishSignedPreKey(String uid) async {
    try {
      final signingPrivB64 = await _storage.read(key: _kSigningPriv);
      if (signingPrivB64 == null) {
        debugPrint('[SignalKeyService] No signing key found, skipping SPK republish.');
        return;
      }

      final signingPrivBytes = base64Decode(signingPrivB64);
      final signingKeyPair = await _ed25519.newKeyPairFromSeed(signingPrivBytes);

      final now = DateTime.now();
      final spkId = now.millisecondsSinceEpoch;
      final spkKeyPair = await _x25519.newKeyPair();
      final spkPub = await spkKeyPair.extractPublicKey();
      final spkPriv = await spkKeyPair.extractPrivateKeyBytes();

      final signature = await _ed25519.sign(
        spkPub.bytes,
        keyPair: signingKeyPair,
      );

      // Save new SPK private key locally
      await _storage.write(
        key: '$_kSignedPreKeyPriv$spkId',
        value: base64Encode(spkPriv),
      );
      await _storage.write(
        key: '$_kSignedPreKeyPub$spkId',
        value: base64Encode(spkPub.bytes),
      );
      await _storage.write(key: _kLastSignedPreKeyId, value: spkId.toString());

      // Publish to Supabase (keep old SPKs for backward compat; just add new one)
      await _supabase.from('signal_signed_prekeys').upsert({
        'uid': uid,
        'key_id': spkId,
        'public_key': base64Encode(spkPub.bytes),
        'signature': base64Encode(signature.bytes),
        'created_at': now.toIso8601String(),
      });

      debugPrint('[SignalKeyService] Published new Signed PreKey (SPK ID: $spkId).');
    } catch (e) {
      debugPrint('[SignalKeyService] SPK republish failed: $e');
    }
  }
}
