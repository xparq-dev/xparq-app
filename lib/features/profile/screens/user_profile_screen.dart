// lib/features/profile/screens/user_profile_screen.dart

import 'dart:math' as math;
import 'dart:ui' as ui;
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:xparq_app/l10n/app_localizations.dart';
import 'package:xparq_app/shared/router/app_router.dart';
import 'package:xparq_app/shared/widgets/common/xparq_image.dart';
import 'package:xparq_app/features/auth/providers/auth_providers.dart';
import 'package:xparq_app/features/social/providers/pulse_providers.dart';
import 'package:xparq_app/features/social/widgets/pulse_card.dart';
import 'package:xparq_app/features/social/providers/orbit_providers.dart';
import 'package:xparq_app/features/auth/models/planet_model.dart';
import 'package:image_picker/image_picker.dart';
import 'package:xparq_app/features/profile/providers/image_upload_provider.dart';
import 'package:xparq_app/features/profile/widgets/profile_photo_gallery.dart';
import 'package:xparq_app/features/profile/repositories/profile_repository.dart';
import 'package:xparq_app/shared/widgets/common/expandable_text.dart';
import 'package:xparq_app/features/profile/widgets/profile_actions.dart';

class UserProfileScreen extends ConsumerStatefulWidget {
  /// When null = viewing own profile. When set = viewing another user's profile.
  final String? viewingUid;
  const UserProfileScreen({super.key, this.viewingUid});

  @override
  ConsumerState<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends ConsumerState<UserProfileScreen>
    with AutomaticKeepAliveClientMixin {
  bool _isRepositioningCover = false;
  bool _isRepositioningAvatar = false;
  double _coverYOffset = 0.0;
  double _avatarYOffset = 0.0;
  bool _isGalleryOpening = false;
  Timer? _galleryTriggerTimer;
  final ValueNotifier<double> _headerOpacityNotifier = ValueNotifier<double>(0.0);

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    // If viewingUid is set, load that user's profile; otherwise load own
    final viewingUid = widget.viewingUid;
    final currentUser = ref.watch(supabaseAuthStateProvider).valueOrNull;
    final currentUid = currentUser?.id;

    // Robust check: own profile if no UID provided OR provided UID matches current user
    final isOwnProfile =
        viewingUid == null || (currentUid != null && viewingUid == currentUid);

    final profileAsync = isOwnProfile
        ? ref.watch(planetProfileProvider)
        : ref.watch(planetProfileByUidProvider(viewingUid));

    if (profileAsync.hasValue) {
      final p = profileAsync.value;
      debugPrint(
        'PROFILE_DEBUG: uid=${p?.id}, isOwn=$isOwnProfile, alignment=${p?.photoAlignment}, expanded=${p?.isExpandedHeader}',
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      extendBodyBehindAppBar: true,
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(
          child: Text(
            AppLocalizations.of(context)!.profileErrorLoading(e.toString()),
          ),
        ),
        data: (profile) {
          if (profile == null) {
            return Center(
              child: Text(AppLocalizations.of(context)!.profileGuestMode),
            );
          }

          return DefaultTabController(
            length: 3,
            child: _isRepositioningCover || _isRepositioningAvatar
                ? _buildRepositioningFocusMode(profile)
                : OrientationBuilder(
                    builder: (context, orientation) {
                      if (orientation == Orientation.landscape) {
                        return _buildLandscapeLayout(
                          context,
                          profile,
                          isOwnProfile,
                          viewingUid,
                        );
                      }
                      return _buildPortraitLayout(
                        context,
                        profile,
                        isOwnProfile,
                      );
                    },
                  ),
          );
        },
      ),
    );
  }

  void _showAvatarMenu(
    BuildContext context,
    WidgetRef ref,
    PlanetModel profile,
    bool isOwnProfile,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
            padding: const EdgeInsets.only(top: 20, bottom: 10),
            child: SafeArea(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Pull Bar
                    Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    if (isOwnProfile)
                      _buildMenuOption(
                        context: context,
                        icon: Icons.fullscreen,
                        label: profile.isExpandedHeader
                            ? AppLocalizations.of(context)!.profileStandardView
                            : AppLocalizations.of(context)!.profileSocialLayout,
                        onTap: () {
                          Navigator.pop(context);
                          _updateAlignment(
                            context,
                            ref,
                            profile.id,
                            profile.photoAlignment,
                            !profile.isExpandedHeader,
                          );
                        },
                      ),
                    _buildMenuOption(
                      context: context,
                      icon: Icons.visibility_outlined,
                      label: AppLocalizations.of(context)!.profileViewIdentity,
                      onTap: () {
                        Navigator.pop(context);
                        _viewFullImage(context, profile.photoUrl);
                      },
                    ),
                    if (isOwnProfile) ...[
                      _buildMenuOption(
                        context: context,
                        icon: Icons.aspect_ratio,
                        label: AppLocalizations.of(
                          context,
                        )!.profileRepositionIdentity,
                        onTap: () {
                          Navigator.pop(context);
                          setState(() {
                            _isRepositioningAvatar = true;
                            _avatarYOffset = profile.photoYPercent * 2 - 1.0;
                          });
                        },
                      ),
                      _buildMenuOption(
                        context: context,
                        icon: Icons.camera_alt_outlined,
                        label: AppLocalizations.of(
                          context,
                        )!.profileCaptureIdentity,
                        onTap: () {
                          Navigator.pop(context);
                          _pickImageFromSource(
                            context,
                            ref,
                            ImageSource.camera,
                            isCover: false,
                          );
                        },
                      ),
                      _buildMenuOption(
                        context: context,
                        icon: Icons.photo_library_outlined,
                        label: AppLocalizations.of(
                          context,
                        )!.profileTransmitPhoto,
                        onTap: () {
                          Navigator.pop(context);
                          _pickImageFromSource(
                            context,
                            ref,
                            ImageSource.gallery,
                            isCover: false,
                          );
                        },
                      ),
                      _buildMenuOption(
                        context: context,
                        icon: Icons.edit_note,
                        label: AppLocalizations.of(
                          context,
                        )!.profileModifyProfile,
                        onTap: () {
                          Navigator.pop(context);
                          context.push(AppRoutes.editProfile);
                        },
                      ),
                      if (!profile.isExpandedHeader)
                        _buildMenuOption(
                          context: context,
                          icon: Icons.align_horizontal_center,
                          label: AppLocalizations.of(context)!.profileAlignment,
                          onTap: () {
                            Navigator.pop(context);
                            _showPositionMenu(context, ref, profile);
                          },
                        ),
                    ],
                    const SizedBox(height: 12),
                    const Divider(),
                    _buildMenuOption(
                      context: context,
                      icon: Icons.delete_forever,
                      label: AppLocalizations.of(
                        context,
                      )!.profileRemoveIdentity,
                      onTap: () {
                        Navigator.pop(context);
                        _removeProfilePhoto();
                      },
                      textColor: Colors.redAccent,
                    ),
                    const SizedBox(height: 10),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showPositionMenu(
    BuildContext context,
    WidgetRef ref,
    PlanetModel profile,
  ) {
    // Vibration / Feedback could be added here
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
            padding: const EdgeInsets.only(top: 20, bottom: 20),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    AppLocalizations.of(context)!.profileAlignmentTitle,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildPositionOption(
                        context,
                        Icons.align_horizontal_left,
                        AppLocalizations.of(context)!.profileLeft,
                        profile.photoAlignment == 'left',
                        () {
                          _updateAlignment(
                            context,
                            ref,
                            profile.id,
                            'left',
                            null,
                          );
                          Navigator.pop(context);
                        },
                      ),
                      _buildPositionOption(
                        context,
                        Icons.align_horizontal_center,
                        AppLocalizations.of(context)!.profileCenter,
                        profile.photoAlignment == 'center',
                        () {
                          _updateAlignment(
                            context,
                            ref,
                            profile.id,
                            'center',
                            null,
                          );
                          Navigator.pop(context);
                        },
                      ),
                      _buildPositionOption(
                        context,
                        Icons.align_horizontal_right,
                        AppLocalizations.of(context)!.profileRight,
                        profile.photoAlignment == 'right',
                        () {
                          _updateAlignment(
                            context,
                            ref,
                            profile.id,
                            'right',
                            null,
                          );
                          Navigator.pop(context);
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPositionOption(
    BuildContext context,
    IconData icon,
    String label,
    bool isSelected,
    VoidCallback onTap,
  ) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color(0xFF4FC3F7).withValues(alpha: 0.2)
                  : theme.colorScheme.onSurface.withValues(alpha: 0.05),
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected
                    ? const Color(0xFF4FC3F7)
                    : Colors.transparent,
                width: 2,
              ),
            ),
            child: Icon(
              icon,
              color: isSelected
                  ? const Color(0xFF4FC3F7)
                  : theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected
                  ? const Color(0xFF4FC3F7)
                  : theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _updateAlignment(
    BuildContext context,
    WidgetRef ref,
    String uid,
    String alignment, [
    bool? isExpanded,
  ]) async {
    try {
      debugPrint(
        'UPDATING_ALIGNMENT: uid=$uid, target_align=$alignment, target_expanded=$isExpanded',
      );
      await ProfileRepository().updateProfile(
        uid: uid,
        photoAlignment: alignment,
        isExpandedHeader: isExpanded,
      );
      debugPrint('UPDATE_SUCCESS: invalidating providers...');
      ref.invalidate(planetProfileProvider);
      ref.invalidate(planetProfileByUidProvider(uid));
    } catch (e) {
      debugPrint('UPDATE_ERROR: $e');
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(
              context,
            )!.profileErrorUpdateAlignment(e.toString()),
          ),
        ),
      );
    }
  }

  Future<void> _removeProfilePhoto() async {
    final uid = ref.read(authRepositoryProvider).currentUser!.id;
    try {
      await ProfileRepository().updateProfile(uid: uid, photoUrl: '');
      ref.invalidate(planetProfileProvider);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(
              context,
            )!.profileErrorRemovePhoto(e.toString()),
          ),
        ),
      );
    }
  }

  void _showCoverMenu(
    BuildContext context,
    WidgetRef ref,
    PlanetModel profile,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
            padding: const EdgeInsets.only(top: 20, bottom: 10),
            child: SafeArea(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Pull Bar
                    Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    if (profile.photoUrl.isNotEmpty)
                      _buildMenuOption(
                        context: context,
                        icon: Icons.fullscreen_exit,
                        label: profile.isExpandedHeader
                            ? AppLocalizations.of(context)!.profileStandardView
                            : AppLocalizations.of(context)!.profileSocialLayout,
                        onTap: () {
                          Navigator.pop(context);
                          _updateAlignment(
                            context,
                            ref,
                            profile.id,
                            profile.photoAlignment,
                            !profile.isExpandedHeader,
                          );
                        },
                      ),
                    _buildMenuOption(
                      context: context,
                      icon: Icons.add_photo_alternate_outlined,
                      label: AppLocalizations.of(context)!.profileAddCover,
                      onTap: () {
                        Navigator.pop(context);
                        _pickImageFromSource(
                          context,
                          ref,
                          ImageSource.gallery,
                          isCover: true,
                        );
                      },
                    ),
                    _buildMenuOption(
                      context: context,
                      icon: Icons.camera_alt_outlined,
                      label: AppLocalizations.of(context)!.profileCaptureCover,
                      onTap: () {
                        Navigator.pop(context);
                        _pickImageFromSource(
                          context,
                          ref,
                          ImageSource.camera,
                          isCover: true,
                        );
                      },
                    ),
                    if (profile.coverPhotoUrl.isNotEmpty) ...[
                      _buildMenuOption(
                        context: context,
                        icon: Icons.aspect_ratio,
                        label: AppLocalizations.of(
                          context,
                        )!.profileRepositionCover,
                        onTap: () {
                          Navigator.pop(context);
                          setState(() {
                            _isRepositioningCover = true;
                            _coverYOffset =
                                profile.coverPhotoYPercent * 2 - 1.0;
                          });
                        },
                      ),
                      _buildMenuOption(
                        context: context,
                        icon: Icons.delete_outline,
                        label: AppLocalizations.of(context)!.profileRemoveCover,
                        onTap: () {
                          Navigator.pop(context);
                          _removeCoverPhoto();
                        },
                      ),
                    ],
                    const SizedBox(height: 10),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _removeCoverPhoto() async {
    final uid = ref.read(authRepositoryProvider).currentUser!.id;
    try {
      await ProfileRepository().updateProfile(uid: uid, coverPhotoUrl: '');
      ref.invalidate(planetProfileProvider);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(
              context,
            )!.profileErrorRemoveCover(e.toString()),
          ),
        ),
      );
    }
  }

  Future<void> _savePosition() async {
    final profile = ref.read(planetProfileProvider).valueOrNull;
    if (profile == null) return;

    final uid = ref.read(authRepositoryProvider).currentUser!.id;

    try {
      if (_isRepositioningCover) {
        final yPercent = (_coverYOffset + 1.0) / 2;
        await ProfileRepository().updateProfile(
          uid: uid,
          coverPhotoYPercent: yPercent,
        );
      } else if (_isRepositioningAvatar) {
        final yPercent = (_avatarYOffset + 1.0) / 2;
        await ProfileRepository().updateProfile(
          uid: uid,
          photoYPercent: yPercent,
        );
      }

      ref.invalidate(planetProfileProvider);
      setState(() {
        _isRepositioningCover = false;
        _isRepositioningAvatar = false;
      });
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(
              context,
            )!.profileErrorSavingPosition(e.toString()),
          ),
        ),
      );
    }
  }

  void _cancelReposition() {
    setState(() {
      _isRepositioningCover = false;
      _isRepositioningAvatar = false;
      _coverYOffset = 0.0;
      _avatarYOffset = 0.0;
    });
  }

  Widget _buildMenuOption({
    required BuildContext context,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? textColor,
  }) {
    return ListTile(
      leading: Icon(icon, color: textColor ?? const Color(0xFF4FC3F7)),
      title: Text(
        label,
        style: TextStyle(
          color: textColor ?? Theme.of(context).colorScheme.onSurface,
          fontWeight: FontWeight.w500,
        ),
      ),
      onTap: onTap,
    );
  }

  void _viewFullImage(BuildContext context, String url) {
    if (url.isEmpty) return;
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.zero,
        alignment: Alignment.center,
        child: Stack(
          alignment: Alignment.center,
          children: [
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: double.infinity,
                height: double.infinity,
                color: Colors.black87,
              ),
            ),
            InteractiveViewer(
              child: XparqImage(imageUrl: url, fit: BoxFit.contain),
            ),
            Positioned(
              top: 40,
              right: 20,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImageFromSource(
    BuildContext context,
    WidgetRef ref,
    ImageSource source, {
    required bool isCover,
  }) async {
    try {
      final imageService = ref.read(imageUploadServiceProvider);
      final file = await imageService.pickImage(source: source);

      if (file != null) {
        final uid = ref.read(authRepositoryProvider).currentUser!.id;
        final imageUrl = isCover
            ? await imageService.uploadCoverImage(file: file, uid: uid)
            : await imageService.uploadProfileImage(file: file, uid: uid);

        if (isCover) {
          await ProfileRepository().updateProfile(
            uid: uid,
            coverPhotoUrl: imageUrl,
          );
        } else {
          await ProfileRepository().updateProfile(uid: uid, photoUrl: imageUrl);
        }

        // Explicitly refresh profile to show new image immediately
        ref.invalidate(planetProfileProvider);

        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.profilePictureUpdateSuccess,
            ),
          ),
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(
              context,
            )!.profileErrorUpdatingPicture(e.toString()),
          ),
        ),
      );
    }
  }

  Widget _buildPortraitLayout(
    BuildContext context,
    PlanetModel profile,
    bool isOwnProfile,
  ) {
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (profile.isExpandedHeader && !_isGalleryOpening) {
          bool isOverscrolled = false;

          if (notification is ScrollUpdateNotification) {
            if (notification.metrics.pixels < -100) {
              isOverscrolled = true;
            }
          } else if (notification is OverscrollNotification) {
            if (notification.overscroll < -20) {
              isOverscrolled = true;
            }
          }

          if (isOverscrolled) {
            if (_galleryTriggerTimer == null) {
              // Start timer for "Hold" gesture
              HapticFeedback.selectionClick();
              _galleryTriggerTimer = Timer(const Duration(milliseconds: 450), () {
                if (mounted) {
                  _isGalleryOpening = true;
                  HapticFeedback.mediumImpact();
                  _triggerGallery('profile');
                  
                  Future.delayed(const Duration(seconds: 1), () {
                    _isGalleryOpening = false;
                  });
                }
              });
            }
          } else if (notification is ScrollEndNotification || 
                     (notification is UserScrollNotification && 
                      notification.direction == ScrollDirection.idle)) {
            // Cancel timer if user stops pulling or releases
            _galleryTriggerTimer?.cancel();
            _galleryTriggerTimer = null;
          }
        }
        return false;
      },
      child: NestedScrollView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        headerSliverBuilder: (context, _) {
          return [
            ValueListenableBuilder<double>(
              valueListenable: _headerOpacityNotifier,
              builder: (context, opacity, child) {
                final theme = Theme.of(context);
                final isDark = theme.brightness == Brightness.dark;
                final headerBaseColor = isDark ? Colors.black : Colors.white;

                return SliverAppBar(
                  // Dynamic height based on layout mode.
                  // In Full mode, we need more space to prevent "Bottom Overflow" errors.
                  expandedHeight: profile.isExpandedHeader
                      ? (isOwnProfile ? 640 : 740)
                      : (isOwnProfile ? 360 : 500), // Adjusted Own profile to 360 and Public to 500.
                  pinned: true,
                  stretch: true,
                  // [FIX] à¹€à¸›à¸¥à¸µà¹ˆà¸¢à¸™à¹€à¸›à¹‡à¸™à¸—à¸¶à¸šà¸—à¸µà¹ˆ 0.9 à¹à¸—à¸™ 1.0 à¹€à¸žà¸·à¹ˆà¸­à¸„à¸§à¸²à¸¡à¹à¸™à¹ˆà¸™à¸­à¸™ (Rock-Solid for status bar icons)
                  backgroundColor: opacity >= 0.9 ? headerBaseColor : Colors.transparent,
                  surfaceTintColor: Colors.transparent,
                  scrolledUnderElevation: 0,
                  elevation: 0,
                  centerTitle: true,
                  title: LayoutBuilder(
                    builder: (context, constraints) {
                      final topPadding = MediaQuery.of(context).padding.top;
                      final toolbarHeight = isOwnProfile ? 40.0 : kToolbarHeight;
                      
                      // Show name when collapsed enough
                      return AnimatedOpacity(
                        duration: const Duration(milliseconds: 200),
                        opacity: constraints.biggest.height <= (topPadding + toolbarHeight + 48.0 + 10.0) ? 1.0 : 0.0,
                        child: Text(
                          profile.xparqName,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      );
                    },
                  ),
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
                  toolbarHeight: isOwnProfile ? 40 : kToolbarHeight,
                  flexibleSpace: Stack(
                    fit: StackFit.expand,
                    children: [
                      child!, // The FlexibleSpaceBar
                      // [FIX] Independent Solid Shield: à¹à¸œà¹ˆà¸™à¸šà¸±à¸‡à¸—à¸¶à¸šà¸­à¸´à¸ªà¸£à¸°à¸—à¸µà¹ˆà¸­à¸¢à¸¹à¹ˆà¸šà¸™à¹€à¸™à¸·à¹‰à¸­à¸«à¸² FlexibleSpaceBar 
                      // à¹à¸•à¹ˆà¸¢à¸±à¸‡à¸­à¸¢à¸¹à¹ˆà¸‚à¹‰à¸²à¸‡à¸«à¸¥à¸±à¸‡ Toolbar (à¸›à¸¸à¹ˆà¸¡ Settings/Back) à¹€à¸žà¸·à¹ˆà¸­à¸à¸±à¸™à¸‚à¹‰à¸­à¸„à¸§à¸²à¸¡ Bio à¸£à¸±à¹ˆà¸§
                      Positioned.fill(
                        child: IgnorePointer(
                          child: Container(
                            // à¸šà¸±à¸‡à¸—à¸¶à¸šà¸ªà¸™à¸´à¸—à¸—à¸µà¹ˆ 0.9 à¹€à¸žà¸·à¹ˆà¸­à¸à¸±à¸™à¸£à¸±à¹ˆà¸§ 100% à¸•à¸¥à¸­à¸”à¸—à¸±à¹‰à¸‡à¹à¸–à¸§ Status Bar à¹à¸¥à¸° Tab Bar
                            color: (opacity >= 0.9) ? headerBaseColor : Colors.transparent,
                          ),
                        ),
                      ),
                    ],
                  ),
                  bottom: PreferredSize(
                    preferredSize: const Size.fromHeight(48),
                    child: Builder(
                      builder: (context) {
                        final theme = Theme.of(context);
                        final isDark = theme.brightness == Brightness.dark;
                        final headerBaseColor = isDark ? Colors.black : Colors.white;

                        // Hide Tab Bar during repositioning
                        if (_isRepositioningCover || _isRepositioningAvatar) {
                          return const SizedBox.shrink();
                        }

                        final tabBar = _buildTabBar(context);

                        return Container(
                          // [FIX] Tab Bar à¸à¹‡à¸•à¹‰à¸­à¸‡à¸—à¸¶à¸š 100% à¸žà¸£à¹‰à¸­à¸¡à¸à¸±à¸š Shield à¸‚à¹‰à¸²à¸‡à¸šà¸™à¹€à¸žà¸·à¹ˆà¸­à¹„à¸¡à¹ˆà¹ƒà¸«à¹‰à¸¡à¸­à¸‡à¸—à¸°à¸¥à¸¸à¹€à¸«à¹‡à¸™à¹€à¸™à¸·à¹‰à¸­à¸«à¸²
                          color: opacity >= 0.9 ? headerBaseColor : headerBaseColor.withValues(alpha: opacity),
                          child: tabBar,
                        );
                      },
                    ),
                  ),
                );
              },
              child: FlexibleSpaceBar(
                background: Builder(
                  builder: (context) {
                    final theme = Theme.of(context);
                    final isDark = theme.brightness == Brightness.dark;
                    final headerBaseColor = isDark ? Colors.black : Colors.white;
                    
                    // Use FlexibleSpaceBarSettings to get the current extent and calculate opacity
                    final settings = context.dependOnInheritedWidgetOfExactType<FlexibleSpaceBarSettings>();
                    final top = settings?.currentExtent ?? 0.0;
                    final expandedHeight = isOwnProfile ? 340.0 : 460.0; // Synchronized with monolith 340
                    final totalExpandedHeight = expandedHeight +
                        (profile.isExpandedHeader ? (isOwnProfile ? 200.0 : 140.0) : 0.0);
                    final toolbarStripHeight = MediaQuery.paddingOf(context).top +
                        (isOwnProfile ? 40.0 : kToolbarHeight);
                    final minPinnedHeight = toolbarStripHeight + 48.0;

                    // Calculate opacity for flexible content (fades out as it collapses)
                    final visibleT = ((top - (minPinnedHeight + 20.0)) /
                            (totalExpandedHeight - minPinnedHeight))
                        .clamp(0.0, 1.0);
                    final flexibleContentOpacity = math.pow(visibleT, 1.8).toDouble();

                    // DRIVE THE HEADER SOLID STATE (Update notifier on next frame)
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) {
                        final progress = (1.0 - (top - minPinnedHeight) / (totalExpandedHeight - minPinnedHeight)).clamp(0.0, 1.0);
                        // Make it hit solid 1.0 slightly before actual pinning for a tight seal
                        _headerOpacityNotifier.value = (progress * 1.15).clamp(0.0, 1.0);
                      }
                    });

                    return Stack(
                      fit: StackFit.expand,
                      children: [
                        if (profile.isExpandedHeader)
                          ..._buildFullSocialLayout(
                            context,
                            profile,
                            flexibleContentOpacity,
                            isDark,
                            theme,
                            isOwnProfile,
                            headerBaseColor,
                          )
                        else
                          ..._buildStandardLayout(
                            context,
                            profile,
                            flexibleContentOpacity,
                            isDark,
                            theme,
                            isOwnProfile,
                            headerBaseColor,
                          ),

                         // Internal shield removed, moved to outer Stack to bypass fading
                      ],
                    );
                  },
                ),
              ),
            ),
        ];
      },
      body: _buildTabContent(profile),
      ),
    );
  }

  Widget _buildLandscapeLayout(
    BuildContext context,
    PlanetModel profile,
    bool isOwnProfile,
    String? viewingUid,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Row(
      children: [
        // Left Column: Identity
        Expanded(
          flex: 4,
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                right: BorderSide(
                  color: theme.dividerColor.withValues(alpha: 0.1),
                ),
              ),
            ),
            child: Column(
              children: [
                // Top Navigation for Landscape
                SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        if (!isOwnProfile)
                          IconButton(
                            icon: Icon(
                              Icons.arrow_back,
                              color: theme.colorScheme.onSurface,
                            ),
                            onPressed: () => Navigator.pop(context),
                          )
                        else
                          const SizedBox(width: 48),
                        if (isOwnProfile)
                          IconButton(
                            icon: Icon(
                              Icons.settings,
                              color: theme.colorScheme.onSurface,
                            ),
                            onPressed: () => context.push(AppRoutes.settings),
                          ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        const SizedBox(height: 20),
                        _buildAvatar(
                          context,
                          profile,
                          isOwnProfile,
                          isDark,
                          size: 140,
                        ),
                        const SizedBox(height: 20),
                        _buildIdentityInfo(
                          context,
                          profile,
                          isDark,
                          theme,
                          isOwnProfile,
                        ),
                        const SizedBox(height: 32),
                        _buildStats(context, profile),
                        const SizedBox(height: 32),
                        if (!isOwnProfile)
                          ProfileActions(
                            viewingUid: viewingUid!,
                            isOwnProfile: isOwnProfile,
                          ),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        // Right Column: Content
        Expanded(
          flex: 6,
          child: Column(
            children: [
              SafeArea(
                bottom: false,
                left: false,
                child: Container(
                  color: Colors.transparent,
                  child: _buildTabBar(context),
                ),
              ),
              Expanded(child: _buildTabContent(profile)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAvatar(
    BuildContext context,
    PlanetModel profile,
    bool isOwnProfile,
    bool isDark, {
    double size = 120,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: isOwnProfile && !_isRepositioningAvatar
          ? () => _showAvatarMenu(context, ref, profile, isOwnProfile)
          : null,
      onLongPress: isOwnProfile && !_isRepositioningAvatar
          ? () => _showPositionMenu(context, ref, profile)
          : null,
      onVerticalDragUpdate: _isRepositioningAvatar
          ? (details) {
              setState(() {
                _avatarYOffset =
                    (_avatarYOffset - (details.primaryDelta ?? 0.0) / 100)
                        .clamp(-1.0, 1.0);
              });
            }
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
        child: Hero(
          tag: 'profile_photo_hero',
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
                        _isRepositioningAvatar
                            ? _avatarYOffset
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
      ),
    );
  }

  Widget _buildIdentityInfo(
    BuildContext context,
    PlanetModel profile,
    bool isDark,
    ThemeData theme,
    bool isOwnProfile,
  ) {
    // --- MODE 1: FULL SOCIAL MODE (Expanded Header) ---
    // When the profile photo is shown as the full hero cover (100% visibility).
    if (profile.isExpandedHeader) {
      return Container(
        width: double.infinity,
        // CINEMATIC TRANSPARENCY: User-requested card look.
        // We make it transparent to let the Layer 0.1 blur background do the work.
        color: Colors.transparent,
        padding: const EdgeInsets.symmetric(
          horizontal: 24,
          vertical: 12,
        ), // Compact Padding
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (profile.blueOrbit) ...[
                  const Icon(
                    Icons.verified,
                    color: Color(0xFF4FC3F7),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                ],
                Text(
                  profile.xparqName,
                  style: TextStyle(
                    color: theme.colorScheme.onSurface,
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  profile.handle != null
                      ? '@${profile.handle}'
                      : '@${profile.xparqName.toLowerCase().replaceAll(' ', '')}',
                  style: TextStyle(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    '\u00B7',
                    style: TextStyle(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
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
                        ? (isDark
                              ? const Color(0xFFFFF176)
                              : const Color(0xFFB8860B))
                        : (isDark
                              ? const Color(0xFFB39DDB)
                              : const Color(0xFF673AB7)),
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    // --- MODE 2: STANDARD VIEW (Compact Glassmorphic Card) ---
    // A minimalist, floating glass card for a premium "Planet" feel.
    return ClipRRect(
      borderRadius: BorderRadius.circular(
        20,
      ), // Slightly sharper corner for compact look
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(
          sigmaX: profile.isExpandedHeader ? 8 : 2,
          sigmaY: profile.isExpandedHeader ? 8 : 2,
        ),
        child: Container(
          // COMPACT PADDING: Minimalist approach to reduce "Boxy" look
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            // Dynamic transparency for the glass effect
            color: profile.isExpandedHeader
                ? (isDark ? Colors.black.withValues(alpha: 0.4) : Colors.white)
                : (isDark
                      ? Colors.black.withValues(alpha: 
                          0.4,
                        ) // Slightly darker for contrast
                      : Colors.white.withValues(alpha: 
                          0.5,
                        )), // Soft white for light mode
            borderRadius: profile.isExpandedHeader
                ? BorderRadius.zero
                : BorderRadius.circular(20),
            // MINIMALIST BORDER: Subtle outline for depth
            border: profile.isExpandedHeader
                ? null
                : Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.12)
                        : Colors.black.withValues(alpha: 0.06),
                  ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            // Align based on User Photo Alignment setting (Left/Center/Right)
            crossAxisAlignment: profile.isExpandedHeader
                ? CrossAxisAlignment.start
                : profile.photoAlignment == 'left' &&
                      MediaQuery.of(context).orientation == Orientation.portrait
                ? CrossAxisAlignment.start
                : profile.photoAlignment == 'right' &&
                      MediaQuery.of(context).orientation == Orientation.portrait
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (profile.blueOrbit) ...[
                    const Icon(
                      Icons.verified,
                      color: Color(0xFF4FC3F7),
                      size: 16, // Smaller icon for compact look
                    ),
                    const SizedBox(width: 4),
                  ],
                  Text(
                    profile.xparqName,
                    style: TextStyle(
                      color: theme.colorScheme.onSurface,
                      fontSize: 18, // COMPACT FONT: Modern, minimalist size
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.2, // Tighter tracking for premium feel
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 1), // Minimal vertical gap
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    profile.handle != null
                        ? '@${profile.handle}'
                        : '@${profile.xparqName.toLowerCase().replaceAll(' ', '')}',
                    style: TextStyle(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                      fontSize: 12, // Smaller handle
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Text(
                      '\u00B7',
                      style: TextStyle(
                        color: theme.colorScheme.onSurface.withValues(alpha: 
                          0.3,
                        ),
                        fontSize: 14,
                      ),
                    ),
                  ),
                  Text(
                    profile.isCadet
                        ? AppLocalizations.of(context)!.galacticCadet
                        : AppLocalizations.of(context)!.interstellarExplorer,
                    style: TextStyle(
                      color: profile.isCadet
                          ? (isDark
                                ? const Color(0xFFFFF176)
                                : const Color(0xFFB8860B))
                          : (isDark
                                ? const Color(0xFFB39DDB)
                                : const Color(0xFF673AB7)),
                      fontSize: 11, // Smaller badge text
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStats(BuildContext context, PlanetModel profile) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: profile.isExpandedHeader
            ? Colors.transparent
            : Colors.transparent,
        border: profile.isExpandedHeader
            ? null
            : Border(
                top: BorderSide(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.04),
                  width: 0.5,
                ),
                bottom: BorderSide(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.04),
                  width: 0.5,
                ),
              ),
      ),
      padding: const EdgeInsets.only(
        left: 40,
        right: 40,
        top: 4,
        bottom: 0,
      ), // Tight Padding
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _ProfileStat(
            label: AppLocalizations.of(context)!.signals,
            uid: profile.id,
            collection: 'orbited_by',
          ),
          _StatColumn(
            label: AppLocalizations.of(context)!.lightYears,
            value: '1,205',
          ),
          _ProfileStat(
            label: AppLocalizations.of(context)!.planets,
            uid: profile.id,
            collection: 'orbiting',
          ),
        ],
      ),
    );
  }


  Widget _buildTabBar(BuildContext context) {
    return TabBar(
      dividerColor: Theme.of(
        context,
      ).colorScheme.onSurface.withValues(alpha: 0.05),
      indicatorColor: const Color(0xFF4FC3F7),
      labelColor: const Color(0xFF4FC3F7),
      unselectedLabelColor: Theme.of(
        context,
      ).colorScheme.onSurface.withValues(alpha: 0.54),
      tabs: [
        Tab(text: AppLocalizations.of(context)!.about),
        Tab(text: AppLocalizations.of(context)!.pulses),
        Tab(text: AppLocalizations.of(context)!.warps),
      ],
    );
  }

  Widget _buildTabContent(PlanetModel profile) {
    return TabBarView(
      children: [
        _AboutTab(
          profile: profile,
          isOwnProfile:
              profile.id ==
              (ref.watch(supabaseAuthStateProvider).valueOrNull?.id),
          onAlbumTap: (category) => _triggerGallery(category),
        ),
        _PulseListTab(uid: profile.id),
        _WarpListTab(uid: profile.id),
      ],
    );
  }

  /// ==========================================
  /// MODE-BASED LAYOUT BUILDERS (Structural Separation)
  /// ==========================================

  List<Widget> _buildStandardLayout(
    BuildContext context,
    PlanetModel profile,
    double opacity,
    bool isDark,
    ThemeData theme,
    bool isOwnProfile,
    Color headerBaseColor,
  ) {
    return [
      // 0. FIXED-HEIGHT PHOTO LAYER (Standard View)
      Opacity(
        opacity: opacity,
        child: Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: double.infinity,
            height: 250, // Standard cover height (Reduced from 300 for half-overlap)
            child: Stack(
              children: [
                _buildCoverContent(
                  context,
                  profile,
                  isOwnProfile,
                  isDark,
                  theme,
                ),
                // Interaction Layer (Edit Cover)
                if (isOwnProfile)
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTap: !(_isRepositioningCover || _isRepositioningAvatar)
                          ? () => _showCoverMenu(context, ref, profile)
                          : null,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),

      // 0. WHITE CARD BACKGROUND (Rounded Corners)
      if (!_isRepositioningCover && !_isRepositioningAvatar)
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          top: 240, // Overlap cover (fixed at 250) by 30px for a solid card start
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(32),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.08),
                  blurRadius: 12,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
          ),
        ),

      // 1. STANDARD IDENTITY & STATS (Floating over photo)
      if (!_isRepositioningCover && !_isRepositioningAvatar)
        Positioned(
          bottom: isOwnProfile ? 60 : 75, // Lowered from 110 to 74px for Public profiles to reduce High overlap.
          left: 0,
          right: 0,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Circular Avatar
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: profile.photoAlignment == 'center' ? 0 : 24,
                ),
                child: Align(
                  alignment: profile.photoAlignment == 'left'
                      ? AlignmentDirectional.centerStart
                      : profile.photoAlignment == 'right'
                      ? AlignmentDirectional.centerEnd
                      : Alignment.center,
                  child: _buildAvatar(context, profile, isOwnProfile, isDark),
                ),
              ),
              const SizedBox(height: 6), // Tightened from 12
              // Identity Info Card
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: profile.photoAlignment == 'center' ? 0 : 24,
                ),
                child: Align(
                  alignment: profile.photoAlignment == 'left'
                      ? AlignmentDirectional.centerStart
                      : profile.photoAlignment == 'right'
                      ? AlignmentDirectional.centerEnd
                      : Alignment.center,
                  child: _buildIdentityInfo(
                    context,
                    profile,
                    isDark,
                    theme,
                    isOwnProfile,
                  ),
                ),
              ),
              const SizedBox(height: 4), // Tightened from 8
              // Stats Row (RESTORED for Standard Mode)
              _buildStats(context, profile),
              if (!isOwnProfile) ...[
                const SizedBox(height: 20), // Minimal gap in Expanded mode.
                ProfileActions(
                  viewingUid: widget.viewingUid!,
                  isOwnProfile: isOwnProfile,
                ),
              ],
            ],
          ),
        ),
    ];
  }

  List<Widget> _buildFullSocialLayout(
    BuildContext context,
    PlanetModel profile,
    double opacity,
    bool isDark,
    ThemeData theme,
    bool isOwnProfile,
    Color headerBaseColor,
  ) {
    return [
      // 0. FULL-HEIGHT PHOTO LAYER
      Opacity(
        opacity: opacity,
        child: Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: double.infinity,
            height: double.infinity,
            child: Stack(
              key: ValueKey('${profile.photoAlignment}_expanded_photo'),
              children: [
                _buildCoverContent(
                  context,
                  profile,
                  isOwnProfile,
                  isDark,
                  theme,
                ),
                // Cinematic Gradient Overlay
                Positioned.fill(
                  child: IgnorePointer(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            headerBaseColor.withValues(alpha: 0.0),
                            headerBaseColor.withValues(alpha: 0.0),
                            headerBaseColor.withValues(alpha: 0.0),
                            headerBaseColor.withValues(alpha: 0.0),
                            headerBaseColor.withValues(alpha: 0.0),
                            headerBaseColor.withValues(alpha: 0.0),
                          ],
                          stops: const [0.0, 0.76, 0.88, 0.95, 0.98, 1.0],
                        ),
                      ),
                    ),
                  ),
                ),
                // 1.5 INTERACTION LAYER (Limit to top area for gallery trigger)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: 300, // Only the top 300px triggers the photogallery
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: !(_isRepositioningCover || _isRepositioningAvatar)
                        ? () {
                            if (isOwnProfile) {
                              _showAvatarMenu(
                                context,
                                ref,
                                profile,
                                isOwnProfile,
                              );
                            } else {
                              // Visitors can tap to open gallery directly
                              HapticFeedback.lightImpact();
                              _triggerGallery('profile');
                            }
                          }
                        : null,
                    onVerticalDragUpdate: (details) {
                      if (_isRepositioningCover) {
                        setState(() {
                          _coverYOffset =
                              (_coverYOffset - details.primaryDelta! / 100)
                                  .clamp(-1.0, 1.0);
                        });
                      } else if (profile.isExpandedHeader && !_isGalleryOpening) {
                        // Detect pull-down gesture direct on image (Timed Hold)
                        if (details.delta.dy > 15) { // Downward movement detected
                           if (_galleryTriggerTimer == null) {
                              HapticFeedback.selectionClick();
                              _galleryTriggerTimer = Timer(const Duration(milliseconds: 450), () {
                                if (mounted) {
                                  _isGalleryOpening = true;
                                  HapticFeedback.mediumImpact();
                                  _triggerGallery('profile');
                                  
                                  Future.delayed(const Duration(seconds: 1), () {
                                    _isGalleryOpening = false;
                                  });
                                }
                              });
                           }
                        } else if (details.delta.dy < -5) {
                          // Cancel on upward movement
                          _galleryTriggerTimer?.cancel();
                          _galleryTriggerTimer = null;
                        }
                      }
                    },
                    onVerticalDragEnd: (_) {
                      _galleryTriggerTimer?.cancel();
                      _galleryTriggerTimer = null;
                    },
                    onVerticalDragCancel: () {
                      _galleryTriggerTimer?.cancel();
                      _galleryTriggerTimer = null;
                    },
                  ),
                ),
],
            ),
          ),
        ),
      ),

      // 1. DYNAMIC BLURRED BACKGROUND (Glassmorphism Backdrop)
      if (profile.photoUrl.isNotEmpty) // Removed isDark restriction
        Positioned(
          top: 435, // Positioned for cinematic spacing
          left: 0,
          right: 0,
          bottom: 0,
          child: Opacity(
            opacity: opacity,
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(32),
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image(
                    image: XparqImage.getImageProvider(profile.photoUrl),
                    fit: BoxFit.cover,
                    alignment: Alignment.bottomCenter,
                  ),
                  ClipRRect(
                    child: BackdropFilter(
                      filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                      child: Container(
                        color: isDark 
                            ? Colors.black.withValues(alpha: 0.3)
                            : Colors.white.withValues(alpha: 0.45),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

      // 2. EXPANDED IDENTITY & STATS (Below Backdrop Start)
      Opacity(
        opacity: opacity,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 48), // TabBar Height
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              const SizedBox(height: 330), // Adjusted to prevent bottom overflow
              if (!(_isRepositioningCover || _isRepositioningAvatar)) ...[
                _buildIdentityInfo(
                  context,
                  profile,
                  isDark,
                  theme,
                  isOwnProfile,
                ),
                 Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: isDark 
                        ? Colors.white.withValues(alpha: 0.05)
                        : Colors.black.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildStats(context, profile),
                      if (!isOwnProfile)
                        ProfileActions(
                          viewingUid: widget.viewingUid!,
                          isOwnProfile: isOwnProfile,
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 2), // Minimal gap in Expanded mode.
              ],
            ],
          ),
        ),
      ),
    ];
  }

  Widget _buildCoverContent(
    BuildContext context,
    PlanetModel profile,
    bool isOwnProfile,
    bool isDark,
    ThemeData theme,
  ) {
    // 0. Expanded Profile Mode (Sharp avatar as cover)
    if (profile.photoUrl.isNotEmpty && profile.isExpandedHeader) {
      return SizedBox(
        height: double.infinity,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Hero(
              tag: 'profile_photo_hero',
              child: Image(
                image: XparqImage.getImageProvider(profile.photoUrl),
                fit: BoxFit.cover,
                alignment: Alignment(
                  0,
                  _isRepositioningCover
                      ? _coverYOffset
                      : profile.photoYPercent * 2 - 1.0,
                ),
              ),
            ),
            // Inner gradient removed for ExpandedHeader (handled by overlay)
          ],
        ),
      );
    }

    if (profile.coverPhotoUrl.isNotEmpty) {
      return SizedBox(
        height: double.infinity,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image(
              image: XparqImage.getImageProvider(profile.coverPhotoUrl),
              fit: BoxFit.cover,
              alignment: Alignment(
                0,
                _isRepositioningCover
                    ? _coverYOffset
                    : profile.coverPhotoYPercent * 2 - 1.0,
              ),
            ),
            // --- LIGHT MODE FADE (START) ---
            // This section adds a white gradient at the bottom of the cover photo for Light Mode.
            // Uncomment the block below to re-enable the "Smoke/Fade" effect.
            /*
            if (!isDark)
              Positioned(
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
              ),
            */
            // --- LIGHT MODE FADE (END) ---
          ],
        ),
      );
    }

    // Empty Cover: Avatar Mirror or Mesh Gradient
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? Colors.blueGrey.shade900 : Colors.white,
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Avatar Mirror (Blurred Background) - Only in Dark Mode for "Galactic" feel
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
            // 2. Stellar Canvas (Mesh Gradientish fallback) - Only in Dark Mode
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

          // 3. Creative CTA / Instruction
          if (isOwnProfile && !_isRepositioningCover && !_isRepositioningAvatar)
            Align(
              alignment: const Alignment(
                0,
                -0.75,
              ), // Pushed much higher to clear avatar in all positions
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: (isDark ? Colors.white : Colors.black).withValues(alpha: 
                      0.15,
                    ),
                    width: 1.2,
                    style: BorderStyle.solid, // Solid border
                  ),
                  color: (isDark ? Colors.black : Colors.white).withValues(alpha: 
                    0.1,
                  ),
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
                        color: theme.colorScheme.onSurface.withValues(alpha: 
                          0.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
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

  Widget _buildRepositioningFocusMode(PlanetModel profile) {
    final isCover = _isRepositioningCover;

    return Stack(
      fit: StackFit.expand,
      children: [
        // 1. Dark Backdrop
        Container(color: Colors.black.withValues(alpha: 0.95)),

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
              GestureDetector(
                onVerticalDragUpdate: (details) {
                  setState(() {
                    if (isCover) {
                      _coverYOffset =
                          (_coverYOffset - details.primaryDelta! / 100).clamp(
                            -1.0,
                            1.0,
                          );
                    } else {
                      _avatarYOffset =
                          (_avatarYOffset - details.primaryDelta! / 100).clamp(
                            -1.0,
                            1.0,
                          );
                    }
                  });
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
                              color: Colors.white.withValues(alpha: 0.05),
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
                          alignment: Alignment(0, _coverYOffset),
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
                              color: Colors.white.withValues(alpha: 0.05),
                              blurRadius: 30,
                            ),
                          ],
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.2),
                            width: 3,
                          ),
                          image: DecorationImage(
                            image: XparqImage.getImageProvider(
                              profile.photoUrl,
                            ),
                            fit: BoxFit.cover,
                            alignment: Alignment(0, _avatarYOffset),
                          ),
                        ),
                      ),

                    // Central Drag Handle Icon
                    IgnorePointer(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.4),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.open_with,
                          color: Colors.white,
                          size: 40,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 80),

              // Action Buttons
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: _cancelReposition,
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        child: Text(
                          AppLocalizations.of(context)!.cancel,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _savePosition,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4FC3F7),
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          AppLocalizations.of(context)!.savePosition,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _triggerGallery(String category) async {
    // Resolve the current profile from providers
    final viewingUid = widget.viewingUid;
    final profileAsync = viewingUid == null
        ? ref.read(planetProfileProvider)
        : ref.read(planetProfileByUidProvider(viewingUid));

    final profile = profileAsync.value;
    if (profile == null) return;

    final repo = ProfileRepository();
    List<String> photos = [];

    if (category == 'profile' || category == 'cover') {
      photos = await repo.fetchPhotoHistory(profile.id, category);
      // Ensure the current one is included at the start if it's missing
      final current =
          category == 'profile' ? profile.photoUrl : profile.coverPhotoUrl;
      if (current.isNotEmpty && !photos.contains(current)) {
        photos.insert(0, current);
      }
    } else if (category == 'pulse') {
      photos = await repo.fetchPulsePhotos(profile.id);
    }

    if (photos.isEmpty && (category == 'profile' || category == 'cover')) {
      final current =
          category == 'profile' ? profile.photoUrl : profile.coverPhotoUrl;
      if (current.isNotEmpty) photos = [current];
    }

    if (mounted && photos.isNotEmpty) {
      _openPhotoGallery(photos);
    }
  }

  void _openPhotoGallery(List<String> photos) {
    if (photos.isEmpty) return;
    
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        pageBuilder: (context, animation, secondaryAnimation) {
          return FadeTransition(
            opacity: animation,
            child: ProfilePhotoGallery(photos: photos, initialIndex: 0),
          );
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return child; // We handle transition in pageBuilder
        },
      ),
    );
  }
}

class _AboutTab extends ConsumerStatefulWidget {
  final PlanetModel profile;
  final bool isOwnProfile;
  final Function(String category)? onAlbumTap;
  const _AboutTab({
    required this.profile,
    required this.isOwnProfile,
    this.onAlbumTap,
  });

  @override
  ConsumerState<_AboutTab> createState() => _AboutTabState();
}

class _AboutTabState extends ConsumerState<_AboutTab> {
  // No longer needed: bool _contactVisible = false;

  PlanetModel get profile => widget.profile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 0.5 COSMIC ALBUMS Section
          _buildSection(
            context,
            title: AppLocalizations.of(context)!.cosmicAlbums,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              child: Row(
                children: [
                  _PhotoAlbumFolder(
                    title: AppLocalizations.of(context)!.profileAlbum,
                    icon: Icons.person_search_outlined,
                    onTap: () => widget.onAlbumTap?.call('profile'),
                  ),
                  const SizedBox(width: 12),
                  _PhotoAlbumFolder(
                    title: AppLocalizations.of(context)!.coverAlbum,
                    icon: Icons.landscape_outlined,
                    onTap: () => widget.onAlbumTap?.call('cover'),
                  ),
                  const SizedBox(width: 12),
                  _PhotoAlbumFolder(
                    title: AppLocalizations.of(context)!.pulseAlbum,
                    icon: Icons.auto_awesome_motion_outlined,
                    onTap: () => widget.onAlbumTap?.call('pulse'),
                  ),
                ],
              ),
            ),
          ),

          // 1. BIO Section
          if (profile.bio.isNotEmpty)
            _buildSection(
              context,
              title: AppLocalizations.of(context)!.bio,
              child: ExpandableText(
                text: profile.bio,
                style: TextStyle(
                  color: theme.colorScheme.onSurface,
                  fontSize: 15,
                  height: 1.5,
                ),
              ),
            ),

          // 2. EXTENDED BIO Section
          if (profile.extendedBio != null && profile.extendedBio!.isNotEmpty)
            _buildSection(
              context,
              title: AppLocalizations.of(context)!.extendedBio,
              child: ExpandableText(
                text: profile.extendedBio!,
                style: TextStyle(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                  fontSize: 14,
                  height: 1.6,
                ),
              ),
            ),

          // 3. BASIC INFO Section
          _buildSection(
            context,
            title: AppLocalizations.of(context)!.basicInfo,
            child: Column(
              children: [
                if (profile.gender != null && profile.gender!.isNotEmpty)
                  _buildInfoRow(
                    context,
                    Icons.person_outline,
                    AppLocalizations.of(context)!.gender,
                    profile.gender!,
                  ),
                if (profile.locationName != null &&
                    profile.locationName!.isNotEmpty)
                  _buildInfoRow(
                    context,
                    Icons.location_on_outlined,
                    AppLocalizations.of(context)!.location,
                    profile.locationName!,
                  ),
                // â”€â”€ Contact Info Rows â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
                if (profile.contactEmail != null &&
                    profile.contactEmail!.isNotEmpty)
                  _buildInfoRow(
                    context,
                    Icons.email_outlined,
                    AppLocalizations.of(context)!.email,
                    profile.isContactPublic || widget.isOwnProfile
                        ? profile.contactEmail!
                        : _maskedEmail(profile.contactEmail!),
                    trailing: _buildEyeToggle(theme),
                  ),
                if (profile.contactPhone != null &&
                    profile.contactPhone!.isNotEmpty)
                  _buildInfoRow(
                    context,
                    Icons.phone_outlined,
                    AppLocalizations.of(context)!.tel,
                    profile.isContactPublic || widget.isOwnProfile
                        ? profile.contactPhone!
                        : _maskedPhone(profile.contactPhone!),
                    trailing:
                        (profile.contactEmail == null ||
                            profile.contactEmail!.isEmpty)
                        ? _buildEyeToggle(
                            theme,
                          ) // show on phone row if no email row
                        : null,
                  ),
              ],
            ),
          ),

          // 3.5 PROFESSIONAL & ACADEMIC Section
          if ((profile.work != null && profile.work!.isNotEmpty) ||
              (profile.education != null && profile.education!.isNotEmpty) ||
              (profile.experience != null && profile.experience!.isNotEmpty) ||
              (profile.occupation != null && profile.occupation!.isNotEmpty))
            _buildSection(
              context,
              title: AppLocalizations.of(context)!.professionalAcademic,
              child: Column(
                children: [
                  if (profile.occupation != null &&
                      profile.occupation!.isNotEmpty)
                    _buildInfoRow(
                      context,
                      Icons.work_outline,
                      AppLocalizations.of(context)!.occupation,
                      profile.occupation!,
                    ),
                  if (profile.work != null && profile.work!.isNotEmpty)
                    _buildInfoRow(
                      context,
                      Icons.business_outlined,
                      AppLocalizations.of(context)!.workplace,
                      profile.work!,
                    ),
                  if (profile.education != null &&
                      profile.education!.isNotEmpty)
                    _buildInfoRow(
                      context,
                      Icons.school_outlined,
                      AppLocalizations.of(context)!.education,
                      profile.education!,
                    ),
                  if (profile.experience != null &&
                      profile.experience!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.stars_outlined,
                                size: 18,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurface.withValues(alpha: 0.5),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                AppLocalizations.of(context)!.experience,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.onSurface
                                      .withValues(alpha: 0.5),
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2), // Minimal gap in Expanded mode.
                          Padding(
                            padding: const EdgeInsetsDirectional.only(
                              end: 20,
                              start: 30,
                            ),
                            child: ExpandableText(
                              text: profile.experience!,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface,
                                fontSize: 14,
                                height: 1.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),

          // 3.7 PROFESSIONAL SKILLS Section
          if (profile.skills.isNotEmpty)
            _buildSection(
              context,
              title: 'PROFESSIONAL SKILLS',
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: profile.skills.map((skill) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(
                        0xFF81C784,
                      ).withValues(alpha: 0.1), // Gentle green
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: const Color(0xFF81C784).withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      skill,
                      style: const TextStyle(
                        color: Color(0xFF66BB6A),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

          // 4. STELLAR DECOR Section
          _buildSection(
            context,
            title: 'STELLAR DECOR',
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                if (profile.mbti != null && profile.mbti!.isNotEmpty)
                  _IdentityChip(
                    icon: Icons.psychology,
                    label: profile.mbti!,
                    color: Colors.blueGrey,
                  ),
                if (profile.zodiac != null && profile.zodiac!.isNotEmpty)
                  _IdentityChip(
                    icon: Icons.auto_awesome,
                    label: profile.zodiac!,
                    color: Colors.amber,
                  ),
                if (profile.bloodType != null && profile.bloodType!.isNotEmpty)
                  _IdentityChip(
                    icon: Icons.bloodtype_outlined,
                    label: 'Type ${profile.bloodType}',
                    color: Colors.redAccent,
                  ),
              ],
            ),
          ),

          // 5. COSMIC INTERESTS Section
          if (profile.constellations.isNotEmpty)
            _buildSection(
              context,
              title: 'COSMIC INTERESTS',
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: profile.constellations
                    .map((tag) => _InterestTag(label: tag))
                    .toList(),
              ),
            ),

          // 6. LINKS Section
          if (profile.links.isNotEmpty)
            _buildSection(
              context,
              title: 'LINKS',
              child: Column(
                children: profile.links
                    .map((link) => _LinkTile(url: link))
                    .toList(),
              ),
            ),

          const SizedBox(height: 100), // Extra space for bottom padding
        ],
      ),
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required Widget child,
  }) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.04),
            width: 0.5,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.0, // Removed 1.2 spacing to prevent Thai character disconnection
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _buildInfoRow(
    BuildContext context,
    IconData icon,
    String label,
    String value, {
    Widget? trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.5),
          ),
          const SizedBox(width: 12),
          Text(
            '$label: ',
            style: TextStyle(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.5),
              fontSize: 13,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (trailing != null) trailing,
        ],
      ),
    );
  }

  Widget _buildEyeToggle(ThemeData theme) {
    // If not own profile and NOT public, show request button instead of eye
    if (!widget.isOwnProfile && !profile.isContactPublic) {
      return TextButton(
        onPressed: () {
          // Centralized ProfileActions already handles this via the main "Request Contact" button.
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Use the "Request Contact" button in the profile header.',
              ),
            ),
          );
        },
        style: TextButton.styleFrom(
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
        ),
        child: const Text(
          'Request',
          style: TextStyle(color: Color(0xFF4FC3F7), fontSize: 12),
        ),
      );
    }

    // Owner view or Public view
    final isVisible = profile.isContactPublic;

    return GestureDetector(
      onTap: widget.isOwnProfile
          ? () async {
              try {
                await ProfileRepository().updateProfile(
                  uid: profile.id,
                  isContactPublic: !isVisible,
                );
                // Invalidate providers to refresh UI immediately
                ref.invalidate(planetProfileProvider);
                ref.invalidate(planetProfileByUidProvider(profile.id));
              } catch (e) {
                if (mounted) {
                  final messenger = ScaffoldMessenger.of(context);
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('Error: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            }
          : null,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: Icon(
          isVisible ? Icons.visibility : Icons.visibility_off_outlined,
          key: ValueKey(isVisible),
          size: 18,
          color: isVisible
              ? const Color(0xFF4FC3F7)
              : theme.colorScheme.onSurface.withValues(alpha: 0.3),
        ),
      ),
    );
  }

  String _maskedEmail(String email) {
    final atIdx = email.indexOf('@');
    if (atIdx < 2) return email;
    final local = email.substring(0, atIdx);
    final domain = email.substring(atIdx);
    return '${local[0]}${'*' * (local.length - 2)}${local[local.length - 1]}$domain';
  }

  String _maskedPhone(String phone) {
    if (phone.length < 5) return phone;
    const visible = 2, tail = 2;
    final stars = '*' * (phone.length - visible - tail);
    return '${phone.substring(0, visible)}$stars${phone.substring(phone.length - tail)}';
  }
}

class _PhotoAlbumFolder extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback onTap;

  const _PhotoAlbumFolder({
    required this.title,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 120,
        height: 140,
        decoration: BoxDecoration(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.05),
          ),
        ),
        child: Stack(
          children: [
            // Folder geometry backdrop
            Positioned(
              top: 10,
              left: 10,
              child: Container(
                width: 40,
                height: 10,
                decoration: BoxDecoration(
                  color: (isDark ? const Color(0xFF4FC3F7) : Colors.blueGrey)
                      .withValues(alpha: 0.2),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(6),
                    topRight: Radius.circular(6),
                  ),
                ),
              ),
            ),
            // Main folder body
            Positioned.fill(
              top: 15,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.cardColor.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      icon,
                      size: 28,
                      color: isDark ? const Color(0xFF4FC3F7) : Colors.blueGrey,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                        color: theme.colorScheme.onSurface.withValues(alpha: 
                          0.6,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // "Peek" photos indicator (Subtle stack effect)
            Positioned(
              top: 8,
              right: 15,
              child: Opacity(
                opacity: 0.3,
                child: Container(
                  width: 30,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurface,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InterestTag extends StatelessWidget {
  final String label;
  const _InterestTag({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _LinkTile extends StatelessWidget {
  final String url;
  const _LinkTile({required this.url});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF4FC3F7).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(Icons.link, size: 16, color: Color(0xFF4FC3F7)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              url,
              style: const TextStyle(
                color: Color(0xFF4FC3F7),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _IdentityChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _IdentityChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _PulseListTab extends ConsumerWidget {
  final String uid;
  const _PulseListTab({required this.uid});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pulsesAsync = ref.watch(userPulsesProvider(uid));

    return pulsesAsync.when(
      data: (pulses) {
        if (pulses.isEmpty) {
          return Center(
            child: Text(
              'No pulses yet.',
              style: TextStyle(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.38),
              ),
            ),
          );
        }
        return ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(0),
          itemCount: pulses.length,
          itemBuilder: (context, index) {
            return PulseCard(pulse: pulses[index]);
          },
        );
      },
      loading: () => Center(
        child: CircularProgressIndicator(
          color: Theme.of(
            context,
          ).colorScheme.onSurface.withValues(alpha: 0.24),
        ),
      ),
      error: (e, _) => Center(
        child: Text(
          'Error: $e',
          style: TextStyle(
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.38),
          ),
        ),
      ),
    );
  }
}

class _WarpListTab extends ConsumerWidget {
  final String uid;
  const _WarpListTab({required this.uid});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final warpsAsync = ref.watch(userWarpsProvider(uid));

    return warpsAsync.when(
      data: (pulses) {
        if (pulses.isEmpty) {
          return Center(
            child: Text(
              'No warps yet.',
              style: TextStyle(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.38),
              ),
            ),
          );
        }
        return ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(0),
          itemCount: pulses.length,
          itemBuilder: (context, index) {
            return PulseCard(pulse: pulses[index]);
          },
        );
      },
      loading: () => Center(
        child: CircularProgressIndicator(
          color: Theme.of(
            context,
          ).colorScheme.onSurface.withValues(alpha: 0.24),
        ),
      ),
      error: (e, _) => Center(
        child: Text(
          'Error: $e',
          style: TextStyle(
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.38),
          ),
        ),
      ),
    );
  }
}

class _ProfileStat extends ConsumerWidget {
  final String label;
  final String uid;
  final String collection;

  const _ProfileStat({
    required this.label,
    required this.uid,
    required this.collection,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final countAsync = ref.watch(
      orbitCountProvider(OrbitListParams(uid, collection)),
    );

    return GestureDetector(
      onTap: () {
        context.push(
          AppRoutes.orbitList,
          extra: {'uid': uid, 'collection': collection, 'title': label},
        );
      },
      child: Column(
        children: [
          Text(
            countAsync.when(
              data: (count) => count.toString(),
              loading: () => '...',
              error: (err, stack) => '0',
            ),
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.54),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  final String label;
  final String value;
  const _StatColumn({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.54),
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}



