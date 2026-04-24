// lib/core/router/router_providers.dart
//
// Riverpod providers that support the router:
//   - sharedPreferencesProvider: canonical definition (initialize via overrides in main.dart)
//   - navigationPersistenceProvider: provides NavigationPersistenceService

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xparq_app/shared/router/navigation_persistence_service.dart';

/// The single canonical definition of sharedPreferencesProvider.
/// Must be overridden in main.dart via ProviderScope overrides.
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('Initialize sharedPreferencesProvider in main.dart overrides!');
});

/// Provides a [NavigationPersistenceService] backed by SharedPreferences.
final navigationPersistenceProvider = Provider<NavigationPersistenceService>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return NavigationPersistenceService(prefs);
});

