// lib/core/services/notification_action_handler.dart
//
// Handles taps on notification actions (Silence, Spark, Echo) and navigation
// from notification payloads. Extracted from notification_service.dart.

import 'dart:convert';
import 'dart:ui';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:xparq_app/features/chat/data/repositories/chat_repository.dart';
import 'package:xparq_app/core/config/supabase_config.dart';
import 'package:xparq_app/features/chat/data/services/notification_service.dart';
import 'package:xparq_app/features/chat/data/services/signal/signal_session_manager.dart';
import 'package:xparq_app/core/utils/isolate_logger.dart';

// ── Background tap handler (must be top-level for platform channel) ───────────

@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse response) async {
  print('NOTIF_TAP_BG: Start. Action=${response.actionId}');
  await IsolateLogger.log('Background action received: ${response.actionId}');
  await IsolateLogger.log('Background action input: ${response.input}');
  if (response.payload == null) {
    print('NOTIF_TAP_BG: Payload is null');
    return;
  }

  String? messageId;
  try {
    final Map<String, dynamic> data = jsonDecode(response.payload!);
    messageId = data['message_id']?.toString();
  } catch (_) {}

  try {
    WidgetsFlutterBinding.ensureInitialized();
    DartPluginRegistrant.ensureInitialized();

    // Always initialize Supabase first — accessing .instance before init
    // throws an unhandled exception in background isolates → SIGKILL
    try {
      await Supabase.initialize(
        url: SupabaseConfig.url,
        anonKey: SupabaseConfig.anonKey,
      );
    } catch (_) {
      // Already initialized or init failed — safe to continue
    }

    final service = FlutterBackgroundService();
    if (await service.isRunning()) {
      service.invoke('onNotificationAction', {
        'actionId': response.actionId,
        'input': response.input,
        'payload': response.payload,
      });
      debugPrint('[NotificationBg] Forwarded tap to BackgroundSignalService.');
      await IsolateLogger.log(
        '[NotificationBg] Forwarded action=${response.actionId}, input=${response.input}',
      );
      return;
    }
  } catch (e) {
    debugPrint('[NotificationBg] Error forwarding tap: $e');
    await IsolateLogger.log('[NotificationBg] Error forwarding tap: $e');
  } finally {
    if (messageId != null) {
      await FlutterLocalNotificationsPlugin().cancel(messageId.hashCode);
    }
  }
}

// ── NotificationActionHandler ─────────────────────────────────────────────────

class NotificationActionHandler {
  NotificationActionHandler._();
  static final NotificationActionHandler instance =
      NotificationActionHandler._();

  String? _currentUid;
  void setUserId(String? uid) => _currentUid = uid;
  String? get currentUserId => _currentUid;

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  void Function(String chatId, String otherUid)? onNavigateToChat;

  /// Called when the user taps a local notification or a notification action.
  void onLocalNotificationTap(NotificationResponse response) async {
    debugPrint('[NotificationActionHandler] onLocalNotificationTap called');
    debugPrint('[NotificationActionHandler] Action: ${response.actionId}');
    debugPrint('[NotificationActionHandler] Input: ${response.input}');
    debugPrint('[NotificationActionHandler] Payload: ${response.payload}');

    if (response.payload == null) {
      debugPrint('[NotificationActionHandler] Payload is null!');
      return;
    }

    try {
      final Map<String, dynamic> data = jsonDecode(response.payload!);
      debugPrint('[NotificationActionHandler] Parsed data: $data');

      if (response.actionId != null) {
        debugPrint(
          '[NotificationActionHandler] Processing action: ${response.actionId}',
        );

        // For Echo action, send the message and don't navigate
        if (response.actionId == NotificationService.actionEcho) {
          debugPrint(
            '[NotificationActionHandler] Echo action detected, input: ${response.input}',
          );
          await handleAction(response.actionId!, response.input, data);
          return; // Don't navigate after sending Echo
        }

        // For other actions (Silence, Spark), handle and return
        await handleAction(response.actionId!, response.input, data);
        return;
      }

      // No action tapped - just navigate to chat
      if (onNavigateToChat != null) {
        _navigateFromPayload(data, onNavigateToChat!);
      }
    } catch (e) {
      debugPrint('[NotificationActionHandler] Error parsing tap payload: $e');
    }
  }

  /// Executes a given notification quick action (Silence, Spark, Echo).
  Future<void> handleAction(
    String actionId,
    String? input,
    Map<String, dynamic> data,
  ) async {
    debugPrint('[handleAction] Start. Action=$actionId, Input=$input');

    final chatId = data['chat_id'] as String?;
    final otherUid = (data['other_uid'] ?? data['sender_uid']) as String?;
    final messageIdStr = data['message_id'] as String?;
    final messageIdHash = messageIdStr?.hashCode;

    debugPrint('[handleAction] chatId=$chatId, otherUid=$otherUid');
    await IsolateLogger.log('Handling action $actionId for chat $chatId');

    if (chatId == null || otherUid == null) {
      debugPrint('[handleAction] ERROR: ChatId or otherUid is null!');
      await IsolateLogger.log(
        'ChatId or otherUid is null. Cancelling notification.',
      );
      if (messageIdHash != null) {
        await _localNotifications.cancel(messageIdHash);
      }
      return;
    }

    try {
      final repo = ChatRepository();

      // Wait for auth session loop
      debugPrint('[handleAction] Checking auth session...');
      await IsolateLogger.log('Checking auth session...');
      int attempts = 0;
      while (Supabase.instance.client.auth.currentSession == null &&
          attempts < 10) {
        attempts++;
        debugPrint('[handleAction] Session null, attempt $attempts/10');
        await IsolateLogger.log(
          'Session null, attempt $attempts/10, waiting 500ms...',
        );
        await Future.delayed(const Duration(milliseconds: 500));
      }

      var myUid =
          (data['my_uid'] as String?) ??
          _currentUid ??
          Supabase.instance.client.auth.currentUser?.id;

      debugPrint(
        '[handleAction] myUid=$myUid, data[my_uid]=${data['my_uid']}, _currentUid=$_currentUid',
      );

      if (myUid == null) {
        debugPrint('[handleAction] ERROR: UID missing after wait loop!');
        await IsolateLogger.log('UID missing after wait loop. Aborting.');
        return;
      }

      await IsolateLogger.log('Using UID: $myUid');

      switch (actionId) {
        case NotificationService.actionSilence:
          debugPrint('[handleAction] Silencing chat $chatId');
          final until = DateTime.now().add(const Duration(hours: 8));
          await repo.silenceChat(chatId, until, uid: myUid);
          await IsolateLogger.log('Silenced $chatId until $until');
          break;

        case NotificationService.actionSpark:
          debugPrint('[handleAction] Sparking message $messageIdStr');
          if (messageIdStr != null) {
            await repo.toggleMessageSpark(messageIdStr, myUid);
            await IsolateLogger.log('Sparked message $messageIdStr');
          }
          break;

        case NotificationService.actionEcho:
          debugPrint(
            '[handleAction] Echo action! Input length: ${input?.length}',
          );
          if (input != null && input.isNotEmpty) {
            debugPrint('[handleAction] Initializing Signal...');
            await IsolateLogger.log('Initializing SignalSessionManager...');
            await SignalSessionManager.instance.initialize(myUid);
            debugPrint(
              '[handleAction] Signal initialized. Fetching profile...',
            );
            await IsolateLogger.log('Signal initialized. Fetching profile...');

            final senderProfile = await repo.getMinimalProfile(myUid);
            if (senderProfile != null) {
              debugPrint('[handleAction] Sending message to $otherUid...');
              await IsolateLogger.log('Sending message to $otherUid...');
              await repo.sendMessage(
                chatId: chatId,
                senderProfile: senderProfile,
                plaintext: input,
                isSensitive: false,
                otherUid: otherUid,
              );
              debugPrint('[handleAction] ✅ Echo sent successfully!');
              await IsolateLogger.log('Echo sent successfully.');
            } else {
              debugPrint('[handleAction] ❌ ERROR: Profile null');
              await IsolateLogger.log('Echo Fail: Profile null');
            }
          } else {
            debugPrint('[handleAction] ❌ ERROR: Input empty or null');
            await IsolateLogger.log('Echo Fail: Input empty');
          }
          break;
      }
    } catch (e) {
      debugPrint('[handleAction] ❌ ERROR: $e');
      await IsolateLogger.log('Action failed: $e');
    } finally {
      if (messageIdHash != null) {
        await _localNotifications.cancel(messageIdHash);
      }
    }
  }

  /// Sets up listeners for FCM open events (app opened / brought to foreground).
  void handleFcmTap({
    required void Function(String chatId, String otherUid) onNavigate,
  }) {
    onNavigateToChat = onNavigate;

    FirebaseMessaging.instance
        .getInitialMessage()
        .then((message) {
          if (message != null) _navigateFromPayload(message.data, onNavigate);
        })
        .catchError((e) {
          debugPrint('[NotificationActionHandler] getInitialMessage error: $e');
        });

    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      _navigateFromPayload(message.data, onNavigateToChat ?? onNavigate);
    });
  }

  void _navigateFromPayload(
    Map<String, dynamic> data,
    void Function(String chatId, String otherUid) onNavigate,
  ) {
    final chatId = data['chat_id'] as String?;
    final otherUid = (data['other_uid'] ?? data['sender_uid']) as String?;
    if (chatId != null && otherUid != null) {
      onNavigate(chatId, otherUid);
    }
  }
}
