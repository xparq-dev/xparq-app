class UserValidator {
  static const int maxNameLen = 32;
  static const int maxBioLen = 300;

  static String? xparqName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'XPARQ name is required.';
    }

    final trimmed = value.trim();

    if (trimmed.length < 3) return 'At least 3 characters.';
    if (trimmed.length > maxNameLen) {
      return 'Max $maxNameLen characters.';
    }

    final valid = RegExp(r'^[\w.\-]+$');
    if (!valid.hasMatch(trimmed)) {
      return 'Invalid characters.';
    }

    return null;
  }

  static String? bio(String? value) {
    if (value == null) return null;
    if (value.length > maxBioLen) return 'Too long.';
    if (value.contains('<') || value.contains('>')) {
      return 'HTML not allowed.';
    }
    return null;
  }
}