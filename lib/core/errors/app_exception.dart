// lib/core/errors/app_exception.dart
//
// Typed exception hierarchy for XPARQ App.
// Use these instead of raw Exception/String throws for better error handling.

/// Base class for all XPARQ application exceptions.
class AppException implements Exception {
  final String message;
  final Object? cause;

  const AppException(this.message, {this.cause});

  @override
  String toString() => 'AppException: $message${cause != null ? ' (cause: $cause)' : ''}';
}

/// Thrown when an authentication operation fails.
class AuthException extends AppException {
  const AuthException(super.message, {super.cause});

  @override
  String toString() => 'AuthException: $message';
}

/// Thrown when a network request fails.
class NetworkException extends AppException {
  final int? statusCode;

  const NetworkException(super.message, {this.statusCode, super.cause});

  @override
  String toString() =>
      'NetworkException: $message${statusCode != null ? ' [HTTP $statusCode]' : ''}';
}

/// Thrown when user-provided input fails validation.
class ValidationException extends AppException {
  final String field;

  const ValidationException(super.message, {required this.field, super.cause});

  @override
  String toString() => 'ValidationException on "$field": $message';
}

/// Thrown when a required record is not found in the data source.
class NotFoundException extends AppException {
  const NotFoundException(super.message, {super.cause});

  @override
  String toString() => 'NotFoundException: $message';
}

/// Thrown when the user does not have permission to perform an action.
class PermissionException extends AppException {
  const PermissionException(super.message, {super.cause});

  @override
  String toString() => 'PermissionException: $message';
}

/// Thrown when an encryption or decryption operation fails.
class EncryptionException extends AppException {
  const EncryptionException(super.message, {super.cause});

  @override
  String toString() => 'EncryptionException: $message';
}
