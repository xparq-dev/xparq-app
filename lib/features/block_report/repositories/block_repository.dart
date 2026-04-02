import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:xparq_app/core/errors/app_exception.dart';

class BlockRepository {
  BlockRepository({SupabaseClient? client, SharedPreferences? preferences})
    : _client = client ?? Supabase.instance.client,
      _preferences = preferences;

  final SupabaseClient _client;
  SharedPreferences? _preferences;
  static const String _localBlocksKeyPrefix =
      'block_report.local.blocked_users';

  Future<void> block({
    required String blockerId,
    required String blockedUserId,
  }) async {
    try {
      final existing = await _client
          .from('blocked_users')
          .select('id')
          .eq('blocker_id', blockerId)
          .eq('blocked_id', blockedUserId)
          .maybeSingle();

      if (existing != null) {
        return;
      }

      await _client.from('blocked_users').insert({
        'blocker_id': blockerId,
        'blocked_id': blockedUserId,
        'source': 'online',
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });
    } on PostgrestException catch (error) {
      if (_shouldUseLocalFallback(error)) {
        await _storeLocalBlock(
          blockerId: blockerId,
          blockedUserId: blockedUserId,
        );
        return;
      }

      throw _mapPostgrestException(error);
    } catch (error) {
      throw AppException('Failed to block the user.', cause: error);
    }
  }

  Future<SharedPreferences> _getPreferences() async {
    return _preferences ??= await SharedPreferences.getInstance();
  }

  Future<void> _storeLocalBlock({
    required String blockerId,
    required String blockedUserId,
  }) async {
    final preferences = await _getPreferences();
    final key = '$_localBlocksKeyPrefix.$blockerId';
    final blockedUsers = preferences.getStringList(key) ?? <String>[];

    if (!blockedUsers.contains(blockedUserId)) {
      blockedUsers.add(blockedUserId);
      await preferences.setStringList(key, blockedUsers);
    }
  }

  bool _shouldUseLocalFallback(PostgrestException error) {
    return error.code == 'PGRST205';
  }

  AppException _mapPostgrestException(PostgrestException error) {
    if (error.code == '42501') {
      return PermissionException(
        'You do not have permission to block this user.',
        cause: error,
      );
    }

    return AppException(
      error.message.isNotEmpty
          ? error.message
          : 'A database error occurred while blocking the user.',
      cause: error,
    );
  }
}
