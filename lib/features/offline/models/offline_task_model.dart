import 'dart:convert';

import 'package:xparq_app/core/errors/app_exception.dart';

class OfflineTask {
  const OfflineTask({required this.id, required this.payload});

  final String id;
  final Map<String, dynamic> payload;

  factory OfflineTask.fromJson(Map<String, dynamic> json) {
    final id = json['id']?.toString().trim() ?? '';
    if (id.isEmpty) {
      throw const ValidationException(
        'Offline task id is required.',
        field: 'id',
      );
    }

    final rawPayload = json['payload'];
    if (rawPayload is! Map) {
      throw const ValidationException(
        'Offline task payload must be a JSON object.',
        field: 'payload',
      );
    }

    return OfflineTask(id: id, payload: Map<String, dynamic>.from(rawPayload));
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{'id': id, 'payload': payload};
  }

  OfflineTask copyWith({String? id, Map<String, dynamic>? payload}) {
    return OfflineTask(id: id ?? this.id, payload: payload ?? this.payload);
  }

  String get prettyPayload {
    return const JsonEncoder.withIndent('  ').convert(payload);
  }
}
