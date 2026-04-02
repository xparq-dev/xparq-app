// lib/features/profile/widgets/profile_flexible_header.dart

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:xparq_app/features/auth/models/planet_model.dart';
import 'package:xparq_app/features/profile/widgets/profile_avatar.dart';
import 'package:xparq_app/features/profile/widgets/profile_header_widgets.dart';
import 'package:xparq_app/features/profile/widgets/profile_identity.dart';
import 'package:xparq_app/features/profile/widgets/profile_stats.dart';
import 'package:xparq_app/features/profile/widgets/profile_actions.dart';

class ProfileFlexibleHeader extends StatelessWidget {
  final PlanetModel profile;
  final bool isOwnProfile;
  final double currentHeight;
  final double expandedHeight;
  final double minHeight;
  final bool isRepositioningCover;
  final bool isRepositioningAvatar;
  final double coverYOffset;
  final double avatarYOffset;

  final VoidCallback? onAvatarTap;
  final VoidCallback? onAvatarLongPress;
  final Function(double)? onAvatarDragUpdate;
  final VoidCallback? onCoverTap;
  final Function(double)? onCoverDragUpdate;
  final String? viewingUid;

  const ProfileFlexibleHeader({
    super.key,
    required this.profile,
    required this.isOwnProfile,
    required this.currentHeight,
    required this.expandedHeight,
    required this.minHeight,
    this.isRepositioningCover = false,
    this.isRepositioningAvatar = false,
    this.coverYOffset = 0.0,
    this.avatarYOffset = 0.0,
    this.onAvatarTap,
    this.onAvatarLongPress,
    this.onAvatarDragUpdate,
    this.onCoverTap,
    this.onCoverDragUpdate,
    this.viewingUid,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final headerBaseColor = isDark ? Colors.black : Colors.white;

    final visibleT =
        ((currentHeight - (minHeight + 24.0)) / (expandedHeight - minHeight))
            .clamp(0.0, 1.0);
    final opacity = math.pow(visibleT, 1.8).toDouble();

    return Opacity(
      opacity: opacity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _buildHeaderStack(context, isDark, theme, headerBaseColor),
          ),
          if (!(isRepositioningCover || isRepositioningAvatar)) ...[
            ProfileStats(profile: profile),
            if (!isOwnProfile) const SizedBox(height: 8),
            if (!isOwnProfile)
              ProfileActions(
                viewingUid: viewingUid ?? profile.id,
                isOwnProfile: isOwnProfile,
              ),
            const SizedBox(height: 80), // Reduced from 100 to 80 to match the tighter layout.
          ],
        ],
      ),
    );
  }

  Widget _buildHeaderStack(
    BuildContext context,
    bool isDark,
    ThemeData theme,
    Color headerBaseColor,
  ) {
    return Stack(
      alignment: AlignmentDirectional.centerStart,
      children: [
        ProfileCover(
          profile: profile,
          isOwnProfile: isOwnProfile,
          isDark: isDark,
          isRepositioning: isRepositioningCover,
          repositionYOffset: coverYOffset,
          onTap: onCoverTap,
          onVerticalDragUpdate: onCoverDragUpdate,
        ),
        _buildGradientOverlay(isDark, theme, headerBaseColor),
        if (!isRepositioningCover && !profile.isExpandedHeader)
          _buildAvatarPositioned(context, isDark),
        if (!(isRepositioningCover || isRepositioningAvatar))
          _buildIdentityPositioned(context),
      ],
    );
  }

  Widget _buildGradientOverlay(
    bool isDark,
    ThemeData theme,
    Color headerBaseColor,
  ) {
    return Positioned.fill(
      child: IgnorePointer(
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                theme.colorScheme.onSurface.withOpacity(
                  isDark ? 0.08 : 0.02,
                ),
                Colors.transparent,
                Colors.transparent,
                headerBaseColor.withOpacity(isDark ? 0.08 : 0.03),
                headerBaseColor.withOpacity(isDark ? 0.22 : 0.10),
                headerBaseColor.withOpacity(isDark ? 0.42 : 0.24),
                headerBaseColor.withOpacity(isDark ? 0.64 : 0.46),
                headerBaseColor.withOpacity(isDark ? 0.84 : 0.70),
                headerBaseColor.withOpacity(isDark ? 0.96 : 0.90),
                headerBaseColor,
              ],
              stops: const [
                0.0,
                0.18,
                0.36,
                0.54,
                0.68,
                0.78,
                0.87,
                0.93,
                0.97,
                1.0,
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatarPositioned(BuildContext context, bool isDark) {
    return Positioned(
      bottom: 95,
      left: 0,
      right: 0,
      child: Align(
        alignment: _getAlignment(),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: profile.photoAlignment == 'center' ? 0 : 24,
          ),
          child: ProfileAvatar(
            profile: profile,
            isOwnProfile: isOwnProfile,
            isDark: isDark,
            isRepositioning: isRepositioningAvatar,
            repositionYOffset: avatarYOffset,
            onTap: onAvatarTap,
            onLongPress: onAvatarLongPress,
            onVerticalDragUpdate: onAvatarDragUpdate,
          ),
        ),
      ),
    );
  }

  Widget _buildIdentityPositioned(BuildContext context) {
    return Positioned(
      bottom: 2,
      left: 0,
      right: 0,
      child: Align(
        alignment: _getAlignment(),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: profile.photoAlignment == 'center' ? 0 : 24,
          ),
          child: ProfileIdentity(profile: profile, isOwnProfile: isOwnProfile),
        ),
      ),
    );
  }

  AlignmentGeometry _getAlignment() {
    if (profile.photoAlignment == 'left') {
      return AlignmentDirectional.centerStart;
    }
    if (profile.photoAlignment == 'right') {
      return AlignmentDirectional.centerEnd;
    }
    return Alignment.center;
  }
}
