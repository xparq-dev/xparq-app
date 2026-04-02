// lib/core/constants/app_constants.dart

class AppConstants {
  // App Info
  static const String appName = 'iXPARQ';
  static const String appTagline = 'Safe Galactic Social';

  // Age Gating
  static const int minimumAge = 13;
  static const int adultAge = 18;

  // Offline
  static const String offlineDbName = 'iXPARQ_offline.db';
  static const String offlineTempIdKey = 'iXPARQ_offline_temp_id';

  // Encryption
  static const String dobEncryptionKeyName = 'iXPARQ_dob_key';
  static const String encryptionKeyName = 'iXPARQ_chat_key';

  // Chat Message Encryption — shared secret for HMAC-SHA256 key derivation.
  // All devices derive the same per-chat AES-256 key from:
  //   HMAC-SHA256(key=chatMasterSecret, data=chatId)
  // ⚠️  Change this value before releasing to production.
  //     In production, inject via --dart-define=CHAT_SECRET=... at build time.
  static const String chatMasterSecret = String.fromEnvironment(
    'CHAT_SECRET',
    defaultValue: 'iXPARQ-signal-master-secret-v1-dev-2026',
  );
}
