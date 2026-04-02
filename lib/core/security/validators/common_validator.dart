class CommonValidator {
  static String? phoneNumber(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Phone number is required.';
    }

    final phone = value.trim().replaceAll(' ', '');

    if (!RegExp(r'^\+[1-9]\d{6,14}$').hasMatch(phone)) {
      return 'Invalid phone number.';
    }

    return null;
  }
}