// lib/features/auth/providers/auth_providers.dart
//
// Riverpod providers for the auth module.

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../main.dart'; // To access initialPasswordRecoveryEvent
import 'package:xparq_app/features/auth/models/planet_model.dart';
import 'package:xparq_app/features/chat/presentation/providers/active_chat_provider.dart';
import 'package:xparq_app/features/auth/repositories/supabase_auth_repository.dart';
import 'package:xparq_app/features/offline/services/offline_chat_database.dart';
import 'package:xparq_app/shared/enums/age_group.dart';
import 'package:xparq_app/features/auth/models/quick_account.dart';
import 'package:xparq_app/features/auth/services/quick_auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:xparq_app/shared/router/router_providers.dart';

// ── Repository Provider ───────────────────────────────────────────────────

final authRepositoryProvider = Provider<SupabaseAuthRepository>((ref) {
  return SupabaseAuthRepository();
});

final quickAuthServiceProvider = FutureProvider<QuickAuthService>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  const secureStorage = FlutterSecureStorage();
  return QuickAuthService(prefs, secureStorage);
});

/// A reactive provider that listens to the [QuickAuthService] and automatically
/// rebuilds when the quick accounts list changes.
final quickAccountsProvider = Provider<List<QuickAccount>>((ref) {
  final serviceAsync = ref.watch(quickAuthServiceProvider);
  final service = serviceAsync.valueOrNull;
  if (service == null) return [];

  // When the service notifies (account added/removed), invalidate this provider.
  void listener() => ref.invalidateSelf();
  service.addListener(listener);
  ref.onDispose(() => service.removeListener(listener));

  return service.getQuickAccounts();
});

// ── Firebase Auth State ───────────────────────────────────────────────────

/// Streams the raw Supabase [User] (null = logged out).
final supabaseAuthStateProvider = StreamProvider<User?>((ref) async* {
  final repo = ref.watch(authRepositoryProvider);

  // Yield the current synchronous state immediately
  // This prevents the screen from getting stuck in a loading state if
  // the initial broadcast event fired before this provider started listening.
  yield repo.currentUser;

  // Then listen for all subsequent changes
  await for (final state in repo.authStateChanges) {
    yield state.session?.user;
  }
});

/// Flag to indicate if we are in an explicit "Login" flow (vs Sign Up).
/// Used by the router to be more patient with profile fetching.
final isLoginFlowProvider = StateProvider<bool>((ref) => false);

// ── Planet Profile ────────────────────────────────────────────────────────

/// Streams the current user's [PlanetModel] from Supabase.
/// Returns null if not logged in or profile not yet created.
final planetProfileProvider = StreamProvider<PlanetModel?>((ref) async* {
  final authState = ref.watch(supabaseAuthStateProvider);
  final user = authState.valueOrNull;

  if (user == null) {
    yield null;
    return;
  }

  // 0. Check user metadata: If the account was created more than 1 minute ago,
  // it MUST have a profile (unless it was an abandoned signup).
  // We can use this to wait longer for the initial fetch.
  final createdAt = DateTime.tryParse(user.createdAt);
  final isNewUser =
      createdAt != null && DateTime.now().difference(createdAt).inMinutes < 2;

  final repo = ref.watch(authRepositoryProvider);

  // 1. Fetch initial state using a standard HTTP request to bypass Realtime RLS delays
  // We don't yield immediately if it's null, we wait for a second attempt or the stream.
  Map<String, dynamic>? initialData;
  try {
    initialData = await repo
        .fetchPlanetProfileForProvider(user.id)
        .timeout(const Duration(seconds: 12)); // Increased from 8s
  } catch (e) {
    debugPrint('AUTH: Initial profile fetch error ($e)');
  }

  if (initialData != null) {
    if (ref.read(isLoginFlowProvider)) {
      Future.delayed(const Duration(seconds: 30), () {
        if (ref.exists(isLoginFlowProvider)) {
          ref.read(isLoginFlowProvider.notifier).state = false;
        }
      });
    }
    yield PlanetModel.fromMap(initialData, user.id);
  } else if (!isNewUser) {
    // If not a new user, and first fetch failed/null, retry multiple times with delay.
    // Returning users should almost never be redirected to onboarding due to transient network lag.
    debugPrint('AUTH: Profile null for returning user. Retrying...');
    for (int i = 0; i < 3; i++) {
      await Future.delayed(const Duration(seconds: 3)); // 3s, 6s, 9s total wait
      try {
        initialData = await repo.fetchPlanetProfileForProvider(user.id);
        if (initialData != null) {
          yield PlanetModel.fromMap(initialData, user.id);
          break;
        }
      } catch (_) {}
    }
  }

  // 2. Yield updates from the realtime stream with timeout protection
  try {
    // FINAL SAFETY: If we are about to enter the stream loop and haven't yielded yet,
    // and we suspect this is a returning user OR isLoginFlow is true, WAIT.
    final isLoginFlow = ref.read(isLoginFlowProvider);
    if (!isNewUser || isLoginFlow) {
      debugPrint('AUTH: Stubborn profile fetch waiting for Realtime sync...');
      await Future.delayed(const Duration(seconds: 4));
    }

    await for (final data in repo.watchProfile(user.id)) {
      if (data == null && (!isNewUser || isLoginFlow)) {
        // If stream says null but it's an old user or explicit login, continue.
        // We only yield null if we are 100% sure this is a fresh signup.
        debugPrint(
          'AUTH: watchProfile yielded null for returning/login user. Ignoring.',
        );
        continue;
      }
      if (data != null) {
        debugPrint('AUTH: Profile synced successfully for ${user.id}');
      }
      yield data != null ? PlanetModel.fromMap(data, user.id) : null;
    }
  } catch (e) {
    debugPrint('AUTH: Profile Realtime Error: $e');
  }
});

// ── Age Group (derived) ───────────────────────────────────────────────────

/// Derived provider: current user's [AgeGroup].
final currentAgeGroupProvider = Provider<AgeGroup>((ref) {
  final profile = ref.watch(planetProfileProvider).valueOrNull;
  return profile?.ageGroup ?? AgeGroup.cadet; // Safe default
});

/// Derived provider: whether the current user can view sensitive content.
final canViewSensitiveProvider = Provider<bool>((ref) {
  final profile = ref.watch(planetProfileProvider).valueOrNull;
  return profile?.canViewSensitive ?? false;
});

// ── Presence Provider ───────────────────────────────────────────────────

/// Synchronously returns the current presence (online status) of a user
/// if it exists in the profile cache.
final userPresenceProvider = Provider.family<PlanetModel?, String>((ref, uid) {
  return ref.watch(planetProfileByUidProvider(uid)).valueOrNull;
});

// ── Profile Cache (In-Memory) ──────────────────────────────────────────────────

/// Holds the last-known PlanetModel for each UID to prevent UI flickering/UID display
/// during stream transitions or network reconnection cycles.
final profileCacheProvider = StateProvider<Map<String, PlanetModel>>(
  (ref) => {},
);

final planetProfileByUidProvider = StreamProvider.family<PlanetModel?, String>((
  ref,
  uid,
) async* {
  if (uid.isEmpty) {
    yield null;
    return;
  }

  final repo = ref.watch(authRepositoryProvider);

  // Helper to update global cache
  void updateCache(PlanetModel? model) {
    if (model != null) {
      Future.microtask(() {
        if (!ref.exists(profileCacheProvider)) return;
        final current = ref.read(profileCacheProvider);
        if (current[uid] != model) {
          ref.read(profileCacheProvider.notifier).state = {
            ...current,
            uid: model,
          };
        }
      });
    }
  }

  // 1. Fetch initial state via HTTP to bypass potential Realtime delays/timeouts
  try {
    final initialData = await repo.fetchPlanetProfileForProvider(uid);
    debugPrint(
      'AUTH: Initial profile fetch for $uid: ${initialData != null ? "FOUND (${initialData['xparq_name']})" : "NOT FOUND"}',
    );
    final model =
        initialData != null ? PlanetModel.fromMap(initialData, uid) : null;
    updateCache(model);

    // If initial fetch fails/is empty, check SQLite then memory cache
    if (model != null) {
      yield model;
    } else {
      // 1. Try Memory Cache
      final memoryCached = ref.read(profileCacheProvider)[uid];
      if (memoryCached != null) {
        yield memoryCached;
      } else {
        // 2. Try Persistent SQLite Cache
        final dbData = await OfflineChatDatabase.instance.getProfileCache(uid);
        if (dbData != null) {
          final dbModel = PlanetModel.fromMap(dbData, uid);
          updateCache(dbModel); // Update memory cache and re-persist to SQLite
          yield dbModel;
        } else {
          // 3. Fallback to Placeholder if absolutely no data is found
          final placeholder = PlanetModel.placeholder(uid);
          updateCache(placeholder);
          yield placeholder;
        }
      }
    }
  } catch (e) {
    debugPrint('AUTH: Initial profile fetch error for $uid: $e');
    // Fallback to cache if HTTP fails
    final cached = ref.read(profileCacheProvider)[uid];
    if (cached != null) {
      yield cached;
    } else {
      yield PlanetModel.placeholder(uid);
    }
  }

  // 2. Yield updates from realtime stream
  try {
    await for (final data in repo.watchProfile(uid)) {
      final model = data != null ? PlanetModel.fromMap(data, uid) : null;
      if (model != null) {
        updateCache(model);
        yield model;
        continue;
      }

      // If the realtime stream is temporarily empty, fall back to the best
      // known local state instead of replacing a valid profile with null.
      final cached = ref.read(profileCacheProvider)[uid];
      if (cached != null) {
        yield cached;
      } else {
        yield PlanetModel.placeholder(uid);
      }
    }
  } catch (e) {
    debugPrint('AUTH: Profile Realtime family error ($uid): $e');
    // Final fallback
    final cached = ref.read(profileCacheProvider)[uid];
    yield cached ?? PlanetModel.placeholder(uid);
  }
});

// ── Auth Notifier ─────────────────────────────────────────────────────────

/// State for the auth flow (used during onboarding screens).
class AuthState {
  final bool isLoading;
  final String? errorMessage;
  final String? successMessage;
  final AuthStep step;
  final String? verificationId;
  final String authMethod; // 'phone' or 'email'
  final bool isDeleting;
  final String? email; // Store email for OTP verification
  final String? phoneNumber; // Store phone number for OTP verification

  const AuthState({
    this.isLoading = false,
    this.errorMessage,
    this.successMessage,
    this.step = AuthStep.initial,
    this.verificationId,
    this.authMethod = 'phone',
    this.isDeleting = false,
    this.email,
    this.phoneNumber,
  });

  AuthState copyWith({
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
    String? successMessage,
    bool clearSuccess = false,
    AuthStep? step,
    String? verificationId,
    bool clearVerificationId = false,
    String? authMethod,
    bool? isDeleting,
    String? email,
    String? phoneNumber,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      successMessage:
          clearSuccess ? null : (successMessage ?? this.successMessage),
      step: step ?? this.step,
      verificationId:
          clearVerificationId ? null : (verificationId ?? this.verificationId),
      authMethod: authMethod ?? this.authMethod,
      isDeleting: isDeleting ?? this.isDeleting,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
    );
  }
}

enum AuthStep {
  initial,
  otpSent,
  otpVerified,
  emailVerificationSent,
  profileCreation,
  nsfwOptIn,
  complete,
  recovery,
  forgotPasswordEmailInput,
  forgotPasswordEmailSent,
}

class AuthNotifier extends StateNotifier<AuthState> {
  final SupabaseAuthRepository _repository;
  final Ref _ref;

  AuthNotifier(this._repository, this._ref) : super(const AuthState()) {
    _initRestoreListener();
  }

  void _initRestoreListener() {
    // Check if we captured the initial event in main.dart
    if (initialPasswordRecoveryEvent) {
      debugPrint('AUTH: Detected initial recovery event from global flag.');
      state = state.copyWith(step: AuthStep.recovery);
    }

    _repository.authStateChanges.listen((event) {
      debugPrint('AUTH: Auth event received: ${event.event}');
      if (event.event == AuthChangeEvent.passwordRecovery) {
        state = state.copyWith(step: AuthStep.recovery);
      }
    });
  }

  Future<QuickAuthService?> _getQuickAuth() async {
    return await _ref.read(quickAuthServiceProvider.future);
  }

  Future<void> _cacheUserForQuickLogin(User user) async {
    try {
      final quickAuth = await _getQuickAuth();
      if (quickAuth == null) return;

      final session = Supabase.instance.client.auth.currentSession;
      if (session != null &&
          session.accessToken.isNotEmpty &&
          session.refreshToken != null) {
        await quickAuth.saveSession(
          user.id,
          accessToken: session.accessToken,
          refreshToken: session.refreshToken!,
        );
      }

      // Don't let profile fetch block the quick login flow
      final profileData = await _repository
          .fetchPlanetProfile(user.id)
          .timeout(const Duration(seconds: 5))
          .catchError((e) => null);

      if (profileData != null) {
        final profile = PlanetModel.fromMap(profileData, user.id);
        await quickAuth.saveQuickAccount(
          QuickAccount(
            uid: user.id,
            email: user.email ?? '',
            xparqName: profile.xparqName,
            photoUrl: profile.photoUrl,
            lastUsed: DateTime.now(),
            isEnabled: (quickAuth.getQuickAccounts())
                .firstWhere(
                  (a) => a.uid == user.id,
                  orElse: () => QuickAccount(
                    uid: '',
                    email: '',
                    xparqName: profile.xparqName,
                    photoUrl: '',
                    lastUsed: DateTime.now(),
                    isEnabled: false,
                  ),
                )
                .isEnabled,
          ),
        );
      }
    } catch (e) {
      // Silent error for caching
    }
  }

  Future<void> _clearLocalAuthState({String? uid}) async {
    _ref.read(isLoginFlowProvider.notifier).state = false;
    _ref.read(profileCacheProvider.notifier).state = {};
    _ref.read(activeChatIdProvider.notifier).state = null;

    try {
      final navPersist = _ref.read(navigationPersistenceProvider);
      await navPersist.clear();
    } catch (e) {
      debugPrint('AUTH: Failed to clear router state: $e');
    }

    try {
      await OfflineChatDatabase.instance.clearProfileCache();
    } catch (e) {
      debugPrint('AUTH: Failed to clear profile cache: $e');
    }

    try {
      await OfflineChatDatabase.instance.clearSignalSessions();
    } catch (e) {
      debugPrint('AUTH: Failed to clear signal sessions: $e');
    }

    if (uid == null) return;

    try {
      final quickAuth = await _getQuickAuth();
      if (quickAuth != null) {
        await quickAuth.clearSession(uid);
      }
    } catch (e) {
      debugPrint('AUTH: Failed to clear quick session for $uid: $e');
    }
  }

  void resetAuthState() {
    state = const AuthState();
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }

  void resetToForgotPassword() {
    state = const AuthState(step: AuthStep.forgotPasswordEmailInput);
  }

  // ── Phone OTP ─────────────────────────────────────────────────────────

  Future<void> sendPhoneOtp(String phoneNumber) async {
    state = state.copyWith(
      isLoading: true,
      clearError: true,
      authMethod: 'phone',
      isDeleting: false,
      phoneNumber: phoneNumber,
    );
    try {
      await _repository.sendPhoneOtp(
        phoneNumber: phoneNumber,
        // Supabase doesn't use these specific callbacks
        verificationCompleted: (_) {},
        verificationFailed: (_) {},
        codeSent: (String vid, int? token) {
          state = state.copyWith(
            isLoading: false,
            step: AuthStep.otpSent,
            verificationId: vid,
          );
        },
        codeAutoRetrievalTimeout: (_) {},
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: _mapError(e));
    }
  }

  Future<void> verifyPhoneOtp(String otpCode) async {
    state = state.copyWith(
      isLoading: true,
      clearError: true,
      isDeleting: false,
    );
    try {
      await _repository.verifyPhoneCredential(
        phoneNumber: state.phoneNumber ?? '',
        otpCode: otpCode,
      );
      state = state.copyWith(
        isLoading: false,
        step: AuthStep.otpVerified,
        isDeleting: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: _mapError(e));
    }
  }

  // ── Email Auth (Password) ─────────────────────────────────────────────

  Future<void> signInWithEmailPassword({
    required String email,
    required String password,
  }) async {
    state = state.copyWith(
      isLoading: true,
      clearError: true,
      authMethod: 'email',
      isDeleting: false,
    );
    try {
      final response = await _repository.signInWithEmail(
        email: email,
        password: password,
      );
      if (response.user != null) {
        unawaited(_cacheUserForQuickLogin(response.user!));
        _ref.read(isLoginFlowProvider.notifier).state = true;
        state = state.copyWith(
          isLoading: false,
          step: AuthStep.complete, // No OTP needed, immediately proceed
        );
      } else {
        throw const AuthException('Invalid login credentials');
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: _mapError(e));
    }
  }

  Future<void> registerWithEmailPassword({
    required String email,
    required String password,
  }) async {
    state = state.copyWith(
      isLoading: true,
      clearError: true,
      authMethod: 'email',
      isDeleting: false,
    );
    try {
      final response = await _repository.registerWithEmail(
        email: email,
        password: password,
      );
      if (response.user != null) {
        // Go to OTP verification step
        state = state.copyWith(
          isLoading: false,
          step: AuthStep.emailVerificationSent,
          email: email, // Store email for the OTP step
        );
      } else {
        throw const AuthException('Failed to register');
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: _mapError(e));
    }
  }

  Future<void> verifyEmailOtpSignup(String email, String otpCode) async {
    state = state.copyWith(
      isLoading: true,
      clearError: true,
      isDeleting: false,
    );
    try {
      final response = await _repository.verifyEmailOtpSignup(
        email: email,
        otpCode: otpCode,
      );
      if (response.user != null) {
        await _cacheUserForQuickLogin(response.user!);
        _ref.read(isLoginFlowProvider.notifier).state = true;
        state = state.copyWith(isLoading: false, step: AuthStep.otpVerified);
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'authErrorInvalidOtp',
      );
    }
  }

  Future<void> sendEmailOtp(String email) async {
    state = state.copyWith(
      isLoading: true,
      clearError: true,
      authMethod: 'email',
      isDeleting: false,
      email: email,
    );
    try {
      await _repository.signInWithEmailOtp(email: email);
      state = state.copyWith(
        isLoading: false,
        step: AuthStep.emailVerificationSent,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: _mapError(e));
    }
  }

  // ── Forgot Password ───────────────────────────────────────────────────

  /// Step 1 (Real): Send Firebase password reset email.
  Future<void> sendRealPasswordResetEmail(String email) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      await _repository.sendPasswordResetEmail(email);
      state = state.copyWith(
        isLoading: false,
        step: AuthStep.forgotPasswordEmailSent,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: _mapError(e));
    }
  }

  Future<void> updatePassword(String newPassword) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: newPassword),
      );
      state = state.copyWith(isLoading: false, step: AuthStep.complete);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: _mapError(e));
    }
  }

  // verifyEmailOtp was moved and merged into verifyEmailOtpLogin

  // ── Profile Creation ──────────────────────────────────────────────────

  Future<void> createProfile({
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
    final uid = _repository.currentUser?.id;
    if (uid == null) return;

    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final planet = await _repository.createPlanetProfile(
        uid: uid,
        xparqName: xparqName,
        bio: bio,
        mbti: mbti,
        enneagram: enneagram,
        zodiac: zodiac,
        bloodType: bloodType,
        photoUrl: photoUrl,
        dob: dob,
        constellations: constellations,
      );

      // If Explorer, go to NSFW opt-in step; otherwise complete
      state = state.copyWith(
        isLoading: false,
        step: planet.isExplorer ? AuthStep.nsfwOptIn : AuthStep.complete,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: _mapError(e));
    }
  }

  Future<void> setNsfwOptIn({
    required bool value,
    required AgeGroup ageGroup,
  }) async {
    final uid = _repository.currentUser?.id;
    if (uid == null) return;
    await _repository.setNsfwOptIn(uid: uid, value: value, ageGroup: ageGroup);
    state = state.copyWith(step: AuthStep.complete);
  }

  // ── Ghost Mode ────────────────────────────────────────────────────────────

  Future<void> toggleGhostMode(bool enabled) async {
    try {
      await _repository.updateGhostMode(enabled);
    } catch (e) {
      state = state.copyWith(errorMessage: _mapError(e));
    }
  }

  Future<void> signOut() async {
    final uid = _repository.currentUser?.id;
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      await _repository.signOut();
    } catch (e) {
      debugPrint('AUTH: Signout error: $e');
    } finally {
      await _clearLocalAuthState(uid: uid);
      state = const AuthState();
    }
  }

  Future<void> quickLogin(String uid, String email, String password) async {
    if (email.isEmpty) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'authErrorInvalidEmail',
      );
      return;
    }

    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final response = await _repository.signInWithEmail(
        email: email,
        password: password,
      );

      if (response.user != null) {
        unawaited(_cacheUserForQuickLogin(response.user!));
        _ref.read(isLoginFlowProvider.notifier).state = true;
        state = state.copyWith(isLoading: false, step: AuthStep.complete);
      } else {
        state = state.copyWith(
          isLoading: false,
          errorMessage: 'authErrorInvalidCredentials',
        );
      }
    } catch (e) {
      debugPrint('QuickLogin Error: $e');
      state = state.copyWith(isLoading: false, errorMessage: _mapError(e));
    }
  }

  // ── Account Management ────────────────────────────────────────────────────────

  Future<void> deleteAccount() async {
    final uid = _repository.currentUser?.id;
    state = state.copyWith(
      isLoading: true,
      clearError: true,
      isDeleting: false,
    );
    try {
      await _repository.deleteUserAccount();
      await _clearLocalAuthState(uid: uid);
      state = state.copyWith(isLoading: false, isDeleting: true);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: _mapError(e),
        isDeleting: false,
      );
    }
  }

  Future<void> sendRecoveryOtp() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      await Future.delayed(const Duration(seconds: 1));
      state = state.copyWith(isLoading: false, step: AuthStep.otpSent);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: _mapError(e));
    }
  }

  Future<void> restoreAccount() async {
    final uid = _repository.currentUser?.id;
    if (uid == null) return;
    
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      await _repository.restoreAccount(uid);
      state = state.copyWith(isLoading: false, step: AuthStep.complete);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: _mapError(e));
    }
  }

  void cancelRecovery() {
    state = const AuthState();
    signOut();
  }

  String _mapError(Object e) {
    if (e is AuthException) return e.message;
    return e.toString();
  }
}

final authNotifierProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref.watch(authRepositoryProvider), ref);
});