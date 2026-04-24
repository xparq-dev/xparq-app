import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:xparq_app/shared/constants/app_constants.dart';

import '../models/block_report_models.dart';

class BlockReportRepository {
  BlockReportRepository({SupabaseClient? client, http.Client? httpClient})
    : _client = client ?? Supabase.instance.client,
      _httpClient = httpClient ?? http.Client();

  final SupabaseClient _client;
  final http.Client _httpClient;
  static const _offlineBlockKey = 'iXPARQ_offline_blocks';

  /// Block a user. This remains on the legacy write path for Batch A3.1.
  Future<void> blockUser({
    required String myUid,
    required String targetUid,
    String source = 'online',
  }) async {
    await _client.from('blocked_users').insert({
      'blocker_id': myUid,
      'blocked_id': targetUid,
      'source': source,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  /// Unblock a user.
  Future<void> unblockUser({
    required String myUid,
    required String targetUid,
  }) async {
    await _client
        .from('blocked_users')
        .delete()
        .eq('blocker_id', myUid)
        .eq('blocked_id', targetUid);

    await _removeOfflineBlock(targetUid);
  }

  /// Stream of blocked IDs for the current user.
  ///
  /// When the central backend flag is enabled, this emits a backend-owned
  /// snapshot first and then continues on the legacy Supabase realtime stream
  /// so the rollout stays low-risk.
  Stream<List<String>> watchBlockedUids(String myUid) {
    if (AppConstants.useCentralBackendBlockListRead) {
      return _watchBlockedUidsViaCentralBackend(myUid);
    }

    return _watchBlockedUidsViaLegacy(myUid);
  }

  Stream<List<String>> _watchBlockedUidsViaLegacy(String myUid) {
    return _client
        .from('blocked_users')
        .stream(primaryKey: ['id'])
        .eq('blocker_id', myUid)
        .map((data) => data.map((d) => d['blocked_id'] as String).toList());
  }

  Stream<List<String>> _watchBlockedUidsViaCentralBackend(String myUid) async* {
    try {
      final snapshot = await _getBlockedUidsViaCentralBackend();
      if (snapshot != null) {
        yield snapshot;
      }
    } catch (_) {
      yield* _watchBlockedUidsViaLegacy(myUid);
      return;
    }

    yield* _watchBlockedUidsViaLegacy(myUid);
  }

  /// Check if a user is blocked (one-time check).
  Future<bool> isBlocked({
    required String myUid,
    required String targetUid,
  }) async {
    if (await _isOfflineBlocked(targetUid)) return true;

    if (AppConstants.useCentralBackendBlockListRead) {
      try {
        final blockedUids = await _getBlockedUidsViaCentralBackend();
        if (blockedUids != null) {
          return blockedUids.contains(targetUid);
        }
      } catch (_) {
        // Fall back to the legacy query below.
      }
    }

    final response = await _client
        .from('blocked_users')
        .select()
        .eq('blocker_id', myUid)
        .eq('blocked_id', targetUid)
        .maybeSingle();

    return response != null;
  }

  Future<List<String>?> _getBlockedUidsViaCentralBackend() async {
    final session = _client.auth.currentSession;
    final accessToken = session?.accessToken ?? '';
    if (accessToken.isEmpty) {
      return null;
    }

    final response = await _httpClient.get(
      Uri.parse('${AppConstants.platformApiBaseUrl}/moderation/blocks/me'),
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      return null;
    }

    final payload = jsonDecode(response.body);
    if (payload is! Map<String, dynamic>) {
      return null;
    }

    final blockedUsers = payload['blocked_users'];
    if (blockedUsers is! List) {
      return null;
    }

    return blockedUsers
        .whereType<Map<String, dynamic>>()
        .map((entry) => entry['blocked_user_id'])
        .whereType<String>()
        .toList();
  }

  Future<void> addOfflineBlock(String deviceId) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getStringList(_offlineBlockKey) ?? [];
    if (!existing.contains(deviceId)) {
      existing.add(deviceId);
      await prefs.setStringList(_offlineBlockKey, existing);
    }
  }

  Future<bool> _isOfflineBlocked(String deviceId) async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_offlineBlockKey) ?? []).contains(deviceId);
  }

  Future<void> _removeOfflineBlock(String deviceId) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getStringList(_offlineBlockKey) ?? [];
    existing.remove(deviceId);
    await prefs.setStringList(_offlineBlockKey, existing);
  }

  Future<List<String>> getOfflineBlocks() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_offlineBlockKey) ?? [];
  }

  Future<void> syncOfflineBlocks(String myUid) async {
    final offlineBlocks = await getOfflineBlocks();
    for (final deviceId in offlineBlocks) {
      await blockUser(myUid: myUid, targetUid: deviceId, source: 'offline');
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_offlineBlockKey);
  }

  Future<void> submitReport(ReportModel report) async {
    await _client.from('reports').insert(report.toMap());
  }

  Future<void> applyGuardianSanction({
    required String reporterUid,
    required String targetUid,
    required String violationLevel,
  }) async {
    final now = DateTime.now();
    DateTime? expiresAt;
    String banType = 'none';

    if (violationLevel == 'minor') {
      expiresAt = now.add(const Duration(days: 365));
      banType = 'exclusion_1yr';
    } else if (violationLevel == 'major') {
      expiresAt = now.add(const Duration(days: 365 * 5));
      banType = 'exclusion_5yr';

      await _client
          .from('users')
          .update({
            'next_ban_check_in_at': now
                .add(const Duration(days: 365))
                .toIso8601String(),
            'account_status': 'suspended',
          })
          .eq('id', targetUid);
    } else if (violationLevel == 'permanent') {
      await _client
          .from('users')
          .update({'account_status': 'suspended'})
          .eq('id', targetUid);
    }

    if (expiresAt != null) {
      await _client.from('bans').insert({
        'banner_id': 'system_guardian',
        'banned_id': targetUid,
        'target_id': 'global',
        'type': banType,
        'expires_at': expiresAt.toIso8601String(),
        'created_at': now.toIso8601String(),
      });
    }

    await _client.from('permanent_invisibility').insert({
      'blocker_id': reporterUid,
      'blocked_id': targetUid,
      'reason': 'guardian_sanction_$violationLevel',
    });

    await _client.from('permanent_invisibility').insert({
      'blocker_id': targetUid,
      'blocked_id': reporterUid,
      'reason': 'guardian_sanction_bidirectional',
    });
  }
}
