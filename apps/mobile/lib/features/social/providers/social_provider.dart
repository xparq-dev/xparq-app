import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xparq_app/shared/errors/app_exception.dart';
import 'package:xparq_app/features/social/models/post_model.dart';
import 'package:xparq_app/features/social/repositories/social_repository.dart';
import 'package:xparq_app/features/social/services/social_service.dart';

final socialRepositoryProvider = Provider<SocialRepository>((ref) {
  return SocialRepository();
});

final socialServiceProvider = Provider<SocialService>((ref) {
  return SocialService(ref.read(socialRepositoryProvider));
});

@immutable
class SocialState {
  final List<Post> posts;
  final bool isLoading;
  final bool isCreating;
  final String? errorMessage;
  final String? successMessage;

  const SocialState({
    this.posts = const <Post>[],
    this.isLoading = false,
    this.isCreating = false,
    this.errorMessage,
    this.successMessage,
  });

  SocialState copyWith({
    List<Post>? posts,
    bool? isLoading,
    bool? isCreating,
    String? errorMessage,
    bool clearError = false,
    String? successMessage,
    bool clearSuccess = false,
  }) {
    return SocialState(
      posts: posts ?? this.posts,
      isLoading: isLoading ?? this.isLoading,
      isCreating: isCreating ?? this.isCreating,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      successMessage: clearSuccess
          ? null
          : (successMessage ?? this.successMessage),
    );
  }
}

class SocialProvider extends StateNotifier<SocialState> {
  SocialProvider(this._service) : super(const SocialState());

  final SocialService _service;

  Future<void> loadFeed() async {
    state = state.copyWith(
      isLoading: true,
      clearError: true,
      clearSuccess: true,
    );

    try {
      final posts = await _service.getFeed();
      state = state.copyWith(posts: posts, isLoading: false, clearError: true);
    } on AppException catch (error) {
      state = state.copyWith(isLoading: false, errorMessage: error.message);
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Unable to load the feed.',
      );
    }
  }

  Future<void> createPost({
    required String content,
    required String userId,
  }) async {
    state = state.copyWith(
      isCreating: true,
      clearError: true,
      clearSuccess: true,
    );

    try {
      final post = await _service.createPost(content: content, userId: userId);

      state = state.copyWith(
        posts: <Post>[post, ...state.posts],
        isCreating: false,
        successMessage: 'Post created successfully.',
        clearError: true,
      );
    } on AppException catch (error) {
      state = state.copyWith(isCreating: false, errorMessage: error.message);
    } catch (_) {
      state = state.copyWith(
        isCreating: false,
        errorMessage: 'Unable to create the post.',
      );
    }
  }

  void clearMessages() {
    state = state.copyWith(clearError: true, clearSuccess: true);
  }
}

final socialProvider =
    StateNotifierProvider.autoDispose<SocialProvider, SocialState>((ref) {
      return SocialProvider(ref.read(socialServiceProvider));
    });
