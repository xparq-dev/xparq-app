import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xparq_app/shared/errors/app_exception.dart';
import 'package:xparq_app/features/profile/models/user_model.dart';
import 'package:xparq_app/features/profile/repositories/profile_repository.dart';
import 'package:xparq_app/features/profile/services/profile_service.dart';

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository();
});

final profileServiceProvider = Provider<ProfileService>((ref) {
  return ProfileService(ref.read(profileRepositoryProvider));
});

@immutable
class ProfileState {
  final UserModel? user;
  final bool isLoading;
  final bool isUpdating;
  final String? errorMessage;
  final String? successMessage;

  const ProfileState({
    this.user,
    this.isLoading = false,
    this.isUpdating = false,
    this.errorMessage,
    this.successMessage,
  });

  ProfileState copyWith({
    UserModel? user,
    bool clearUser = false,
    bool? isLoading,
    bool? isUpdating,
    String? errorMessage,
    bool clearError = false,
    String? successMessage,
    bool clearSuccess = false,
  }) {
    return ProfileState(
      user: clearUser ? null : (user ?? this.user),
      isLoading: isLoading ?? this.isLoading,
      isUpdating: isUpdating ?? this.isUpdating,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      successMessage: clearSuccess
          ? null
          : (successMessage ?? this.successMessage),
    );
  }
}

class ProfileProvider extends StateNotifier<ProfileState> {
  ProfileProvider(this._service) : super(const ProfileState());

  final ProfileService _service;

  Future<void> load({required String id}) async {
    state = state.copyWith(
      isLoading: true,
      clearError: true,
      clearSuccess: true,
    );

    try {
      final user = await _service.getProfile(id: id);
      
      // Guard: do not replace valid cached profile with an empty placeholder
      final isIncomingEmpty = user.name.isEmpty && user.bio.isEmpty;
      final isCachedValid = state.user != null && 
          (state.user!.name.isNotEmpty || state.user!.bio.isNotEmpty);

      if (isCachedValid && isIncomingEmpty) {
        // Keep existing valid profile, just clear loading
        state = state.copyWith(isLoading: false, clearError: true);
      } else {
        // Normal update
        state = state.copyWith(user: user, isLoading: false, clearError: true);
      }
    } on AppException catch (error) {
      state = state.copyWith(isLoading: false, errorMessage: error.message);
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Unable to load the profile.',
      );
    }
  }

  Future<void> update({
    required String id,
    required String name,
    required String bio,
  }) async {
    state = state.copyWith(
      isUpdating: true,
      clearError: true,
      clearSuccess: true,
    );

    try {
      final user = await _service.update(id: id, name: name, bio: bio);

      state = state.copyWith(
        user: user,
        isUpdating: false,
        successMessage: 'Profile updated successfully.',
        clearError: true,
      );
    } on AppException catch (error) {
      state = state.copyWith(isUpdating: false, errorMessage: error.message);
    } catch (_) {
      state = state.copyWith(
        isUpdating: false,
        errorMessage: 'Unable to update the profile.',
      );
    }
  }

  void clearMessages() {
    state = state.copyWith(clearError: true, clearSuccess: true);
  }
}

final profileProvider = StateNotifierProvider.autoDispose
    .family<ProfileProvider, ProfileState, String>((ref, userId) {
      return ProfileProvider(ref.read(profileServiceProvider));
    });
