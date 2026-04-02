class ChatValidator {
  static const int maxMessageLen = 4096;

  static String? message(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    if (value.trim().length > maxMessageLen) {
      return 'Message too long.';
    }
    return null;
  }
}