// lib/features/profile/widgets/profile_header_widgets.dart

import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:xparq_app/shared/widgets/common/xparq_image.dart';
import 'package:xparq_app/features/auth/models/planet_model.dart';
import 'package:xparq_app/l10n/app_localizations.dart';

class ProfileCover extends StatelessWidget {
  final PlanetModel profile;
  final bool isOwnProfile;
  final bool isDark;
  final bool isRepositioning;
  final double repositionYOffset;
  final VoidCallback? onTap;
  final Function(double)? onVerticalDragUpdate;

  const ProfileCover({
    super.key,
    required this.profile,
    required this.isOwnProfile,
    required this.isDark,
    this.isRepositioning = false,
    this.repositionYOffset = 0.0,
    this.onTap,
    this.onVerticalDragUpdate,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Widget content;
    if (profile.photoUrl.isNotEmpty && profile.isExpandedHeader) {
      content = _buildFullPhotoHeader();
    } else if (profile.coverPhotoUrl.isNotEmpty) {
      content = _buildCoverPhoto();
    } else {
      content = _buildEmptyCoverFallback(context, theme);
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        content,
        if (!isDark &&
            (profile.photoUrl.isNotEmpty && profile.isExpandedHeader ||
                profile.coverPhotoUrl.isNotEmpty))
          _buildLightModeFade(),
        if (isOwnProfile) _buildInteractionLayer(),
      ],
    );
  }

  Widget _buildFullPhotoHeader() {
    return Image(
      image: XparqImage.getImageProvider(profile.photoUrl),
      fit: BoxFit.cover,
      alignment: Alignment(
        0,
        isRepositioning ? repositionYOffset : profile.photoYPercent * 2 - 1.0,
      ),
    );
  }

  Widget _buildCoverPhoto() {
    return Image(
      image: XparqImage.getImageProvider(profile.coverPhotoUrl),
      fit: BoxFit.cover,
      alignment: Alignment(
        0,
        isRepositioning
            ? repositionYOffset
            : profile.coverPhotoYPercent * 2 - 1.0,
      ),
    );
  }

  Widget _buildEmptyCoverFallback(BuildContext context, ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.blueGrey.shade900 : Colors.white,
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (profile.photoUrl.isNotEmpty && isDark)
            Opacity(
              opacity: 0.35,
              child: ImageFiltered(
                imageFilter: ui.ImageFilter.blur(sigmaX: 40, sigmaY: 40),
                child: Image(
                  image: XparqImage.getImageProvider(profile.photoUrl),
                  fit: BoxFit.cover,
                ),
              ),
            )
          else if (isDark)
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.blueGrey.shade900,
                    const Color(0xFF1A237E).withValues(alpha: 0.4),
                    const Color(0xFF311B92).withValues(alpha: 0.4),
                    Colors.blueGrey.shade900,
                  ],
                  stops: const [0.0, 0.4, 0.6, 1.0],
                ),
              ),
            ),
          if (isOwnProfile && !isRepositioning)
            _buildAddCoverButton(context, theme)
          else if (!isOwnProfile && profile.coverPhotoUrl.isEmpty)
            Center(
              child: Icon(
                Icons.landscape_outlined,
                size: 60,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.05),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAddCoverButton(BuildContext context, ThemeData theme) {
    return Align(
      alignment: const Alignment(0, -0.75),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: (isDark ? Colors.white : Colors.black).withValues(alpha: 
              0.15,
            ),
            width: 1.2,
          ),
          color: (isDark ? Colors.black : Colors.white).withValues(alpha: 0.1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.add_photo_alternate_outlined,
              size: 18,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
            ),
            const SizedBox(width: 8),
            Text(
              AppLocalizations.of(context)!.profileAddCover,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLightModeFade() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      height: 80,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.white.withValues(alpha: 0.0),
              Colors.white.withValues(alpha: 0.4),
              Colors.white.withValues(alpha: 0.8),
              Colors.white,
            ],
            stops: const [0.0, 0.4, 0.8, 1.0],
          ),
        ),
      ),
    );
  }

  Widget _buildInteractionLayer() {
    return Positioned.fill(
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: !isRepositioning ? onTap : null,
        onVerticalDragUpdate: isRepositioning
            ? (details) =>
                  onVerticalDragUpdate?.call(details.primaryDelta ?? 0.0)
            : null,
      ),
    );
  }
}
