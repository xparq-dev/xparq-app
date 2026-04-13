import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:xparq_app/features/offline/providers/offline_state_provider.dart';
import 'package:xparq_app/features/offline/providers/offline_user_provider.dart';
import 'package:xparq_app/features/offline/services/offline_chat_database.dart';
import 'package:xparq_app/shared/router/app_router.dart';
import 'package:xparq_app/shared/theme/theme_provider.dart';
import 'package:xparq_app/l10n/app_localizations.dart';

class OfflineSettingsScreen extends ConsumerWidget {
  const OfflineSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userState = ref.watch(offlineUserProvider);
    final themeMode = ref.watch(themeProvider);
    final isDark = themeMode == ThemeMode.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.offlineSettingsTitle),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          SwitchListTile(
            secondary: Icon(
              userState.isAnonymous ? Icons.masks : Icons.visibility_rounded,
              color: userState.isAnonymous ? Colors.blueAccent : Colors.grey,
            ),
            title: Text(AppLocalizations.of(context)!.offlineAnonTitle),
            subtitle: Text(AppLocalizations.of(context)!.offlineAnonSubtitle),
            value: userState.isAnonymous,
            activeThumbColor: Colors.blueAccent,
            onChanged: (val) =>
                ref.read(offlineUserProvider.notifier).toggleAnonymous(val),
          ),
          const Divider(),
          SwitchListTile(
            secondary: Icon(
              isDark ? Icons.dark_mode : Icons.light_mode,
              color: isDark ? Colors.blueAccent : Colors.orangeAccent,
            ),
            title: Text(AppLocalizations.of(context)!.themeTitle),
            value: isDark,
            activeThumbColor: Colors.blueAccent,
            onChanged: (val) => ref.read(themeProvider.notifier).toggleTheme(),
          ),
          const SizedBox(height: 24),
          ListTile(
            leading: const Icon(Icons.delete_outline, color: Colors.amber),
            title: Text(AppLocalizations.of(context)!.offlineClearCacheTitle),
            subtitle: Text(
              AppLocalizations.of(context)!.offlineClearCacheSubtitle,
            ),
            onTap: () => _showClearConfirm(context),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.delete_forever, color: Colors.redAccent),
            title: Text(
              AppLocalizations.of(context)!.offlineResetAccountTitle,
              style: const TextStyle(color: Colors.redAccent),
            ),
            subtitle: Text(
              AppLocalizations.of(context)!.offlineResetAccountSubtitle,
            ),
            onTap: () => _showResetConfirm(context, ref),
          ),
          const SizedBox(height: 24),
          const Divider(),
          ListTile(
            leading: Icon(
              Icons.exit_to_app,
              color: Theme.of(context).colorScheme.primary,
            ),
            title: Text(AppLocalizations.of(context)!.offlineExitMode),
            onTap: () {
              ref.read(isOfflineModeProvider.notifier).state = false;
              context.go(AppRoutes.welcome);
            },
          ),
          const SizedBox(height: 48),
        ],
      ),
    );
  }

  Future<void> _showClearConfirm(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.offlineClearConfirmTitle),
        content: Text(AppLocalizations.of(context)!.offlineClearConfirmDesc),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppLocalizations.of(context)!.offlineCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              AppLocalizations.of(context)!.offlineClear,
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await OfflineChatDatabase.instance.clearAllHistory();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.offlineHistoryCleared),
          ),
        );
      }
    }
  }

  Future<void> _showResetConfirm(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.offlineResetConfirmTitle),
        content: Text(AppLocalizations.of(context)!.offlineResetConfirmDesc),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppLocalizations.of(context)!.offlineCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              AppLocalizations.of(context)!.offlineReset,
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await OfflineChatDatabase.instance.clearAllData();
      await ref.read(offlineUserProvider.notifier).resetIdentity();
      ref.read(isOfflineModeProvider.notifier).state = false;
      if (context.mounted) {
        context.go(AppRoutes.welcome);
      }
    }
  }
}

