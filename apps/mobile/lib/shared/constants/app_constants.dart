// lib/core/constants/app_constants.dart

class AppConstants {
  // App Info
  static const String appName = 'iXPARQ';
  static const String appTagline = 'Safe Galactic Social';

  // Platform backend
  static const String platformApiBaseUrl = String.fromEnvironment(
    'XPARQ_PLATFORM_API_BASE_URL',
    defaultValue: 'https://api.xparq.me/api/v1',
  );
  static const bool useCentralBackendRead = bool.fromEnvironment(
    'USE_CENTRAL_BACKEND_READ',
    defaultValue: true,
  );
  static const bool useCentralBackendProfileRead = bool.fromEnvironment(
    'USE_CENTRAL_BACKEND_PROFILE_READ',
    defaultValue: true,
  );
  static const bool useCentralBackendProfileWrite = bool.fromEnvironment(
    'USE_CENTRAL_BACKEND_PROFILE_WRITE',
    defaultValue: false,
  );
  static const bool useCentralBackendDeviceRegister = bool.fromEnvironment(
    'USE_CENTRAL_BACKEND_DEVICE_REGISTER',
    defaultValue: false,
  );
  static const bool useCentralBackendDeviceRead = bool.fromEnvironment(
    'USE_CENTRAL_BACKEND_DEVICE_READ',
    defaultValue: true,
  );
  static const bool useCentralBackendDeviceReadSelf = bool.fromEnvironment(
    'USE_CENTRAL_BACKEND_DEVICE_READ_SELF',
    defaultValue: true,
  );
  static const bool useCentralBackendDeviceReadPublic = bool.fromEnvironment(
    'USE_CENTRAL_BACKEND_DEVICE_READ_PUBLIC',
    defaultValue: true,
  );
  static const bool useCentralBackendModerationWrite = bool.fromEnvironment(
    'USE_CENTRAL_BACKEND_MODERATION_WRITE',
    defaultValue: false,
  );
  static const bool useCentralBackendBlockListRead = bool.fromEnvironment(
    'USE_CENTRAL_BACKEND_BLOCK_LIST_READ',
    defaultValue: true,
  );

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

  // Google Sign In
  static const String googleWebClientId = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
    defaultValue: '932423344853-gjo7d820c0v7jig70mr17eqh0huu0qkc.apps.googleusercontent.com',
  );
  static const String googleIosClientId = String.fromEnvironment(
    'GOOGLE_IOS_CLIENT_ID',
    defaultValue: 'YOUR_IOS_CLIENT_ID.apps.googleusercontent.com',
  );
}
