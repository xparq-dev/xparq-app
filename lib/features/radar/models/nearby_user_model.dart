import 'package:flutter/foundation.dart';

@immutable
class NearbyUser {
  final String id;
  final String name;
  final double distance;

  const NearbyUser({
    required this.id,
    required this.name,
    required this.distance,
  });

  factory NearbyUser.fromJson(Map<String, dynamic> json) {
    return NearbyUser(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? json['xparq_name']?.toString() ?? '',
      distance: (json['distance'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'name': name, 'distance': distance};
  }

  NearbyUser copyWith({String? id, String? name, double? distance}) {
    return NearbyUser(
      id: id ?? this.id,
      name: name ?? this.name,
      distance: distance ?? this.distance,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    return other is NearbyUser &&
        other.id == id &&
        other.name == name &&
        other.distance == distance;
  }

  @override
  int get hashCode => Object.hash(id, name, distance);
}
