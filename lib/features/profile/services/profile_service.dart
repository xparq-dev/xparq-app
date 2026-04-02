import 'package:xparq_app/core/errors/app_exception.dart';
import 'package:xparq_app/core/security/input_validator.dart';
import 'package:xparq_app/features/profile/models/user_model.dart';
import 'package:xparq_app/features/profile/repositories/profile_repository.dart';

class ProfileService {
  const ProfileService(this._repository);

  final ProfileRepository _repository;

  Future<UserModel> getProfile({required String id}) async {
    final normalizedId = id.trim();
    if (normalizedId.isEmpty) {
      throw const ValidationException('User id is required.', field: 'id');
    }

    try {
      return await _repository.get(id: normalizedId);
    } on AppException {
      rethrow;
    } catch (error) {
      throw AppException('Unable to fetch the profile.', cause: error);
    }
  }

  Future<UserModel> update({
    required String id,
    required String name,
    required String bio,
  }) async {
    final normalizedId = id.trim();
    final normalizedName = name.trim();
    final normalizedBio = bio.trim();

    if (normalizedId.isEmpty) {
      throw const ValidationException('User id is required.', field: 'id');
    }

    final nameValidation = InputValidator.xparqName(normalizedName);
    if (nameValidation != null) {
      throw ValidationException(nameValidation, field: 'name');
    }

    final bioValidation = InputValidator.bio(normalizedBio);
    if (bioValidation != null) {
      throw ValidationException(bioValidation, field: 'bio');
    }

    try {
      return await _repository.update(
        id: normalizedId,
        name: normalizedName,
        bio: normalizedBio,
      );
    } on AppException {
      rethrow;
    } catch (error) {
      throw AppException('Unable to update the profile.', cause: error);
    }
  }
}
