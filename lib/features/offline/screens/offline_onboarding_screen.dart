import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/offline_user_provider.dart';
import '../providers/offline_state_provider.dart';
import '../services/nearby_service.dart';

import 'package:xparq_app/core/widgets/xparq_logo.dart';
import 'package:xparq_app/core/widgets/galaxy_button.dart';
import 'package:xparq_app/core/widgets/galaxy_text_field.dart';
import '../../../../l10n/app_localizations.dart';

class OfflineOnboardingScreen extends ConsumerStatefulWidget {
  const OfflineOnboardingScreen({super.key});

  @override
  ConsumerState<OfflineOnboardingScreen> createState() =>
      _OfflineOnboardingScreenState();
}

class _OfflineOnboardingScreenState
    extends ConsumerState<OfflineOnboardingScreen>
    with SingleTickerProviderStateMixin {
  final _nameController = TextEditingController();
  bool _isAnonymous = false;
  bool _isSaving = false;
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _handleContinue() async {
    final name = _nameController.text.trim();
    if (name.isEmpty && !_isAnonymous) {
      HapticFeedback.vibrate();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.offlineEnterName)),
      );
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() => _isSaving = true);

    final finalName = _isAnonymous
        ? AppLocalizations.of(context)!.offlineStayAnonymous
        : name;
    await ref.read(offlineUserProvider.notifier).updateDisplayName(finalName);
    await ref.read(offlineUserProvider.notifier).toggleAnonymous(_isAnonymous);

    if (mounted) {
      context.go('/offline/dashboard/radar');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark
        ? const Color(0xFFE7E9EA)
        : const Color(0xFF0F1419);
    final textSecondary = isDark
        ? const Color(0xFF71767B)
        : const Color(0xFF536471);
    final primaryColor = const Color(0xFF1D9BF0);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight:
                  MediaQuery.of(context).size.height -
                  MediaQuery.of(context).padding.top -
                  MediaQuery.of(context).padding.bottom,
            ),
            child: IntrinsicHeight(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Spacer(flex: 2),

                    // Logo & Branding Section
                    _buildAnimatedMember(
                      interval: const Interval(
                        0.1,
                        0.7,
                        curve: Curves.easeOutCubic,
                      ),
                      child: Column(
                        children: [
                          const XparqLogo(size: 80),
                          const SizedBox(height: 24),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: primaryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: primaryColor.withOpacity(0.2),
                              ),
                            ),
                            child: Text(
                              AppLocalizations.of(
                                context,
                              )!.offlineOnboardingTitle,
                              style: TextStyle(
                                color: primaryColor,
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            AppLocalizations.of(
                              context,
                            )!.offlineStellarIdentity,
                            style: TextStyle(
                              color: textColor,
                              fontSize: 32,
                              fontWeight: FontWeight.w900,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            AppLocalizations.of(context)!.offlineOnboardingDesc,
                            style: TextStyle(
                              color: textSecondary,
                              fontSize: 14,
                              height: 1.4,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),

                    const Spacer(flex: 3),

                    // Input Section
                    _buildAnimatedMember(
                      interval: const Interval(
                        0.3,
                        0.9,
                        curve: Curves.easeOutCubic,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          GalaxyTextField(
                            controller: _nameController,
                            enabled: !_isAnonymous,
                            label: AppLocalizations.of(
                              context,
                            )!.offlineDisplayNameLabel,
                          ),
                          const SizedBox(height: 24),

                          // Anonymous Toggle
                          InkWell(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              setState(() => _isAnonymous = !_isAnonymous);
                            },
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.surface,
                                border: Border.all(
                                  color: Theme.of(context).dividerColor,
                                ),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    _isAnonymous
                                        ? Icons.visibility_off_rounded
                                        : Icons.visibility_rounded,
                                    color: _isAnonymous
                                        ? Theme.of(context).colorScheme.primary
                                        : Theme.of(context)
                                              .colorScheme
                                              .onSurface
                                              .withOpacity(0.5),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          AppLocalizations.of(
                                            context,
                                          )!.offlineStayAnonymous,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Text(
                                          AppLocalizations.of(
                                            context,
                                          )!.offlineStayAnonymousDesc,
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurface
                                                .withOpacity(0.5),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Switch.adaptive(
                                    value: _isAnonymous,
                                    onChanged: (val) {
                                      HapticFeedback.selectionClick();
                                      setState(() => _isAnonymous = val);
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const Spacer(flex: 4),

                    // Action Button
                    _buildAnimatedMember(
                      interval: const Interval(
                        0.5,
                        1.0,
                        curve: Curves.easeOutCubic,
                      ),
                      child: Column(
                        children: [
                          GalaxyButton(
                            label: AppLocalizations.of(
                              context,
                            )!.offlineLaunchIdentity,
                            isLoading: _isSaving,
                            onTap: _handleContinue,
                          ),
                          const SizedBox(height: 12),
                          TextButton(
                            onPressed: () async {
                              HapticFeedback.mediumImpact();
                              await NearbyService.instance.resetAll();
                              ref.read(isOfflineModeProvider.notifier).state =
                                  false;
                              if (mounted) {
                                context.go('/');
                              }
                            },
                            child: Text(
                              AppLocalizations.of(context)!.offlineBackToOnline,
                              style: TextStyle(
                                color: textSecondary,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(height: 32),
                        ],
                      ),
                    ),
                  ],
                ),
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
        position: Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero)
            .animate(
              CurvedAnimation(parent: _animationController, curve: interval),
            ),
        child: child,
      ),
    );
  }
}
