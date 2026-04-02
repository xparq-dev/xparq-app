import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:xparq_app/core/errors/app_exception.dart';
import 'package:xparq_app/features/profile/models/user_model.dart';

class ProfileRepository {
  final SupabaseClient _client;

  ProfileRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  Future<UserModel> get({required String id}) async {
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

  Future<UserModel> update({
    required String id,
    required String name,
    required String bio,
  }) async {
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
}
