// lib/features/radar/models/radar_xparq_model.dart
//
// Represents a nearby Xparq (user) discovered via online Radar query.

import 'package:xparq_app/features/auth/models/planet_model.dart';

class RadarXparq {
  final PlanetModel planet;
  final double distanceMeters;

  const RadarXparq({required this.planet, required this.distanceMeters});

  bool get isOnline => planet.isActuallyOnline;

  /// Galactic distance display string (1km = 1 light-year in Xparq universe).
  String get galacticDistance {
    if (distanceMeters < 1000) {
      return '${distanceMeters.toStringAsFixed(0)} parsecs';
    }
    final km = distanceMeters / 1000;
    return '${km.toStringAsFixed(1)} light-years';
  }

  /// Sort key: closer = higher priority.
  double get sortKey => distanceMeters;
}
