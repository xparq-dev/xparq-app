// lib/core/extensions/context_extensions.dart

import 'package:flutter/material.dart';
import 'package:xparq_app/l10n/app_localizations.dart';

extension BuildContextExtensions on BuildContext {
  /// Quick access to AppLocalizations without null assertion.
  AppLocalizations get l10n => AppLocalizations.of(this)!;

  /// Returns true if the current theme is dark mode.
  bool get isDark => Theme.of(this).brightness == Brightness.dark;

  /// Returns the screen width.
  double get screenWidth => MediaQuery.of(this).size.width;

  /// Returns the screen height.
  double get screenHeight => MediaQuery.of(this).size.height;

  /// Returns the bottom safe area padding (e.g. home indicator on iOS).
  double get bottomPadding => MediaQuery.paddingOf(this).bottom;

  /// Returns true if the screen is wider than 600 (tablet/desktop breakpoint).
  bool get isWideScreen => screenWidth > 600;

  /// Returns the current theme's primary color.
  Color get primaryColor => Theme.of(this).colorScheme.primary;

  /// Returns the current theme's surface color.
  Color get surfaceColor => Theme.of(this).colorScheme.surface;

  /// Returns the current ColorScheme.
  ColorScheme get colorScheme => Theme.of(this).colorScheme;
}
