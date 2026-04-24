// lib/features/profile/screens/settings/content_display_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:xparq_app/l10n/app_localizations.dart';
import 'package:xparq_app/shared/constants/language_data.dart';
import 'package:xparq_app/shared/providers/locale_provider.dart';
import 'package:xparq_app/shared/theme/theme_provider.dart';

class ContentDisplayScreen extends ConsumerWidget {
  const ContentDisplayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final textColor = Theme.of(context).colorScheme.onSurface;
    final subtitleColor = textColor.withValues(alpha: 0.55);

    final themeMode = ref.watch(themeProvider);
    final isDark = themeMode == ThemeMode.dark;
    final currentLocale = ref.watch(localeProvider);
    final currentLang = allLanguages.firstWhere(
      (l) => l.code == currentLocale.languageCode,
      orElse: () => allLanguages.first,
    );

    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        surfaceTintColor: Colors.transparent,
        iconTheme: IconThemeData(color: textColor),
        title: Text(
          l10n.settingsDisplayTitle,
          style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            HapticFeedback.lightImpact();
            context.pop();
          },
        ),
      ),
      body: ListView(
        children: [
          // ── Appearance ───────────────────────────────────────────────
          _Header(title: l10n.appearanceSection),
          SwitchListTile(
            secondary: Icon(
              isDark ? Icons.dark_mode : Icons.light_mode,
              color: const Color(0xFF1D9BF0),
            ),
            title: Text(
              isDark ? l10n.darkMode : l10n.lightMode,
              style: TextStyle(color: textColor),
            ),
            subtitle: Text(
              isDark ? 'Using dark theme' : 'Using light theme',
              style: TextStyle(color: subtitleColor, fontSize: 12),
            ),
            value: isDark,
            activeThumbColor: const Color(0xFF1D9BF0),
            onChanged: (_) {
              HapticFeedback.lightImpact();
              ref.read(themeProvider.notifier).toggleTheme();
            },
          ),
          _ComingSoonTile(
            icon: Icons.text_fields_outlined,
            title: 'Text Size',
            subtitle: 'Adjust font size across the app',
            textColor: textColor,
            subtitleColor: subtitleColor,
          ),

          // ── Language ─────────────────────────────────────────────────
          _Header(title: l10n.languageTitle),
          ListTile(
            leading: Icon(Icons.language, color: subtitleColor),
            title: Text(
              l10n.appLanguageTitle,
              style: TextStyle(color: textColor),
            ),
            subtitle: Text(
              currentLang.localName,
              style: TextStyle(color: subtitleColor, fontSize: 12),
            ),
            trailing: Icon(Icons.chevron_right, color: subtitleColor),
            onTap: () {
              HapticFeedback.lightImpact();
              _showLanguagePicker(context, ref);
            },
          ),

          // ── Feed Preferences ─────────────────────────────────────────
          _Header(title: l10n.feedOrbitSection),
          _ComingSoonTile(
            icon: Icons.play_circle_outline,
            title: l10n.autoplayVideoTitle,
            subtitle: l10n.autoplayVideoSubtitle,
            textColor: textColor,
            subtitleColor: subtitleColor,
          ),
          _ComingSoonTile(
            icon: Icons.topic_outlined,
            title: l10n.manageTopicsTitle,
            subtitle: l10n.manageTopicsSubtitle,
            textColor: textColor,
            subtitleColor: subtitleColor,
          ),
          _ComingSoonTile(
            icon: Icons.videocam_outlined,
            title: l10n.videoResolutionTitle,
            subtitle: l10n.videoResolutionSubtitle,
            textColor: textColor,
            subtitleColor: subtitleColor,
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  void _showLanguagePicker(BuildContext context, WidgetRef ref) {
    final sorted = getSortedLanguages();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context)!;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF16181C) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                l10n.languagePickerTitle,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: sorted.length,
                itemBuilder: (_, i) {
                  final lang = sorted[i];
                  final isSelected =
                      ref.read(localeProvider).languageCode == lang.code;
                  return ListTile(
                    title: Text(
                      lang.localName,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                    trailing: isSelected
                        ? const Icon(Icons.check, color: Color(0xFF1D9BF0))
                        : null,
                    onTap: () {
                      HapticFeedback.mediumImpact();
                      ref
                          .read(localeProvider.notifier)
                          .setLocale(Locale(lang.code));
                      Navigator.pop(ctx);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final String title;
  const _Header({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          color: Color(0xFF1D9BF0),
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _ComingSoonTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Color textColor;
  final Color subtitleColor;

  const _ComingSoonTile({
    required this.icon,
    required this.title,
    required this.textColor,
    required this.subtitleColor,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: subtitleColor),
      title: Text(title, style: TextStyle(color: textColor)),
      subtitle: subtitle != null
          ? Text(
              subtitle!,
              style: TextStyle(color: subtitleColor, fontSize: 12),
            )
          : null,
      trailing: Icon(Icons.chevron_right, color: subtitleColor),
      onTap: () {
        HapticFeedback.lightImpact();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Coming soon ✨')));
      },
    );
  }
}
