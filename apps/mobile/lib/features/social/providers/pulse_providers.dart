import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xparq_app/features/auth/models/planet_model.dart';
import 'package:xparq_app/features/auth/providers/auth_providers.dart';
import 'package:xparq_app/features/social/models/pulse_model.dart';
import 'package:xparq_app/features/social/repositories/pulse_repository.dart';

// ── Repository ──────────────────────────────────────────────────────────────

final pulseRepositoryProvider = Provider<PulseRepository>((ref) {
  return PulseRepository();
});

// ── Refresh Control ─────────────────────────────────────────────────────────

/// A simple counter used to force providers to refresh (e.g. after a delete)
final pulseRefreshProvider = StateProvider<int>((ref) => 0);

// ── Feed (Orbit) ────────────────────────────────────────────────────────────

final orbitFeedProvider = FutureProvider<List<PulseModel>>((ref) async {
  // Watch the refresh counter: whenever it changes, this future re-runs
  ref.watch(pulseRefreshProvider);
  
  final repo = ref.watch(pulseRepositoryProvider);
  final profile = ref.watch(planetProfileProvider).valueOrNull;
  final isCadet = profile?.isCadet ?? true;
  final ageGroup = profile?.ageGroup;

  // Use the standard fetch instead of the stream to ensure consistency
  return repo.getGlobalOrbit(
    limit: 50,
    safeOnly: isCadet,
    callerAgeGroup: ageGroup,
    // We don't use 'since' here to ensure everything is visible for cleaning
  );
});

/// Feed of active Supernovas (stories from the last 24h).
final supernovaFeedProvider = FutureProvider<List<PulseModel>>((ref) async {
  ref.watch(pulseRefreshProvider);
  final repo = ref.watch(pulseRepositoryProvider);
  final profile = ref.watch(planetProfileProvider).valueOrNull;
  final isCadet = profile?.isCadet ?? true;

  return repo.getActiveSupernovas(
    safeOnly: isCadet,
    callerAgeGroup: profile?.ageGroup,
  );
});

/// Specific user's pulses (for profile).
/// Always fetch all pulses (safeOnly: false).
/// - Cadets: Will see "Locked" UI for NSFW posts.
/// - Explorers: Will see blurred/revealed UI.
final userPulsesProvider = FutureProvider.family<List<PulseModel>, String>((
  ref,
  uid,
) async {
  ref.watch(pulseRefreshProvider);
  final repo = ref.watch(pulseRepositoryProvider);
  return repo.getUserPulses(uid, safeOnly: false);
});

/// Pulses warped by a specific user.
final userWarpsProvider = FutureProvider.family<List<PulseModel>, String>((
  ref,
  uid,
) async {
  ref.watch(pulseRefreshProvider);
  final repo = ref.watch(pulseRepositoryProvider);
  return repo.getUserWarps(uid, safeOnly: false);
});

/// Total aggregate sparks (likes) received by a user.
final userSparkCountProvider = FutureProvider.family<int, String>((ref, uid) async {
  ref.watch(pulseRefreshProvider);
  final repo = ref.watch(pulseRepositoryProvider);
  return repo.getTotalUserSparks(uid);
});

/// Total number of pulses (posts) created by a user.
final userPulseCountProvider = FutureProvider.family<int, String>((ref, uid) async {
  ref.watch(pulseRefreshProvider);
  final repo = ref.watch(pulseRepositoryProvider);
  return repo.getTotalUserPulses(uid);
});

// ── Creation Logic ──────────────────────────────────────────────────────────

class PulseState {
  final bool isLoading;
  final String? errorMessage;
  final bool isSuccess;

  const PulseState({
    this.isLoading = false,
    this.errorMessage,
    this.isSuccess = false,
  });
}

class PulseNotifier extends StateNotifier<PulseState> {
  final PulseRepository _repo;
  final Ref _ref;

  PulseNotifier(this._repo, this._ref) : super(const PulseState());

  Future<void> createPulse(
    String content, {
    String? imageUrl,
    String? videoUrl,
    String? moodEmoji,
    String? moodLabel,
    String? locationName,
    required PlanetModel author,
    bool isNsfw = false,
    String pulseType = 'post',
  }) async {
    state = const PulseState(isLoading: true);

    try {
      await _repo.createPulse(
        uid: author.id,
        content: content,
        authorProfile: author,
        imageUrl: imageUrl,
        videoUrl: videoUrl,
        moodEmoji: moodEmoji,
        moodLabel: moodLabel,
        locationName: locationName,
        isNsfw: isNsfw,
        pulseType: pulseType,
      );

      state = const PulseState(isLoading: false, isSuccess: true);

      state = const PulseState(isLoading: false, isSuccess: true);
      
      // TRIGGER GLOBAL PROVIDER RELOAD: Automatically updates Orbit, Planet, and Supernova feeds
      _ref.read(pulseRefreshProvider.notifier).state++;
    } catch (e) {
      state = PulseState(
        isLoading: false,
        errorMessage: 'Failed to launch pulse: $e',
      );
    }
  }

  void reset() => state = const PulseState();
}

final pulseNotifierProvider = StateNotifierProvider<PulseNotifier, PulseState>((
  ref,
) {
  return PulseNotifier(ref.watch(pulseRepositoryProvider), ref);
});

// ── Interaction Logic (Likes) ───────────────────────────────────────────────

/// Check if current user has liked a pulse.
final hasSparkedProvider = FutureProvider.family<bool, String>((
  ref,
  pulseId,
) async {
  final uid = ref.watch(authRepositoryProvider).currentUser?.id;
  if (uid == null) return false;
  return ref.watch(pulseRepositoryProvider).hasSparked(pulseId, uid);
});

/// Check if current user has warped a pulse.
final hasWarpedProvider = FutureProvider.family<bool, String>((
  ref,
  pulseId,
) async {
  final uid = ref.watch(authRepositoryProvider).currentUser?.id;
  if (uid == null) return false;
  return ref.watch(pulseRepositoryProvider).hasWarped(pulseId, uid);
});

/// Real-time stream of echoes (comments) for a pulse.
final echoesProvider = StreamProvider.family<List<dynamic>, String>((
  ref,
  pulseId,
) {
  return ref.watch(pulseRepositoryProvider).watchEchoes(pulseId);
});
