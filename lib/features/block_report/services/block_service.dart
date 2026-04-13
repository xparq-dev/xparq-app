import 'package:xparq_app/shared/errors/app_exception.dart';
import 'package:xparq_app/features/block_report/repositories/block_repository.dart';

class BlockService {
  const BlockService(this._repository);

  final BlockRepository _repository;

  Future<void> block({
    required String currentUserId,
    required String targetUserId,
  }) async {
    final normalizedCurrentUserId = currentUserId.trim();
    final normalizedTargetUserId = targetUserId.trim();

    if (normalizedCurrentUserId.isEmpty) {
      throw const ValidationException(
        'Current user id is required.',
        field: 'currentUserId',
      );
    }

    if (normalizedTargetUserId.isEmpty) {
      throw const ValidationException(
        'Target user id is required.',
        field: 'targetUserId',
      );
    }

    if (normalizedCurrentUserId == normalizedTargetUserId) {
      throw const ValidationException(
        'You cannot block yourself.',
        field: 'targetUserId',
      );
    }

    try {
      await _repository.block(
        blockerId: normalizedCurrentUserId,
        blockedUserId: normalizedTargetUserId,
      );
    } on AppException {
      rethrow;
    } catch (error) {
      throw AppException('Unable to block the user.', cause: error);
    }
  }
}
