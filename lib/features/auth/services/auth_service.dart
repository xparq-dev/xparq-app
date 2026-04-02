import 'package:xparq_app/core/errors/app_exception.dart';
import 'package:xparq_app/core/security/input_validator.dart';
import 'package:xparq_app/features/auth/models/user_model.dart';
import 'package:xparq_app/features/auth/repositories/auth_repository.dart';

class AuthService {
  const AuthService(this._repository);

  final AuthRepository _repository;

  Future<UserModel> login({
    required String email,
    required String password,

    /// 🔥 localization messages inject
    required String emailRequiredMessage,
    required String emailInvalidMessage,
    required String passwordRequiredMessage,
    required String genericErrorMessage,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    final normalizedPassword = password.trim();

    // 🔥 ใช้ InputValidator (ลบ duplicate logic)
    final emailError = InputValidator.email(normalizedEmail);
    if (emailError != null) {
      throw ValidationException(
        emailError.isEmpty ? emailRequiredMessage : emailInvalidMessage,
        field: 'email',
      );
    }

    final passwordError = InputValidator.password(normalizedPassword);
    if (passwordError != null) {
      throw ValidationException(
        passwordRequiredMessage,
        field: 'password',
      );
    }

    try {
      return await _repository.login(
        email: normalizedEmail,
        password: normalizedPassword,
      );
    } on AuthException {
      rethrow;
    } on ValidationException {
      rethrow;
    } on AppException catch (e) {
      // 🔥 map domain error
      throw _mapAuthError(e, genericErrorMessage);
    } catch (error) {
      throw AuthException(genericErrorMessage, cause: error);
    }
  }

  // ======================
  // Error Mapping
  // ======================

  AuthException _mapAuthError(
    AppException error,
    String fallbackMessage,
  ) {
    final message = error.message.toLowerCase();

    if (message.contains('invalid') ||
        message.contains('wrong password')) {
      return AuthException('Invalid email or password.');
    }

    if (message.contains('not found')) {
      return AuthException('Account not found.');
    }

    if (message.contains('network')) {
      return AuthException('Network error. Please try again.');
    }

    return AuthException(fallbackMessage, cause: error);
  }
}