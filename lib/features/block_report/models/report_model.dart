import 'package:flutter/foundation.dart';

@immutable
class Report {
  final String userId;
  final String reason;

  const Report({required this.userId, required this.reason});

  factory Report.fromJson(Map<String, dynamic> json) {
    return Report(
      userId:
          json['user_id']?.toString() ?? json['reported_id']?.toString() ?? '',
      reason: json['reason']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {'user_id': userId, 'reason': reason};
  }

  Report copyWith({String? userId, String? reason}) {
    return Report(userId: userId ?? this.userId, reason: reason ?? this.reason);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    return other is Report && other.userId == userId && other.reason == reason;
  }

  @override
  int get hashCode => Object.hash(userId, reason);
}
