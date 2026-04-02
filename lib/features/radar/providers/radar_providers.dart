// lib/features/radar/providers/radar_providers.dart
//
// Riverpod providers for the Radar module.

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:xparq_app/features/auth/providers/auth_providers.dart';
import 'package:xparq_app/features/radar/models/radar_xparq_model.dart';
import 'package:xparq_app/features/radar/repositories/radar_repository.dart';
import 'package:xparq_app/features/radar/services/location_service.dart';

// ── Repository ────────────────────────────────────────────────────────────────

final radarRepositoryProvider = Provider<RadarRepository>((ref) {
  return RadarRepository();
});

// ── Radar Mode ────────────────────────────────────────────────────────────────

enum RadarMode { online, offline }

// ── Radar State ───────────────────────────────────────────────────────────────

class RadarState {
  final RadarMode mode;
  final double radiusKm;
  final List<RadarXparq> onlineXparqs;
  final List<dynamic>
  offlineXparqs; // Kept for backwards compatibility but unused
  final List<RadarXparq> searchResults;
  final Position? currentPosition;
  final bool isLoading;
  final bool isSearching;
  final bool isNearXparq;
  final String? errorMessage;

  const RadarState({
    this.mode = RadarMode.online,
    this.radiusKm = 5.0,
    this.onlineXparqs = const [],
    this.offlineXparqs = const [],
    this.searchResults = const [],
    this.currentPosition,
    this.isLoading = false,
    this.isSearching = false,
    this.isNearXparq = false,
    this.errorMessage,
  });

  RadarState copyWith({
    RadarMode? mode,
    double? radiusKm,
    List<RadarXparq>? onlineXparqs,
    List<dynamic>? offlineXparqs,
    List<RadarXparq>? searchResults,
    Position? currentPosition,
    bool? isLoading,
    bool? isSearching,
    bool? isNearXparq,
    String? errorMessage,
  }) {
    return RadarState(
      mode: mode ?? this.mode,
      radiusKm: radiusKm ?? this.radiusKm,
      onlineXparqs: onlineXparqs ?? this.onlineXparqs,
      offlineXparqs: offlineXparqs ?? this.offlineXparqs,
      searchResults: searchResults ?? this.searchResults,
      currentPosition: currentPosition ?? this.currentPosition,
      isLoading: isLoading ?? this.isLoading,
      isSearching: isSearching ?? this.isSearching,
      isNearXparq: isNearXparq ?? this.isNearXparq,
      errorMessage: errorMessage,
    );
  }
}

// ── Radar Notifier ────────────────────────────────────────────────────────────

class RadarNotifier extends StateNotifier<RadarState> {
  final RadarRepository _repo;
  final Ref _ref;

  RadarNotifier(this._repo, this._ref) : super(const RadarState());

  // ── Global Search ─────────────────────────────────────────────────────────

  Future<void> searchUsers(String query) async {
    if (query.isEmpty) {
      state = state.copyWith(searchResults: [], isSearching: false);
      return;
    }

    state = state.copyWith(isSearching: true, errorMessage: null);

    try {
      final results = await _repo.searchUsers(query);
      state = state.copyWith(searchResults: results, isSearching: false);
    } catch (e) {
      state = state.copyWith(
        isSearching: false,
        errorMessage: 'Search failed: $e',
      );
    }
  }

  // ── Online Radar ──────────────────────────────────────────────────────────

  Future<void> scanOnline() async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final position = await LocationService.getCurrentPosition();
      if (position == null) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: 'Location permission denied',
        );
        return;
      }

      // Update own location — pass ghostMode so updateLocation() won't flip
      // is_online to true while the user wants to stay hidden.
      final uid = _ref.read(authRepositoryProvider).currentUser?.id;
      final isGhost =
          _ref.read(planetProfileProvider).valueOrNull?.ghostMode ?? false;

      if (uid != null) {
        await _repo.updateLocation(
          uid: uid,
          lat: position.latitude,
          lng: position.longitude,
          ghostMode: isGhost,
        );
      }

      // If ghost mode is on, this user should not appear in others' radar.
      // We still run the query so the ghost user can SEE others.
      final ageGroup = _ref.read(currentAgeGroupProvider);

      // Try Cloud Function first, fallback to local query
      List<RadarXparq> xparqs;
      try {
        xparqs = await _repo.queryNearby(
          lat: position.latitude,
          lng: position.longitude,
          radiusKm: state.radiusKm,
          callerAgeGroup: ageGroup,
        );
      } catch (_) {
        // Fallback to local Firestore query
        xparqs = await _repo.queryNearbyLocal(
          lat: position.latitude,
          lng: position.longitude,
          radiusKm: state.radiusKm,
          callerAgeGroup: ageGroup,
          callerUid: uid ?? '',
        );
      }

      // Check for proximity (within 50m)
      bool isNear = xparqs.any((s) => s.distanceMeters < 50);
      if (isNear && !state.isNearXparq) {
        HapticFeedback.vibrate();
      }

      state = state.copyWith(
        isLoading: false,
        currentPosition: position,
        onlineXparqs: xparqs,
        isNearXparq: isNear,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  // ── Offline BLE Radar ─────────────────────────────────────────────────────

  Future<void> startOfflineScan() async {
    // Note: Offline mode logic is now fully handled in the separate generic
    // offline feature folder via Google Nearby Connections.
    // Setting state here just updates the UI to show an empty state or redirect.
    state = state.copyWith(
      mode: RadarMode.offline,
      isLoading: false,
      offlineXparqs: [],
    );
  }

  Future<void> stopOfflineScan() async {
    state = state.copyWith(isLoading: false);
  }

  // ── Background / Silent Updates ───────────────────────────────────────────

  /// Silently update location if permission is already granted.
  /// Called on app startup (ControlDeck) to ensure discoverability.
  Future<void> refreshLocationIfPermitted() async {
    try {
      // Don't request permission, just check
      final position = await LocationService.getCurrentPosition(
        requestPermission: false,
      );
      if (position == null) return;

      final uid = _ref.read(authRepositoryProvider).currentUser?.id;
      if (uid == null) return;

      final isGhost =
          _ref.read(planetProfileProvider).valueOrNull?.ghostMode ?? false;

      // Update location coords but respect ghost mode (won't flip is_online)
      await _repo.updateLocation(
        uid: uid,
        lat: position.latitude,
        lng: position.longitude,
        ghostMode: isGhost,
      );
    } catch (_) {
      // Silent failure is purposeful here
    }
  }

  // ── Controls ──────────────────────────────────────────────────────────────

  void setMode(RadarMode mode) {
    if (mode == RadarMode.offline) {
      startOfflineScan();
    } else {
      stopOfflineScan();
      state = state.copyWith(mode: RadarMode.online);
      scanOnline();
    }
  }

  void expandRadius() {
    // Expand: 5km → 50km → country → global
    final next = state.radiusKm < 50
        ? 50.0
        : state.radiusKm < 500
        ? 500.0
        : 20000.0;
    state = state.copyWith(radiusKm: next);
    scanOnline();
  }
}

final radarNotifierProvider = StateNotifierProvider<RadarNotifier, RadarState>((
  ref,
) {
  return RadarNotifier(ref.watch(radarRepositoryProvider), ref);
});
