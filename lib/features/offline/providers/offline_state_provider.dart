import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Toggles whether the app is currently running in completely offline Bluetooth mode.
final isOfflineModeProvider = StateProvider<bool>((ref) => false);
