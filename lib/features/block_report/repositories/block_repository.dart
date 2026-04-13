import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthException;
import 'package:xparq_app/shared/constants/app_constants.dart';
import 'package:xparq_app/shared/errors/app_exception.dart';

class BlockRepository {
  BlockRepository({
    SupabaseClient? client,
    SharedPreferences? preferences,
    http.Client? httpClient,
  })  : _client = client ?? Supabase.instance.client,
        _preferences = preferences,
        _httpClient = httpClient ?? http.Client();

  final SupabaseClient _client;
  final http.Client _httpClient;
  SharedPreferences? _preferences;
  static const String _localBlocksKeyPrefix =
      'block_report.local.blocked_users';

  Future<void> block({
    required String blockerId,
    required String blockedUserId,
  }) async {
    if (AppConstants.useCentralBackendModerationWrite) {
      try {
        await _blockViaCentralBackend(blockedUserId: blockedUserId);
        return;
      } catch (_) {
        // Fall back to the legacy write path below.
      }
    }

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

  Future<void> _blockViaCentralBackend({
    required String blockedUserId,
  }) async {
    final session = _client.auth.currentSession;
    final accessToken = session?.accessToken ?? '';
    if (accessToken.isEmpty) {
      throw const AuthException(
        'No active session is available for the platform backend request.',
      );
    }

    final response = await _httpClient.post(
      Uri.parse('${AppConstants.platformApiBaseUrl}/moderation/blocks'),
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode({
        'blocked_user_id': blockedUserId,
      }),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return;
    }

    throw NetworkException(
      'The platform backend could not block the requested user.',
      statusCode: response.statusCode,
    );
  }
}
