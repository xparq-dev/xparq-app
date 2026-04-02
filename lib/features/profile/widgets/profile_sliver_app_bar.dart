// lib/features/profile/widgets/profile_sliver_app_bar.dart

import 'package:flutter/material.dart';
import 'package:xparq_app/features/auth/models/planet_model.dart';
import 'package:xparq_app/features/profile/widgets/profile_flexible_header.dart';
import 'package:xparq_app/features/profile/widgets/profile_tabs.dart';
import 'package:xparq_app/core/router/app_router.dart';
import 'package:go_router/go_router.dart';
import 'package:xparq_app/l10n/app_localizations.dart';

class ProfileSliverAppBar extends StatelessWidget {
  final PlanetModel profile;
  final bool isOwnProfile;
  final bool isRepositioningCover;
  final bool isRepositioningAvatar;
  final double coverYOffset;
  final double avatarYOffset;
  final VoidCallback onAvatarTap;
  final VoidCallback onAvatarLongPress;
  final Function(double) onAvatarDragUpdate;
  final VoidCallback onCoverTap;
  final Function(double) onCoverDragUpdate;
  final String? viewingUid;

  const ProfileSliverAppBar({
    super.key,
    required this.profile,
    required this.isOwnProfile,
    required this.isRepositioningCover,
    required this.isRepositioningAvatar,
    required this.coverYOffset,
    required this.avatarYOffset,
    required this.onAvatarTap,
    required this.onAvatarLongPress,
    required this.onAvatarDragUpdate,
    required this.onCoverTap,
    required this.onCoverDragUpdate,
    this.viewingUid,
  });

  @override
  Widget build(BuildContext context) {
    final toolbarHeight = isOwnProfile ? 40.0 : kToolbarHeight;
    final expandedHeight = isOwnProfile ? 340.0 : 460.0;

    return SliverAppBar(
      pinned: true,
      expandedHeight: expandedHeight,
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      automaticallyImplyLeading: false,
      leading: isOwnProfile
          ? null
          : IconButton(
              icon: Icon(
                Icons.arrow_back,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              onPressed: () => Navigator.pop(context),
            ),
      actions: [
        if (isOwnProfile)
          IconButton(
            icon: Icon(
              Icons.settings,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            tooltip: AppLocalizations.of(context)!.settingsTitle,
            onPressed: () => context.push(AppRoutes.settings),
          ),
      ],
      toolbarHeight: toolbarHeight,
      flexibleSpace: LayoutBuilder(
        builder: (context, constraints) {
          final top = constraints.biggest.height;
          final toolbarStripHeight =
              MediaQuery.paddingOf(context).top + toolbarHeight;
          final minHeight = toolbarStripHeight + 48.0;

          return FlexibleSpaceBar(
            background: ProfileFlexibleHeader(
              profile: profile,
              isOwnProfile: isOwnProfile,
              currentHeight: top,
              expandedHeight: expandedHeight,
              minHeight: minHeight,
              isRepositioningCover: isRepositioningCover,
              isRepositioningAvatar: isRepositioningAvatar,
              coverYOffset: coverYOffset,
              avatarYOffset: avatarYOffset,
              onAvatarTap: onAvatarTap,
              onAvatarLongPress: onAvatarLongPress,
              onAvatarDragUpdate: onAvatarDragUpdate,
              onCoverTap: onCoverTap,
              onCoverDragUpdate: onCoverDragUpdate,
              viewingUid: viewingUid,
            ),
          );
        },
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(48),
        child: (isRepositioningCover || isRepositioningAvatar)
            ? const SizedBox.shrink()
            : const ProfileTabs(),
      ),
    );
  }
}
