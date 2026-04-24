import 'dart:ui';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final localeProvider = StateNotifierProvider<LocaleNotifier, Locale>((ref) {
  return LocaleNotifier();
});

class LocaleNotifier extends StateNotifier<Locale> {
  LocaleNotifier({Locale? initial}) : super(initial ?? const Locale('en')) {
    if (initial == null) {
      _loadLocale();
    }
  }

  static const String _prefsKey = 'app_locale';

  Future<void> _loadLocale() async {
    final prefs = await SharedPreferences.getInstance();
    final languageCode = prefs.getString(_prefsKey);
    if (languageCode != null) {
      state = Locale(languageCode);
    } else {
      // Default to system locale if supported, else English
      final systemLocale = PlatformDispatcher.instance.locale;
      if (['en', 'th'].contains(systemLocale.languageCode)) {
        state = Locale(systemLocale.languageCode);
      }
    }
  }

  Future<void> setLocale(Locale locale) async {
    // Allow all supported locales defined in the app

    state = locale;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, locale.languageCode);
  }
}
