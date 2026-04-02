import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/block_report_models.dart';

class BlockReportRepository {
  final SupabaseClient _client;
  static const _offlineBlockKey = 'iXPARQ_offline_blocks';

  BlockReportRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  // ── BLOCK ─────────────────────────────────────────────────────────────────

  /// Block a user — writes to Supabase.
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

    // Also remove from offline cache
    await _removeOfflineBlock(targetUid);
  }

  /// Stream of blocked IDs for the current user.
  Stream<List<String>> watchBlockedUids(String myUid) {
    return _client
        .from('blocked_users')
        .stream(primaryKey: ['id'])
        .eq('blocker_id', myUid)
        .map((data) => data.map((d) => d['blocked_id'] as String).toList());
  }

  /// Check if a user is blocked (one-time check).
  Future<bool> isBlocked({
    required String myUid,
    required String targetUid,
  }) async {
    // Check offline cache first (fast path)
    if (await _isOfflineBlocked(targetUid)) return true;

    final response = await _client
        .from('blocked_users')
        .select()
        .eq('blocker_id', myUid)
        .eq('blocked_id', targetUid)
        .maybeSingle();

    return response != null;
  }

  // ── OFFLINE BLOCK ─────────────────────────────────────────────────────────

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

  // ── REPORT ────────────────────────────────────────────────────────────────

  Future<void> submitReport(ReportModel report) async {
    await _client.from('reports').insert(report.toMap());
  }

  Future<void> applyGuardianSanction({
    required String reporterUid,
    required String targetUid,
    required String violationLevel, // "minor" | "major" | "permanent"
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

    // Permanent invisibility (using blocks table for simplicity or separate table)
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
