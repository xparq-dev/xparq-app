// lib/core/extensions/string_extensions.dart

extension StringExtensions on String {
  /// Capitalizes the first letter of the string.
  String get capitalize {
    if (isEmpty) return this;
    return this[0].toUpperCase() + substring(1);
  }

  /// Returns true if the string is a valid email address.
  bool get isValidEmail {
    return RegExp(r'^[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$')
        .hasMatch(trim());
  }

  /// Truncates the string to [maxLength] characters, appending [ellipsis] if truncated.
  String truncate(int maxLength, {String ellipsis = '...'}) {
    if (length <= maxLength) return this;
    return '${substring(0, maxLength)}$ellipsis';
  }

  /// Returns null if the string is empty, otherwise returns itself.
  String? get orNull => isEmpty ? null : this;

  /// Returns true if the string is a valid URL.
  bool get isValidUrl {
    return Uri.tryParse(this)?.hasAbsolutePath ?? false;
  }
}

extension NullableStringExtensions on String? {
  /// Returns true if the string is null or empty.
  bool get isNullOrEmpty => this == null || this!.isEmpty;

  /// Returns the string or a fallback if null/empty.
  String orDefault(String fallback) =>
      isNullOrEmpty ? fallback : this!;
}
