class ReportValidator {
  static const int maxDetailLen = 500;

  static String? detail(String? value) {
    if (value == null || value.isEmpty) return null;
    if (value.length > maxDetailLen) {
      return 'Detail too long.';
    }
    return null;
  }
}