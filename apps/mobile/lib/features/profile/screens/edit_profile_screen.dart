// lib/features/profile/screens/edit_profile_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:xparq_app/features/auth/models/planet_model.dart';
import 'package:xparq_app/l10n/app_localizations.dart';
import 'package:xparq_app/features/radar/services/location_service.dart';
import 'package:xparq_app/shared/utils/thailand_location_utils.dart';
import 'package:xparq_app/shared/widgets/common/expandable_text.dart';
import 'package:xparq_app/features/auth/providers/auth_providers.dart';
import 'package:xparq_app/shared/widgets/common/xparq_image.dart';
import 'package:xparq_app/features/profile/providers/image_upload_provider.dart';
import 'package:xparq_app/features/profile/repositories/profile_repository.dart';
import 'package:xparq_app/shared/constants/thailand_provinces.dart';
import 'package:xparq_app/shared/utils/stellar_identity_helper.dart';
import 'package:xparq_app/features/profile/widgets/edit_profile/edit_profile_widgets.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _nameController = TextEditingController();
  final _handleController = TextEditingController();
  final _shortBioController = TextEditingController();
  final _extendedBioController = TextEditingController();
  final _genderController = TextEditingController();
  final _locationController = TextEditingController();
  final _occupationController = TextEditingController();
  final _link1Controller = TextEditingController();
  final _link2Controller = TextEditingController();
  final _link3Controller = TextEditingController();
  final _mbtiController = TextEditingController();
  final _zodiacController = TextEditingController();
  final _bloodTypeController = TextEditingController();
  final _workController = TextEditingController();
  final _educationController = TextEditingController();
  final _experienceController = TextEditingController();
  final _emailController = TextEditingController(); // Contact email
  final _phoneController = TextEditingController(); // Contact phone
  final _locationFocusNode = FocusNode();

  final _repo = ProfileRepository();

  XFile? _newAvatarFile;
  XFile? _newCoverFile;
  double _coverYOffset = 0.0;
  bool _isSaving = false;
  List<String> _constellations = [];
  List<String> _skills = [];
  bool _populated = false; // Guard: only populate once
  bool _isEditing = false;

  static const _allConstellations = [
    '🎵 Music',
    '🎮 Gaming',
    '📚 Books',
    '🎨 Art',
    '🏃 Sports',
    '🍜 Food',
    '✈️ Travel',
    '💻 Tech',
    '🎬 Movies',
    '🌿 Nature',
    '🔭 Science',
    '💃 Dance',
    '🎤 Karaoke',
    '👽 Sci-Fi',
    '🔥 18+',
  ];

  static const _allSkills = [
    '💻 Coding',
    '🎨 Design',
    '📈 Marketing',
    '✍️ Writing',
    '📊 Data',
    '🤝 Sales',
    '💡 Strategy',
    '📷 Photo',
    '🎥 Video',
    '🎧 Audio',
    '🗣️ Languages',
    '🍳 Cooking',
    '🛠️ Engineering',
    '🧬 Science',
  ];

  static const _genderOptions = [
    'Male',
    'Female',
    'Non-binary',
    'LGBTQ+',
    'Prefer not to say',
    'Custom',
  ];

  // MBTI, Zodiac, Blood types are now handled by StellarIdentityHelper

  @override
  void initState() {
    super.initState();
    // Initialize focus node if needed (though already done at declaration)
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Populate fields once when the profile stream first emits data
    if (!_populated) {
      final profile = ref.read(planetProfileProvider).valueOrNull;
      if (profile != null) {
        _populateFields(profile);
        _populated = true;
      }
    }
  }

  void _populateFields(PlanetModel profile) {
    _nameController.text = profile.xparqName;
    _handleController.text = profile.handle ?? '';
    _shortBioController.text = profile.bio;
    _extendedBioController.text = profile.extendedBio ?? '';
    _genderController.text = profile.gender ?? '';
    _locationController.text = profile.locationName ?? '';
    _occupationController.text = profile.occupation ?? '';
    _mbtiController.text = profile.mbti ?? '';
    _zodiacController.text = profile.zodiac ?? '';
    _bloodTypeController.text = profile.bloodType ?? '';
    _workController.text = profile.work ?? '';
    _educationController.text = profile.education ?? '';
    _experienceController.text = profile.experience ?? '';

    if (profile.links.isNotEmpty) _link1Controller.text = profile.links[0];
    if (profile.links.length > 1) _link2Controller.text = profile.links[1];
    if (profile.links.length > 2) _link3Controller.text = profile.links[2];

    _constellations = List.from(profile.constellations);
    _skills = List.from(profile.skills);
    _coverYOffset = profile.coverPhotoYPercent * 2 - 1.0;
    _emailController.text = profile.contactEmail ?? '';
    _phoneController.text = profile.contactPhone ?? '';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _handleController.dispose();
    _shortBioController.dispose();
    _extendedBioController.dispose();
    _genderController.dispose();
    _locationController.dispose();
    _occupationController.dispose();
    _link1Controller.dispose();
    _link2Controller.dispose();
    _link3Controller.dispose();
    _mbtiController.dispose();
    _zodiacController.dispose();
    _bloodTypeController.dispose();
    _workController.dispose();
    _educationController.dispose();
    _experienceController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _locationFocusNode.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final file = await ref
        .read(imageUploadServiceProvider)
        .pickImage(source: ImageSource.gallery);
    if (file != null) setState(() => _newAvatarFile = file);
  }

  Future<void> _pickCover() async {
    final file = await ref
        .read(imageUploadServiceProvider)
        .pickImage(source: ImageSource.gallery);
    if (file != null) setState(() => _newCoverFile = file);
  }

  Future<void> _handleGpsLocation() async {
    try {
      final hasPermission = await LocationService.requestPermission();
      if (!hasPermission) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                AppLocalizations.of(context)!.locationPermissionDenied,
              ),
            ),
          );
        }
        return;
      }

      final position = await LocationService.getCurrentPosition();
      if (position == null) return;

      final province = findNearestProvince(
        position.latitude,
        position.longitude,
      );
      if (province != null) {
        setState(() {
          _locationController.text = formatThailandLocation(province);
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                AppLocalizations.of(context)!.locationUpdated(province),
              ),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                AppLocalizations.of(context)!.locationProvinceError,
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.errorGettingLocation(e.toString()),
            ),
          ),
        );
      }
    }
  }

  int _daysUntilHandleChange(DateTime? updatedAt) {
    if (updatedAt == null) return 0;
    final daysSince = DateTime.now().difference(updatedAt).inDays;
    // If within the 90-day cooldown, return days remaining
    if (daysSince < 90) return 90 - daysSince;
    return 0; // Cooldown cleared
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final uid = ref.read(authRepositoryProvider).currentUser!.id;
      final profile = ref.read(planetProfileProvider).valueOrNull!;

      String? photoUrl;
      if (_newAvatarFile != null) {
        photoUrl = await ref
            .read(imageUploadServiceProvider)
            .uploadProfileImage(file: _newAvatarFile!, uid: uid);
      }

      String? coverPhotoUrl;
      if (_newCoverFile != null) {
        coverPhotoUrl = await ref
            .read(imageUploadServiceProvider)
            .uploadCoverImage(file: _newCoverFile!, uid: uid);
      }

      final links = [
        _link1Controller.text.trim(),
        _link2Controller.text.trim(),
        _link3Controller.text.trim(),
      ].where((l) => l.isNotEmpty).toList();

      final newHandle = _handleController.text.trim().replaceAll('@', '');
      DateTime? handleUpdateAt = profile.handleUpdatedAt;
      if (newHandle != profile.handle) {
        handleUpdateAt = DateTime.now();
      }

      await _repo.updateProfile(
        uid: uid,
        xparqName: _nameController.text.trim(),
        handle: newHandle.isEmpty ? null : newHandle,
        handleUpdatedAt: handleUpdateAt,
        bio: _shortBioController.text.trim(),
        extendedBio: _extendedBioController.text.trim(),
        gender: _genderController.text.trim(),
        locationName: _locationController.text.trim(),
        occupation: _occupationController.text.trim(),
        links: links,
        mbti: _mbtiController.text.trim().toUpperCase(),
        zodiac: _zodiacController.text.trim(),
        bloodType: _bloodTypeController.text.trim(),
        photoUrl: photoUrl,
        coverPhotoUrl: coverPhotoUrl,
        coverPhotoYPercent: (_coverYOffset + 1.0) / 2,
        constellations: _constellations,
        work: _workController.text.trim(),
        education: _educationController.text.trim(),
        experience: _experienceController.text.trim(),
        skills: _skills,
        contactEmail: _emailController.text.trim(),
        contactPhone: _phoneController.text.trim(),
      );

      final _ = await ref.refresh(planetProfileProvider.future);
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.errorSavingProfile(e.toString()),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(planetProfileProvider).value;
    if (profile == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // Populate fields the first time the profile stream emits data.
    // This handles the race condition where the stream fires after initState/didChangeDependencies.
    if (!_populated) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_populated && mounted) {
          _populateFields(profile);
          setState(() => _populated = true);
        }
      });
    }

    final handleCooldown = _daysUntilHandleChange(profile.handleUpdatedAt);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          AppLocalizations.of(context)!.editProfileTitle,
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
        ),
        centerTitle: true,
        actions: [
          if (_isSaving)
            const Center(
              child: Padding(
                padding: EdgeInsetsDirectional.only(end: 16),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else if (!_isEditing)
            TextButton(
              onPressed: () => setState(() => _isEditing = true),
              child: Text(
                AppLocalizations.of(context)!.editProfileEdit,
                style: const TextStyle(
                  color: Color(0xFF4FC3F7),
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
          else
            TextButton(
              onPressed: _save,
              child: Text(
                AppLocalizations.of(context)!.editProfileSave,
                style: const TextStyle(
                  color: Color(0xFF4FC3F7),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Media Section
              _buildMediaSection(profile),
              const SizedBox(height: 16),

              // Identity Section
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    _buildTextField(
                      controller: _nameController,
                      label: AppLocalizations.of(context)!.editProfileNameLabel,
                      hint: AppLocalizations.of(context)!.editProfileNameHint,
                      maxLength: 30,
                      validator: (v) => (v == null || v.trim().length < 3)
                          ? 'Min 3 chars'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    _buildHandleField(handleCooldown),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Contact Info Section
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLocalizations.of(context)!.editProfileContactInfo,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      AppLocalizations.of(context)!.editProfileContactInfoDesc,
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildTextField(
                      controller: _emailController,
                      label: AppLocalizations.of(
                        context,
                      )!.editProfileContactEmailLabel,
                      hint: 'example@email.com',
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 12),
                    _buildTextField(
                      controller: _phoneController,
                      label: AppLocalizations.of(
                        context,
                      )!.editProfileContactPhoneLabel,
                      hint: '08XXXXXXXX',
                      keyboardType: TextInputType.phone,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Professional Section
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLocalizations.of(
                        context,
                      )!.editProfileSectionProfessional,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _workController,
                      label: AppLocalizations.of(context)!.editProfileWorkLabel,
                      hint: AppLocalizations.of(context)!.editProfileWorkHint,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _educationController,
                      label: AppLocalizations.of(
                        context,
                      )!.editProfileEducationLabel,
                      hint: AppLocalizations.of(
                        context,
                      )!.editProfileEducationHint,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _experienceController,
                      label: AppLocalizations.of(
                        context,
                      )!.editProfileExperienceLabel,
                      hint: AppLocalizations.of(
                        context,
                      )!.editProfileExperienceHint,
                      maxLines: 10,
                      maxLength: 3000,
                    ),
                    const SizedBox(height: 16),
                    _buildSkillsSection(),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Bio Section
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    _buildTextField(
                      controller: _shortBioController,
                      label: AppLocalizations.of(
                        context,
                      )!.editProfileShortBioLabel,
                      hint: AppLocalizations.of(
                        context,
                      )!.editProfileShortBioHint,
                      maxLength: 200,
                      maxLines: 3,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _extendedBioController,
                      label: AppLocalizations.of(
                        context,
                      )!.editProfileExtendedBioLabel,
                      hint: AppLocalizations.of(
                        context,
                      )!.editProfileExtendedBioHint,
                      maxLength: 2000,
                      maxLines: 8,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Persona Details Section
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _buildPickerField(
                            controller: _genderController,
                            label: AppLocalizations.of(
                              context,
                            )!.editProfileGenderLabel,
                            options: _genderOptions,
                            title: AppLocalizations.of(
                              context,
                            )!.editProfileSelectGender,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildTextField(
                            controller: _occupationController,
                            label: AppLocalizations.of(
                              context,
                            )!.editProfileOccupationLabel,
                            hint: AppLocalizations.of(
                              context,
                            )!.editProfileOccupationHint,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Autocomplete<String>(
                      textEditingController: _locationController,
                      focusNode: _locationFocusNode,
                      displayStringForOption: (option) =>
                          formatThailandLocation(option),
                      optionsBuilder: (TextEditingValue textEditingValue) {
                        String text = textEditingValue.text;
                        // Strip suffix if present to allow searching again
                        if (text.endsWith(', TH')) {
                          text = text.substring(0, text.length - 4);
                        }
                        if (text.isEmpty) {
                          return const Iterable<String>.empty();
                        }
                        return thailandProvinces.where((String option) {
                          return option.toLowerCase().contains(
                            text.toLowerCase(),
                          );
                        });
                      },
                      fieldViewBuilder:
                          (context, controller, focusNode, onFieldSubmitted) {
                            return _buildTextField(
                              focusNode: focusNode,
                              controller: controller,
                              label: AppLocalizations.of(
                                context,
                              )!.editProfileLocationLabel,
                              hint: AppLocalizations.of(
                                context,
                              )!.editProfileLocationHint,
                              suffixIcon: _isEditing
                                  ? IconButton(
                                      icon: const Icon(
                                        Icons.gps_fixed,
                                        size: 20,
                                        color: Color(0xFF4FC3F7),
                                      ),
                                      onPressed: _handleGpsLocation,
                                      tooltip: 'Use Current Location',
                                    )
                                  : null,
                            );
                          },
                      optionsViewBuilder: (context, onSelected, options) {
                        return Align(
                          alignment: Alignment.topLeft,
                          child: Material(
                            elevation: 8.0,
                            borderRadius: BorderRadius.circular(12),
                            color: Theme.of(context).cardColor,
                            child: SizedBox(
                              height: 250, // Fixed height is safer
                              width: MediaQuery.of(context).size.width - 40,
                              child: ListView.separated(
                                padding: EdgeInsets.zero,
                                itemCount: options.length,
                                separatorBuilder: (context, index) => Divider(
                                  height: 1,
                                  color: Theme.of(
                                    context,
                                  ).dividerColor.withValues(alpha: 0.1),
                                ),
                                itemBuilder: (BuildContext context, int index) {
                                  final String option = options.elementAt(
                                    index,
                                  );
                                  return ListTile(
                                    visualDensity: VisualDensity.compact,
                                    title: Text(
                                      option,
                                      style: TextStyle(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurface,
                                        fontSize: 14,
                                      ),
                                    ),
                                    trailing: Text(
                                      'TH',
                                      style: TextStyle(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary
                                            .withValues(alpha: 0.5),
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    onTap: () => onSelected(option),
                                  );
                                },
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Links Section
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    _buildTextField(
                      controller: _link1Controller,
                      label: AppLocalizations.of(
                        context,
                      )!.editProfileLinkLabel('1'),
                      hint: AppLocalizations.of(context)!.editProfileLink1Hint,
                    ),
                    const SizedBox(height: 12),
                    _buildTextField(
                      controller: _link2Controller,
                      label: AppLocalizations.of(
                        context,
                      )!.editProfileLinkLabel('2'),
                      hint: AppLocalizations.of(context)!.editProfileLink2Hint,
                    ),
                    const SizedBox(height: 12),
                    _buildTextField(
                      controller: _link3Controller,
                      label: AppLocalizations.of(
                        context,
                      )!.editProfileLinkLabel('3'),
                      hint: AppLocalizations.of(context)!.editProfileLink3Hint,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Stellar Decor Section
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _buildIconPickerField(
                            controller: _mbtiController,
                            label: AppLocalizations.of(
                              context,
                            )!.editProfileMbtiLabel,
                            options: StellarIdentityHelper.getMbtiTypes(),
                            title: AppLocalizations.of(
                              context,
                            )!.editProfileSelectMbti,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildIconPickerField(
                            controller: _zodiacController,
                            label: AppLocalizations.of(
                              context,
                            )!.editProfileZodiacLabel,
                            options: StellarIdentityHelper.getZodiacTypes(context),
                            title: AppLocalizations.of(
                              context,
                            )!.editProfileSelectZodiac,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildIconPickerField(
                            controller: _bloodTypeController,
                            label: AppLocalizations.of(
                              context,
                            )!.editProfileBloodLabel,
                            options: StellarIdentityHelper.getBloodTypes(context),
                            title: AppLocalizations.of(
                              context,
                            )!.editProfileSelectBloodType,
                            crossAxisCount: 2,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _buildInterestsSection(),
                  ],
                ),
              ),
              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMediaSection(PlanetModel profile) {
    return Column(
      children: [
        // Cover Photo
        Stack(
          children: [
            GestureDetector(
              onTap: _isEditing ? _pickCover : null,
              child: Container(
                height: 180,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.blueGrey.withValues(alpha: 0.1),
                  image: _newCoverFile != null
                      ? DecorationImage(
                          image: XparqImage.getImageProvider(
                            _newCoverFile!.path,
                          ),
                          fit: BoxFit.cover,
                          alignment: Alignment(0, _coverYOffset),
                        )
                      : (profile.coverPhotoUrl.isNotEmpty
                            ? DecorationImage(
                                image: XparqImage.getImageProvider(
                                  profile.coverPhotoUrl,
                                ),
                                fit: BoxFit.cover,
                                alignment: Alignment(0, _coverYOffset),
                              )
                            : null),
                ),
                child: (_newCoverFile == null && profile.coverPhotoUrl.isEmpty)
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
            if (_isEditing) _buildCoverMenu(),
            // Avatar positioned over cover
            Positioned(
              bottom: 0,
              left: 20,
              child: Transform.translate(
                offset: const Offset(0, 40),
                child: GestureDetector(
                  onTap: _isEditing ? _pickAvatar : null,
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
                          backgroundImage: _newAvatarFile != null
                              ? XparqImage.getImageProvider(
                                  _newAvatarFile!.path,
                                )
                              : (profile.photoUrl.isNotEmpty
                                    ? XparqImage.getImageProvider(
                                        profile.photoUrl,
                                      )
                                    : null),
                          child:
                              (_newAvatarFile == null &&
                                  profile.photoUrl.isEmpty)
                              ? const Icon(Icons.person, size: 40)
                              : null,
                        ),
                      ),
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

  Widget _buildCoverMenu() {
    return Positioned(
      top: 10,
      right: 10,
      child: PopupMenuButton<String>(
        icon: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.5),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.more_vert, size: 18, color: Colors.white),
        ),
        offset: const Offset(0, 40),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        onSelected: (val) {
          if (val == 'change') {
            _pickCover();
          } else if (val == 'delete') {
            setState(() {
              _newCoverFile = null;
            });
            // Also need to handle clear cover in the profile model if needed
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
                  AppLocalizations.of(context)!.editProfileChangeImage,
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
                  AppLocalizations.of(context)!.editProfileDeleteImage,
                  style: const TextStyle(fontSize: 14, color: Colors.redAccent),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHandleField(int cooldownDays) {
    final locked = cooldownDays > 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _handleController,
          enabled: !locked && _isEditing,
          decoration: InputDecoration(
            labelText: AppLocalizations.of(context)!.editProfileHandleLabel,
            prefixText: '@',
            prefixStyle: const TextStyle(
              color: Color(0xFF4FC3F7),
              fontWeight: FontWeight.bold,
            ),
            filled: true,
            fillColor: locked
                ? Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.02)
                : Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.05),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            suffixIcon: locked
                ? const Icon(Icons.lock_outline, size: 18)
                : null,
          ),
          onChanged: (v) {
            // Enforcement: no spaces, lowercase
            final safe = v.toLowerCase().replaceAll(' ', '');
            if (safe != v) {
              _handleController.text = safe;
              _handleController.selection = TextSelection.fromPosition(
                TextPosition(offset: safe.length),
              );
            }
          },
        ),
        if (locked)
          Padding(
            padding: const EdgeInsets.only(top: 8, left: 4),
            child: Text(
              AppLocalizations.of(
                context,
              )!.editProfileHandleCooldown(cooldownDays.toString()),
              style: const TextStyle(fontSize: 11, color: Colors.orangeAccent),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.only(top: 8, left: 4),
            child: Text(
              AppLocalizations.of(context)!.editProfileHandleLockNote,
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.38),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildIconPickerField({
    required TextEditingController controller,
    required String label,
    required List<Map<String, String>> options,
    required String title,
    int crossAxisCount = 4,
  }) {
    final icon = label.contains('MBTI')
        ? StellarIdentityHelper.getIconForMbti(controller.text)
        : (label.contains('Zodiac')
            ? StellarIdentityHelper.getIconForZodiac(controller.text)
            : StellarIdentityHelper.getIconForBloodType(controller.text));

    return GestureDetector(
      onTap: _isEditing
          ? () => EditProfileWidgets.showIconSelectionPicker(
                context: context,
                title: title,
                options: options,
                currentValue: controller.text,
                onSelect: (val) => setState(() => controller.text = val),
                crossAxisCount: crossAxisCount,
              )
          : null,
      child: AbsorbPointer(
        absorbing: !_isEditing,
        child: _buildTextField(
          controller: controller,
          label: label,
          hint: 'Tap to select',
          suffixIcon: Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Text(
              icon,
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPickerField({
    required TextEditingController controller,
    required String label,
    required List<String> options,
    required String title,
  }) {
    return GestureDetector(
      onTap: _isEditing
          ? () => EditProfileWidgets.showSelectionPicker(
                context: context,
                title: title,
                options: options,
                onSelect: (val) => setState(() => controller.text = val),
              )
          : null,
      child: AbsorbPointer(
        absorbing: !_isEditing,
        child: _buildTextField(
          controller: controller,
          label: label,
          hint: 'Tap to select',
        ),
      ),
    );
  }

  // _showSelectionPicker and _buildTextField logic moved to EditProfileWidgets or unified above

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    FocusNode? focusNode,
    String? hint,
    Widget? suffixIcon,
    int? maxLength,
    int maxLines = 1,
    bool? enabled,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    if (!_isEditing && maxLines > 1 && controller.text.isNotEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.35),
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 8),
          ExpandableText(
            text: controller.text,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 14,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
        ],
      );
    }

    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      maxLength: maxLength,
      maxLines: maxLines,
      validator: validator,
      enabled: enabled ?? _isEditing,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: Theme.of(
            context,
          ).colorScheme.onSurface.withValues(alpha: 0.35),
          fontSize: 13,
        ),
        floatingLabelStyle: TextStyle(
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
          fontSize: 12,
        ),
        hintText: hint,
        hintStyle: TextStyle(
          color: Theme.of(
            context,
          ).colorScheme.onSurface.withValues(alpha: 0.15),
          fontSize: 13,
        ),
        filled: true,
        fillColor: Theme.of(
          context,
        ).colorScheme.onSurface.withValues(alpha: 0.05),
        suffixIcon: suffixIcon,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        // Show counter only if maxLength is provided
        counterStyle: TextStyle(
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
          fontSize: 10,
        ),
      ),
    );
  }

  Widget _buildInterestsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppLocalizations.of(
            context,
          )!.editProfileInterestsLabel(_constellations.length.toString()),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _allConstellations.map((tag) {
            final isSelected = _constellations.contains(tag);
            return FilterChip(
              label: Text(
                tag,
                style: TextStyle(
                  fontSize: 12,
                  color: isSelected
                      ? Theme.of(context).colorScheme.surface
                      : Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              selected: isSelected,
              onSelected: _isEditing
                  ? (val) {
                      setState(() {
                        if (val) {
                          if (_constellations.length < 5) {
                            _constellations.add(tag);
                          }
                        } else {
                          _constellations.remove(tag);
                        }
                      });
                    }
                  : null,
              selectedColor: const Color(0xFF4FC3F7),
              backgroundColor: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.05),
              checkmarkColor: Theme.of(context).colorScheme.surface,
              side: BorderSide(
                color: isSelected
                    ? const Color(0xFF4FC3F7)
                    : Colors.transparent,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildSkillsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppLocalizations.of(
            context,
          )!.editProfileSkillsLabel(_skills.length.toString()),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _allSkills.map((tag) {
            final isSelected = _skills.contains(tag);
            return FilterChip(
              label: Text(
                tag,
                style: TextStyle(
                  fontSize: 12,
                  color: isSelected
                      ? Theme.of(context).colorScheme.surface
                      : Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              selected: isSelected,
              onSelected: _isEditing
                  ? (val) {
                      setState(() {
                        if (val) {
                          if (_skills.length < 10) _skills.add(tag);
                        } else {
                          _skills.remove(tag);
                        }
                      });
                    }
                  : null,
              selectedColor: const Color(0xFF81C784), // Greenish for skills
              backgroundColor: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.05),
              checkmarkColor: Theme.of(context).colorScheme.surface,
              side: BorderSide(
                color: isSelected
                    ? const Color(0xFF81C784)
                    : Colors.transparent,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
