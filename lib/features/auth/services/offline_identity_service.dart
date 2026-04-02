// lib/features/auth/services/offline_identity_service.dart
//
// Manages the anonymous temp ID used in Offline Mesh Mode.
// No DOB is collected; the device UUID is used as a temp identifier.
// When the user goes online, they are prompted to verify their DOB.

import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:xparq_app/core/constants/app_constants.dart';
import 'package:xparq_app/core/enums/age_group.dart';

class OfflineIdentityService {
  static const _uuid = Uuid();

  /// Get or create a persistent device-level temp ID for offline mesh.
  static Future<String> getOrCreateTempId() async {
    final prefs = await SharedPreferences.getInstance();
    String? tempId = prefs.getString(AppConstants.offlineTempIdKey);
    if (tempId == null) {
      tempId = _uuid.v4();
      await prefs.setString(AppConstants.offlineTempIdKey, tempId);
    }
    return tempId;
  }

  /// Clear the temp ID (e.g., on full logout or account deletion).
  static Future<void> clearTempId() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConstants.offlineTempIdKey);
  }

  /// In offline mode, unregistered users are always treated as CADET (restricted).
  static AgeGroup get offlineDefaultAgeGroup => AgeGroup.cadet;
}
