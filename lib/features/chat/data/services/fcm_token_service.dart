// lib/core/services/fcm_token_service.dart
//
// Handles FCM token acquisition, upload to Supabase, and retry logic.
// Extracted from notification_service.dart for single responsibility.

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FcmTokenService {
  FcmTokenService._();
  static final FcmTokenService instance = FcmTokenService._();

  bool _isFirebaseAvailable = true;
  bool _isFirebaseGloballyDisabled = false;

  bool get isFirebaseAvailable => _isFirebaseAvailable;
  bool get isFirebaseGloballyDisabled => _isFirebaseGloballyDisabled;

  void disableFirebase() => _isFirebaseGloballyDisabled = true;
  void markUnavailable() => _isFirebaseAvailable = false;

  /// Retrieves the FCM token and uploads it to Supabase with retry logic.
  /// Retries up to [maxRetries] times with exponential backoff.
  Future<void> uploadToken({int maxRetries = 5}) async {
    if (_isFirebaseGloballyDisabled) {
      debugPrint('[FcmTokenService] Firebase globally disabled, skipping upload.');
      return;
    }

    String? token;

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      if (!_isFirebaseAvailable) {
        debugPrint('[FcmTokenService] Firebase unavailable, skipping.');
        return;
      }

      try {
        final fcm = _getFcm();
        if (fcm == null) return;

        final settings = await fcm.getNotificationSettings();
        if (settings.authorizationStatus == AuthorizationStatus.denied) {
          debugPrint('[FcmTokenService] Notifications denied. Skipping upload.');
          return;
        }

        token = await fcm.getToken();
        if (token != null && token.isNotEmpty) {
          debugPrint(
            '[FcmTokenService] Token acquired on attempt $attempt: ${token.substring(0, 20)}...',
          );
          break;
        }

        debugPrint('[FcmTokenService] Token null on attempt $attempt/$maxRetries.');
      } catch (e) {
        final errorMsg = e.toString();
        if (errorMsg.contains('FIS_AUTH_ERROR')) {
          debugPrint('[FcmTokenService] FIS_AUTH_ERROR — disabling Firebase.');
          _isFirebaseGloballyDisabled = true;
          break;
        }
        debugPrint('[FcmTokenService] Error on attempt $attempt: $errorMsg');
        if (_isFirebaseGloballyDisabled) break;
      }

      if (attempt < maxRetries) {
        final delay = Duration(seconds: (2 << (attempt - 1)).clamp(2, 30));
        await Future.delayed(delay);
      }
    }

    if (token == null || token.isEmpty) {
      debugPrint('[FcmTokenService] ⚠️ Failed to get FCM token after $maxRetries attempts.');
      return;
    }

    await _saveTokenToSupabase(token);
  }

  /// Listens for token refreshes and re-uploads automatically.
  void listenForTokenRefresh() {
    try {
      _getFcm()?.onTokenRefresh.listen(
        (token) async {
          debugPrint('[FcmTokenService] Token refreshed: ${token.substring(0, 20)}...');
          await _saveTokenToSupabase(token);
        },
        onError: (e) {
          debugPrint('[FcmTokenService] Token refresh error: $e');
          if (e.toString().contains('FIS_AUTH_ERROR')) {
            _isFirebaseGloballyDisabled = true;
          }
        },
      );
    } catch (e) {
      debugPrint('[FcmTokenService] Error setting up tokenRefresh listener: $e');
    }
  }

  Future<void> _saveTokenToSupabase(String token) async {
    try {
      final uid = Supabase.instance.client.auth.currentUser?.id;
      if (uid == null) {
        debugPrint('[FcmTokenService] Cannot save token: User not logged in.');
        return;
      }

      final existing = await Supabase.instance.client
          .from('profiles')
          .select('fcm_token')
          .eq('id', uid)
          .maybeSingle();

      final currentSaved = existing?['fcm_token'] as String?;
      if (currentSaved == token) {
        debugPrint('[FcmTokenService] Token already up-to-date. Skipping.');
        return;
      }

      await Supabase.instance.client
          .from('profiles')
          .update({'fcm_token': token})
          .eq('id', uid);

      debugPrint('[FcmTokenService] ✅ Token synced for uid: $uid');
    } catch (e) {
      debugPrint('[FcmTokenService] Error saving token: $e');
    }
  }

  FirebaseMessaging? _getFcm() {
    try {
      return FirebaseMessaging.instance;
    } catch (e) {
      debugPrint('[FcmTokenService] Error accessing FirebaseMessaging: $e');
      _isFirebaseAvailable = false;
      return null;
    }
  }
}
