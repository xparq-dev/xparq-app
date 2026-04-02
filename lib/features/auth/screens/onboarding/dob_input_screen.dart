// lib/features/auth/screens/onboarding/dob_input_screen.dart
//
// DOB input screen with DatePicker and age validation.
// Shown after successful OTP/email verification.
// Minimum age: 13 years. Blocks registration if < 13.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:intl/intl.dart';
import 'package:xparq_app/core/router/app_router.dart';
import 'package:xparq_app/core/enums/age_group.dart';
import 'package:xparq_app/core/widgets/galaxy_button.dart';
import 'package:xparq_app/features/auth/services/age_gating_service.dart';
import 'package:xparq_app/features/auth/providers/auth_providers.dart';
import 'package:xparq_app/l10n/app_localizations.dart';

class DobInputScreen extends ConsumerStatefulWidget {
  const DobInputScreen({super.key});

  @override
  ConsumerState<DobInputScreen> createState() => _DobInputScreenState();
}

class _DobInputScreenState extends ConsumerState<DobInputScreen>
    with SingleTickerProviderStateMixin {
  DateTime? _selectedDob;
  String? _dobError;
  AgeGroup? _previewAgeGroup;
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    FlutterNativeSplash.remove();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _onDobSelected(DateTime dob) {
    final error = AgeGatingService.validateDob(dob);
    final group = error == null
        ? AgeGatingService.calculateAgeGroup(dob)
        : null;
    setState(() {
      _selectedDob = dob;
      _dobError = error;
      _previewAgeGroup = group;
    });
  }

  Future<void> _pickDate() async {
    HapticFeedback.lightImpact();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDob ?? AgeGatingService.maxDobDate,
      firstDate: AgeGatingService.minDobDate,
      lastDate: AgeGatingService.maxDobDate,
      helpText: AppLocalizations.of(context)!.dobPickerHelp,
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF4FC3F7),
              onPrimary: Colors.black,
              surface: Color(0xFF0D1B2A),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      HapticFeedback.mediumImpact();
      _onDobSelected(picked);
    }
  }

  void _continue() {
    final error = AgeGatingService.validateDob(_selectedDob);
    if (error != null) {
      setState(() => _dobError = error);
      return;
    }
    final dobStr = _selectedDob!.toIso8601String().split('T')[0];
    context.go('${AppRoutes.planetCreateBase}/$dobStr');
  }

  @override
  Widget build(BuildContext context) {
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
          AppLocalizations.of(context)!.dobScreenTitle,
          style: TextStyle(fontWeight: FontWeight.bold, color: textColor),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            HapticFeedback.lightImpact();
            final authState = ref.read(authNotifierProvider);
            final method = authState.authMethod;
            ref.read(authNotifierProvider.notifier).signOut();
            if (method == 'email') {
              context.go(AppRoutes.emailAuth);
            } else {
              context.go(AppRoutes.phoneAuth);
            }
          },
        ),
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildAnimatedMember(
                  interval: const Interval(0.1, 0.7),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppLocalizations.of(context)!.dobQuestion,
                        style: TextStyle(
                          color: textColor,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        AppLocalizations.of(context)!.dobSafetyDesc,
                        style: TextStyle(color: textSecondary, height: 1.5),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
                _buildAnimatedMember(
                  interval: const Interval(0.2, 0.8),
                  child: GestureDetector(
                    onTap: _pickDate,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 18,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(
                          999,
                        ), // Consistent pill shape
                        border: Border.all(
                          color: _dobError != null
                              ? const Color(0xFFF91880)
                              : borderColor,
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.calendar_today,
                            color: Color(0xFF1D9BF0),
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            _selectedDob != null
                                ? DateFormat(
                                    'dd MMMM yyyy',
                                  ).format(_selectedDob!)
                                : AppLocalizations.of(context)!.dobSelectHint,
                            style: TextStyle(
                              color: _selectedDob != null
                                  ? textColor
                                  : textSecondary,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (_dobError != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _dobError!,
                    style: const TextStyle(
                      color: Color(0xFFF91880),
                      fontSize: 13,
                    ),
                  ),
                ],
                if (_previewAgeGroup != null && _dobError == null) ...[
                  const SizedBox(height: 20),
                  _buildAnimatedMember(
                    interval: const Interval(0.4, 0.9),
                    child: _AgeGroupBadge(ageGroup: _previewAgeGroup!),
                  ),
                ],
                const Spacer(),
                _buildAnimatedMember(
                  interval: const Interval(0.3, 1.0),
                  child: GalaxyButton(
                    onTap: (_selectedDob != null && _dobError == null)
                        ? _continue
                        : null,
                    label: AppLocalizations.of(context)!.dobContinueBtn,
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: Text(
                    AppLocalizations.of(context)!.dobEncryptedNote,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: textSecondary, fontSize: 12),
                  ),
                ),
              ],
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
        position: Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero)
            .animate(
              CurvedAnimation(parent: _animationController, curve: interval),
            ),
        child: child,
      ),
    );
  }
}

class _AgeGroupBadge extends StatelessWidget {
  final AgeGroup ageGroup;
  const _AgeGroupBadge({required this.ageGroup});

  @override
  Widget build(BuildContext context) {
    final isCadet = ageGroup == AgeGroup.cadet;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isCadet ? const Color(0xFF1A2A1A) : const Color(0xFF1A1A2A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCadet ? const Color(0xFF4CAF50) : const Color(0xFF7C4DFF),
        ),
      ),
      child: Row(
        children: [
          Text(isCadet ? '🛡️' : '🌌', style: const TextStyle(fontSize: 24)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isCadet
                      ? AppLocalizations.of(context)!.galacticCadet
                      : AppLocalizations.of(context)!.interstellarExplorer,
                  style: TextStyle(
                    color: isCadet
                        ? const Color(0xFF4CAF50)
                        : const Color(0xFF7C4DFF),
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                Text(
                  isCadet
                      ? AppLocalizations.of(context)!.galacticCadetDesc
                      : AppLocalizations.of(context)!.interstellarExplorerDesc,
                  style: TextStyle(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withOpacity(0.54),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
