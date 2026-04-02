// lib/features/profile/widgets/profile_reposition_overlay.dart

import 'package:flutter/material.dart';
import 'package:xparq_app/core/widgets/xparq_image.dart';
import 'package:xparq_app/features/auth/models/planet_model.dart';
import 'package:xparq_app/l10n/app_localizations.dart';

class ProfileRepositionOverlay extends StatelessWidget {
  final PlanetModel profile;
  final bool isCover;
  final double currentYOffset;
  final Function(double) onDragUpdate;
  final VoidCallback onSave;
  final VoidCallback onCancel;

  const ProfileRepositionOverlay({
    super.key,
    required this.profile,
    required this.isCover,
    required this.currentYOffset,
    required this.onDragUpdate,
    required this.onSave,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // 1. Dark Backdrop
        Container(color: Colors.black.withOpacity(0.95)),

        // 2. Focused Content
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Instruction
              Text(
                isCover
                    ? AppLocalizations.of(context)!.profileDragCover
                    : AppLocalizations.of(context)!.profileDragAvatar,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 48),

              // The Adjustable Image
              _buildAdjustableImage(),

              const SizedBox(height: 80),

              // Action Buttons
              _buildActionButtons(context),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAdjustableImage() {
    return GestureDetector(
      onVerticalDragUpdate: (details) {
        onDragUpdate(details.primaryDelta ?? 0.0);
      },
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (isCover)
            Container(
              height: 300,
              width: double.infinity,
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: Colors.white.withOpacity(0.05),
                    blurRadius: 30,
                  ),
                ],
              ),
              child: Image(
                image: XparqImage.getImageProvider(
                  profile.coverPhotoUrl.isNotEmpty
                      ? profile.coverPhotoUrl
                      : profile.photoUrl,
                ),
                fit: BoxFit.cover,
                alignment: Alignment(0, currentYOffset),
              ),
            )
          else
            Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.white.withOpacity(0.05),
                    blurRadius: 30,
                  ),
                ],
                border: Border.all(
                  color: Colors.white.withOpacity(0.2),
                  width: 3,
                ),
                image: DecorationImage(
                  image: XparqImage.getImageProvider(profile.photoUrl),
                  fit: BoxFit.cover,
                  alignment: Alignment(0, currentYOffset),
                ),
              ),
            ),

          // Central Drag Handle Icon
          IgnorePointer(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.4),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.open_with, color: Colors.white, size: 40),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Row(
        children: [
          Expanded(
            child: TextButton(
              onPressed: onCancel,
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              child: Text(AppLocalizations.of(context)!.cancel),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: ElevatedButton(
              onPressed: onSave,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4FC3F7),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                elevation: 0,
              ),
              child: Text(
                AppLocalizations.of(context)!.editProfileSave,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
