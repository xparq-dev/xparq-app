import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:xparq_app/core/errors/app_exception.dart';
import 'package:xparq_app/features/block_report/models/report_model.dart';

class ReportRepository {
  ReportRepository({SupabaseClient? client, SharedPreferences? preferences})
    : _client = client ?? Supabase.instance.client,
      _preferences = preferences;

  final SupabaseClient _client;
  SharedPreferences? _preferences;
  static const String _localReportsKey = 'block_report.local.pending_reports';

  Future<void> report({
    required String reporterId,
    required Report report,
  }) async {
    try {
      await _client.from('reports').insert({
        'reporter_id': reporterId,
        'reported_id': report.userId,
        'reason': report.reason,
        'created_at': DateTime.now().toUtc().toIso8601String(),
        'status': 'pending',
        'context': 'profile',
      });
    } on PostgrestException catch (error) {
      if (_shouldUseLocalFallback(error)) {
        await _storeLocalReport(reporterId: reporterId, report: report);
        return;
      }

      throw _mapPostgrestException(error);
    } catch (error) {
      throw AppException('Failed to submit the report.', cause: error);
    }
  }

  Future<SharedPreferences> _getPreferences() async {
    return _preferences ??= await SharedPreferences.getInstance();
  }

  Future<void> _storeLocalReport({
    required String reporterId,
    required Report report,
  }) async {
    final preferences = await _getPreferences();
    final entries = preferences.getStringList(_localReportsKey) ?? <String>[];

    entries.add(
      jsonEncode(<String, dynamic>{
        'reporter_id': reporterId,
        'user_id': report.userId,
        'reason': report.reason,
        'created_at': DateTime.now().toUtc().toIso8601String(),
        'status': 'pending_local_sync',
      }),
    );

    await preferences.setStringList(_localReportsKey, entries);
  }

  bool _shouldUseLocalFallback(PostgrestException error) {
    return error.code == 'PGRST205';
  }

  AppException _mapPostgrestException(PostgrestException error) {
    if (error.code == '42501') {
      return PermissionException(
        'You do not have permission to report this user.',
        cause: error,
      );
    }

    return AppException(
      error.message.isNotEmpty
          ? error.message
          : 'A database error occurred while submitting the report.',
      cause: error,
    );
  }
}
