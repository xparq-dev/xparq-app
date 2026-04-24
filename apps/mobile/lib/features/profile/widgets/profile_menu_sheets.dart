// lib/features/profile/widgets/profile_menu_sheets.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:xparq_app/features/auth/models/planet_model.dart';
import 'package:xparq_app/features/auth/providers/auth_providers.dart';
import 'package:xparq_app/l10n/app_localizations.dart';
import 'package:xparq_app/shared/router/app_router.dart';

class ProfileMenuSheets {
  static void showAvatarMenu({
    required BuildContext context,
    required WidgetRef ref,
    required PlanetModel profile,
    required bool isOwnProfile,
    required VoidCallback onViewFullImage,
    required VoidCallback onReposition,
    required VoidCallback onPickCamera,
    required VoidCallback onPickGallery,
    required VoidCallback onRemoveImage,
    required VoidCallback onShowAlignmentMenu,
    required Function(bool) onToggleExpanded,
  }) {
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _BaseMenuSheet(
        children: [
          if (isOwnProfile)
            _buildOption(
              context,
              icon: Icons.fullscreen,
              label: profile.isExpandedHeader
                  ? l10n.profileStandardView
                  : l10n.profileSocialLayout,
              onTap: () {
                Navigator.pop(context);
                onToggleExpanded(!profile.isExpandedHeader);
              },
            ),
          _buildOption(
            context,
            icon: Icons.visibility_outlined,
            label: l10n.profileViewIdentity,
            onTap: () {
              Navigator.pop(context);
              onViewFullImage();
            },
          ),
          if (isOwnProfile) ...[
            _buildOption(
              context,
              icon: Icons.aspect_ratio,
              label: l10n.profileRepositionIdentity,
              onTap: () {
                Navigator.pop(context);
                onReposition();
              },
            ),
            _buildOption(
              context,
              icon: Icons.camera_alt_outlined,
              label: l10n.profileCaptureIdentity,
              onTap: () {
                Navigator.pop(context);
                onPickCamera();
              },
            ),
            _buildOption(
              context,
              icon: Icons.photo_library_outlined,
              label: l10n.profileTransmitPhoto,
              onTap: () {
                Navigator.pop(context);
                onPickGallery();
              },
            ),
            _buildOption(
              context,
              icon: Icons.edit_note,
              label: l10n.profileModifyProfile,
              onTap: () {
                Navigator.pop(context);
                context.push(AppRoutes.editProfile);
              },
            ),
            if (!profile.isExpandedHeader)
              _buildOption(
                context,
                icon: Icons.align_horizontal_center,
                label: l10n.profileAlignment,
                onTap: () {
                  Navigator.pop(context);
                  onShowAlignmentMenu();
                },
              ),
            const Divider(),
            _buildOption(
              context,
              icon: Icons.delete_forever,
              label: l10n.profileRemoveIdentity,
              onTap: () {
                Navigator.pop(context);
                onRemoveImage();
              },
              textColor: Colors.redAccent,
            ),
          ],
        ],
      ),
    );
  }

  static void showCoverMenu({
    required BuildContext context,
    required WidgetRef ref,
    required PlanetModel profile,
    required VoidCallback onReposition,
    required VoidCallback onPickCamera,
    required VoidCallback onPickGallery,
    required VoidCallback onRemoveImage,
  }) {
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _BaseMenuSheet(
        children: [
          _buildOption(
            context,
            icon: Icons.camera_alt_outlined,
            label:
                l10n.profileCaptureIdentity, // reusing labels for consistency
            onTap: () {
              Navigator.pop(context);
              onPickCamera();
            },
          ),
          _buildOption(
            context,
            icon: Icons.photo_library_outlined,
            label: l10n.profileTransmitPhoto,
            onTap: () {
              Navigator.pop(context);
              onPickGallery();
            },
          ),
          if (profile.coverPhotoUrl.isNotEmpty) ...[
            _buildOption(
              context,
              icon: Icons.aspect_ratio,
              label: l10n.profileRepositionCover,
              onTap: () {
                Navigator.pop(context);
                onReposition();
              },
            ),
            const Divider(),
            _buildOption(
              context,
              icon: Icons.delete_forever,
              label: l10n.profileRemoveCover,
              onTap: () {
                Navigator.pop(context);
                onRemoveImage();
              },
              textColor: Colors.redAccent,
            ),
          ],
        ],
      ),
    );
  }

  static void showPositionMenu({
    required BuildContext context,
    required WidgetRef ref,
    required PlanetModel profile,
  }) {
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _BaseMenuSheet(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              l10n.profileAlignment,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildAlignmentOption(
                context,
                ref,
                profile,
                Icons.align_horizontal_left,
                'left',
                profile.photoAlignment == 'left',
              ),
              _buildAlignmentOption(
                context,
                ref,
                profile,
                Icons.align_horizontal_center,
                'center',
                profile.photoAlignment == 'center',
              ),
              _buildAlignmentOption(
                context,
                ref,
                profile,
                Icons.align_horizontal_right,
                'right',
                profile.photoAlignment == 'right',
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  static Widget _buildOption(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? textColor,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: textColor ?? Theme.of(context).colorScheme.onSurface,
      ),
      title: Text(label, style: TextStyle(color: textColor)),
      onTap: onTap,
    );
  }

  static Widget _buildAlignmentOption(
    BuildContext context,
    WidgetRef ref,
    PlanetModel profile,
    IconData icon,
    String value,
    bool isSelected,
  ) {
    return InkWell(
      onTap: () {
        unawaited(
          ref.read(authRepositoryProvider).updatePlanetProfile(profile.id, {
            'photo_alignment': value,
          }),
        );
        Navigator.pop(context);
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).colorScheme.primaryContainer
              : null,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          icon,
          color: isSelected ? Theme.of(context).colorScheme.primary : null,
        ),
      ),
    );
  }
}

class _BaseMenuSheet extends StatelessWidget {
  final List<Widget> children;
  const _BaseMenuSheet({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).dividerColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            ...children,
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

