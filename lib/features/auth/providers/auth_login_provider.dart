import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xparq_app/shared/errors/app_exception.dart';
import 'package:xparq_app/features/auth/models/user_model.dart';
import 'package:xparq_app/features/auth/repositories/auth_repository.dart';
import 'package:xparq_app/features/auth/services/auth_service.dart';

final authLoginRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository();
});

final authLoginServiceProvider = Provider<AuthService>((ref) {
  return AuthService(ref.read(authLoginRepositoryProvider));
});

@immutable
class AuthLoginState {
  final bool isLoading;
  final UserModel? user;
  final String? errorMessage;

  const AuthLoginState({this.isLoading = false, this.user, this.errorMessage});

  bool get isAuthenticated => user != null;

  AuthLoginState copyWith({
    bool? isLoading,
    UserModel? user,
    bool clearUser = false,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AuthLoginState(
      isLoading: isLoading ?? this.isLoading,
      user: clearUser ? null : (user ?? this.user),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class AuthProvider extends StateNotifier<AuthLoginState> {
  AuthProvider(this._service) : super(const AuthLoginState());

  final AuthService _service;

  Future<void> login({required String email, required String password}) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final user = await _service.login(email: email, password: password);

      state = state.copyWith(isLoading: false, user: user, clearError: true);
    } on AppException catch (error) {
      state = state.copyWith(isLoading: false, errorMessage: error.message);
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'An unexpected error occurred. Please try again.',
      );
    }
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }

  void reset() {
    state = const AuthLoginState();
  }
}

final authLoginProvider =
    StateNotifierProvider.autoDispose<AuthProvider, AuthLoginState>((ref) {
      return AuthProvider(ref.read(authLoginServiceProvider));
    });
