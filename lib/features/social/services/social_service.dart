import 'package:xparq_app/core/errors/app_exception.dart';
import 'package:xparq_app/core/security/input_validator.dart';
import 'package:xparq_app/features/social/models/post_model.dart';
import 'package:xparq_app/features/social/repositories/social_repository.dart';

class SocialService {
  const SocialService(this._repository);

  final SocialRepository _repository;

  Future<List<Post>> getFeed() async {
    try {
      return await _repository.getFeed();
    } on AppException {
      rethrow;
    } catch (error) {
      throw AppException('Unable to load the feed.', cause: error);
    }
  }

  Future<Post> createPost({
    required String content,
    required String userId,
  }) async {
    final normalizedContent = content.trim();
    final normalizedUserId = userId.trim();

    if (normalizedUserId.isEmpty) {
      throw const ValidationException('User id is required.', field: 'userId');
    }

    final contentValidation = InputValidator.chatMessage(normalizedContent);
    if (normalizedContent.isEmpty) {
      throw const ValidationException(
        'Post content cannot be empty.',
        field: 'content',
      );
    }
    if (contentValidation != null) {
      throw ValidationException(contentValidation, field: 'content');
    }

    try {
      return await _repository.createPost(
        content: normalizedContent,
        userId: normalizedUserId,
      );
    } on AppException {
      rethrow;
    } catch (error) {
      throw AppException('Unable to create the post.', cause: error);
    }
  }
}
