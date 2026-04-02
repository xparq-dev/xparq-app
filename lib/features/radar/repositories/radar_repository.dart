import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:xparq_app/core/errors/app_exception.dart';
import 'package:xparq_app/core/enums/age_group.dart';
import 'package:xparq_app/features/auth/models/planet_model.dart';
import 'package:xparq_app/features/radar/models/nearby_user_model.dart';
import 'package:xparq_app/features/radar/models/radar_xparq_model.dart';
// Note: GeohashService might still be useful for local encoding but Supabase/PostGIS handles distances better.
import 'package:xparq_app/features/radar/services/geohash_service.dart';

class RadarRepository {
  final SupabaseClient _client;

  RadarRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  // ── Update own location ───────────────────────────────────────────────────

  Future<void> updateLocation({
    required String uid,
    required double lat,
    required double lng,
    bool ghostMode = false,
  }) async {
    // Ghost Mode guard: do NOT flip is_online to true while ghost mode is on.
    // We still update location coords so the record is accurate when ghost mode
    // is later disabled, but we never expose the user as discoverable.
    final Map<String, dynamic> updates = {
      'location_lat': lat,
      'location_lng': lng,
      'location_updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    if (!ghostMode) {
      updates['is_online'] = true;
      updates['last_seen'] = DateTime.now().toUtc().toIso8601String();
    }
    await _client.from('profiles').update(updates).eq('id', uid);
  }

  // ── Query nearby via Cloud Function ──────────────────────────────────────

  /// Calls a Postgres function `query_nearby_users` via RPC.
  Future<List<RadarXparq>> queryNearby({
    required double lat,
    required double lng,
    required double radiusKm,
    required AgeGroup callerAgeGroup,
  }) async {
    final List<dynamic> result = await _client.rpc(
      'query_nearby_users',
      params: {
        'p_lat': lat,
        'p_lng': lng,
        'p_radius_km': radiusKm,
        'p_caller_age_group': callerAgeGroup.name,
      },
    );

    return result.map((item) {
      final map = Map<String, dynamic>.from(item as Map);
      final planet = PlanetModel.fromMap(map, map['id'] as String);
      return RadarXparq(
        planet: planet,
        distanceMeters: (map['distance_meters'] as num).toDouble(),
      );
    }).toList();
  }

  // ── Fallback: Direct Firestore query (no Cloud Function) ─────────────────

  /// Queries users with matching geohash prefix (approximate nearby).
  /// Less accurate than Cloud Function but works offline-first.
  Future<List<RadarXparq>> queryNearbyLocal({
    required double lat,
    required double lng,
    required double radiusKm,
    required AgeGroup callerAgeGroup,
    required String callerUid,
  }) async {
    // Basic local query using simple bounding box logic or just filtering online users
    // For a true "local" fallback in Supabase, we can use PostgREST filters
    // However, rpc is generally preferred for geo. This serves as a simpler version.
    final List<dynamic> response = await _client
        .from('profiles')
        .select()
        .eq('is_online', true)
        .eq('ghost_mode', false)
        .neq('id', callerUid)
        .limit(50);

    final results = <RadarXparq>[];
    for (final data in response) {
      final planet = PlanetModel.fromMap(data, data['id']);

      if (callerAgeGroup == AgeGroup.cadet &&
          (planet.nsfwOptIn || planet.isHighRiskCreator)) {
        continue;
      }

      final docLat = data['location_lat'] as double? ?? 0;
      final docLng = data['location_lng'] as double? ?? 0;
      final distance = GeohashService.distanceMeters(lat, lng, docLat, docLng);

      if (distance <= radiusKm * 1000) {
        results.add(RadarXparq(planet: planet, distanceMeters: distance));
      }
    }

    results.sort((a, b) => a.sortKey.compareTo(b.sortKey));
    return results;
  }

  // ── Global Search ─────────────────────────────────────────────────────────

  /// Search for users by xparq_name (case sensitive prefix match).
  /// Doesn't require location or online status.
  Future<List<RadarXparq>> searchUsers(String query) async {
    if (query.length < 3) return [];

    final List<dynamic> response = await _client
        .from('profiles')
        .select()
        .ilike('xparq_name', '$query%')
        .eq('ghost_mode', false)
        .limit(20);

    return response.map((data) {
      final planet = PlanetModel.fromMap(data, data['id']);
      return RadarXparq(planet: planet, distanceMeters: -1);
    }).toList();
  }

  Future<List<NearbyUser>> getNearby({
    required double lat,
    required double lng,
    required double radiusKm,
    String? excludedUserId,
  }) async {
    try {
      final response = await _client
          .from('profiles')
          .select('id, xparq_name, location_lat, location_lng')
          .eq('is_online', true)
          .eq('ghost_mode', false)
          .limit(100);

      final nearbyUsers = <NearbyUser>[];

      for (final row in response as List<dynamic>) {
        final data = Map<String, dynamic>.from(row as Map);
        final id = data['id']?.toString() ?? '';

        if (id.isEmpty || id == excludedUserId) {
          continue;
        }

        final locationLat = (data['location_lat'] as num?)?.toDouble();
        final locationLng = (data['location_lng'] as num?)?.toDouble();

        if (locationLat == null || locationLng == null) {
          continue;
        }

        final distanceMeters = GeohashService.distanceMeters(
          lat,
          lng,
          locationLat,
          locationLng,
        );

        if (distanceMeters > radiusKm * 1000) {
          continue;
        }

        nearbyUsers.add(
          NearbyUser(
            id: id,
            name: data['xparq_name']?.toString() ?? 'Unknown User',
            distance: distanceMeters / 1000,
          ),
        );
      }

      nearbyUsers.sort((a, b) => a.distance.compareTo(b.distance));
      return nearbyUsers;
    } on PostgrestException catch (error) {
      if (error.code == '42501') {
        throw PermissionException(
          'You do not have permission to access nearby users.',
          cause: error,
        );
      }

      throw AppException(
        error.message.isNotEmpty
            ? error.message
            : 'Failed to fetch nearby users.',
        cause: error,
      );
    } catch (error) {
      throw AppException('Failed to fetch nearby users.', cause: error);
    }
  }
}
