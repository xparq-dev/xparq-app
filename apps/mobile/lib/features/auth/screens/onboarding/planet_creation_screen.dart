// lib/features/auth/screens/onboarding/planet_creation_screen.dart
//
// Planet profile creation screen.
// Collects: iXPARQ Name, Bio, Avatar (photo_url), Constellations (interests).
// DOB is passed in from DobInputScreen and encrypted here.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:xparq_app/features/auth/providers/auth_providers.dart';
import 'package:xparq_app/features/profile/providers/image_upload_provider.dart';
import 'package:xparq_app/shared/router/app_router.dart';
import 'package:xparq_app/shared/widgets/ui/buttons/galaxy_button.dart';
import 'package:xparq_app/l10n/app_localizations.dart';
import 'package:xparq_app/shared/widgets/common/xparq_image.dart';
import 'package:xparq_app/shared/utils/stellar_identity_helper.dart';
import 'nsfw_opt_in_dialog.dart';

class PlanetCreationScreen extends ConsumerStatefulWidget {
  final DateTime? dob;
  const PlanetCreationScreen({super.key, this.dob});

  @override
  ConsumerState<PlanetCreationScreen> createState() =>
      _PlanetCreationScreenState();
}

class _PlanetCreationScreenState extends ConsumerState<PlanetCreationScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _bioController = TextEditingController();
  final _scrollController = ScrollController();
  final _selectedConstellations = <String>[];
  String? _selectedMbti;
  String? _selectedEnneagram;
  String? _selectedZodiac;
  String? _selectedBloodType;
  XFile? _avatarFile;
  bool _isUploading = false;
  late AnimationController _animationController;

  List<String> _getAvailableConstellations(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return [
      l10n.tagMusic,
      l10n.tagGaming,
      l10n.tagBooks,
      l10n.tagArt,
      l10n.tagSports,
      l10n.tagFood,
      l10n.tagTravel,
      l10n.tagTech,
      l10n.tagMovies,
      l10n.tagNature,
    ];
  }

  List<Map<String, String>> _getMbtiTypes(BuildContext context) =>
      StellarIdentityHelper.getMbtiTypes();

  List<Map<String, String>> _getEnneagramTypes(BuildContext context) =>
      StellarIdentityHelper.getEnneagramTypes(context);

  List<Map<String, String>> _getZodiacTypes(BuildContext context) =>
      StellarIdentityHelper.getZodiacTypes(context);

  List<Map<String, String>> _getBloodTypes(BuildContext context) =>
      StellarIdentityHelper.getBloodTypes(context);

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..forward();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    _scrollController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final notifier = ref.read(authNotifierProvider.notifier);

    ref.listen(authNotifierProvider, (prev, next) {
      if (next.step == AuthStep.nsfwOptIn && prev?.step != AuthStep.nsfwOptIn) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => NsfwOptInDialog(
            onAccept: () async {
              final nav = Navigator.of(context);
              await notifier.setNsfwOptIn(
                value: true,
                ageGroup: ref.read(currentAgeGroupProvider),
              );
              if (!context.mounted) return;
              nav.pop(); // Close Dialog
              ref.invalidate(planetProfileProvider); // Force router check
            },
            onDecline: () async {
              final nav = Navigator.of(context);
              await notifier.setNsfwOptIn(
                value: false,
                ageGroup: ref.read(currentAgeGroupProvider),
              );
              if (!context.mounted) return;
              nav.pop(); // Close Dialog
              ref.invalidate(planetProfileProvider); // Force router check
            },
          ),
        );
      }
    });

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark
        ? Theme.of(context).scaffoldBackgroundColor
        : const Color(0xFFFFFFFF);
    final textColor = isDark
        ? const Color(0xFFE7E9EA)
        : const Color(0xFF0F1419);
    final textSecondary = isDark
        ? const Color(0xFF71767B)
        : const Color(0xFF536471);
    final primaryColor = const Color(0xFF1D9BF0);
    final borderColor = isDark
        ? const Color(0xFF2F3336)
        : const Color(0xFFCFD9DE);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        surfaceTintColor: Colors.transparent,
        foregroundColor: textColor,
        iconTheme: IconThemeData(color: textColor),
        title: Text(
          AppLocalizations.of(context)!.planetCreateTitle,
          style: TextStyle(fontWeight: FontWeight.bold, color: textColor),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            HapticFeedback.lightImpact();
            context.go(AppRoutes.dobInput);
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              HapticFeedback.lightImpact();
              notifier.signOut();
            },
          ),
        ],
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SafeArea(
          child: SingleChildScrollView(
            controller: _scrollController,
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   _buildAnimatedMember(
                    interval: const Interval(0.1, 0.6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppLocalizations.of(context)!.planetDesignTitle,
                          style: TextStyle(
                            color: textColor,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          AppLocalizations.of(context)!.planetDesignDesc,
                          style: TextStyle(color: textSecondary, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                   _buildAnimatedMember(
                    interval: const Interval(0.2, 0.7),
                    child: Center(
                      child: GestureDetector(
                        onTap: () async {
                          HapticFeedback.lightImpact();
                          final file = await ref
                              .read(imageUploadServiceProvider)
                              .pickImage(source: ImageSource.gallery);
                          if (file != null) {
                            HapticFeedback.mediumImpact();
                            setState(() => _avatarFile = file);
                          }
                        },
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.transparent,
                            border: Border.all(color: primaryColor, width: 2),
                          ),
                          child: _avatarFile != null
                              ? ClipOval(
                                  child: XparqImage(
                                    imageUrl: _avatarFile!.path,
                                    width: 80,
                                    height: 80,
                                    fit: BoxFit.cover,
                                  ),
                                )
                              : Icon(
                                  Icons.add_a_photo,
                                  color: primaryColor,
                                  size: 28,
                                ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                   _buildAnimatedMember(
                    interval: const Interval(0.3, 0.8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLabel(
                          AppLocalizations.of(context)!.iXparqNameLabel,
                          textSecondary,
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _nameController,
                          style: TextStyle(color: textColor),
                          maxLength: 24,
                          keyboardType: TextInputType.visiblePassword,
                          validator: (v) {
                            if (v == null || v.trim().length < 3) {
                              return AppLocalizations.of(
                                context,
                              )!.iXparqNameErrorLen;
                            }
                            if (v.trim().length > 24) {
                              return AppLocalizations.of(
                                context,
                              )!.iXparqNameErrorMax;
                            }
                            return null;
                          },
                          decoration:
                              _inputDecoration(
                                AppLocalizations.of(context)!.iXparqNameHint,
                                borderColor,
                                primaryColor,
                                textSecondary,
                                isDark,
                              ).copyWith(
                                suffix:
                                    ValueListenableBuilder<TextEditingValue>(
                                      valueListenable: _nameController,
                                      builder: (context, value, _) {
                                        final handle = value.text
                                            .trim()
                                            .toLowerCase()
                                            .replaceAll(RegExp(r'\s+'), '');
                                        if (handle.isEmpty) {
                                          return const SizedBox.shrink();
                                        }
                                        return Text(
                                          '@$handle',
                                          style: TextStyle(
                                            color: primaryColor.withValues(alpha: 0.8),
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        );
                                      },
                                    ),
                              ),
                        ),
                        const SizedBox(height: 16),
                        _buildLabel(
                          AppLocalizations.of(context)!.bioLabel,
                          textSecondary,
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _bioController,
                          style: TextStyle(color: textColor),
                          keyboardType: TextInputType.visiblePassword,
                          maxLength: 160,
                          maxLines: 3,
                          decoration: _inputDecoration(
                            AppLocalizations.of(context)!.bioHint,
                            borderColor,
                            primaryColor,
                            textSecondary,
                            isDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                   _buildAnimatedMember(
                    interval: const Interval(0.4, 0.9),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLabel(
                          AppLocalizations.of(context)!.stellarIdentityLabel,
                          textSecondary,
                        ),
                        const SizedBox(height: 12),
                        _buildIdentityDashboard(
                          context,
                          primaryColor,
                          textColor,
                          isDark,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                   _buildAnimatedMember(
                    interval: const Interval(0.5, 1.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLabel(
                          AppLocalizations.of(context)!.constellationsLabel,
                          textSecondary,
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: _getAvailableConstellations(context).map((
                            tag,
                          ) {
                            final selected = _selectedConstellations.contains(
                              tag,
                            );
                            return FilterChip(
                              label: Text(
                                tag,
                                style: TextStyle(
                                  color: selected ? Colors.white : textColor,
                                  fontSize: 12,
                                ),
                              ),
                              selected: selected,
                              onSelected: (val) {
                                HapticFeedback.lightImpact();
                                setState(() {
                                  if (val &&
                                      _selectedConstellations.length < 5) {
                                    _selectedConstellations.add(tag);
                                  } else {
                                    _selectedConstellations.remove(tag);
                                  }
                                });
                              },
                              selectedColor: primaryColor,
                              backgroundColor: Colors.transparent,
                              checkmarkColor: Colors.white,
                              shape: StadiumBorder(
                                side: BorderSide(
                                  color: selected ? primaryColor : borderColor,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (authState.errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                         _getLocalizedError(context, authState.errorMessage!),
                        style: const TextStyle(color: Color(0xFFFF6B6B)),
                      ),
                    ),
                   _buildAnimatedMember(
                    interval: const Interval(0.6, 1.0),
                    child: GalaxyButton(
                      isLoading: authState.isLoading || _isUploading,
                      onTap: () async {
                        if (!_formKey.currentState!.validate()) {
                          _scrollController.animateTo(
                            0,
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOut,
                          );
                          return;
                        }
                        final dob = widget.dob;
                        if (dob == null) {
                          context.go(AppRoutes.dobInput);
                          return;
                        }
                        setState(() => _isUploading = true);
                        String photoUrl = '';
                        try {
                          if (_avatarFile != null) {
                            final user = ref
                                .read(authRepositoryProvider)
                                .currentUser;
                            photoUrl = await ref
                                .read(imageUploadServiceProvider)
                                .uploadProfileImage(
                                  file: _avatarFile!,
                                  uid:
                                      user?.id ??
                                      'temp_${DateTime.now().millisecondsSinceEpoch}',
                                );
                          }
                          await notifier.createProfile(
                            xparqName: _nameController.text.trim(),
                            bio: _bioController.text.trim(),
                            mbti: _selectedMbti,
                            enneagram: _selectedEnneagram,
                            zodiac: _selectedZodiac,
                            bloodType: _selectedBloodType,
                            photoUrl: photoUrl,
                            dob: dob,
                            constellations: _selectedConstellations,
                          );
                        } catch (e) {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error: ${e.toString()}'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        } finally {
                          if (mounted) setState(() => _isUploading = false);
                        }
                      },
                      label: AppLocalizations.of(context)!.launchPlanetBtn,
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedMember({
    required Interval interval,
    required Widget child,
  }) {
    return FadeTransition(
      opacity: CurvedAnimation(parent: _animationController, curve: interval),
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 0.04), end: Offset.zero)
            .animate(
              CurvedAnimation(parent: _animationController, curve: interval),
            ),
        child: child,
      ),
    );
  }

  Widget _buildLabel(String text, Color color) => Text(
    text,
    style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w600),
  );

  InputDecoration _inputDecoration(
    String hint,
    Color border,
    Color focus,
    Color secondary,
    bool isDark,
  ) => InputDecoration(
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    hintText: hint,
    hintStyle: TextStyle(color: secondary, fontSize: 13),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: focus, width: 2),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: const Color(0xFFF91880)),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: const Color(0xFFF91880), width: 2),
    ),
    fillColor: isDark
        ? Colors.white.withValues(alpha: 0.02)
        : Colors.black.withValues(alpha: 0.01),
    filled: true,
  );

  Widget _buildIdentityDashboard(
    BuildContext context,
    Color primaryColor,
    Color textColor,
    bool isDark,
  ) {
    final l10n = AppLocalizations.of(context)!;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      child: Row(
        children: [
          _buildCompactIdentityTile(
            context: context,
            label: l10n.labelMbti,
            value: _selectedMbti,
            icon: _selectedMbti != null
                ? StellarIdentityHelper.getIconForMbti(_selectedMbti)
                : '🧠',
            onTap: () => _showIdentityPicker(
              context,
              l10n.labelMbti,
              _getMbtiTypes(context),
              (val) => setState(() => _selectedMbti = val),
              _selectedMbti,
            ),
            primaryColor: primaryColor,
            textColor: textColor,
            isDark: isDark,
          ),
          const SizedBox(width: 8),
          _buildCompactIdentityTile(
            context: context,
            label: l10n.labelEnneagram,
            value: _selectedEnneagram != null
                ? _getEnneagramTypes(
                    context,
                  ).firstWhere((m) => m['type'] == _selectedEnneagram)['name']
                : null,
            icon: _selectedEnneagram != null
                ? _getEnneagramTypes(
                    context,
                  ).firstWhere((m) => m['type'] == _selectedEnneagram)['icon']!
                : '💎',
            onTap: () => _showIdentityPicker(
              context,
              l10n.labelEnneagram,
              _getEnneagramTypes(context),
              (val) => setState(() => _selectedEnneagram = val),
              _selectedEnneagram,
              crossAxisCount: 3,
              isSimple: false,
            ),
            primaryColor: primaryColor,
            textColor: textColor,
            isDark: isDark,
          ),
          const SizedBox(width: 8),
          _buildCompactIdentityTile(
            context: context,
            label: l10n.labelZodiac,
            value: _selectedZodiac != null
                ? _getZodiacTypes(
                    context,
                  ).firstWhere((m) => m['type'] == _selectedZodiac)['name']
                : null,
            icon: _selectedZodiac != null
                ? _getZodiacTypes(
                    context,
                  ).firstWhere((m) => m['type'] == _selectedZodiac)['icon']!
                : '✨',
            onTap: () => _showIdentityPicker(
              context,
              l10n.labelZodiac,
              _getZodiacTypes(context),
              (val) => setState(() => _selectedZodiac = val),
              _selectedZodiac,
            ),
            primaryColor: primaryColor,
            textColor: textColor,
            isDark: isDark,
          ),
          const SizedBox(width: 8),
          _buildCompactIdentityTile(
            context: context,
            label: l10n.labelBloodType,
            value: _selectedBloodType != null
                ? _getBloodTypes(
                    context,
                  ).firstWhere((m) => m['type'] == _selectedBloodType)['name']
                : null,
            icon: _selectedBloodType != null
                ? _getBloodTypes(
                    context,
                  ).firstWhere((m) => m['type'] == _selectedBloodType)['icon']!
                : '🩸',
            onTap: () => _showIdentityPicker(
              context,
              l10n.labelBloodType,
              _getBloodTypes(context),
              (val) => setState(() => _selectedBloodType = val),
              _selectedBloodType,
              crossAxisCount: 2,
            ),
            primaryColor: primaryColor,
            textColor: textColor,
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildCompactIdentityTile({
    required BuildContext context,
    required String label,
    required String? value,
    required String icon,
    required VoidCallback onTap,
    required Color primaryColor,
    required Color textColor,
    required bool isDark,
  }) {
    final hasValue = value != null;
    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: hasValue
              ? primaryColor.withValues(alpha: 0.12)
              : primaryColor.withValues(alpha: isDark ? 0.05 : 0.03),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: hasValue
                ? primaryColor.withValues(alpha: 0.5)
                : textColor.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(icon, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 6),
            Text(
              value ?? label,
              style: TextStyle(
                color: hasValue ? textColor : textColor.withValues(alpha: 0.5),
                fontSize: 12,
                fontWeight: hasValue ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showIdentityPicker(
    BuildContext context,
    String title,
    List<Map<String, String>> items,
    Function(String) onSelect,
    String? currentValue, {
    int crossAxisCount = 4,
    bool isSimple = true,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF16181C) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    final primaryColor = const Color(0xFF1D9BF0);

    showModalBottomSheet(
      context: context,
      backgroundColor: bgColor,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          maxChildSize: 0.9,
          minChildSize: 0.4,
          expand: false,
          builder: (context, scrollController) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 12),
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: textColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        AppLocalizations.of(
                          context,
                        )!.selectIdentityTitle(title),
                        style: TextStyle(
                          color: textColor,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                        color: textColor.withValues(alpha: 0.5),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: GridView.builder(
                      controller: scrollController,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: isSimple ? 0.9 : 0.85,
                      ),
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final item = items[index];
                        final type = item['type']!;
                        final name = item['name'];
                        final icon = item['icon']!;
                        final isSelected = currentValue == type;

                        return GestureDetector(
                          onTap: () {
                            HapticFeedback.mediumImpact();
                            onSelect(type);
                            Navigator.pop(context);
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? primaryColor.withValues(alpha: 0.15)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected
                                    ? primaryColor
                                    : textColor.withValues(alpha: 0.1),
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  icon,
                                  style: const TextStyle(fontSize: 24),
                                ),
                                const SizedBox(height: 4),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                  ),
                                  child: Text(
                                    name != null ? '$type\n$name' : type,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: textColor,
                                      fontSize: 10,
                                      fontWeight: isSelected
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  String _getLocalizedError(BuildContext context, String error) {
    final l10n = AppLocalizations.of(context)!;
    switch (error) {
      case 'authErrorInvalidCredentials':
        return l10n.authErrorInvalidCredentials;
      case 'authErrorEmailInUse':
        return l10n.authErrorEmailInUse;
      case 'authErrorWeakPassword':
        return l10n.authErrorWeakPassword;
      case 'authErrorTooManyRequests':
        return l10n.authErrorTooManyRequests;
      case 'authErrorNetwork':
        return l10n.authErrorNetwork;
      case 'authErrorInvalidEmail':
        return l10n.authErrorInvalidEmail;
      case 'authErrorNameTaken':
        return l10n.authErrorNameTaken;
      case 'USER_EXISTS':
        return l10n.authErrorNameTaken;
      default:
        // If the error message doesn't look like a localization key (e.g., contains spaces),
        // show it directly to help with debugging.
        if (error.contains(' ') || error.contains('(')) return error;
        return l10n.authErrorGeneric;
    }
  }
}

