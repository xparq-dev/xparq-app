import 'package:flutter/foundation.dart';

@immutable
class SignalEvent {
  final String type;
  final Map<String, dynamic> payload;

  const SignalEvent({required this.type, required this.payload});

  factory SignalEvent.fromJson(Map<String, dynamic> json) {
    final rawPayload = json['payload'];

    return SignalEvent(
      type: json['type']?.toString() ?? 'signal',
      payload: rawPayload is Map<String, dynamic>
          ? rawPayload
          : rawPayload is Map
          ? Map<String, dynamic>.from(rawPayload)
          : <String, dynamic>{},
    );
  }

  Map<String, dynamic> toJson() {
    return {'type': type, 'payload': payload};
  }

  SignalEvent copyWith({String? type, Map<String, dynamic>? payload}) {
    return SignalEvent(
      type: type ?? this.type,
      payload: payload ?? this.payload,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    return other is SignalEvent &&
        other.type == type &&
        mapEquals(other.payload, payload);
  }

  @override
  int get hashCode =>
      Object.hash(type, Object.hashAllUnordered(payload.entries));
}
