// lib/features/profile/widgets/profile_avatar.dart

import 'package:flutter/material.dart';
import 'package:xparq_app/shared/widgets/common/xparq_image.dart';
import 'package:xparq_app/features/auth/models/planet_model.dart';

class ProfileAvatar extends StatelessWidget {
  final PlanetModel profile;
  final bool isOwnProfile;
  final bool isDark;
  final double size;
  final bool isRepositioning;
  final double repositionYOffset;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Function(double)? onVerticalDragUpdate;

  const ProfileAvatar({
    super.key,
    required this.profile,
    required this.isOwnProfile,
    required this.isDark,
    this.size = 120,
    this.isRepositioning = false,
    this.repositionYOffset = 0.0,
    this.onTap,
    this.onLongPress,
    this.onVerticalDragUpdate,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: isOwnProfile && !isRepositioning ? onTap : null,
      onLongPress: isOwnProfile && !isRepositioning ? onLongPress : null,
      onVerticalDragUpdate: isRepositioning
          ? (details) => onVerticalDragUpdate?.call(details.primaryDelta ?? 0.0)
          : null,
      child: Container(
        padding: EdgeInsets.all(isDark ? 4 : 2.5),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.12)
              : Colors.white.withValues(alpha: 0.6),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.08),
              blurRadius: isDark ? 25 : 20,
              spreadRadius: 1,
              offset: Offset(0, isDark ? 6 : 2),
            ),
          ],
        ),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.blueGrey.shade800,
            image: profile.photoUrl.isNotEmpty
                ? DecorationImage(
                    image: XparqImage.getImageProvider(profile.photoUrl),
                    fit: BoxFit.cover,
                    alignment: Alignment(
                      0,
                      isRepositioning
                          ? repositionYOffset
                          : profile.photoYPercent * 2 - 1.0,
                    ),
                  )
                : null,
          ),
          child: profile.photoUrl.isEmpty
              ? Icon(
                  Icons.person,
                  size: size * 0.4,
                  color: isDark ? Colors.white24 : Colors.blueGrey.shade200,
                )
              : null,
        ),
      ),
    );
  }
}
