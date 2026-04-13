// lib/features/auth/services/age_gating_service.dart

import 'package:xparq_app/shared/constants/app_constants.dart';
import 'package:xparq_app/shared/enums/age_group.dart';

/// AgeGatingService
/// Centralizes all age-related calculations and gating decisions.
/// NOTE: Client-side checks are UX only. Server-side Cloud Functions
/// perform the authoritative validation.
class AgeGatingService {
  AgeGatingService._();

  /// Calculate age in years from a given [birthDate].
  static int calculateAge(DateTime birthDate) {
    final today = DateTime.now();
    int age = today.year - birthDate.year;
    // Adjust if birthday hasn't occurred yet this year
    if (today.month < birthDate.month ||
        (today.month == birthDate.month && today.day < birthDate.day)) {
      age--;
    }
    return age;
  }

  /// Determine [AgeGroup] from [birthDate].
  ///
  /// - < 13  → [AgeGroup.blocked]
  /// - 13–17 → [AgeGroup.cadet]
  /// - 18+   → [AgeGroup.explorer]
  static AgeGroup calculateAgeGroup(DateTime birthDate) {
    final age = calculateAge(birthDate);
    if (age < AppConstants.minimumAge) return AgeGroup.blocked;
    if (age < AppConstants.adultAge) return AgeGroup.cadet;
    return AgeGroup.explorer;
  }

  /// Returns true if the user can view or send sensitive (NSFW) content.
  static bool canViewSensitive({
    required AgeGroup ageGroup,
    required bool nsfwOptIn,
  }) {
    return ageGroup == AgeGroup.explorer && nsfwOptIn;
  }

  /// Validate DOB input from the registration form.
  /// Returns an error string, or null if valid.
  static String? validateDob(DateTime? dob) {
    if (dob == null) return 'Please select your date of birth.';
    final group = calculateAgeGroup(dob);
    if (group == AgeGroup.blocked) {
      return 'You must be at least ${AppConstants.minimumAge} years old to join the galaxy.';
    }
    // Sanity check: DOB cannot be in the future
    if (dob.isAfter(DateTime.now())) {
      return 'Date of birth cannot be in the future.';
    }
    // Sanity check: DOB cannot be more than 120 years ago
    if (calculateAge(dob) > 120) {
      return 'Please enter a valid date of birth.';
    }
    return null;
  }

  /// Check if a birthday transition has occurred (Cadet → Explorer).
  /// Returns the new [AgeGroup] if changed, otherwise null.
  static AgeGroup? checkBirthdayTransition({
    required DateTime birthDate,
    required AgeGroup currentGroup,
  }) {
    final newGroup = calculateAgeGroup(birthDate);
    if (newGroup != currentGroup) return newGroup;
    return null;
  }

  /// Maximum selectable date for DOB picker (today - minimum age).
  static DateTime get maxDobDate {
    final now = DateTime.now();
    return DateTime(now.year - AppConstants.minimumAge, now.month, now.day);
  }

  /// Minimum selectable date for DOB picker (today - 120 years).
  static DateTime get minDobDate {
    final now = DateTime.now();
    return DateTime(now.year - 120, now.month, now.day);
  }
}
