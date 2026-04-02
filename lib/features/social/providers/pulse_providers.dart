import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xparq_app/features/auth/models/planet_model.dart';
import 'package:xparq_app/features/auth/providers/auth_providers.dart';
import 'package:xparq_app/features/social/models/pulse_model.dart';
import 'package:xparq_app/features/social/repositories/pulse_repository.dart';

// ── Repository ──────────────────────────────────────────────────────────────

final pulseRepositoryProvider = Provider<PulseRepository>((ref) {
  return PulseRepository();
});

// ── Feed (Orbit) ────────────────────────────────────────────────────────────

/// Global feed of pulses.
/// - Cadets: See only safe content (filtered at query level).
/// - Explorers: See all content (NSFW is blurred by PulseCard).
final orbitFeedProvider = FutureProvider<List<PulseModel>>((ref) async {
  final repo = ref.watch(pulseRepositoryProvider);
  final profile = ref.watch(planetProfileProvider).valueOrNull;
  final isCadet = profile?.isCadet ?? true; // Default to safe if null

  // Only show pulses from the last 24 hours
  final cutoff = DateTime.now().subtract(const Duration(hours: 24));

  return repo.getGlobalOrbit(
    limit: 50,
    safeOnly: isCadet,
    since: cutoff,
    pulseType: 'post',
  );
});

/// Feed of active Supernovas (stories from the last 24h).
final supernovaFeedProvider = FutureProvider<List<PulseModel>>((ref) async {
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
  final repo = ref.watch(pulseRepositoryProvider);
  return repo.getUserPulses(uid, safeOnly: false);
});

/// Pulses warped by a specific user.
final userWarpsProvider = FutureProvider.family<List<PulseModel>, String>((
  ref,
  uid,
) async {
  final repo = ref.watch(pulseRepositoryProvider);
  return repo.getUserWarps(uid, safeOnly: false);
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
        isNsfw: isNsfw,
        pulseType: pulseType,
      );

      state = const PulseState(isLoading: false, isSuccess: true);

      // Refresh the feeds locally so user sees their post/story
      // Ignore the returned Future since we don't need to await the refresh completion here
      // ignore: unused_result
      _ref.refresh(orbitFeedProvider);
      if (pulseType == 'story') {
        // ignore: unused_result
        _ref.refresh(supernovaFeedProvider);
      }
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
