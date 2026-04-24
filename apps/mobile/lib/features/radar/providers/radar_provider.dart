import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xparq_app/shared/errors/app_exception.dart';
import 'package:xparq_app/features/radar/models/nearby_user_model.dart';
import 'package:xparq_app/features/radar/repositories/radar_repository.dart';
import 'package:xparq_app/features/radar/services/radar_service.dart';

final nearbyRadarRepositoryProvider = Provider<RadarRepository>((ref) {
  return RadarRepository();
});

final nearbyRadarServiceProvider = Provider<RadarService>((ref) {
  return RadarService(ref.read(nearbyRadarRepositoryProvider));
});

@immutable
class RadarRequest {
  final String? currentUserId;
  final double radiusKm;

  const RadarRequest({this.currentUserId, this.radiusKm = 5});

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    return other is RadarRequest &&
        other.currentUserId == currentUserId &&
        other.radiusKm == radiusKm;
  }

  @override
  int get hashCode => Object.hash(currentUserId, radiusKm);
}

@immutable
class RadarNearbyState {
  final List<NearbyUser> users;
  final bool isLoading;
  final String? errorMessage;

  const RadarNearbyState({
    this.users = const <NearbyUser>[],
    this.isLoading = false,
    this.errorMessage,
  });

  RadarNearbyState copyWith({
    List<NearbyUser>? users,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
  }) {
    return RadarNearbyState(
      users: users ?? this.users,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class RadarProvider extends StateNotifier<RadarNearbyState> {
  RadarProvider({required RadarService service, required RadarRequest request})
    : _service = service,
      _request = request,
      super(const RadarNearbyState());

  final RadarService _service;
  final RadarRequest _request;

  Future<void> fetchNearby() async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final users = await _service.fetch(
        radiusKm: _request.radiusKm,
        excludedUserId: _request.currentUserId,
      );

      state = state.copyWith(users: users, isLoading: false, clearError: true);
    } on AppException catch (error) {
      state = state.copyWith(isLoading: false, errorMessage: error.message);
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Unable to load nearby users.',
      );
    }
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }
}

final radarProvider = StateNotifierProvider.autoDispose
    .family<RadarProvider, RadarNearbyState, RadarRequest>((ref, request) {
      return RadarProvider(
        service: ref.read(nearbyRadarServiceProvider),
        request: request,
      );
    });
