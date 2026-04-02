import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';

class NavigationPersistenceService {
  static const String _keyLastLocation = 'last_nav_location';
  static const String _keySessionActive = 'is_session_active';
  static const String _keyLastActiveTime = 'last_active_time';

  final SharedPreferences _prefs;

  NavigationPersistenceService(this._prefs);

  /// Saves the current location to persistent storage.
  Future<void> saveLocation(String location) async {
    debugPrint('NAV_PERSIST: Saving location: $location');
    await _prefs.setString(_keyLastLocation, location);
    await _prefs.setInt(
      _keyLastActiveTime,
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  /// Gets the last saved location, or null if none exists.
  String? getLastLocation() {
    return _prefs.getString(_keyLastLocation);
  }

  /// Sets the session as "Active". This is used to detect "Swipe Away".
  /// If the app starts and this was already true, it means it wasn't closed gracefully
  /// (or it was an OS kill).
  Future<void> setSessionActive(bool active) async {
    debugPrint('NAV_PERSIST: Setting session active: $active');
    await _prefs.setBool(_keySessionActive, active);
  }

  /// Checks if the previous session was potentially "Swiped away".
  /// On most OSs, when swiped away, the app is killed immediately.
  /// If we find [is_session_active] is true BUT [last_active_time] is very old,
  /// it might be an OS kill.
  /// If it's fresh, we restore.
  bool shouldRestore() {
    final sessionActive = _prefs.getBool(_keySessionActive) ?? false;
    final lastActive = _prefs.getInt(_keyLastActiveTime) ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;

    // If session wasn't active, it was a clean exit or first run
    if (!sessionActive) return false;

    // If it was swiped away recently (or OS killed it recently), restore.
    // If it's been more than 12 hours, start fresh anyway.
    final horizontalGap = now - lastActive;
    if (horizontalGap > 12 * 60 * 60 * 1000) {
      return false;
    }

    return true;
  }

  /// Clears the saved location.
  Future<void> clear() async {
    await _prefs.remove(_keyLastLocation);
    await _prefs.setBool(_keySessionActive, false);
  }
}
