// lib/features/profile/widgets/edit_profile/edit_profile_media.dart

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:xparq_app/features/auth/models/planet_model.dart';
import 'package:xparq_app/core/widgets/xparq_image.dart';
import '../../../../l10n/app_localizations.dart';

class EditProfileMedia extends StatelessWidget {
  final PlanetModel profile;
  final XFile? newAvatarFile;
  final XFile? newCoverFile;
  final double coverYOffset;
  final bool isEditing;
  final VoidCallback onPickAvatar;
  final VoidCallback onPickCover;
  final VoidCallback onDeleteCover;

  const EditProfileMedia({
    super.key,
    required this.profile,
    required this.newAvatarFile,
    required this.newCoverFile,
    required this.coverYOffset,
    required this.isEditing,
    required this.onPickAvatar,
    required this.onPickCover,
    required this.onDeleteCover,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Cover Photo
        Stack(
          children: [
            GestureDetector(
              onTap: isEditing ? onPickCover : null,
              child: Container(
                height: 180,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.blueGrey.withOpacity(0.1),
                  image: newCoverFile != null
                      ? DecorationImage(
                          image: XparqImage.getImageProvider(
                            newCoverFile!.path,
                          ),
                          fit: BoxFit.cover,
                          alignment: Alignment(0, coverYOffset),
                        )
                      : (profile.coverPhotoUrl.isNotEmpty
                            ? DecorationImage(
                                image: XparqImage.getImageProvider(
                                  profile.coverPhotoUrl,
                                ),
                                fit: BoxFit.cover,
                                alignment: Alignment(0, coverYOffset),
                              )
                            : null),
                ),
                child: (newCoverFile == null && profile.coverPhotoUrl.isEmpty)
                    ? const Center(
                        child: Icon(
                          Icons.add_photo_alternate_outlined,
                          size: 40,
                          color: Colors.white24,
                        ),
                      )
                    : null,
              ),
            ),
            if (isEditing) _buildCoverMenu(context),
            // Avatar positioned over cover
            Positioned(
              bottom: 0,
              left: 20,
              child: Transform.translate(
                offset: const Offset(0, 40),
                child: GestureDetector(
                  onTap: isEditing ? onPickAvatar : null,
                  child: Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Theme.of(context).scaffoldBackgroundColor,
                          shape: BoxShape.circle,
                        ),
                        child: CircleAvatar(
                          radius: 45,
                          backgroundColor: Colors.blueGrey.shade900,
                          backgroundImage: newAvatarFile != null
                              ? XparqImage.getImageProvider(newAvatarFile!.path)
                              : (profile.photoUrl.isNotEmpty
                                    ? XparqImage.getImageProvider(
                                        profile.photoUrl,
                                      )
                                    : null),
                          child:
                              (newAvatarFile == null &&
                                  profile.photoUrl.isEmpty)
                              ? const Icon(Icons.person, size: 40)
                              : null,
                        ),
                      ),
                      if (isEditing)
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            color: Color(0xFF4FC3F7),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.camera_alt,
                            size: 14,
                            color: Colors.black,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 45), // Space for avatar overlap
      ],
    );
  }

  Widget _buildCoverMenu(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Positioned(
      top: 10,
      right: 10,
      child: PopupMenuButton<String>(
        icon: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.5),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.more_vert, size: 18, color: Colors.white),
        ),
        offset: const Offset(0, 40),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        onSelected: (val) {
          if (val == 'change') {
            onPickCover();
          } else if (val == 'delete') {
            onDeleteCover();
          }
        },
        itemBuilder: (context) => [
          PopupMenuItem(
            value: 'change',
            child: Row(
              children: [
                const Icon(Icons.photo_library_outlined, size: 20),
                const SizedBox(width: 12),
                Text(
                  l10n.editProfileChangeImage,
                  style: const TextStyle(fontSize: 14),
                ),
              ],
            ),
          ),
          PopupMenuItem(
            value: 'delete',
            child: Row(
              children: [
                const Icon(
                  Icons.delete_outline,
                  size: 20,
                  color: Colors.redAccent,
                ),
                const SizedBox(width: 12),
                Text(
                  l10n.editProfileDeleteImage,
                  style: const TextStyle(fontSize: 14, color: Colors.redAccent),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
