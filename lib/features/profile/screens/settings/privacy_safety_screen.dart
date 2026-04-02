// lib/features/profile/screens/settings/privacy_safety_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:xparq_app/core/enums/age_group.dart';
import 'package:xparq_app/features/auth/providers/auth_providers.dart';
import 'package:xparq_app/features/block_report/screens/blocked_users_screen.dart';
import 'package:xparq_app/l10n/app_localizations.dart';

import 'package:xparq_app/features/auth/services/privacy_service.dart';

class PrivacySafetyScreen extends ConsumerStatefulWidget {
  const PrivacySafetyScreen({super.key});

  @override
  ConsumerState<PrivacySafetyScreen> createState() =>
      _PrivacySafetyScreenState();
}

class _PrivacySafetyScreenState extends ConsumerState<PrivacySafetyScreen> {
  bool _isBiometricAvailable = false;
  bool _screenLockEnabled = false;

  @override
  void initState() {
    super.initState();
    _checkBiometrics();
  }

  Future<void> _checkBiometrics() async {
    final available = await PrivacyService.instance.isBiometricAvailable();
    final enabled = await PrivacyService.instance.isScreenLockEnabled();
    if (mounted) {
      setState(() {
        _isBiometricAvailable = available;
        _screenLockEnabled = enabled;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final textColor = Theme.of(context).colorScheme.onSurface;
    final subtitleColor = textColor.withOpacity(0.55);
    final profile = ref.watch(planetProfileProvider).valueOrNull;
    final ageGroup = ref.watch(currentAgeGroupProvider);
    final notifier = ref.read(authNotifierProvider.notifier);

    final bool isAdult = ageGroup == AgeGroup.explorer;
    final bool ghostMode = profile?.ghostMode ?? false;
    final bool nsfwEnabled = profile?.canViewSensitive ?? false;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        surfaceTintColor: Colors.transparent,
        iconTheme: IconThemeData(color: textColor),
        title: Text(
          AppLocalizations.of(context)!.privacyTitle,
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
          // ── Screen Lock ──────────────────────────────────────────────
          _Header(title: AppLocalizations.of(context)!.privacySecurity),
          if (_isBiometricAvailable)
            SwitchListTile(
              secondary: Icon(
                Icons.screen_lock_portrait,
                color: _screenLockEnabled
                    ? const Color(0xFF4FC3F7)
                    : subtitleColor,
              ),
              title: Text(AppLocalizations.of(context)!.privacyScreenLock),
              subtitle: Text(
                AppLocalizations.of(context)!.privacyScreenLockDesc,
              ),
              value: _screenLockEnabled,
              activeThumbColor: const Color(0xFF4FC3F7),
              onChanged: (val) async {
                HapticFeedback.heavyImpact();
                final success = await PrivacyService.instance.authenticate(
                  reason: AppLocalizations.of(
                    context,
                  )!.privacyScreenLockConfirm,
                );
                if (success) {
                  await PrivacyService.instance.setScreenLockEnabled(val);
                  setState(() => _screenLockEnabled = val);
                }
              },
            )
          else
            ListTile(
              leading: Icon(Icons.screen_lock_portrait, color: subtitleColor),
              title: Text(AppLocalizations.of(context)!.privacyScreenLock),
              subtitle: Text(
                AppLocalizations.of(context)!.privacyBiometricsNotAvailable,
              ),
              trailing: Icon(
                Icons.lock_outline,
                color: subtitleColor,
                size: 18,
              ),
            ),

          // ── Visibility ───────────────────────────────────────────────
          _Header(title: AppLocalizations.of(context)!.privacyVisibility),
          SwitchListTile(
            secondary: Icon(
              Icons.visibility_off_outlined,
              color: ghostMode ? const Color(0xFF00BA7C) : subtitleColor,
            ),
            title: Text(
              AppLocalizations.of(context)!.ghostModeTitle,
              style: TextStyle(color: textColor),
            ),
            subtitle: Text(
              AppLocalizations.of(context)!.privacyGhostModeDesc,
              style: TextStyle(color: subtitleColor, fontSize: 12),
            ),
            value: ghostMode,
            activeThumbColor: const Color(0xFF00BA7C),
            onChanged: (val) {
              HapticFeedback.lightImpact();
              notifier.toggleGhostMode(val);
            },
          ),
          _ComingSoonTile(
            icon: Icons.person_search_outlined,
            title: AppLocalizations.of(context)!.privacyWhoCanSeeProfile,
            subtitle: AppLocalizations.of(context)!.privacyWhoCanSeeProfileDesc,
            textColor: textColor,
            subtitleColor: subtitleColor,
          ),
          _ComingSoonTile(
            icon: Icons.circle_outlined,
            title: AppLocalizations.of(context)!.privacyOnlineStatus,
            subtitle: AppLocalizations.of(context)!.privacyOnlineStatusDesc,
            textColor: textColor,
            subtitleColor: subtitleColor,
          ),

          // ── 18+ Content ──────────────────────────────────────────────
          _Header(title: AppLocalizations.of(context)!.privacyContentFiltering),
          if (!isAdult) ...[
            ListTile(
              leading: Icon(Icons.dark_mode_outlined, color: subtitleColor),
              title: Text(
                '${AppLocalizations.of(context)!.nsfwTitle} (18+)',
                style: TextStyle(color: subtitleColor),
              ),
              subtitle: Text(
                AppLocalizations.of(context)!.privacyAdultOnly,
                style: TextStyle(color: subtitleColor, fontSize: 12),
              ),
              trailing: Icon(
                Icons.lock_outline,
                color: subtitleColor,
                size: 18,
              ),
            ),
          ] else ...[
            SwitchListTile(
              secondary: Icon(
                Icons.dark_mode_outlined,
                color: nsfwEnabled ? const Color(0xFF9C27B0) : subtitleColor,
              ),
              title: Text(
                '${AppLocalizations.of(context)!.nsfwTitle} (18+)',
                style: TextStyle(color: textColor),
              ),
              subtitle: Text(
                nsfwEnabled
                    ? AppLocalizations.of(context)!.privacyNsfwOn
                    : AppLocalizations.of(context)!.privacyNsfwOff,
                style: TextStyle(
                  color: nsfwEnabled
                      ? const Color(0xFF9C27B0).withOpacity(0.8)
                      : subtitleColor,
                  fontSize: 12,
                ),
              ),
              value: nsfwEnabled,
              activeThumbColor: const Color(0xFF9C27B0),
              onChanged: (val) {
                HapticFeedback.mediumImpact();
                if (val) {
                  _showBlackHoleConfirmation(context, ref);
                } else {
                  // Turn off immediately
                  ref
                      .read(authNotifierProvider.notifier)
                      .setNsfwOptIn(value: false, ageGroup: ageGroup);
                }
              },
            ),
          ],
          _ComingSoonTile(
            icon: Icons.comments_disabled_outlined,
            title: AppLocalizations.of(context)!.privacyHiddenWords,
            subtitle: AppLocalizations.of(context)!.privacyHiddenWordsDesc,
            textColor: textColor,
            subtitleColor: subtitleColor,
          ),

          // ── Interactions ─────────────────────────────────────────────
          _Header(title: AppLocalizations.of(context)!.privacyInteractions),
          _ComingSoonTile(
            icon: Icons.message_outlined,
            title: AppLocalizations.of(context)!.privacyWhoCanDM,
            subtitle: AppLocalizations.of(context)!.privacyWhoCanDMDesc,
            textColor: textColor,
            subtitleColor: subtitleColor,
          ),
          _ComingSoonTile(
            icon: Icons.comment_outlined,
            title: AppLocalizations.of(context)!.privacyWhoCanComment,
            subtitle: AppLocalizations.of(context)!.privacyWhoCanCommentDesc,
            textColor: textColor,
            subtitleColor: subtitleColor,
          ),
          ListTile(
            leading: Icon(Icons.block, color: subtitleColor),
            title: Text(
              AppLocalizations.of(context)!.blockedUsersTitle,
              style: TextStyle(color: textColor),
            ),
            trailing: Icon(Icons.chevron_right, color: subtitleColor),
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const BlockedUsersScreen()),
              );
            },
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  void _showBlackHoleConfirmation(BuildContext context, WidgetRef ref) {
    final ageGroup = ref.read(currentAgeGroupProvider);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.dark_mode_outlined, color: Color(0xFF9C27B0)),
            const SizedBox(width: 10),
            Text(AppLocalizations.of(context)!.privacyNsfwConfirmTitle),
          ],
        ),
        content: Text(
          AppLocalizations.of(context)!.privacyNsfwConfirmDesc,
          style: const TextStyle(height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF9C27B0),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              ref
                  .read(authNotifierProvider.notifier)
                  .setNsfwOptIn(value: true, ageGroup: ageGroup);
            },
            child: Text(AppLocalizations.of(context)!.privacyNsfwConfirmButton),
          ),
        ],
      ),
    );
  }
}

// ── Reusable Helpers ────────────────────────────────────────────────────────

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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.comingSoon)),
        );
      },
    );
  }
}
