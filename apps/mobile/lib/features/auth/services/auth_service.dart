import 'package:xparq_app/shared/errors/app_exception.dart';
import 'package:xparq_app/features/auth/models/user_model.dart';
import 'package:xparq_app/features/auth/repositories/auth_repository.dart';

class AuthService {
  const AuthService(this._repository);

  final AuthRepository _repository;

  Future<UserModel> login({
    required String email,
    required String password,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    final normalizedPassword = password.trim();

    if (normalizedEmail.isEmpty) {
      throw const ValidationException('Email is required.', field: 'email');
    }

    if (!_isValidEmail(normalizedEmail)) {
      throw const ValidationException(
        'Please enter a valid email address.',
        field: 'email',
      );
    }

    if (normalizedPassword.isEmpty) {
      throw const ValidationException(
        'Password is required.',
        field: 'password',
      );
    }

    try {
      return await _repository.login(
        email: normalizedEmail,
        password: normalizedPassword,
      );
    } on AppException {
      rethrow;
    } catch (error) {
      throw AuthException('Unable to complete login right now.', cause: error);
    }
  }

  bool _isValidEmail(String email) {
    final emailExpression = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    return emailExpression.hasMatch(email);
  }
}
