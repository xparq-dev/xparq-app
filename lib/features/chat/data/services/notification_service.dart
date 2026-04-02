// lib/core/services/notification_service.dart
//
// NotificationService — wraps Firebase Messaging (FCM) and flutter_local_notifications.
//
// Responsibilities (post-refactor):
//   1. Request notification permissions (Android 13+ / iOS)
//   2. Create Android notification channels
//   3. Initialize flutter_local_notifications
//   4. Handle foreground messages — show local notification
//
// Delegated responsibilities:
//   - FCM token management          → FcmTokenService
//   - Notification action handling  → NotificationActionHandler

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:xparq_app/core/config/supabase_config.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:xparq_app/features/chat/data/services/fcm_token_service.dart';
import 'package:xparq_app/features/chat/data/services/notification_action_handler.dart';
import 'package:xparq_app/features/chat/data/services/message_encryption_service.dart';
import 'package:xparq_app/features/chat/data/services/signal/signal_session_manager.dart';

// ── Background message handler (must be a top-level function) ─────────────────

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint(
    '🔴 [FCM Background] 🔥 Message received in background: ${message.messageId}',
  );
  debugPrint('🔴 [FCM Background] Data: ${message.data}');
  debugPrint(
    '🔴 [FCM Background] Notification: ${message.notification?.title} / ${message.notification?.body}',
  );

  // IMPORTANT: Firebase.initializeApp() is removed here.
  // It is handled by the native SDK in the background process.

  try {
    await Supabase.initialize(
      url: SupabaseConfig.url,
      anonKey: SupabaseConfig.anonKey,
    );
    debugPrint('🔴 [FCM Background] Supabase initialized');
  } catch (e) {
    debugPrint('🔴 [FCM Background] Failed to init Supabase: $e');
  }

  try {
    await SignalSessionManager.instance.initialize();
    debugPrint('🔴 [FCM Background] Signal initialized');
  } catch (e) {
    debugPrint('🔴 [FCM Background] Failed to init Signal: $e');
  }

  try {
    await NotificationService.instance.initForBackground();
    debugPrint('🔴 [FCM Background] Local Notifications initialized');
  } catch (e) {
    debugPrint('🔴 [FCM Background] Failed to init Local Notifications: $e');
  }

  if (message.data.isNotEmpty) {
    debugPrint('🔴 [FCM Background] Showing notification...');
    await NotificationService.instance.showNotificationFromRemoteMessage(
      message,
    );
    debugPrint('🔴 [FCM Background] Notification display completed');
  } else {
    debugPrint('🔴 [FCM Background] No data in message');
  }
}

// ── NotificationService ───────────────────────────────────────────────────────

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  String? Function()? _activeChatIdGetter;

  // Action IDs (kept here as they are referenced by other services)
  static const String actionSilence = 'silence';
  static const String actionSpark = 'spark';
  static const String actionEcho = 'echo';

  static const AndroidNotificationChannel _chatChannel =
      AndroidNotificationChannel(
        'xparq_signal_channel',
        'XPARQ Secure Signal',
        description: 'Encrypted message delivery with Signal Protocol',
        importance: Importance.max,
      );

  // ── Initialize ───────────────────────────────────────────────────────────

  Future<void> initialize({
    String? Function()? activeChatIdGetter,
    void Function(String chatId, String otherUid)? onNavigateToChat,
  }) async {
    _activeChatIdGetter = activeChatIdGetter;

    final tokenService = FcmTokenService.instance;

    if (!kIsWeb) {
      if (tokenService.isFirebaseGloballyDisabled) {
        debugPrint(
          '[NotificationService] Firebase globally disabled, but continuing with local notifications',
        );
        // Don't return - continue with local notifications initialization
      } else {
        // Register background handler
        try {
          FirebaseMessaging.onBackgroundMessage(
            _firebaseMessagingBackgroundHandler,
          );
        } catch (e) {
          debugPrint(
            '[NotificationService] Failed to set background handler: $e',
          );
          tokenService.markUnavailable();
          if (e.toString().contains('FIS_AUTH_ERROR')) {
            tokenService.disableFirebase();
          }
        }
      }

      debugPrint('[NotificationService] Creating notification channel...');
      await _localNotifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(_chatChannel);

      final actionHandler = NotificationActionHandler.instance;

      final initSettings = InitializationSettings(
        android: const AndroidInitializationSettings('@mipmap/launcher_icon'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: true,
          requestSoundPermission: true,
          notificationCategories: [
            DarwinNotificationCategory(
              'CHAT_ACTIONS',
              actions: [
                DarwinNotificationAction.plain(actionSilence, 'Silence'),
                DarwinNotificationAction.plain(actionSpark, 'Spark'),
                DarwinNotificationAction.text(
                  actionEcho,
                  'Echo',
                  buttonTitle: 'Send',
                  placeholder: 'Send an echo...',
                ),
              ],
            ),
          ],
        ),
      );

      debugPrint('[NotificationService] Initializing local notifications...');
      await _localNotifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: actionHandler.onLocalNotificationTap,
        onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
      );

      debugPrint(
        '[NotificationService] Local notifications initialized with callbacks',
      );
    }

    debugPrint('[NotificationService] Requesting permissions...');
    await _requestPermissions();
    debugPrint('[NotificationService] Permissions requested');

    // Listen for foreground messages
    if (tokenService.isFirebaseAvailable &&
        !tokenService.isFirebaseGloballyDisabled) {
      try {
        FirebaseMessaging.onMessage.listen(
          (message) async => showNotificationFromRemoteMessage(message),
        );
      } catch (e) {
        debugPrint(
          '[NotificationService] Failed to set onMessage listener: $e',
        );
      }

      // Upload FCM token (non-blocking)
      try {
        unawaited(tokenService.uploadToken());
      } catch (e) {
        debugPrint('[NotificationService] uploadToken start error: $e');
      }

      // Listen for token refresh
      tokenService.listenForTokenRefresh();

      // Retry token upload after 30s if it was initially missing
      Timer(const Duration(seconds: 30), () async {
        if (!tokenService.isFirebaseAvailable) return;
        final uid = Supabase.instance.client.auth.currentUser?.id;
        if (uid == null) return;
        final snap = await Supabase.instance.client
            .from('profiles')
            .select('fcm_token')
            .eq('id', uid)
            .maybeSingle();
        final saved = snap?['fcm_token'] as String?;
        if (saved == null || saved.isEmpty) {
          debugPrint(
            '[NotificationService] 🔁 Scheduled retry: token missing. Retrying...',
          );
          unawaited(tokenService.uploadToken(maxRetries: 3));
        }
      });
    }

    // Register navigation tap handler
    if (onNavigateToChat != null) {
      NotificationActionHandler.instance.handleFcmTap(
        onNavigate: onNavigateToChat,
      );
    }

    debugPrint('[NotificationService] Initialized.');
  }

  /// Lightweight initialization for the background isolate.
  Future<void> initForBackground() async {
    if (!kIsWeb) {
      await _localNotifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(_chatChannel);

      const initSettings = InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/launcher_icon'),
        iOS: DarwinInitializationSettings(),
      );
      await _localNotifications.initialize(
        initSettings,
        onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
      );
      debugPrint('[NotificationService] Background isolate initialized.');
    }
  }

  // ── Foreground Notification Display ───────────────────────────────────────

  /// Decrypts and displays a local notification from a remote FCM message.
  Future<void> showNotificationFromRemoteMessage(RemoteMessage message) async {
    debugPrint(
      '🔔 [NotificationService] showNotificationFromRemoteMessage called',
    );
    debugPrint('🔔 [NotificationService] Message ID: ${message.messageId}');
    debugPrint('🔔 [NotificationService] Data: ${message.data}');
    debugPrint(
      '🔔 [NotificationService] Notification: ${message.notification?.title} / ${message.notification?.body}',
    );

    final data = Map<String, dynamic>.from(message.data);
    final myUid = Supabase.instance.client.auth.currentUser?.id;
    if (myUid != null) data['my_uid'] = myUid;

    final notificationChatId = data['chat_id'] as String?;
    final remoteNotification = message.notification;

    // Suppress notification if the chat is currently active
    final activeChatId = _activeChatIdGetter?.call();
    debugPrint(
      '🔔 [NotificationService] Active chat ID: $activeChatId, Notification chat ID: $notificationChatId',
    );
    if (activeChatId != null &&
        notificationChatId != null &&
        activeChatId == notificationChatId) {
      debugPrint(
        '🔔 [NotificationService] Active chat — silencing notification.',
      );
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final showPreview = prefs.getBool('show_notification_preview') ?? true;
    final showActions = prefs.getBool('show_notification_actions') ?? true;

    debugPrint(
      '[NotificationService] showActions=$showActions, showPreview=$showPreview',
    );

    String senderName = data['sender_name'] ?? 'New Signal 📡';
    String title = data['title'] ?? senderName;
    String body = data['body'] ?? 'You have a new message';
    String? avatarUrl = data['sender_avatar'];
    senderName =
        (data['sender_name'] as String?) ??
        remoteNotification?.title ??
        senderName;
    title = (data['title'] as String?) ?? remoteNotification?.title ?? title;
    body = (data['body'] as String?) ?? remoteNotification?.body ?? body;
    final notificationId = _notificationIdFor(message, data);
    final avatarFileSeed =
        message.messageId ??
        data['message_id']?.toString() ??
        data['sender_uid']?.toString() ??
        notificationChatId ??
        notificationId.toString();

    if (showPreview) {
      final encryptedPayload = data['encrypted_payload'] as String?;
      if (encryptedPayload != null && notificationChatId != null) {
        try {
          body = await MessageEncryptionService.decrypt(
            encryptedPayload,
            notificationChatId,
          );
        } catch (e) {
          debugPrint(
            '[NotificationService] Decryption failed for $notificationChatId: $e',
          );
        }
      }
    }

    String? largeIconPath;
    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      largeIconPath = await _downloadAndSaveFile(
        avatarUrl,
        'sender_avatar_$avatarFileSeed.jpg',
      );
    }

    final person = Person(
      name: senderName,
      key: data['sender_uid'],
      icon: largeIconPath != null
          ? BitmapFilePathAndroidIcon(largeIconPath)
          : null,
    );

    await _localNotifications.show(
      notificationId,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _chatChannel.id,
          _chatChannel.name,
          channelDescription: _chatChannel.description,
          importance: Importance.max,
          priority: Priority.high,
          icon: '@mipmap/launcher_icon',
          color: const Color(0xFF4FC3F7),
          styleInformation: MessagingStyleInformation(
            person,
            messages: [Message(body, DateTime.now(), person)],
          ),
          largeIcon: largeIconPath != null
              ? FilePathAndroidBitmap(largeIconPath)
              : null,
          actions: showActions
              ? const [
                  AndroidNotificationAction(
                    actionSilence,
                    'Silence',
                    allowGeneratedReplies: false,
                    cancelNotification: true,
                    showsUserInterface: false,
                    contextual: false,
                  ),
                  AndroidNotificationAction(
                    actionSpark,
                    '⚡ Spark',
                    cancelNotification: false,
                    showsUserInterface: false,
                    contextual: false,
                  ),
                  AndroidNotificationAction(
                    actionEcho,
                    'Echo',
                    showsUserInterface: false,
                    allowGeneratedReplies: true,
                    cancelNotification: false,
                    contextual: false,
                    inputs: [
                      AndroidNotificationActionInput(
                        label: 'Send an echo...',
                        allowFreeFormInput: true,
                        allowedMimeTypes: {'text/plain'},
                      ),
                    ],
                  ),
                ]
              : null,
          tag:
              message.messageId ??
              data['message_id']?.toString() ??
              notificationChatId,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          categoryIdentifier: showActions ? 'CHAT_ACTIONS' : null,
          threadIdentifier: notificationChatId,
        ),
      ),
      payload: jsonEncode(data),
    );

    debugPrint(
      '✅ [NotificationService] Notification shown. ID=$notificationId, payload=${jsonEncode(data)}',
    );
  }

  // ── Permissions ───────────────────────────────────────────────────────────

  Future<void> _requestPermissions() async {
    if (kIsWeb) return;

    debugPrint('[NotificationService] _requestPermissions called');

    try {
      final fcm = FirebaseMessaging.instance;
      final settings = await fcm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
      debugPrint(
        '[NotificationService] FCM permission status: ${settings.authorizationStatus}',
      );
    } catch (e) {
      debugPrint('[NotificationService] Error requesting permissions: $e');
    }

    try {
      final androidPlugin = _localNotifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      debugPrint(
        '[NotificationService] Requesting Android notification permission...',
      );
      final granted = await androidPlugin?.requestNotificationsPermission();
      if (granted != null) {
        debugPrint(
          '[NotificationService] Android local notification permission: $granted',
        );
      } else {
        debugPrint(
          '[NotificationService] Android permission request returned null',
        );
      }
    } catch (e) {
      debugPrint(
        '[NotificationService] Error requesting Android local notification permission: $e',
      );
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Future<String?> _downloadAndSaveFile(String url, String fileName) async {
    try {
      final directory = await getTemporaryDirectory();
      final filePath = '${directory.path}/$fileName';
      final response = await http.get(Uri.parse(url));
      final file = File(filePath);
      await file.writeAsBytes(response.bodyBytes);
      return filePath;
    } catch (e) {
      debugPrint('[NotificationService] Error downloading avatar: $e');
      return null;
    }
  }

  int _notificationIdFor(RemoteMessage message, Map<String, dynamic> data) {
    final rawId =
        message.messageId ??
        data['message_id']?.toString() ??
        data['chat_id']?.toString() ??
        DateTime.now().microsecondsSinceEpoch.toString();
    return rawId.hashCode;
  }
}
