import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:xparq_app/shared/config/supabase_config.dart';
import 'package:xparq_app/shared/constants/app_constants.dart';

Future<void> main() async {
  final client = http.Client();

  try {
    final email = Platform.environment['XPARQ_TEST_EMAIL']?.trim() ?? '';
    final password = Platform.environment['XPARQ_TEST_PASSWORD']?.trim() ?? '';
    final calleeId = Platform.environment['XPARQ_TEST_CALLEE_ID']?.trim() ?? '';
    final callId =
        Platform.environment['XPARQ_TEST_CALL_ID']?.trim() ?? 'diag-call';
    final roomId =
        Platform.environment['XPARQ_TEST_ROOM_ID']?.trim() ?? 'diag-room';

    stdout.writeln('== XPARQ Real Backend Verification ==');
    stdout.writeln('Supabase URL: ${SupabaseConfig.url}');
    stdout.writeln('Platform API: ${AppConstants.platformApiBaseUrl}');
    stdout.writeln('');

    await _checkUnauthenticatedReachability(client);

    if (email.isEmpty || password.isEmpty) {
      stdout.writeln('');
      stdout.writeln('Auth-backed checks skipped.');
      stdout.writeln(
        'Set XPARQ_TEST_EMAIL and XPARQ_TEST_PASSWORD to verify Supabase DB and call API with a real user.',
      );
      exitCode = 0;
      return;
    }

    stdout.writeln('');
    stdout.writeln('== Supabase Auth ==');

    final authPayload = await _login(
      client,
      email: email,
      password: password,
    );
    final accessToken = authPayload['access_token']?.toString() ?? '';
    final user = Map<String, dynamic>.from(
      authPayload['user'] as Map? ?? const <String, dynamic>{},
    );
    final userId = user['id']?.toString() ?? '';

    if (accessToken.isEmpty || userId.isEmpty) {
      throw StateError(
          'Supabase login succeeded but no access token or user id was returned.');
    }

    stdout.writeln('Logged in as: ${user['email'] ?? email}');
    stdout.writeln('User ID: $userId');

    stdout.writeln('');
    stdout.writeln('== Supabase Database ==');
    await _queryProfiles(client, accessToken: accessToken, userId: userId);
    await _queryMessages(client, accessToken: accessToken);

    stdout.writeln('');
    stdout.writeln('== Platform API ==');
    await _checkPlatformProfile(client, accessToken: accessToken);
    await _checkIceServers(
      client,
      accessToken: accessToken,
      callId: callId,
      roomId: roomId,
    );

    if (calleeId.isNotEmpty) {
      stdout.writeln('');
      stdout.writeln('== Real Call Invite ==');
      await _sendRealInvite(
        client,
        accessToken: accessToken,
        callerId: userId,
        calleeId: calleeId,
      );
    } else {
      stdout.writeln('');
      stdout.writeln(
        'Real call invite skipped. Set XPARQ_TEST_CALLEE_ID to post a real invite event.',
      );
    }
  } finally {
    client.close();
  }
}

Future<void> _checkUnauthenticatedReachability(http.Client client) async {
  stdout.writeln('== Public Reachability ==');

  final rest = await client.send(
    http.Request(
      'OPTIONS',
      Uri.parse('${AppConstants.platformApiBaseUrl}/events/call_invite'),
    ),
  );
  stdout.writeln('OPTIONS /events/call_invite -> ${rest.statusCode}');

  final socketProbe = await client.get(
    Uri.parse('https://api.xparq.me/socket.io/?EIO=4&transport=polling&t=diag'),
  );
  stdout.writeln('GET /socket.io polling probe -> ${socketProbe.statusCode}');

  final authHealth = await client.get(
    Uri.parse('${SupabaseConfig.url}/auth/v1/settings'),
    headers: {
      'apikey': SupabaseConfig.anonKey,
    },
  );
  stdout.writeln('GET Supabase auth settings -> ${authHealth.statusCode}');
}

Future<Map<String, dynamic>> _login(
  http.Client client, {
  required String email,
  required String password,
}) async {
  final response = await client.post(
    Uri.parse('${SupabaseConfig.url}/auth/v1/token?grant_type=password'),
    headers: {
      'Content-Type': 'application/json',
      'apikey': SupabaseConfig.anonKey,
    },
    body: jsonEncode({
      'email': email,
      'password': password,
    }),
  );

  final payload = _decodeBody(response.body);
  stdout.writeln('POST /auth/v1/token -> ${response.statusCode}');
  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw HttpException(
      'Supabase login failed: ${payload['msg'] ?? payload['error_description'] ?? payload['error'] ?? response.body}',
    );
  }

  return payload;
}

Future<void> _queryProfiles(
  http.Client client, {
  required String accessToken,
  required String userId,
}) async {
  final response = await client.get(
    Uri.parse(
      '${SupabaseConfig.url}/rest/v1/profiles?id=eq.${Uri.encodeComponent(userId)}&select=id,xparq_name,photo_url,account_status',
    ),
    headers: _supabaseHeaders(accessToken),
  );

  stdout.writeln('GET profiles self row -> ${response.statusCode}');
  stdout.writeln(_truncate(response.body));
}

Future<void> _queryMessages(
  http.Client client, {
  required String accessToken,
}) async {
  final response = await client.get(
    Uri.parse(
      '${SupabaseConfig.url}/rest/v1/messages?select=id,timestamp&order=timestamp.desc&limit=1',
    ),
    headers: _supabaseHeaders(accessToken),
  );

  stdout.writeln('GET messages sample -> ${response.statusCode}');
  stdout.writeln(_truncate(response.body));
}

Future<void> _checkPlatformProfile(
  http.Client client, {
  required String accessToken,
}) async {
  final response = await client.get(
    Uri.parse('${AppConstants.platformApiBaseUrl}/profiles/me'),
    headers: {
      'Accept': 'application/json',
      'Authorization': 'Bearer $accessToken',
    },
  );

  stdout.writeln('GET /profiles/me -> ${response.statusCode}');
  stdout.writeln(_truncate(response.body));
}

Future<void> _checkIceServers(
  http.Client client, {
  required String accessToken,
  required String callId,
  required String roomId,
}) async {
  final response = await client.get(
    Uri.parse('${AppConstants.platformApiBaseUrl}/ice-servers').replace(
      queryParameters: {
        'callId': callId,
        'roomId': roomId,
        'transportPolicy': 'all',
      },
    ),
    headers: {
      'Accept': 'application/json',
      'Authorization': 'Bearer $accessToken',
    },
  );

  stdout.writeln('GET /ice-servers -> ${response.statusCode}');
  stdout.writeln(_truncate(response.body));
}

Future<void> _sendRealInvite(
  http.Client client, {
  required String accessToken,
  required String callerId,
  required String calleeId,
}) async {
  final response = await client.post(
    Uri.parse('${AppConstants.platformApiBaseUrl}/events/call_invite'),
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $accessToken',
    },
    body: jsonEncode({
      'caller_id': callerId,
      'callee_id': calleeId,
    }),
  );

  stdout.writeln('POST /events/call_invite -> ${response.statusCode}');
  stdout.writeln(_truncate(response.body));
}

Map<String, String> _supabaseHeaders(String accessToken) {
  return {
    'apikey': SupabaseConfig.anonKey,
    'Authorization': 'Bearer $accessToken',
    'Accept': 'application/json',
  };
}

Map<String, dynamic> _decodeBody(String body) {
  if (body.trim().isEmpty) {
    return <String, dynamic>{};
  }

  final decoded = jsonDecode(body);
  if (decoded is Map<String, dynamic>) {
    return decoded;
  }

  return <String, dynamic>{'data': decoded};
}

String _truncate(String body, {int maxLength = 600}) {
  final normalized = body.trim();
  if (normalized.isEmpty) {
    return '<empty body>';
  }

  if (normalized.length <= maxLength) {
    return normalized;
  }

  return '${normalized.substring(0, maxLength)}...';
}
