// lib/core/errors/failure.dart
//
// Sealed Failure class for use in Result types.
// Provides a consistent way to surface errors from repositories to the UI layer.

sealed class Failure {
  final String message;
  const Failure(this.message);
}

/// Represents an authentication failure (login, logout, session expired).
final class AuthFailure extends Failure {
  const AuthFailure(super.message);
}

/// Represents a server-side or HTTP failure.
final class ServerFailure extends Failure {
  final int? statusCode;
  const ServerFailure(super.message, {this.statusCode});
}

/// Represents a network connectivity failure (no internet, timeout).
final class NetworkFailure extends Failure {
  const NetworkFailure(super.message);
}

/// Represents a failure caused by invalid input data.
final class ValidationFailure extends Failure {
  final String field;
  const ValidationFailure(super.message, {required this.field});
}

/// Represents a failure where a requested resource was not found.
final class NotFoundFailure extends Failure {
  const NotFoundFailure(super.message);
}

/// Represents an encryption or decryption failure.
final class EncryptionFailure extends Failure {
  const EncryptionFailure(super.message);
}

/// Represents an unexpected/unclassified failure.
final class UnknownFailure extends Failure {
  final Object? cause;
  const UnknownFailure(super.message, {this.cause});
}
