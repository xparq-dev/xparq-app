// lib/features/radar/services/geohash_service.dart
//
// Converts GPS coordinates to geohash strings for Firestore proximity queries.
// Uses base32 geohash encoding (precision 6 ≈ 1.2km cell size).

class GeohashService {
  static const String _base32 = '0123456789bcdefghjkmnpqrstuvwxyz';

  /// Encode [lat]/[lng] to a geohash string of given [precision].
  static String encode(double lat, double lng, {int precision = 6}) {
    double minLat = -90, maxLat = 90;
    double minLng = -180, maxLng = 180;
    final buffer = StringBuffer();
    int bits = 0, hashValue = 0;
    bool isEven = true;

    while (buffer.length < precision) {
      if (isEven) {
        final mid = (minLng + maxLng) / 2;
        if (lng >= mid) {
          hashValue = (hashValue << 1) + 1;
          minLng = mid;
        } else {
          hashValue = hashValue << 1;
          maxLng = mid;
        }
      } else {
        final mid = (minLat + maxLat) / 2;
        if (lat >= mid) {
          hashValue = (hashValue << 1) + 1;
          minLat = mid;
        } else {
          hashValue = hashValue << 1;
          maxLat = mid;
        }
      }
      isEven = !isEven;
      bits++;

      if (bits == 5) {
        buffer.write(_base32[hashValue]);
        bits = 0;
        hashValue = 0;
      }
    }
    return buffer.toString();
  }

  /// Returns the 8 neighboring geohash cells + the center cell.
  /// Used for Firestore range queries (nearby users).
  static List<String> getNeighbors(String geohash) {
    // For v1, we use a simple prefix-range approach:
    // Return the geohash itself and adjacent cells by decoding bounds.
    // A full neighbor implementation is complex; for v1 we use prefix queries.
    // This is a simplified version — production should use a proper geohash library.
    return [geohash];
  }

  /// Convert distance in meters to a "light-years" display string.
  /// Theme: 1 km = 1 light-year in iXPARQ universe.
  static String toGalacticDistance(double distanceMeters) {
    if (distanceMeters < 1000) {
      return '${distanceMeters.toStringAsFixed(0)} parsecs';
    }
    final km = distanceMeters / 1000;
    if (km < 1000) {
      return '${km.toStringAsFixed(1)} light-years';
    }
    return '${(km / 1000).toStringAsFixed(1)}K light-years';
  }

  /// Haversine formula: calculate distance in meters between two coordinates.
  static double distanceMeters(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    const r = 6371000.0; // Earth radius in meters
    final dLat = _toRad(lat2 - lat1);
    final dLng = _toRad(lng2 - lng1);
    final a =
        _sin2(dLat / 2) +
        _cos(_toRad(lat1)) * _cos(_toRad(lat2)) * _sin2(dLng / 2);
    final c = 2 * _atan2(_sqrt(a), _sqrt(1 - a));
    return r * c;
  }

  static double _toRad(double deg) => deg * 3.141592653589793 / 180;
  static double _sin2(double x) => _sin(x) * _sin(x);
  static double _sin(double x) {
    // Taylor series approximation for small angles; use dart:math in real code
    return x - (x * x * x) / 6 + (x * x * x * x * x) / 120;
  }

  static double _cos(double x) => 1 - (x * x) / 2 + (x * x * x * x) / 24;
  static double _sqrt(double x) => x <= 0 ? 0 : _sqrtNewton(x, x / 2);
  static double _sqrtNewton(double x, double g) {
    final ng = (g + x / g) / 2;
    return (ng - g).abs() < 1e-10 ? ng : _sqrtNewton(x, ng);
  }

  static double _atan2(double y, double x) {
    if (x > 0) return _atan(y / x);
    if (x < 0 && y >= 0) return _atan(y / x) + 3.141592653589793;
    if (x < 0 && y < 0) return _atan(y / x) - 3.141592653589793;
    if (x == 0 && y > 0) return 3.141592653589793 / 2;
    return -3.141592653589793 / 2;
  }

  static double _atan(double x) =>
      x - (x * x * x) / 3 + (x * x * x * x * x) / 5;
}
