import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:xparq_app/features/auth/models/planet_model.dart';

/// Repository responsible for user discovery and search operations.
class ChatSearchRepository {
  final SupabaseClient _client;

  ChatSearchRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  /// Searches the directory for users matching the [query] string.
  ///
  /// Matches against `xparq_name` and `handle` using case-insensitive partial matching.
  Future<List<PlanetModel>> searchUsers(String query) async {
    if (query.isEmpty) return [];

    try {
      final response = await _client
          .from('profiles')
          .select()
          .or('xparq_name.ilike.%$query%,handle.ilike.%$query%')
          .limit(10);

      return (response as List).map((data) {
        final map = data as Map<String, dynamic>;
        return PlanetModel.fromMap(map, map['id'] as String);
      }).toList();
    } catch (e) {
      throw Exception('Planet discovery search failed: $e');
    }
  }

  /// Retrieves a minimal profile for the specified [uid].
  Future<PlanetModel?> getMinimalProfile(String uid) async {
    try {
      final doc = await _client
          .from('profiles')
          .select()
          .eq('id', uid)
          .single();
      return PlanetModel.fromMap(doc, uid);
    } catch (e) {
      return null;
    }
  }
}
