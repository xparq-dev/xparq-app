import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:xparq_app/shared/constants/app_constants.dart';

class CallSignalingService {
  CallSignalingService({
    http.Client? client,
    SupabaseClient? supabaseClient,
  })  : _client = client ?? http.Client(),
        _supabase = supabaseClient ?? Supabase.instance.client;

  final http.Client _client;
  final SupabaseClient _supabase;

  Future<Map<String, dynamic>> invite({
    required String callerId,
    required String calleeId,
  }) {
    return _post(
      '/events/call_invite',
      body: {
        'caller_id': callerId,
        'callee_id': calleeId,
      },
    );
  }

  Future<Map<String, dynamic>> accept({
    required String callId,
    required String actorId,
  }) {
    return _post(
      '/events/call_accept',
      body: {
        'call_id': callId,
        'actor_id': actorId,
      },
    );
  }

  Future<Map<String, dynamic>> reject({
    required String callId,
    required String actorId,
  }) {
    return _post(
      '/events/call_reject',
      body: {
        'call_id': callId,
        'actor_id': actorId,
      },
    );
  }

  Future<Map<String, dynamic>> joinLifecycle({
    required String callId,
    required String roomId,
    required String actorId,
  }) {
    return _post(
      '/events/join_room',
      body: {
        'call_id': callId,
        'room_id': roomId,
        'actor_id': actorId,
      },
    );
  }

  Future<Map<String, dynamic>> leaveLifecycle({
    required String callId,
    required String roomId,
    required String actorId,
  }) {
    return _post(
      '/events/leave_room',
      body: {
        'call_id': callId,
        'room_id': roomId,
        'actor_id': actorId,
      },
    );
  }

  Future<Map<String, dynamic>> fetchIceServers({
    required String callId,
    required String roomId,
    String transportPolicy = 'all',
  }) async {
    final accessToken = _supabase.auth.currentSession?.accessToken;
    final uri =
        Uri.parse('${AppConstants.platformApiBaseUrl}/ice-servers').replace(
      queryParameters: {
        'callId': callId,
        'roomId': roomId,
        'transportPolicy': transportPolicy,
      },
    );

    final response = await _client.get(
      uri,
      headers: {
        'Content-Type': 'application/json',
        if (accessToken != null) 'Authorization': 'Bearer $accessToken',
      },
    );

    final decoded = response.body.isEmpty
        ? <String, dynamic>{}
        : Map<String, dynamic>.from(jsonDecode(response.body) as Map);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        decoded['message']?.toString() ??
            decoded['error']?.toString() ??
            'ICE policy request failed',
      );
    }

    return decoded;
  }

  Future<Map<String, dynamic>> _post(
    String path, {
    required Map<String, dynamic> body,
  }) async {
    final accessToken = _supabase.auth.currentSession?.accessToken;
    final response = await _client.post(
      Uri.parse('${AppConstants.platformApiBaseUrl}$path'),
      headers: {
        'Content-Type': 'application/json',
        if (accessToken != null) 'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode(body),
    );

    final decoded = response.body.isEmpty
        ? <String, dynamic>{}
        : Map<String, dynamic>.from(jsonDecode(response.body) as Map);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        decoded['error']?.toString() ?? 'Call signaling request failed',
      );
    }

    return decoded;
  }
}
