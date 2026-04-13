import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthException;
import 'package:xparq_app/shared/constants/app_constants.dart';
import 'package:xparq_app/shared/errors/app_exception.dart';
import 'package:xparq_app/features/profile/models/user_model.dart';

class ProfileRepository {
  final SupabaseClient _client;
  final http.Client _httpClient;

  ProfileRepository({SupabaseClient? client, http.Client? httpClient})
      : _client = client ?? Supabase.instance.client,
        _httpClient = httpClient ?? http.Client();

  Future<UserModel> get({required String id}) async {
    if (AppConstants.useCentralBackendRead ||
        AppConstants.useCentralBackendProfileRead) {
      try {
        return await _getViaCentralBackend(id: id);
      } on AppException catch (error) {
        if (!_shouldFallbackToLegacy(error)) {
          rethrow;
        }
      } catch (_) {
        // Fall back to the legacy path for any unexpected adapter failure.
      }
    }

    return _getViaLegacy(id: id);
  }

  Future<UserModel> _getViaLegacy({required String id}) async {
    try {
      final response = await _client
          .from('profiles')
          .select('id, xparq_name, bio')
          .eq('id', id)
          .maybeSingle();

      if (response == null) {
        throw const NotFoundException('Profile not found.');
      }

      return UserModel.fromJson(response);
    } on AppException {
      rethrow;
    } on PostgrestException catch (error) {
      throw _mapPostgrestException(error);
    } catch (error) {
      throw AppException('Failed to load the profile.', cause: error);
    }
  }

  Future<UserModel> _getViaCentralBackend({required String id}) async {
    final session = _client.auth.currentSession;
    final accessToken = session?.accessToken ?? '';
    if (accessToken.isEmpty) {
      throw const AuthException(
        'No active session is available for the platform backend request.',
      );
    }

    final currentUserId = _client.auth.currentUser?.id;
    final path = currentUserId == id
        ? '/profiles/me'
        : '/profiles/${Uri.encodeComponent(id)}/summary';
    final uri = Uri.parse('${AppConstants.platformApiBaseUrl}$path');

    try {
      final response = await _httpClient.get(
        uri,
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final payload = jsonDecode(response.body);
        if (payload is! Map<String, dynamic>) {
          throw const AppException(
            'The platform backend returned an invalid profile payload.',
          );
        }
        return UserModel.fromJson(payload);
      }

      final backendDetail = _decodeBackendDetail(response.body);
      final backendCode = _extractBackendCode(backendDetail);
      final backendMessage = _extractBackendMessage(
        backendDetail,
        fallbackMessage:
            'The platform backend could not load the requested profile.',
      );

      if (response.statusCode == 404) {
        throw NotFoundException(backendMessage);
      }
      if (response.statusCode == 401) {
        throw AuthException(backendMessage);
      }
      if (response.statusCode == 403) {
        throw PermissionException(backendMessage);
      }
      if (response.statusCode == 409 &&
          backendCode == 'SUPABASE_ID_NOT_LINKED') {
        throw AppException(backendMessage);
      }

      throw NetworkException(
        backendMessage,
        statusCode: response.statusCode,
      );
    } on AppException {
      rethrow;
    } catch (error) {
      throw NetworkException(
        'Unable to reach the platform backend right now.',
        cause: error,
      );
    }
  }

  Future<UserModel> update({
    required String id,
    required String name,
    required String bio,
  }) async {
    if (_canUseCentralBackendProfileWrite(id)) {
      try {
        return await _updateViaCentralBackend(
          updates: {
            'xparq_name': name,
            'bio': bio,
          },
        );
      } on AppException catch (error) {
        if (!_shouldFallbackToLegacy(error)) {
          rethrow;
        }
      } catch (_) {
        // Fall back to the legacy path for any unexpected adapter failure.
      }
    }

    try {
      final response = await _client
          .from('profiles')
          .update({'xparq_name': name, 'bio': bio})
          .eq('id', id)
          .select('id, xparq_name, bio')
          .maybeSingle();

      if (response == null) {
        throw const NotFoundException('Profile could not be updated.');
      }

      return UserModel.fromJson(response);
    } on AppException {
      rethrow;
    } on PostgrestException catch (error) {
      throw _mapPostgrestException(error);
    } catch (error) {
      throw AppException('Failed to update the profile.', cause: error);
    }
  }

  // ── Update Profile Fields ─────────────────────────────────────────────────

  Future<void> updateProfile({
    required String uid,
    String? xparqName,
    String? bio,
    String? photoUrl,
    String? coverPhotoUrl,
    double? coverPhotoYPercent,
    double? photoYPercent,
    String? photoAlignment,
    bool? isExpandedHeader,
    String? mbti,
    List<String>? constellations,
    String? handle,
    DateTime? handleUpdatedAt,
    String? gender,
    String? locationName,
    String? occupation,
    List<String>? links,
    String? extendedBio,
    String? zodiac,
    String? bloodType,
    String? work,
    String? education,
    String? experience,
    List<String>? skills,
    String? contactEmail,
    String? contactPhone,
    bool? isContactPublic,
  }) async {
    final updates = <String, dynamic>{};
    if (xparqName != null) updates['xparq_name'] = xparqName;
    if (bio != null) updates['bio'] = bio;
    if (photoUrl != null) updates['photo_url'] = photoUrl;
    if (coverPhotoUrl != null) updates['cover_photo_url'] = coverPhotoUrl;
    if (coverPhotoYPercent != null) {
      updates['cover_photo_y_percent'] = coverPhotoYPercent;
    }
    if (photoYPercent != null) {
      updates['photo_y_percent'] = photoYPercent;
    }
    if (photoAlignment != null) {
      updates['photo_alignment'] = photoAlignment;
    }
    if (isExpandedHeader != null) {
      updates['is_expanded_header'] = isExpandedHeader;
    }
    if (mbti != null) updates['mbti'] = mbti;
    if (constellations != null) updates['constellations'] = constellations;
    if (handle != null) updates['handle'] = handle;
    if (handleUpdatedAt != null) {
      updates['handle_updated_at'] = handleUpdatedAt.toIso8601String();
    }
    if (gender != null) updates['gender'] = gender;
    if (locationName != null) updates['location_name'] = locationName;
    if (occupation != null) updates['occupation'] = occupation;
    if (links != null) updates['links'] = links;
    if (extendedBio != null) updates['extended_bio'] = extendedBio;
    if (zodiac != null) updates['zodiac'] = zodiac;
    if (bloodType != null) updates['blood_type'] = bloodType;
    if (work != null) updates['work'] = work;
    if (education != null) updates['education'] = education;
    if (experience != null) updates['experience'] = experience;
    if (skills != null) updates['skills'] = skills;
    // Allow empty string to clear contact info
    if (contactEmail != null) {
      updates['contact_email'] = contactEmail.isEmpty ? null : contactEmail;
    }
    if (contactPhone != null) {
      updates['contact_phone'] = contactPhone.isEmpty ? null : contactPhone;
    }
    if (isContactPublic != null) updates['is_contact_public'] = isContactPublic;

    if (updates.isNotEmpty) {
      if (_canUseCentralBackendProfileWrite(uid)) {
        try {
          await _updateViaCentralBackend(updates: updates);
          return;
        } on AppException catch (error) {
          if (!_shouldFallbackToLegacy(error)) {
            rethrow;
          }
        } catch (_) {
          // Fall back to the legacy path for any unexpected adapter failure.
        }
      }

      await _client.from('profiles').update(updates).eq('id', uid);
    }
  }

  // ── Photo History & Albums ───────────────────────────────────────────────

  Future<List<String>> fetchPhotoHistory(String uid, String category) async {
    try {
      final List<dynamic> response = await _client
          .from('user_photos')
          .select('photo_url')
          .eq('uid', uid)
          .eq('category', category)
          .order('created_at', ascending: false);

      return response.map((data) => data['photo_url'] as String).toList();
    } catch (e) {
      return []; // Graceful fallback
    }
  }

  Future<List<String>> fetchPulsePhotos(String uid) async {
    try {
      final List<dynamic> response = await _client
          .from('pulses')
          .select('image_url')
          .eq('uid', uid)
          .not('image_url', 'is', null)
          .order('created_at', ascending: false);

      return response.map((data) => data['image_url'] as String).toList();
    } catch (e) {
      return [];
    }
  }

  // ── Stats (Placeholder for v2) ────────────────────────────────────────────

  Stream<int> watchSignalCount(String uid) {
    // Placeholder: In real app, count messages or connections from Supabase
    return Stream.value(42);
  }

  Stream<int> watchLightYearsTraveled(String uid) {
    // Placeholder: Distance metric
    return Stream.value(1205);
  }

  AppException _mapPostgrestException(PostgrestException error) {
    if (error.code == '42501') {
      return PermissionException(
        'You do not have permission to access this profile.',
        cause: error,
      );
    }

    if (error.code == 'PGRST116') {
      return const NotFoundException('Profile not found.');
    }

    return AppException(
      error.message.isNotEmpty
          ? error.message
          : 'A database error occurred while processing the profile.',
      cause: error,
    );
  }

  bool _shouldFallbackToLegacy(AppException error) {
    if (error is NotFoundException) {
      return true;
    }

    if (error is NetworkException) {
      final statusCode = error.statusCode;
      if (statusCode == null) {
        return true;
      }
      return statusCode >= 500 || statusCode == 409 || statusCode == 501;
    }

    return error.message
        .contains('Current user is not linked to a Supabase identity.');
  }

  Object? _decodeBackendDetail(String body) {
    if (body.trim().isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        return decoded['detail'] ?? decoded;
      }
      return decoded;
    } catch (_) {
      return body;
    }
  }

  String? _extractBackendCode(Object? detail) {
    if (detail is Map<String, dynamic>) {
      final code = detail['code'];
      if (code is String && code.isNotEmpty) {
        return code;
      }
    }
    return null;
  }

  String _extractBackendMessage(
    Object? detail, {
    required String fallbackMessage,
  }) {
    if (detail is String && detail.isNotEmpty) {
      return detail;
    }

    if (detail is Map<String, dynamic>) {
      final message = detail['message'];
      if (message is String && message.isNotEmpty) {
        return message;
      }
      final rawDetail = detail['detail'];
      if (rawDetail is String && rawDetail.isNotEmpty) {
        return rawDetail;
      }
    }

    return fallbackMessage;
  }

  bool _canUseCentralBackendProfileWrite(String targetUserId) {
    if (!AppConstants.useCentralBackendProfileWrite) {
      return false;
    }
    return _client.auth.currentUser?.id == targetUserId;
  }

  Future<UserModel> _updateViaCentralBackend({
    required Map<String, dynamic> updates,
  }) async {
    final session = _client.auth.currentSession;
    final accessToken = session?.accessToken ?? '';
    if (accessToken.isEmpty) {
      throw const AuthException(
        'No active session is available for the platform backend request.',
      );
    }

    final uri = Uri.parse('${AppConstants.platformApiBaseUrl}/profiles/me');

    try {
      final response = await _httpClient.patch(
        uri,
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode(updates),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final payload = jsonDecode(response.body);
        if (payload is! Map<String, dynamic>) {
          throw const AppException(
            'The platform backend returned an invalid profile payload.',
          );
        }
        return UserModel.fromJson(payload);
      }

      final backendDetail = _decodeBackendDetail(response.body);
      final backendCode = _extractBackendCode(backendDetail);
      final backendMessage = _extractBackendMessage(
        backendDetail,
        fallbackMessage:
            'The platform backend could not update the requested profile.',
      );

      if (response.statusCode == 404) {
        throw NotFoundException(backendMessage);
      }
      if (response.statusCode == 401) {
        throw AuthException(backendMessage);
      }
      if (response.statusCode == 403) {
        throw PermissionException(backendMessage);
      }
      if (response.statusCode == 409 &&
          backendCode == 'SUPABASE_ID_NOT_LINKED') {
        throw AppException(backendMessage);
      }

      throw NetworkException(
        backendMessage,
        statusCode: response.statusCode,
      );
    } on AppException {
      rethrow;
    } catch (error) {
      throw NetworkException(
        'Unable to reach the platform backend right now.',
        cause: error,
      );
    }
  }
}
