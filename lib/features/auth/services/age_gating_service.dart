import 'package:xparq_app/core/constants/app_constants.dart';
import 'package:xparq_app/core/enums/age_group.dart';

/// AgeGatingService (v2)
/// - Timezone safe
/// - Localization ready
/// - Clean API
/// - Optional caching

class AgeGatingService {
  AgeGatingService._();

  static int? _cachedAge;
  static DateTime? _cachedDob;

  /// 🔥 Inject current date (timezone-safe)
  static int calculateAge(
    DateTime birthDate, {
    DateTime? now,
  }) {
    final today = now ?? DateTime.now();

    int age = today.year - birthDate.year;

    if (today.month < birthDate.month ||
        (today.month == birthDate.month &&
            today.day < birthDate.day)) {
      age--;
    }

    return age;
  }

  /// 🔥 Cached version (optional optimization)
  static int calculateAgeCached(
    DateTime birthDate, {
    DateTime? now,
  }) {
    if (_cachedDob == birthDate && _cachedAge != null) {
      return _cachedAge!;
    }

    final age = calculateAge(birthDate, now: now);
    _cachedDob = birthDate;
    _cachedAge = age;

    return age;
  }

  static AgeGroup calculateAgeGroup(
    DateTime birthDate, {
    DateTime? now,
  }) {
    final age = calculateAge(birthDate, now: now);

    if (age < AppConstants.minimumAge) return AgeGroup.blocked;
    if (age < AppConstants.adultAge) return AgeGroup.cadet;
    return AgeGroup.explorer;
  }

  /// 🔥 Clean API (ใช้ง่ายขึ้น)
  static bool isAdult(DateTime birthDate, {DateTime? now}) {
    return calculateAgeGroup(birthDate, now: now) ==
        AgeGroup.explorer;
  }

  static bool canViewSensitive({
    required AgeGroup ageGroup,
    required bool nsfwOptIn,
  }) {
    return ageGroup == AgeGroup.explorer && nsfwOptIn;
  }

  /// 🔥 Localization-ready validator
  /// ส่ง message จาก UI layer เข้ามาแทน hardcode
  static String? validateDob(
    DateTime? dob, {
    required String requiredMessage,
    required String underAgeMessage,
    required String futureMessage,
    required String invalidMessage,
    DateTime? now,
  }) {
    final today = now ?? DateTime.now();

    if (dob == null) return requiredMessage;

    if (dob.isAfter(today)) return futureMessage;

    final age = calculateAge(dob, now: today);

    if (age > 120) return invalidMessage;

    if (age < AppConstants.minimumAge) {
      return underAgeMessage;
    }

    return null;
  }

  static AgeGroup? checkBirthdayTransition({
    required DateTime birthDate,
    required AgeGroup currentGroup,
    DateTime? now,
  }) {
    final newGroup = calculateAgeGroup(birthDate, now: now);
    if (newGroup != currentGroup) return newGroup;
    return null;
  }

  /// 🔥 Date picker helpers
  static DateTime getMaxDobDate({DateTime? now}) {
    final today = now ?? DateTime.now();
    return DateTime(
      today.year - AppConstants.minimumAge,
      today.month,
      today.day,
    );
  }

  static DateTime getMinDobDate({DateTime? now}) {
    final today = now ?? DateTime.now();
    return DateTime(
      today.year - 120,
      today.month,
      today.day,
    );
  }

  /// 🔥 clear cache (optional)
  static void clearCache() {
    _cachedAge = null;
    _cachedDob = null;
  }
}