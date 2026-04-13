// lib/features/auth/repositories/supabase_auth_repository.dart

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:xparq_app/shared/constants/app_constants.dart';
import 'package:xparq_app/shared/enums/age_group.dart';
import 'package:xparq_app/features/auth/models/planet_model.dart';
import 'package:xparq_app/features/auth/services/age_gating_service.dart';
import 'package:xparq_app/features/auth/services/dob_encryption_service.dart';
import 'package:xparq_app/features/chat/data/services/signal/signal_session_manager.dart';

class SupabaseAuthRepository {
  final SupabaseClient _client;
  final http.Client _httpClient;

  SupabaseAuthRepository({SupabaseClient? client, http.Client? httpClient})
      : _client = client ?? Supabase.instance.client,
        _httpClient = httpClient ?? http.Client();

  // ── Auth State ────────────────────────────────────────────────────────────

  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  User? get currentUser => _client.auth.currentUser;

  // ── Auth Operations ───────────────────────────────────────────────────────

  Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final response = await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
    if (response.user != null) {
      // Initialize Signal in background to prevent blocking login on network fluctuation
      SignalSessionManager.instance.initialize().catchError((e) {
        debugPrint('[AuthRepo] Post-login Signal initialization failed: $e');
      });
    }
    return response;
  }

  Future<AuthResponse> registerWithEmail({
    required String email,
    required String password,
  }) async {
    final response = await _client.auth.signUp(
      email: email,
      password: password,
    );
    if (response.user != null) {
      SignalSessionManager.instance.initialize().catchError((e) {
        debugPrint('[AuthRepo] Post-register Signal initialization failed: $e');
      });
    }
    return response;
  }

  // ── Email OTP Auth (Magic Link / Passwordless) ───────────────────────────

  Future<void> signInWithEmailOtp({required String email}) async {
    await _client.auth.signInWithOtp(email: email);
  }

  Future<AuthResponse> verifyEmailOtpSignup({
    required String email,
    required String otpCode,
  }) async {
    final response = await _client.auth.verifyOTP(
      email: email,
      token: otpCode,
      type: OtpType.signup,
    );
    if (response.user != null) {
      SignalSessionManager.instance.initialize().catchError((e) {
        debugPrint(
          '[AuthRepo] Post-OTP-Signup Signal initialization failed: $e',
        );
      });
    }
    return response;
  }

  Future<AuthResponse> verifyEmailOtp({
    required String email,
    required String otpCode,
  }) async {
    final response = await _client.auth.verifyOTP(
      email: email,
      token: otpCode,
      type: OtpType.email,
    );
    if (response.user != null) {
      SignalSessionManager.instance.initialize().catchError((e) {
        debugPrint(
          '[AuthRepo] Post-OTP-Email Signal initialization failed: $e',
        );
      });
    }
    return response;
  }

  Future<void> signOut() async {
    try {
      final uid = currentUser?.id;
      if (uid != null) {
        // Add a timeout to status update to prevent hanging the whole signout
        await updateOnlineStatus(uid, false).timeout(
          const Duration(seconds: 2),
          onTimeout: () =>
              debugPrint('PRESENCE: Status update timed out during signout'),
        );
      }
    } catch (e) {
      debugPrint('Error updating online status during signout: $e');
    } finally {
      await _client.auth.signOut();
    }
  }

  /// Update online status and last_seen timestamp
  Future<void> updateOnlineStatus(String uid, bool isOnline) async {
    try {
      final updates = {
        'is_online': isOnline,
        'last_seen': DateTime.now().toUtc().toIso8601String(),
      };
      await _client.from('profiles').update(updates).eq('id', uid);
      debugPrint(
        'PRESENCE: Updated $uid to ${isOnline ? "ONLINE" : "OFFLINE"} at ${updates['last_seen']}',
      );
    } catch (e) {
      debugPrint('PRESENCE: Failed update for $uid: $e');
    }
  }

  Future<void> sendPasswordResetEmail(String email) async {
    await _client.auth.resetPasswordForEmail(
      email,
      redirectTo: kIsWeb ? null : 'xparq://reset-callback',
    );
  }

  // ── Phone Auth (Placeholders for Supabase) ───────────────────────────────

  // Note: Supabase Phone Auth works differently. We'll simplify for now.
  Future<void> sendPhoneOtp({
    required String phoneNumber,
    required dynamic verificationCompleted,
    required dynamic verificationFailed,
    required dynamic codeSent,
    required dynamic codeAutoRetrievalTimeout,
  }) async {
    await _client.auth.signInWithOtp(phone: phoneNumber);
    codeSent('supabase_flow', null); // Trigger the next step in UI
  }

  Future<AuthResponse> verifyPhoneCredential({
    required String phoneNumber,
    required String otpCode,
  }) async {
    final response = await _client.auth.verifyOTP(
      phone: phoneNumber,
      token: otpCode,
      type: OtpType.sms,
    );
    if (response.user != null) {
      SignalSessionManager.instance.initialize().catchError((e) {
        debugPrint('[AuthRepo] Post-Phone Signal initialization failed: $e');
      });
    }
    return response;
  }

  // ── Account Management ────────────────────────────────────────────────────────

  Future<void> updateGhostMode(bool enabled) async {
    final uid = currentUser?.id;
    if (uid == null) return;
    await _client.from('profiles').update(
        {'ghost_mode': enabled, if (enabled) 'is_online': false}).eq('id', uid);
  }

  Future<void> deleteUserAccount() async {
    final uid = currentUser?.id;
    if (uid == null) return;

    await _client.from('profiles').update({
      'account_status': 'pending_deletion',
      'deletion_requested_at': DateTime.now().toIso8601String(),
      'is_online': false,
    }).eq('id', uid);

    await _client.auth.signOut();
  }

  Future<void> restoreAccount(String uid) async {
    await _client.from('profiles').update({
      'account_status': 'active',
      'deletion_requested_at': null,
      'is_online': true,
    }).eq('id', uid);
  }

  Future<void> setNsfwOptIn({
    required String uid,
    required bool value,
    required AgeGroup ageGroup,
  }) async {
    if (ageGroup != AgeGroup.explorer) return;
    await _client.from('profiles').update({'nsfw_opt_in': value}).eq('id', uid);
  }

  Future<void> updatePlanetProfile(
    String uid,
    Map<String, dynamic> updates,
  ) async {
    // Convert Firestore style updates if necessary (though usually they are the same for simple fields)
    // One difference: Firestore uses dot notation for nested fields, Supabase uses JSONB updates.
    // Assuming simple flat updates for now as seen in AuthRepository.
    await _client.from('profiles').update(updates).eq('id', uid);
  }

  Future<void> permanentlyDeleteAccount(String uid) async {
    // Archive account identifier first
    final user = _client.auth.currentUser;
    if (user != null) {
      final identifier = user.email ?? user.phone;
      if (identifier != null) {
        await _client.from('archived_accounts').upsert({
          'identifier': identifier,
          'permanently_deleted_at': DateTime.now().toIso8601String(),
        });
      }
    }

    // Delete profile (cascades to pulses if schema is set correctly)
    await _client.from('profiles').delete().eq('id', uid);

    // Note: Supabase doesn't allow users to delete their own auth account easily from client
    // unless you have a dedicated edge function or use the management API.
    // For now, we sign out and assume a cleanup trigger or function handles the rest.
    await _client.auth.signOut();
  }

  Future<PlanetModel> createPlanetProfile({
    required String uid,
    required String xparqName,
    required String bio,
    String? mbti,
    String? enneagram,
    String? zodiac,
    String? bloodType,
    required String photoUrl,
    required DateTime dob,
    required List<String> constellations,
  }) async {
    final ageGroup = AgeGatingService.calculateAgeGroup(dob);
    if (ageGroup == AgeGroup.blocked) {
      throw Exception('User is too young to register.');
    }

    final encryptedDob = await DobEncryptionService.encrypt(dob);

    final profileData = {
      'id': uid,
      'xparq_name': xparqName,
      'bio': bio,
      'mbti': mbti,
      'enneagram': enneagram,
      'zodiac': zodiac,
      'blood_type': bloodType,
      'photo_url': photoUrl,
      'birth_date_encrypted': encryptedDob,
      'age_group': ageGroup.name,
      'blue_orbit': true,
      'constellations': constellations,
      'account_status': 'active',
      'created_at': DateTime.now().toIso8601String(),
    };

    await _client.from('profiles').upsert(profileData);

    // Return the model (we might need to fetch it back or construct it)
    final profile = await fetchProfile(uid);
    if (profile == null) throw Exception('Profile not found after creation.');
    return PlanetModel.fromMap(profile, uid);
  }

  // ── Profile Methods ────────────────────────────────────────────────────────

  Future<Map<String, dynamic>?> fetchProfile(String uid) async {
    return await _client.from('profiles').select().eq('id', uid).maybeSingle();
  }

  Future<Map<String, dynamic>?> fetchPlanetProfileForProvider(
      String uid) async {
    if (!(AppConstants.useCentralBackendRead ||
        AppConstants.useCentralBackendProfileRead)) {
      return fetchProfile(uid);
    }

    try {
      final backendProfile = await _fetchProfileViaCentralBackend(uid);
      if (backendProfile != null) {
        return backendProfile;
      }
    } catch (e) {
      debugPrint('[AuthRepo] Provider backend profile fetch failed: $e');
    }

    return fetchProfile(uid);
  }

  // Renaming to match expected name in providers/notifier
  Future<Map<String, dynamic>?> fetchPlanetProfile(String uid) =>
      fetchProfile(uid);

  Stream<Map<String, dynamic>?> watchProfile(String uid) {
    return _client
        .from('profiles')
        .stream(primaryKey: ['id'])
        .eq('id', uid)
        .map((list) => list.isNotEmpty ? list.first : null);
  }

  // ... other methods like delete account etc. can be added similarly

  Future<Map<String, dynamic>?> _fetchProfileViaCentralBackend(
      String uid) async {
    final session = _client.auth.currentSession;
    final accessToken = session?.accessToken ?? '';
    if (accessToken.isEmpty) {
      return null;
    }

    final currentUserId = _client.auth.currentUser?.id;
    final path = currentUserId == uid
        ? '/profiles/me'
        : '/profiles/${Uri.encodeComponent(uid)}/summary';
    final uri = Uri.parse('${AppConstants.platformApiBaseUrl}$path');

    final response = await _httpClient.get(
      uri,
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final payload = jsonDecode(response.body);
      if (payload is Map<String, dynamic>) {
        return payload;
      }
      return null;
    }

    if (_shouldFallbackToLegacy(response.statusCode, response.body)) {
      return null;
    }

    throw Exception(
      'Platform backend profile request failed with HTTP ${response.statusCode}.',
    );
  }

  bool _shouldFallbackToLegacy(int statusCode, String responseBody) {
    if (statusCode == 404 || statusCode >= 500) {
      return true;
    }

    if (statusCode == 409) {
      try {
        final decoded = jsonDecode(responseBody);
        if (decoded is Map<String, dynamic>) {
          final detail = decoded['detail'];
          if (detail is Map<String, dynamic> &&
              detail['code'] == 'SUPABASE_ID_NOT_LINKED') {
            return true;
          }
        }
      } catch (_) {
        return true;
      }
    }

    return false;
  }
}
