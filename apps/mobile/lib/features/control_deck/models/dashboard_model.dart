import 'package:flutter/foundation.dart';

@immutable
class Dashboard {
  final int users;
  final int active;

  const Dashboard({required this.users, required this.active});

  factory Dashboard.fromJson(Map<String, dynamic> json) {
    return Dashboard(
      users: (json['users'] as num?)?.toInt() ?? 0,
      active: (json['active'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {'users': users, 'active': active};
  }

  Dashboard copyWith({int? users, int? active}) {
    return Dashboard(users: users ?? this.users, active: active ?? this.active);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    return other is Dashboard && other.users == users && other.active == active;
  }

  @override
  int get hashCode => Object.hash(users, active);
}
