// lib/core/services/privacy_service.dart

import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PrivacyService {
  static final PrivacyService instance = PrivacyService._();
  PrivacyService._();

  final LocalAuthentication _auth = LocalAuthentication();
  static const _kScreenLockEnabled = 'privacy_screen_lock_enabled';

  /// Checks if biometric or PIN authentication is available on this device.
  Future<bool> isBiometricAvailable() async {
    try {
      final bool canAuthenticateWithBiometrics = await _auth.canCheckBiometrics;
      final bool canAuthenticate =
          canAuthenticateWithBiometrics || await _auth.isDeviceSupported();
      return canAuthenticate;
    } catch (e) {
      debugPrint('[PrivacyService] Error checking biometric availability: $e');
      return false;
    }
  }

  /// Attempts to authenticate the user.
  Future<bool> authenticate({required String reason}) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
        ),
      );
    } catch (e) {
      debugPrint('[PrivacyService] Authentication error: $e');
      return false;
    }
  }

  /// Gets the user's preference for screen lock.
  Future<bool> isScreenLockEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kScreenLockEnabled) ?? false;
  }

  /// Sets the user's preference for screen lock.
  Future<void> setScreenLockEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kScreenLockEnabled, enabled);
  }
}
