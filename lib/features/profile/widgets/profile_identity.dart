// lib/features/profile/widgets/profile_identity.dart

import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xparq_app/features/auth/models/planet_model.dart';
import 'package:xparq_app/l10n/app_localizations.dart';

class ProfileIdentity extends ConsumerWidget {
  final PlanetModel profile;
  final bool isOwnProfile;

  const ProfileIdentity({
    super.key,
    required this.profile,
    required this.isOwnProfile,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isPortrait =
        MediaQuery.of(context).orientation == Orientation.portrait;

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.black.withOpacity(0.3)
                : Colors.white.withOpacity(0.6),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isDark
                  ? Colors.white.withOpacity(0.1)
                  : Colors.black.withOpacity(0.05),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: isPortrait && profile.photoAlignment == 'left'
                ? CrossAxisAlignment.start
                : isPortrait && profile.photoAlignment == 'right'
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.center,
            children: [
              _buildNameRow(context, theme),
              const SizedBox(height: 2),
              _buildHandleRow(context, theme, isDark),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNameRow(BuildContext context, ThemeData theme) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (profile.blueOrbit) ...[
          const Icon(Icons.verified, color: Color(0xFF4FC3F7), size: 18),
          const SizedBox(width: 6),
        ],
        Flexible(
          child: Text(
            profile.xparqName,
            style: TextStyle(
              color: theme.colorScheme.onSurface,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildHandleRow(BuildContext context, ThemeData theme, bool isDark) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          profile.handle != null
              ? '@${profile.handle}'
              : '@${profile.xparqName.toLowerCase().replaceAll(' ', '')}',
          style: TextStyle(
            color: theme.colorScheme.onSurface.withOpacity(0.75),
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Text(
            '•',
            style: TextStyle(
              color: theme.colorScheme.onSurface.withOpacity(0.4),
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Text(
          profile.isCadet
              ? AppLocalizations.of(context)!.galacticCadet
              : AppLocalizations.of(context)!.interstellarExplorer,
          style: TextStyle(
            color: profile.isCadet
                ? (isDark ? const Color(0xFFFFF176) : const Color(0xFFB8860B))
                : (isDark ? const Color(0xFFB39DDB) : const Color(0xFF673AB7)),
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
