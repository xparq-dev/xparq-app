import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:xparq_app/shared/errors/app_exception.dart';
import 'package:xparq_app/features/social/models/post_model.dart';

class SocialRepository {
  SocialRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<List<Post>> getFeed() async {
    try {
      final response = await _client
          .from('pulses')
          .select('id, content, uid')
          .eq('pulse_type', 'post')
          .order('created_at', ascending: false)
          .limit(50);

      return (response as List<dynamic>)
          .map((item) => Post.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList();
    } on PostgrestException catch (error) {
      throw _mapPostgrestException(error);
    } catch (error) {
      throw AppException('Failed to load the social feed.', cause: error);
    }
  }

  Future<Post> createPost({
    required String content,
    required String userId,
  }) async {
    try {
      final profile = await _client
          .from('profiles')
          .select('id, xparq_name, photo_url, age_group, blue_orbit')
          .eq('id', userId)
          .maybeSingle();

      if (profile == null) {
        throw const NotFoundException('User profile not found.');
      }

      final payload = <String, dynamic>{
        'uid': userId,
        'content': content,
        'pulse_type': 'post',
        'author_name': profile['xparq_name']?.toString() ?? 'Unknown User',
        'author_avatar': profile['photo_url']?.toString() ?? '',
        'author_planet_type': profile['age_group']?.toString() ?? 'cadet',
        'author_is_high_risk': profile['blue_orbit'] == true,
        'is_nsfw': false,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      };

      final response = await _client
          .from('pulses')
          .insert(payload)
          .select('id, content, uid')
          .maybeSingle();

      if (response == null) {
        throw const AppException('Post was created but no data was returned.');
      }

      return Post.fromJson(response);
    } on AppException {
      rethrow;
    } on PostgrestException catch (error) {
      throw _mapPostgrestException(error);
    } catch (error) {
      throw AppException('Failed to create the post.', cause: error);
    }
  }

  AppException _mapPostgrestException(PostgrestException error) {
    if (error.code == '42501') {
      return PermissionException(
        'You do not have permission to access social posts.',
        cause: error,
      );
    }

    if (error.code == 'PGRST116') {
      return const NotFoundException(
        'The requested social resource was not found.',
      );
    }

    return AppException(
      error.message.isNotEmpty
          ? error.message
          : 'A database error occurred while processing social posts.',
      cause: error,
    );
  }
}
