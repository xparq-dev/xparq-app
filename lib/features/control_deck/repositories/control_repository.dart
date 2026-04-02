import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:xparq_app/core/errors/app_exception.dart';
import 'package:xparq_app/features/control_deck/models/dashboard_model.dart';

class ControlRepository {
  ControlRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<Dashboard> get() async {
    try {
      final results = await Future.wait([
        _client.from('profiles').select('id').count(CountOption.exact),
        _client
            .from('profiles')
            .select('id')
            .eq('is_online', true)
            .count(CountOption.exact),
      ]);

      final totalUsersResponse = results[0];
      final activeUsersResponse = results[1];

      return Dashboard(
        users: totalUsersResponse.count,
        active: activeUsersResponse.count,
      );
    } on PostgrestException catch (error) {
      throw _mapPostgrestException(error);
    } catch (error) {
      throw AppException('Failed to load dashboard data.', cause: error);
    }
  }

  AppException _mapPostgrestException(PostgrestException error) {
    if (error.code == '42501') {
      return PermissionException(
        'You do not have permission to view the dashboard.',
        cause: error,
      );
    }

    return AppException(
      error.message.isNotEmpty
          ? error.message
          : 'A database error occurred while loading the dashboard.',
      cause: error,
    );
  }
}
