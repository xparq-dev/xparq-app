// lib/core/theme/theme_provider.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final themeProvider = StateNotifierProvider<ThemeNotifier, ThemeMode>((ref) {
  return ThemeNotifier();
});

class ThemeNotifier extends StateNotifier<ThemeMode> {
  static const _themePrefKey = 'theme_preference';

  ThemeNotifier({ThemeMode? initial}) : super(initial ?? ThemeMode.dark) {
    // Only async-load if no initial provided (avoids rebuild)
    if (initial == null) _loadTheme();
  }

  void _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final isLight = prefs.getBool(_themePrefKey) ?? false;
    state = isLight ? ThemeMode.light : ThemeMode.dark;
  }

  void toggleTheme() async {
    final isDark = state == ThemeMode.dark;
    state = isDark ? ThemeMode.light : ThemeMode.dark;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_themePrefKey, state == ThemeMode.light);
  }
}
