import 'package:xparq_app/shared/errors/app_exception.dart';
import 'package:xparq_app/features/radar/models/nearby_user_model.dart';
import 'package:xparq_app/features/radar/repositories/radar_repository.dart';
import 'package:xparq_app/features/radar/services/location_service.dart';

class RadarService {
  const RadarService(this._repository);

  final RadarRepository _repository;

  Future<List<NearbyUser>> fetch({
    required double radiusKm,
    String? excludedUserId,
  }) async {
    if (radiusKm <= 0) {
      throw const ValidationException(
        'Radius must be greater than zero.',
        field: 'radiusKm',
      );
    }

    final position = await LocationService.getCurrentPosition();
    if (position == null) {
      throw const PermissionException(
        'Location permission is required to scan nearby users.',
      );
    }

    try {
      return await _repository.getNearby(
        lat: position.latitude,
        lng: position.longitude,
        radiusKm: radiusKm,
        excludedUserId: excludedUserId,
      );
    } on AppException {
      rethrow;
    } catch (error) {
      throw AppException('Unable to fetch nearby users.', cause: error);
    }
  }
}
