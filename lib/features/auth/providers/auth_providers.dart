// ======================
// IMPORTS
// ======================
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:xparq_app/core/sync/sync_manager.dart';
import 'package:xparq_app/core/sync/sync_item.dart';
import 'package:xparq_app/core/errors/app_exception.dart';
import 'package:xparq_app/features/auth/repositories/supabase_auth_repository.dart';

// ======================
// PROVIDERS
// ======================
final authRepositoryProvider = Provider<SupabaseAuthRepository>((ref) {
  return SupabaseAuthRepository();
});

final isLoginFlowProvider = StateProvider<bool>((ref) => false);

// ======================
// STATE
// ======================
class AuthState {
  final bool isLoading;
  final String? errorMessage;
  final AuthStep step;

  const AuthState({
    this.isLoading = false,
    this.errorMessage,
    this.step = AuthStep.initial,
  });

  AuthState copyWith({
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
    AuthStep? step,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      step: step ?? this.step,
    );
  }
}

enum AuthStep {
  initial,
  complete,
}

// ======================
// NOTIFIER
// ======================
class AuthNotifier extends StateNotifier<AuthState> {
  final SupabaseAuthRepository _repository;
  final Ref _ref;

  AuthNotifier(this._repository, this._ref)
      : super(const AuthState());

  // ======================
  // 🔥 LOGIN (FINAL VERSION)
  // ======================
  Future<void> signInWithEmailPassword({
    required String email,
    required String password,
  }) async {
    state = state.copyWith(
      isLoading: true,
      clearError: true,
    );

    try {
      // 🔥 OFFLINE-FIRST
      SyncManager.instance.addEvent(
        type: SyncActionType.login,
        payload: {
          'email': email,
          'password': password,
        },
      );

      // 🔥 ONLINE CALL
      final response = await _repository.signInWithEmail(
        email: email.trim(),
        password: password,
      );

      if (response.user != null) {
        _ref.read(isLoginFlowProvider.notifier).state = true;

        state = state.copyWith(
          isLoading: false,
          step: AuthStep.complete,
          clearError: true,
        );
      } else {
        throw AuthException('Invalid login credentials');
      }

    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: _mapError(e),
      );
    }
  }

  // ======================
  // ERROR MAP
  // ======================
  String _mapError(Object e) {
    final errorStr = e.toString().toLowerCase();

    if (errorStr.contains('network')) {
      return 'Network error';
    }

    if (e is AuthException) {
      return e.message;
    }

    return 'Something went wrong';
  }
}

// ======================
// PROVIDER
// ======================
final authNotifierProvider =
    StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref.watch(authRepositoryProvider), ref);
});