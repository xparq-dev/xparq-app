import 'dart:async';
import 'dart:ui';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart';
import 'package:xparq_app/shared/config/supabase_config.dart';
import 'package:xparq_app/shared/utils/isolate_logger.dart';
import 'package:xparq_app/features/chat/data/services/message_encryption_service.dart';
import 'package:xparq_app/features/chat/data/services/notification_service.dart';
import 'package:xparq_app/features/chat/data/services/notification_action_handler.dart';
import 'package:xparq_app/features/chat/data/services/signal/signal_session_manager.dart';

@pragma('vm:entry-point')
class BackgroundSignalService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    final service = FlutterBackgroundService();

    // Initialize notifications for the main app
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);
    await _notifications.initialize(
      initializationSettings,
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );

    // Create notification channel for Android 14+ for foreground service
    const AndroidNotificationChannel serviceChannel =
        AndroidNotificationChannel(
          'xparq_relay_service', // New ID
          'XPARQ Relay',
          description: 'Background signal relay service',
          importance: Importance.low, // Show icon, stay silent
          showBadge: false,
          enableVibration: false,
        );

    // Create notification channel for Android 14+ for actual signal notifications
    const AndroidNotificationChannel signalChannel = AndroidNotificationChannel(
      'xparq_signal_channel', // Match NotificationService
      'XPARQ Secure Signal',
      description: 'Encrypted message delivery with Signal Protocol',
      importance: Importance.max,
    );

    await _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(serviceChannel);

    await _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(signalChannel);

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: true,
        isForegroundMode: true,
        notificationChannelId: 'xparq_relay_service',
        initialNotificationTitle: 'XPARQ Relay',
        initialNotificationContent: 'Active',
        foregroundServiceNotificationId: 888,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: true,
        onForeground: onStart,
        onBackground: onIosBackground,
      ),
    );

    service.startService();
  }

  @pragma('vm:entry-point')
  static Future<bool> onIosBackground(ServiceInstance service) async {
    WidgetsFlutterBinding.ensureInitialized();
    DartPluginRegistrant.ensureInitialized();
    return true;
  }

  @pragma('vm:entry-point')
  static void onStart(ServiceInstance service) {
    runZonedGuarded(
      () async {
        WidgetsFlutterBinding.ensureInitialized();
        DartPluginRegistrant.ensureInitialized();

        if (service is AndroidServiceInstance) {
          service.setForegroundNotificationInfo(
            title: "XPARQ Relay",
            content: "Active",
          );

          // Initialize notifications for the background isolate
          const AndroidInitializationSettings initializationSettingsAndroid =
              AndroidInitializationSettings('@mipmap/ic_launcher');
          const InitializationSettings initializationSettings =
              InitializationSettings(android: initializationSettingsAndroid);
          await _notifications.initialize(
            initializationSettings,
            onDidReceiveBackgroundNotificationResponse:
                notificationTapBackground,
          );

          service.on('setAsForeground').listen((event) {
            service.setAsForegroundService();
          });

          service.on('setAsBackground').listen((event) {
            service.setAsBackgroundService();
          });
        }

        service.on('stopService').listen((event) {
          service.stopSelf();
        });

        // Initialize Supabase in the background isolate
        final supabase = await Supabase.initialize(
          url: SupabaseConfig.url,
          anonKey: SupabaseConfig.anonKey,
        );

        final client = supabase.client;
        String? currentUserId;

        service.on('updateUser').listen((event) async {
          debugPrint('[BackgroundSignalService] updateUser event: $event');
          if (currentUserId == event?['userId']) {
            debugPrint(
              '[BackgroundSignalService] Same user, skipping subscription',
            );
            return; // Skip if same user
          }
          currentUserId = event?['userId'];
          if (currentUserId != null) {
            NotificationActionHandler.instance.setUserId(currentUserId);
            debugPrint(
              '[BackgroundSignalService] User updated: $currentUserId. Subscribing to signals...',
            );
            await _subscribeToSignals(client, currentUserId!, service);
          } else {
            debugPrint(
              '[BackgroundSignalService] updateUser called with null userId',
            );
          }
        });

        service.on('onNotificationAction').listen((event) async {
          if (event == null) return;
          try {
            final actionId = event['actionId'] as String?;
            final input = event['input'] as String?;
            final payloadStr = event['payload'] as String?;

            await IsolateLogger.log(
              '[BackgroundSignalService] Action received: $actionId',
            );
            await IsolateLogger.log('[BackgroundSignalService] Input: $input');
            await IsolateLogger.log(
              '[BackgroundSignalService] Payload: $payloadStr',
            );

            if (actionId != null && payloadStr != null) {
              final Map<String, dynamic> data = jsonDecode(payloadStr);

              // Get user ID for initialization
              var myUid =
                  (data['my_uid'] as String?) ??
                  NotificationActionHandler.instance.currentUserId;

              // Initialize Signal for Echo action
              if (actionId == NotificationService.actionEcho) {
                await IsolateLogger.log(
                  '[BackgroundSignalService] Initializing Signal for Echo...',
                );
                if (myUid != null) {
                  await SignalSessionManager.instance.initialize(myUid);
                } else {
                  await SignalSessionManager.instance.initialize();
                }
                await IsolateLogger.log(
                  '[BackgroundSignalService] Signal initialized.',
                );
              }
              await IsolateLogger.log(
                '[BackgroundSignalService] Calling handleAction...',
              );
              await NotificationActionHandler.instance.handleAction(
                actionId,
                input,
                data,
              );
              await IsolateLogger.log(
                '[BackgroundSignalService] Action completed.',
              );
            }
          } catch (e) {
            await IsolateLogger.log(
              '[BackgroundSignalService] Action routing failed: $e',
            );
            debugPrint('[BackgroundSignalService] Action routing failed: $e');
          }
        });

        // Update status periodically
        Timer.periodic(const Duration(minutes: 5), (timer) async {
          if (service is AndroidServiceInstance) {
            if (await service.isForegroundService()) {
              service.setForegroundNotificationInfo(
                title: "XPARQ Relay",
                content: "Active (Safe Mode)",
              );
            }
          }

          // Diagnostic heartbeats
          debugPrint('[BackgroundSignalService] Pulse check. Memory safe.');

          if (!client.realtime.isConnected) {
            try {
              // ignore: invalid_use_of_internal_member
              client.realtime.connect();
            } catch (e) {
              // Fallback
            }
          }
        });
      },
      (error, stack) {
        debugPrint('[BackgroundSignalService] CRITICAL ISOLATE ERROR: $error');
        debugPrint(stack.toString());
      },
    );
  }

  static Future<void> _subscribeToSignals(
    SupabaseClient client,
    String userId,
    ServiceInstance service,
  ) async {
    debugPrint(
      '[BackgroundSignalService] _subscribeToSignals for user: $userId',
    );

    try {
      // Ensure realtime is connected
      if (!client.realtime.isConnected) {
        debugPrint('[BackgroundSignalService] Connecting to realtime...');
        // ignore: invalid_use_of_internal_member
        await client.realtime.connect();
        debugPrint(
          '[BackgroundSignalService] Realtime connected: ${client.realtime.isConnected}',
        );
      }

      final channel = client.channel('public:messages');

      channel.onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'messages',
        callback: (payload) {
          final senderId = payload.newRecord['sender_id']?.toString() ?? '';
          debugPrint(
            '🔔 [BackgroundSignalService] Postgres change received: ${payload.eventType}',
          );
          debugPrint(
            '🔔 [BackgroundSignalService] sender_id from DB: $senderId',
          );
          debugPrint(
            '🔔 [BackgroundSignalService] currentUserId in background: $userId',
          );
          debugPrint(
            '🔔 [BackgroundSignalService] Match: ${senderId == userId}',
          );

          if (senderId != userId) {
            debugPrint(
              '🔔 [BackgroundSignalService] ✅ Received new message via RT sync from $senderId',
            );

            // Fallback notification if FCM fails
            _showFallbackNotification(client, payload.newRecord, userId);
          } else {
            debugPrint(
              '🔔 [BackgroundSignalService] ❌ Message from self, ignoring',
            );
          }
        },
      );

      final status = channel.subscribe();
      debugPrint('[BackgroundSignalService] Subscription status: $status');
    } catch (e) {
      debugPrint('[BackgroundSignalService] Subscribe to signals failed: $e');
    }

    debugPrint('[BackgroundSignalService] Subscription initiated');
  }

  static Future<void> _showFallbackNotification(
    SupabaseClient client,
    Map<String, dynamic> record,
    String currentUserId,
  ) async {
    debugPrint('[BackgroundSignalService] _showFallbackNotification called');

    try {
      final senderId = record['sender_id']?.toString() ?? '';
      final messageId = record['id']?.toString() ?? '';
      final chatId = record['chat_id']?.toString() ?? '';
      final encryptedContent = record['content'];

      debugPrint(
        '[BackgroundSignalService] Message from $senderId, chat $chatId',
      );

      // Fetch sender name and avatar
      final senderData = await client
          .from('profiles')
          .select('xparq_name, photo_url')
          .eq('id', senderId)
          .maybeSingle();

      final senderName = senderData?['xparq_name'] ?? "Someone";
      final avatarUrl = senderData?['photo_url'] as String?;

      // Download avatar if available
      String? largeIconPath;
      if (avatarUrl != null && avatarUrl.isNotEmpty) {
        try {
          final tempDir = await getTemporaryDirectory();
          final fileName = 'avatar_${senderId.hashCode}.jpg';
          largeIconPath = '${tempDir.path}/$fileName';

          await Dio().download(avatarUrl, largeIconPath);
        } catch (e) {
          debugPrint('[BackgroundSignalService] Avatar download failed: $e');
          largeIconPath = null;
        }
      }

      // Try to decrypt for a rich preview using the unified MessageEncryptionService
      String preview = "New Signal received 📡";
      try {
        preview = await MessageEncryptionService.decrypt(
          encryptedContent,
          chatId,
        );

        // If content is media (JSON), provide a preview
        if (preview.startsWith('{') && preview.contains('url')) {
          try {
            if (record['message_type'] == 'image') {
              preview = "Sent an image 🖼️";
            } else if (record['message_type'] == 'video') {
              preview = "Sent a video 📹";
            }
          } catch (_) {}
        }
      } catch (e) {
        debugPrint(
          '[BackgroundSignalService] Decryption failed for fallback: $e',
        );
      }

      final person = Person(
        name: senderName,
        key: senderId,
        icon: largeIconPath != null
            ? BitmapFilePathAndroidIcon(largeIconPath)
            : null,
      );

      final androidDetails = AndroidNotificationDetails(
        'xparq_signal_channel',
        'XPARQ Secure Signal',
        channelDescription: 'Encrypted message delivery with Signal Protocol',
        importance: Importance.max,
        priority: Priority.high,
        ticker: 'new_signal',
        largeIcon: largeIconPath != null
            ? FilePathAndroidBitmap(largeIconPath)
            : null,
        styleInformation: MessagingStyleInformation(
          person,
          messages: [Message(preview, DateTime.now(), person)],
        ),
        actions: const [
          AndroidNotificationAction(
            NotificationService.actionSilence,
            'Silence',
            allowGeneratedReplies: false,
            cancelNotification: true,
            showsUserInterface: false,
            contextual: false,
          ),
          AndroidNotificationAction(
            NotificationService.actionSpark,
            '⚡ Spark',
            cancelNotification: false,
            showsUserInterface: false,
            contextual: false,
          ),
          AndroidNotificationAction(
            NotificationService.actionEcho,
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
        ],
        tag: messageId,
      );

      final notificationDetails = NotificationDetails(android: androidDetails);

      final syntheticPayload = {
        'chat_id': chatId,
        'sender_uid': senderId,
        'other_uid': senderId,
        'message_id': messageId,
        'my_uid': currentUserId,
      };

      await _notifications.show(
        messageId.hashCode, // Unique ID
        senderName,
        preview,
        notificationDetails,
        payload: jsonEncode(syntheticPayload),
      );

      debugPrint(
        '[BackgroundSignalService] Notification shown. ID=${messageId.hashCode}, payload=${jsonEncode(syntheticPayload)}',
      );
    } catch (e) {
      debugPrint(
        '[BackgroundSignalService] Failed to show fallback notification: $e',
      );
    }
  }
}
