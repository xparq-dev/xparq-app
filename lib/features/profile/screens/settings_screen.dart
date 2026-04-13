// lib/features/profile/screens/settings_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:xparq_app/shared/router/app_router.dart';
import 'package:xparq_app/features/auth/providers/auth_providers.dart';
import 'package:xparq_app/l10n/app_localizations.dart';
import 'package:xparq_app/shared/widgets/common/xparq_image.dart';
import 'package:xparq_app/shared/widgets/ui/cards/glass_card.dart';
import 'package:xparq_app/features/control_deck/screens/control_deck_screen.dart';
import 'package:xparq_app/features/chat/data/services/signal/signal_backup_service.dart';
import 'package:xparq_app/shared/utils/isolate_logger.dart';

class SettingsScreen extends ConsumerWidget {
  final bool isEmbedded;
  const SettingsScreen({super.key, this.isEmbedded = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textColor = Theme.of(context).colorScheme.onSurface;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final subtitleColor = textColor.withValues(alpha: 0.55);
    final authState = ref.watch(authNotifierProvider);
    final notifier = ref.read(authNotifierProvider.notifier);
    final isLoading = authState.isLoading;

    final body = _buildBody(
      context,
      ref,
      textColor,
      bgColor,
      subtitleColor,
      notifier,
      isLoading,
    );

    final content = Stack(
      children: [
        body,
        if (isLoading)
          Positioned.fill(
            child: Container(
              color: Colors.black.withValues(alpha: 0.5),
              child: Center(
                child: GlassCard(
                  blur: 12,
                  opacity: 0.1,
                  borderRadius: BorderRadius.circular(24),
                  child: const Padding(
                    padding: EdgeInsets.all(40),
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
                ),
              ),
            ),
          ),
      ],
    );

    if (isEmbedded) return content;

    return PopScope(
      canPop: Navigator.of(context).canPop(),
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        final deck = ControlDeckProvider.of(context);
        deck?.pageController.animateToPage(
          3,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOutCubic,
        );
      },
      child: Scaffold(
        backgroundColor: bgColor,
        appBar: AppBar(
          backgroundColor: bgColor,
          surfaceTintColor: Colors.transparent,
          automaticallyImplyLeading: false,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: textColor),
            onPressed: () {
              if (Navigator.of(context).canPop()) {
                Navigator.pop(context);
              } else {
                final deck = ControlDeckProvider.of(context);
                deck?.pageController.animateToPage(
                  3,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOutCubic,
                );
              }
            },
          ),
          title: Text(
            AppLocalizations.of(context)!.settingsTitle,
            style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
          ),
        ),
        body: content,
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    WidgetRef ref,
    Color textColor,
    Color bgColor,
    Color subtitleColor,
    dynamic notifier,
    bool isLoading,
  ) {
    final profile = ref.watch(planetProfileProvider).valueOrNull;

    return ListView(
      padding: EdgeInsets.symmetric(vertical: isEmbedded ? 0 : 8),
      children: [
        if (!isEmbedded && profile != null) ...[
          InkWell(
            onTap: () => context.push(AppRoutes.editProfile),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: Colors.blueGrey.shade800,
                    backgroundImage: profile.photoUrl.isNotEmpty
                        ? XparqImage.getImageProvider(profile.photoUrl)
                        : null,
                    child: profile.photoUrl.isEmpty
                        ? const Icon(Icons.person, color: Colors.white54)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        profile.xparqName,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: textColor,
                        ),
                      ),
                      Text(
                        AppLocalizations.of(context)!.settingsViewAccount,
                        style: const TextStyle(
                          color: Color(0xFF1D9BF0),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Icon(Icons.chevron_right, color: subtitleColor),
                ],
              ),
            ),
          ),
        ],

        _SettingsTile(
          icon: Icons.manage_accounts_outlined,
          iconColor: const Color(0xFF1D9BF0),
          title: AppLocalizations.of(context)!.settingsMyAccountTitle,
          subtitle: AppLocalizations.of(context)!.settingsMyAccountSubtitle,
          onTap: () => context.push(AppRoutes.accountsCenter),
        ),
        _SettingsTile(
          icon: Icons.shield_outlined,
          iconColor: const Color(0xFF00BA7C),
          title: AppLocalizations.of(context)!.settingsPrivacyTitle,
          subtitle: AppLocalizations.of(context)!.settingsPrivacySubtitle,
          onTap: () => context.push(AppRoutes.privacySafety),
        ),
        _SettingsTile(
          icon: Icons.lock_outline,
          iconColor: const Color(0xFFFFB74D),
          title: AppLocalizations.of(context)!.settingsSecurityTitle,
          subtitle: AppLocalizations.of(context)!.settingsSecuritySubtitle,
          onTap: () => context.push(AppRoutes.passwordSecurity),
        ),
        _SettingsTile(
          icon: Icons.notifications_none_outlined,
          iconColor: const Color(0xFFEC407A),
          title: AppLocalizations.of(context)!.settingsNotificationsTitle,
          subtitle: AppLocalizations.of(context)!.settingsNotificationsSubtitle,
          onTap: () => context.push(AppRoutes.notificationsSettings),
        ),
        _SettingsTile(
          icon: Icons.tune_outlined,
          iconColor: const Color(0xFF7E57C2),
          title: AppLocalizations.of(context)!.settingsDisplayTitle,
          subtitle: AppLocalizations.of(context)!.settingsDisplaySubtitle,
          onTap: () => context.push(AppRoutes.contentDisplay),
        ),
        _SettingsTile(
          icon: Icons.perm_media_outlined,
          iconColor: const Color(0xFF26C6DA),
          title: AppLocalizations.of(context)!.settingsMediaTitle,
          subtitle: AppLocalizations.of(context)!.settingsMediaSubtitle,
          onTap: () => context.push(AppRoutes.mediaSettings),
        ),
        _SettingsTile(
          icon: Icons.language_outlined,
          iconColor: const Color(0xFF9C27B0),
          title: AppLocalizations.of(context)!.languageTitle,
          subtitle: AppLocalizations.of(context)!.appLanguageTitle,
          onTap: () => context.push(AppRoutes.contentDisplay),
        ),
        _SettingsTile(
          icon: Icons.family_restroom_outlined,
          iconColor: const Color(0xFF66BB6A),
          title: AppLocalizations.of(context)!.settingsFamilyTitle,
          subtitle: AppLocalizations.of(context)!.settingsFamilySubtitle,
          onTap: () => context.push(AppRoutes.familyCenter),
        ),
        _SettingsTile(
          icon: Icons.help_outline_outlined,
          iconColor: subtitleColor,
          title: AppLocalizations.of(context)!.settingsHelpTitle,
          subtitle: AppLocalizations.of(context)!.settingsHelpSubtitle,
          onTap: () => context.push(AppRoutes.helpSupport),
        ),
        _SettingsTile(
          icon: Icons.backup_outlined,
          iconColor: const Color(0xFFE91E63),
          title: AppLocalizations.of(context)!.settingsBackupTitle,
          subtitle: AppLocalizations.of(context)!.settingsBackupSubtitle,
          onTap: () => _showBackupDialog(context, ref),
        ),
        _SettingsTile(
          icon: Icons.bug_report_outlined,
          iconColor: Colors.orange,
          title: "Diagnostics",
          subtitle: "View background isolate logs",
          onTap: () => _showDiagnosticsDialog(context),
        ),

        const SizedBox(height: 12),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: OutlinedButton.icon(
          onPressed: isLoading ? null : () => _showSignOutDialog(context, notifier),
            icon: const Icon(Icons.logout, size: 18),
            label: Text(AppLocalizations.of(context)!.signOutButton),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red,
              side: BorderSide(color: Colors.red.withValues(alpha: 0.5)),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              minimumSize: const Size(double.infinity, 54),
            ),
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  void _showSignOutDialog(BuildContext context, dynamic notifier) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20),
        child: GlassCard(
          blur: 15,
          opacity: isDark ? 0.1 : 0.8,
          borderRadius: BorderRadius.circular(28),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.logout, color: Colors.red, size: 28),
                ),
                const SizedBox(height: 16),
                Text(
                  l10n.signOutConfirmTitle,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.signOutConfirmMessage,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(
                          l10n.offlineCancel,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          Navigator.pop(context);
                          await notifier.signOut();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(l10n.signOutConfirmButton),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showBackupDialog(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final passController = TextEditingController();
    final profile = ref.read(planetProfileProvider).valueOrNull;
    final lastCid = profile?.backupCid;

    showDialog(
      context: context,
      builder: (context) {
        bool isLoading = false;
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              child: GlassCard(
                blur: 20,
                opacity: isDark ? 0.1 : 0.8,
                borderRadius: BorderRadius.circular(28),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        l10n.backupDialogTitle,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: passController,
                        obscureText: true,
                        decoration: InputDecoration(
                          labelText: l10n.backupPasswordLabel,
                          hintText: l10n.backupPasswordHint,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        l10n.backupWarning,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.red, fontSize: 11),
                      ),
                      const SizedBox(height: 24),
                      if (isLoading) ...[
                        const CircularProgressIndicator(),
                      ] else ...[
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              if (passController.text.length < 8) return;
                              setState(() => isLoading = true);
                              final cid = await SignalBackupService.instance
                                  .createBackup(passController.text);
                              if (context.mounted) {
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      cid != null
                                          ? 'Backup to IPFS success!'
                                          : 'Backup failed',
                                    ),
                                  ),
                                );
                                ref.invalidate(planetProfileProvider);
                              }
                            },
                            icon: const Icon(Icons.cloud_upload_outlined),
                            label: Text(l10n.backupCreateButton),
                          ),
                        ),
                        if (lastCid != null) ...[
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                if (passController.text.isEmpty) return;
                                setState(() => isLoading = true);
                                final success = await SignalBackupService
                                    .instance
                                    .restoreBackup(
                                      passController.text,
                                      lastCid,
                                    );
                                if (context.mounted) {
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        success
                                            ? 'Restore success! Restart app for full effect.'
                                            : 'Restore failed / Wrong password',
                                      ),
                                    ),
                                  );
                                }
                              },
                              icon: const Icon(Icons.settings_backup_restore),
                              label: Text(l10n.backupRestoreButton),
                            ),
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showDiagnosticsDialog(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: GlassCard(
          blur: 20,
          opacity: isDark ? 0.1 : 0.8,
          borderRadius: BorderRadius.circular(28),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Background Logs",
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.bug_report, size: 20, color: Colors.amber),
                      onPressed: () async {
                        await IsolateLogger.log("Manual test log from UI isolate.");
                        if (context.mounted) {
                          // Close and reopen is easiest for a quick debug UI
                          Navigator.pop(context);
                          _showDiagnosticsDialog(context);
                        }
                      },
                      tooltip: 'Test Log Entry',
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  height: 300,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: FutureBuilder<String>(
                    future: IsolateLogger.readLogs(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final text = snapshot.data ?? "No logs found.";
                      return SingleChildScrollView(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          text,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 10,
                            color: Colors.white70,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () async {
                          await IsolateLogger.clearLogs();
                          if (context.mounted) Navigator.pop(context);
                        },
                        child: const Text("Clear Logs", style: TextStyle(color: Colors.red)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text("Close"),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).colorScheme.onSurface;
    final subtitleColor = textColor.withValues(alpha: 0.55);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: iconColor, size: 22),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 15,
          color: textColor,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(color: subtitleColor, fontSize: 12),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Icon(Icons.chevron_right, color: subtitleColor),
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
    );
  }
}

