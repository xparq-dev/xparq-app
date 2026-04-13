// lib/core/security/input_validator.dart
//
// Client-side input validation — mirrors server-side Firestore rule constraints.
// Centralised here so all validation logic is consistent across screens.

class InputValidator {
  // ── Character Limits (must match firestore.rules) ─────────────────────────

  static const int maxXparqNameLen = 32;
  static const int maxBioLen = 300;
  static const int maxConstellations = 10;
  static const int maxConstellationTagLen = 32;
  static const int maxMessageLen = 4096;
  static const int maxReportDetailLen = 500;

  // ── Name Validation ───────────────────────────────────────────────────────

  static String? xparqName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'XPARQ name is required.';
    }
    final trimmed = value.trim();
    if (trimmed.length < 3) return 'XPARQ name must be at least 3 characters.';
    if (trimmed.length > maxXparqNameLen) {
      return 'XPARQ name must be ≤ $maxXparqNameLen characters.';
    }

    // Only allow letters, numbers, underscores, dots, hyphens
    final valid = RegExp(r'^[\w.\-]+$');
    if (!valid.hasMatch(trimmed)) {
      return 'Only letters, numbers, _, . and - are allowed.';
    }
    // No consecutive special chars
    if (trimmed.contains('..') ||
        trimmed.contains('__') ||
        trimmed.contains('--')) {
      return 'No consecutive special characters.';
    }
    return null;
  }

  // ── Bio Validation ────────────────────────────────────────────────────────

  static String? bio(String? value) {
    if (value == null) return null; // Bio is optional
    if (value.length > maxBioLen) return 'Bio must be ≤ $maxBioLen characters.';
    // Strip potential XSS (no <script> etc.) — client-side hint only
    if (value.contains('<') || value.contains('>')) {
      return 'HTML tags are not allowed in bio.';
    }
    return null;
  }

  // ── Constellation Tag ─────────────────────────────────────────────────────

  static String? constellationTag(String? value) {
    if (value == null || value.trim().isEmpty) return 'Tag cannot be empty.';
    final trimmed = value.trim();
    if (trimmed.length > maxConstellationTagLen) {
      return 'Tag must be ≤ $maxConstellationTagLen characters.';
    }
    return null;
  }

  static String? constellationList(List<String> tags) {
    if (tags.length > maxConstellations) {
      return 'Maximum $maxConstellations constellations allowed.';
    }
    for (final tag in tags) {
      final err = constellationTag(tag);
      if (err != null) return err;
    }
    return null;
  }

  // ── Email ─────────────────────────────────────────────────────────────────

  static String? email(String? value) {
    if (value == null || value.trim().isEmpty) return 'Email is required.';
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$',
    );
    if (!emailRegex.hasMatch(value.trim())) {
      return 'Enter a valid email address.';
    }
    return null;
  }

  // ── Password ──────────────────────────────────────────────────────────────

  static String? password(String? value) {
    if (value == null || value.isEmpty) return 'Password is required.';
    if (value.length < 8) return 'Password must be at least 8 characters.';
    if (!RegExp(r'[A-Z]').hasMatch(value)) {
      return 'Include at least one uppercase letter.';
    }
    if (!RegExp(r'[0-9]').hasMatch(value)) {
      return 'Include at least one number.';
    }
    return null;
  }

  // ── Phone Number ──────────────────────────────────────────────────────────

  static String? phoneNumber(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Phone number is required.';
    }
    final phone = value.trim().replaceAll(' ', '');
    // E.164 format: + followed by 7-15 digits
    if (!RegExp(r'^\+[1-9]\d{6,14}$').hasMatch(phone)) {
      return 'Enter a valid international phone number (e.g. +66812345678)';
    }
    return null;
  }

  // ── OTP ───────────────────────────────────────────────────────────────────

  static String? otp(String? value) {
    if (value == null || value.trim().isEmpty) return 'OTP code is required.';
    if (!RegExp(r'^\d{6}$').hasMatch(value.trim())) {
      return 'OTP must be 6 digits.';
    }
    return null;
  }

  // ── Chat Message ──────────────────────────────────────────────────────────

  static String? chatMessage(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null; // Empty = don't send
    }
    if (value.trim().length > maxMessageLen) {
      return 'Message too long (max $maxMessageLen chars).';
    }
    return null;
  }

  // ── Report Detail ─────────────────────────────────────────────────────────

  static String? reportDetail(String? value) {
    if (value == null || value.isEmpty) return null; // Optional
    if (value.length > maxReportDetailLen) {
      return 'Detail too long (max $maxReportDetailLen chars).';
    }
    return null;
  }
}
