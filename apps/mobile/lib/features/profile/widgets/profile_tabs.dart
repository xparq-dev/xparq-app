// lib/features/profile/widgets/profile_tabs.dart

import 'package:flutter/material.dart';
import 'package:xparq_app/l10n/app_localizations.dart';

class ProfileTabs extends StatelessWidget implements PreferredSizeWidget {
  const ProfileTabs({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(48);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return TabBar(
      dividerColor: theme.colorScheme.onSurface.withValues(alpha: 0.05),
      indicatorColor: const Color(0xFF4FC3F7),
      labelColor: const Color(0xFF4FC3F7),
      unselectedLabelColor: theme.colorScheme.onSurface.withValues(alpha: 0.54),
      tabs: [
        Tab(text: AppLocalizations.of(context)!.about),
        Tab(text: AppLocalizations.of(context)!.pulses),
        Tab(text: AppLocalizations.of(context)!.warps),
      ],
    );
  }
}
