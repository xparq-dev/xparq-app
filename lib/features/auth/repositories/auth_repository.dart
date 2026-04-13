import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import 'package:xparq_app/shared/errors/app_exception.dart';
import 'package:xparq_app/features/auth/models/user_model.dart';

class AuthRepository {
  AuthRepository({supabase.SupabaseClient? client})
    : _client = client ?? supabase.Supabase.instance.client;

  final supabase.SupabaseClient _client;

  Future<UserModel> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      final user = response.user ?? _client.auth.currentUser;
      final session = response.session ?? _client.auth.currentSession;

      if (user == null || session == null || session.accessToken.isEmpty) {
        throw const AuthException(
          'Login completed but the session could not be established.',
        );
      }

      return UserModel(
        id: user.id,
        email: user.email ?? email,
        token: session.accessToken,
      );
    } on supabase.AuthApiException catch (error) {
      throw AuthException(
        error.message.isNotEmpty
            ? error.message
            : 'Unable to log in with the provided credentials.',
        cause: error,
      );
    } on supabase.AuthRetryableFetchException catch (error) {
      throw NetworkException(
        'Unable to reach Supabase right now. Please try again.',
        cause: error,
      );
    } on FormatException catch (error) {
      throw AuthException(
        'Received an invalid login response from Supabase.',
        cause: error,
      );
    } catch (error) {
      throw AppException('Failed to log in with Supabase.', cause: error);
    }
  }
}
