// lib/features/auth/repositories/devices_repository.dart

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:xparq_app/features/chat/data/services/signal/signal_key_service.dart';
import 'package:xparq_app/core/services/device_service.dart';

class DevicesRepository {
  final SupabaseClient _client;

  DevicesRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  /// Registers or updates the current device in Supabase.
  /// Includes the Signal Identity Key for discovery by other users/devices.
  Future<void> registerCurrentDevice() async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    try {
      final deviceId = await DeviceService.instance.getDeviceId();
      final identityKey = await SignalKeyService.instance
          .getIdentityPublicKey();

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
      final response = await _client.from('devices').select().eq('uid', uid);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      // Table may not exist yet or RLS denied — return empty so encrypt()
      // falls back to 'default' device target gracefully.
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

      final response = await _client
          .from('devices')
          .select()
          .eq('uid', user.id)
          .neq('device_id', deviceId);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      // Table may not exist yet — return empty list so caller skips sync.
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
}
