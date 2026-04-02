// lib/features/radar/services/location_service.dart
//
// Handles GPS location permission and streaming for online Radar mode.

import 'package:geolocator/geolocator.dart';
import 'geohash_service.dart';

class LocationService {
  /// Request location permission. Returns true if granted.
  static Future<bool> requestPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always;
  }

  /// Get the current position once.
  /// If [requestPermission] is true (default), prompts the user.
  /// If false, returns null if permission is not already granted.
  static Future<Position?> getCurrentPosition({
    bool requestPermission = true,
  }) async {
    if (requestPermission) {
      final hasPermission = await LocationService.requestPermission();
      if (!hasPermission) return null;
    } else {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }
    }

    return await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 50, // Only update if moved 50m
      ),
    );
  }

  /// Stream of position updates (for live Radar).
  static Stream<Position> positionStream() {
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.medium,
        distanceFilter: 100, // Update every 100m movement
      ),
    );
  }

  /// Convert a [Position] to a geohash string (precision 6).
  static String toGeohash(Position position) {
    return GeohashService.encode(
      position.latitude,
      position.longitude,
      precision: 6,
    );
  }
}
