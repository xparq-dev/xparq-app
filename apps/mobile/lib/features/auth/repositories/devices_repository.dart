// lib/features/auth/repositories/devices_repository.dart

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:xparq_app/features/chat/data/services/signal/signal_key_service.dart';
import 'package:xparq_app/shared/constants/app_constants.dart';
import 'package:xparq_app/shared/services/device_service.dart';

class DevicesRepository {
  final SupabaseClient _client;
  final http.Client _httpClient;

  DevicesRepository({SupabaseClient? client, http.Client? httpClient})
      : _client = client ?? Supabase.instance.client,
        _httpClient = httpClient ?? http.Client();

  /// Registers or updates the current device in Supabase.
  /// Includes the Signal Identity Key for discovery by other users/devices.
  Future<void> registerCurrentDevice() async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    try {
      final deviceId = await DeviceService.instance.getDeviceId();
      final identityKey =
          await SignalKeyService.instance.getIdentityPublicKey();

      if (AppConstants.useCentralBackendDeviceRegister) {
        try {
          await _registerViaCentralBackend(
            deviceId: deviceId,
            identityKey: identityKey,
          );
          return;
        } catch (e) {
          debugPrint(
            '[DevicesRepository] registerCurrentDevice backend path failed, falling back: $e',
          );
        }
      }

      await _client.from('devices').upsert({
        'uid': user.id,
        'device_id': deviceId,
        'identity_key': identityKey,
        'last_active_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('[DevicesRepository] registerCurrentDevice failed: $e');
    }
  }

  /// Fetches all devices for a specific user.
  /// Used to encrypt messages for all of a recipient's devices.
  Future<List<Map<String, dynamic>>> getUserDevices(String uid) async {
    try {
      if (AppConstants.useCentralBackendRead ||
          AppConstants.useCentralBackendDeviceRead ||
          AppConstants.useCentralBackendDeviceReadPublic) {
        try {
          return await _getUserDevicesViaCentralBackend(uid: uid);
        } catch (e) {
          debugPrint(
            '[DevicesRepository] getUserDevices backend path failed, falling back: $e',
          );
        }
      }

      final response = await _client.from('devices').select().eq('uid', uid);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      // Table may not exist yet or RLS denied. Return empty so encrypt()
      // falls back to the existing degraded target behavior safely.
      debugPrint(
        '[DevicesRepository] getUserDevices failed (table missing?): $e',
      );
      return [];
    }
  }

  /// Fetches all devices for the current user *except* this one.
  /// Used for "Sync with my other devices" logic.
  Future<List<Map<String, dynamic>>> getMyOtherDevices() async {
    final user = _client.auth.currentUser;
    if (user == null) return [];

    try {
      final deviceId = await DeviceService.instance.getDeviceId();

      if (AppConstants.useCentralBackendRead ||
          AppConstants.useCentralBackendDeviceRead ||
          AppConstants.useCentralBackendDeviceReadSelf) {
        try {
          return await _getMyOtherDevicesViaCentralBackend(
            deviceId: deviceId,
          );
        } catch (e) {
          debugPrint(
            '[DevicesRepository] getMyOtherDevices backend path failed, falling back: $e',
          );
        }
      }

      final response = await _client
          .from('devices')
          .select()
          .eq('uid', user.id)
          .neq('device_id', deviceId);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      // Table may not exist yet. Return empty list so caller skips sync.
      debugPrint(
        '[DevicesRepository] getMyOtherDevices failed (table missing?): $e',
      );
      return [];
    }
  }

  /// Deletes all devices for the current user.
  /// Used during fresh install / recovery to purge dead device IDs.
  Future<void> deleteAllUserDevices() async {
    final user = _client.auth.currentUser;
    if (user == null) return;
    try {
      await _client.from('devices').delete().eq('uid', user.id);
    } catch (e) {
      debugPrint('[DevicesRepository] deleteAllUserDevices failed: $e');
    }
  }

  Future<void> _registerViaCentralBackend({
    required String deviceId,
    required String identityKey,
  }) async {
    final session = _client.auth.currentSession;
    final accessToken = session?.accessToken ?? '';
    if (accessToken.isEmpty) {
      throw Exception(
        'No active session is available for device registration.',
      );
    }

    final response = await _httpClient.post(
      Uri.parse('${AppConstants.platformApiBaseUrl}/devices/register'),
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode({
        'device_id': deviceId,
        'identity_key': identityKey,
      }),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return;
    }

    throw Exception(
      'Device registration failed with HTTP ${response.statusCode}: ${response.body}',
    );
  }

  Future<List<Map<String, dynamic>>> _getMyOtherDevicesViaCentralBackend({
    required String deviceId,
  }) async {
    final session = _client.auth.currentSession;
    final accessToken = session?.accessToken ?? '';
    if (accessToken.isEmpty) {
      throw Exception(
        'No active session is available for self-device lookup.',
      );
    }

    final response = await _httpClient.get(
      Uri.parse('${AppConstants.platformApiBaseUrl}/devices/me/others'),
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $accessToken',
        'X-Device-ID': deviceId,
      },
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Self-device lookup failed with HTTP ${response.statusCode}: ${response.body}',
      );
    }

    final payload = jsonDecode(response.body);
    if (payload is! Map<String, dynamic>) {
      throw Exception('Self-device lookup returned an invalid payload.');
    }

    final devices = payload['devices'];
    if (devices is! List) {
      throw Exception('Self-device lookup returned an invalid devices list.');
    }

    return devices
        .whereType<Map>()
        .map((entry) => Map<String, dynamic>.from(entry))
        .toList();
  }

  Future<List<Map<String, dynamic>>> _getUserDevicesViaCentralBackend({
    required String uid,
  }) async {
    final session = _client.auth.currentSession;
    final accessToken = session?.accessToken ?? '';
    if (accessToken.isEmpty) {
      throw Exception(
        'No active session is available for public device lookup.',
      );
    }

    final response = await _httpClient.get(
      Uri.parse(
        '${AppConstants.platformApiBaseUrl}/users/${Uri.encodeComponent(uid)}/devices/public',
      ),
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Public device lookup failed with HTTP ${response.statusCode}: ${response.body}',
      );
    }

    final payload = jsonDecode(response.body);
    if (payload is! Map<String, dynamic>) {
      throw Exception('Public device lookup returned an invalid payload.');
    }

    final devices = payload['devices'];
    if (devices is! List) {
      throw Exception('Public device lookup returned an invalid devices list.');
    }

    return devices
        .whereType<Map>()
        .map((entry) => Map<String, dynamic>.from(entry))
        .toList();
  }
}
