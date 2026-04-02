import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xparq_app/features/offline/services/nearby_service.dart';

class OfflineUserState {
  final String userId;
  final String displayName;
  final bool isAnonymous;
  final bool isLoaded;

  OfflineUserState({
    this.userId = '',
    this.displayName = '',
    this.isAnonymous = false,
    this.isLoaded = false,
  });

  OfflineUserState copyWith({
    String? userId,
    String? displayName,
    bool? isAnonymous,
    bool? isLoaded,
  }) {
    return OfflineUserState(
      userId: userId ?? this.userId,
      displayName: displayName ?? this.displayName,
      isAnonymous: isAnonymous ?? this.isAnonymous,
      isLoaded: isLoaded ?? this.isLoaded,
    );
  }
}

class OfflineUserNotifier extends StateNotifier<OfflineUserState> {
  OfflineUserNotifier() : super(OfflineUserState()) {
    _loadFromPrefs();
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();

    String? userId = prefs.getString('offline_user_id');
    if (userId == null) {
      userId = 'user_${DateTime.now().millisecondsSinceEpoch}';
      await prefs.setString('offline_user_id', userId);
    }

    final name = prefs.getString('offline_display_name') ?? '';
    final anon = prefs.getBool('offline_is_anonymous') ?? false;
    state = OfflineUserState(
      userId: userId,
      displayName: name,
      isAnonymous: anon,
      isLoaded: true,
    );
  }

  Future<void> updateDisplayName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('offline_display_name', name);
    state = state.copyWith(displayName: name);
  }

  Future<void> toggleAnonymous(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('offline_is_anonymous', value);
    state = state.copyWith(isAnonymous: value);
  }

  Future<void> resetIdentity() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('offline_user_id');
    await prefs.remove('offline_display_name');
    await prefs.remove('offline_is_anonymous');

    // Explicitly reset mesh service state to kill any active advertisement/discovery
    await NearbyService.instance.resetAll();

    state = OfflineUserState(
      isLoaded: true,
    ); // Reset to empty, which will trigger redirection
  }
}

final offlineUserProvider =
    StateNotifierProvider<OfflineUserNotifier, OfflineUserState>((ref) {
      return OfflineUserNotifier();
    });
