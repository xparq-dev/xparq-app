// lib/features/auth/screens/onboarding/welcome_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:xparq_app/shared/router/app_router.dart';
import 'package:xparq_app/shared/providers/locale_provider.dart';
import 'package:xparq_app/shared/theme/theme_provider.dart';
import 'package:xparq_app/l10n/app_localizations.dart';
import 'package:xparq_app/shared/widgets/branding/xparq_logo.dart';
import 'package:xparq_app/shared/constants/language_data.dart';
import 'package:xparq_app/shared/widgets/ui/buttons/galaxy_button.dart';
import 'package:xparq_app/shared/widgets/common/typing_text.dart';
import 'package:xparq_app/features/auth/providers/auth_providers.dart';
import 'package:xparq_app/features/auth/models/quick_account.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:xparq_app/shared/widgets/backgrounds/galactic_background.dart';

class WelcomeScreen extends ConsumerStatefulWidget {
  const WelcomeScreen({super.key});

  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<WelcomeScreen>
    with SingleTickerProviderStateMixin {
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
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (l10n == null) return const Scaffold(backgroundColor: Color(0xFF0F1419));

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final labelColor = isDark
        ? Colors.white54
        : const Color(0xFF0D1B2A).withValues(alpha: 0.5);

    // Listen for auth success to navigate home
    ref.listen(authNotifierProvider, (previous, next) {
      final l10n = AppLocalizations.of(context);
      if (next.step == AuthStep.complete) {
        context.go(AppRoutes.radar);
      } else if (next.errorMessage != null && l10n != null) {
        // Map the key to localized string
        String message = next.errorMessage!;
        final map = {
          'authErrorInvalidPhone': l10n.authErrorInvalidPhone,
          'authErrorInvalidOtp': l10n.authErrorInvalidOtp,
          'authErrorEmailInUse': l10n.authErrorEmailInUse,
          'authErrorWeakPassword': l10n.authErrorWeakPassword,
          'authErrorInvalidCredentials': l10n.authErrorInvalidCredentials,
          'authErrorTooManyRequests': l10n.authErrorTooManyRequests,
          'authErrorGeneric': l10n.authErrorGeneric,
          'authErrorNameTaken': l10n.authErrorNameTaken,
          'authErrorNetwork': l10n.authErrorNetwork,
          'authErrorInvalidEmail': l10n.authErrorInvalidEmail,
        };

        if (map.containsKey(message)) {
          message = map[message]!;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
        );
      }
    });

    return GalacticBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Stack(
            children: [
              // Main Content
              LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 40),
                        child: IntrinsicHeight(
                          child: Column(
                            children: [
                              const Spacer(flex: 2),
                              const XparqLogo(size: 80),
                              const SizedBox(height: 12),
                              TypingText(
                                text: 'XPARQ',
                                typingSpeed: const Duration(milliseconds: 150),
                                style: TextStyle(
                                  fontSize: 44,
                                  fontWeight: FontWeight.w900,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurface,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                l10n.welcomeSubtitle,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Theme.of(context).colorScheme.onSurface
                                      .withValues(alpha: 0.6),
                                ),
                              ),
                              const Spacer(flex: 3),
                              _QuickAccountList(),
                              const Spacer(flex: 1),
                              Row(
                                children: [
                                  Expanded(
                                    child: GalaxyButton(
                                      label: l10n.signUpBtn,
                                      onTap: () {
                                        HapticFeedback.lightImpact();
                                        _showAuthMethodPicker(
                                          context,
                                          isLogin: false,
                                        );
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: GalaxyButton(
                                      label: l10n.loginBtn,
                                      isPrimary: false,
                                      onTap: () {
                                        HapticFeedback.lightImpact();
                                        _showAuthMethodPicker(
                                          context,
                                          isLogin: true,
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 24),
                              TextButton.icon(
                                onPressed: () {
                                  HapticFeedback.lightImpact();
                                  context.push(AppRoutes.offlinePermission);
                                },
                                icon: Icon(
                                  Icons.satellite_alt_rounded,
                                  size: 16,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.primary.withValues(alpha: 0.7),
                                ),
                                label: Text(
                                  l10n.enterGuest,
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.primary
                                        .withValues(alpha: 0.7),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const Spacer(),
                              Padding(
                                padding: const EdgeInsets.only(bottom: 24),
                                child: Text(
                                  l10n.termsPolicy,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: isDark
                                        ? Colors.white24
                                        : Colors.black26,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),

              // â”€â”€ Controls Overlay (Drawn on top) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
              // Language Selector (Top Left)
              Positioned(
                top: 8,
                left: 8,
                child: TextButton(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    _showLanguagePicker(context);
                  },
                  style: TextButton.styleFrom(
                    minimumSize: Size.zero,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 1000),
                        curve: Curves.easeInOut,
                        style: TextStyle(
                          color: labelColor,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                        child: Text(_getCurrentLanguageLabel(context)),
                      ),
                      Icon(
                        Icons.keyboard_arrow_down,
                        size: 14,
                        color: labelColor,
                      ),
                    ],
                  ),
                ),
              ),
              const Positioned(top: 4, right: 4, child: _ThemeToggleButton()),
            ],
          ),
        ),
      ),
    );
  }

  String _getCurrentLanguageLabel(BuildContext context) {
    final locale = Localizations.localeOf(context);
    final currentLang = allLanguages.firstWhere(
      (l) => l.code == locale.languageCode,
      orElse: () => allLanguages.first,
    );
    return currentLang.localName.toUpperCase();
  }

  void _showLanguagePicker(BuildContext context) {
    final sortedLanguages = getSortedLanguages();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF16181C) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  AppLocalizations.of(context)!.languagePickerTitle,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.builder(
                  itemCount: sortedLanguages.length,
                  itemBuilder: (context, index) {
                    final lang = sortedLanguages[index];
                    final isSelected =
                        Localizations.localeOf(context).languageCode ==
                        lang.code;

                    return ListTile(
                      title: Text(
                        lang.localName,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                      trailing: isSelected
                          ? const Icon(Icons.check, color: Color(0xFF1D9BF0))
                          : null,
                      onTap: () {
                        HapticFeedback.mediumImpact();
                        ref
                            .read(localeProvider.notifier)
                            .setLocale(Locale(lang.code));
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showAuthMethodPicker(BuildContext context, {required bool isLogin}) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF16181C) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Drag Handle
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Text(
                  isLogin ? l10n.signInTitle : l10n.createAccount,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.selectAuthMethodTitle,
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.white54 : Colors.black54,
                  ),
                ),
                const SizedBox(height: 32),

                // Phone Option
                _buildAuthOption(
                  context: context,
                  icon: Icons.phone_android_rounded,
                  label: l10n.authMethodPhone,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.pop(context);
                    if (isLogin) {
                      ref.read(isLoginFlowProvider.notifier).state = true;
                    }
                    ref.read(authNotifierProvider.notifier).resetAuthState();
                    context.push(AppRoutes.phoneAuth, extra: isLogin);
                  },
                ),
                const SizedBox(height: 16),

                // Email Option
                _buildAuthOption(
                  context: context,
                  icon: Icons.email_outlined,
                  label: l10n.authMethodEmail,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.pop(context);
                    if (isLogin) {
                      ref.read(isLoginFlowProvider.notifier).state = true;
                    }
                    ref.read(authNotifierProvider.notifier).resetAuthState();
                    context.push(AppRoutes.emailAuth, extra: isLogin);
                  },
                ),
                const SizedBox(height: 16),

                // Other Option (Disabled/Placeholder)
                _buildAuthOption(
                  context: context,
                  icon: Icons.more_horiz_rounded,
                  label: l10n.authMethodOther,
                  isPlaceholder: true,
                  onTap: () {
                    HapticFeedback.lightImpact();
                  },
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAuthOption({
    required BuildContext context,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isPlaceholder = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: isPlaceholder ? null : onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: isPlaceholder
              ? (isDark
                    ? Colors.white.withValues(alpha: 0.02)
                    : Colors.black.withValues(alpha: 0.02))
              : (isDark ? const Color(0xFF0D1B2A) : Colors.blueGrey.shade50),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isPlaceholder
                ? (isDark ? Colors.white12 : Colors.black12)
                : (isDark ? const Color(0xFF1E3A5F) : Colors.blue.shade100),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isPlaceholder
                  ? (isDark ? Colors.white30 : Colors.black38)
                  : const Color(0xFF4FC3F7),
              size: 24,
            ),
            const SizedBox(width: 16),
            Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: isPlaceholder ? FontWeight.normal : FontWeight.w600,
                color: isPlaceholder
                    ? (isDark ? Colors.white30 : Colors.black38)
                    : (isDark ? Colors.white : Colors.black87),
              ),
            ),
            const Spacer(),
            if (!isPlaceholder)
              Icon(
                Icons.chevron_right_rounded,
                color: isDark ? Colors.white24 : Colors.black26,
              ),
          ],
        ),
      ),
    );
  }
}

// â”€â”€ Animated Theme Toggle Button â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _ThemeToggleButton extends ConsumerStatefulWidget {
  const _ThemeToggleButton();

  @override
  ConsumerState<_ThemeToggleButton> createState() => _ThemeToggleButtonState();
}

class _ThemeToggleButtonState extends ConsumerState<_ThemeToggleButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;
  late Animation<double> _rotate;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 480),
    );

    // Scale: pop out (1â†’0) then bounce back in (0â†’1)
    _scale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(
          begin: 1.0,
          end: 0.0,
        ).chain(CurveTween(curve: Curves.easeIn)),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: 0.0,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.elasticOut)),
        weight: 60,
      ),
    ]).animate(_ctrl);

    // Rotate half turn while switching
    _rotate = Tween<double>(
      begin: 0,
      end: 3.14159,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ref.watch(themeProvider) == ThemeMode.dark;
    final iconColor = isDark
        ? Colors.white54
        : const Color(0xFF0D1B2A).withValues(alpha: 0.5);

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        _ctrl.forward(from: 0);
        ref.read(themeProvider.notifier).toggleTheme();
      },
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (__, _) => Transform.scale(
            scale: _scale.value,
            child: Transform.rotate(
              angle: _rotate.value,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  isDark ? Icons.wb_sunny_outlined : Icons.nightlight_round,
                  key: ValueKey(isDark),
                  color: iconColor,
                  size: 22,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// â”€â”€ Quick Account List Widget â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _QuickAccountList extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accounts = ref.watch(quickAccountsProvider);

    if (accounts.isEmpty) return const SizedBox.shrink();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 100,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            shrinkWrap: true,
            padding: const EdgeInsets.symmetric(horizontal: 0),
            itemCount: accounts.length,
            separatorBuilder: (__, _) => const SizedBox(width: 20),
            itemBuilder: (context, index) {
              final account = accounts[index];
              return GestureDetector(
                onTap: () => _showPasswordBottomSheet(context, ref, account),
                child: Column(
                   mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Theme.of(
                            context,
                          ).colorScheme.primary.withValues(alpha: 0.5),
                          width: 2,
                        ),
                      ),
                      child: CircleAvatar(
                        radius: 30,
                        backgroundColor: Colors.blueGrey.shade900,
                        backgroundImage: account.photoUrl.isNotEmpty
                            ? CachedNetworkImageProvider(account.photoUrl)
                            : null,
                        child: account.photoUrl.isEmpty
                            ? const Icon(
                                Icons.person,
                                size: 30,
                                color: Colors.white54,
                              )
                            : null,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      account.xparqName,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _showPasswordBottomSheet(
    BuildContext context,
    WidgetRef ref,
    QuickAccount account,
  ) {
    final TextEditingController passwordController = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF16181C) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Drag Handle
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Text(
                  'Quick Login: ${account.xparqName}',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Enter your account password',
                  style: TextStyle(
                    color: isDark ? Colors.white54 : Colors.black54,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 32),
                TextField(
                  controller: passwordController,
                  autofocus: true,
                  obscureText: true,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Password',
                    hintStyle: TextStyle(
                      color: isDark ? Colors.white24 : Colors.black26,
                    ),
                    filled: true,
                    fillColor: isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : Colors.black.withValues(alpha: 0.05),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                  ),
                  onSubmitted: (val) {
                    if (val.isNotEmpty) {
                      Navigator.pop(context);
                      ref
                          .read(authNotifierProvider.notifier)
                          .quickLogin(account.uid, account.email, val);
                    }
                  },
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () {
                      final val = passwordController.text;
                      if (val.isNotEmpty) {
                        Navigator.pop(context);
                        ref
                            .read(authNotifierProvider.notifier)
                            .quickLogin(account.uid, account.email, val);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      'Login',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () async {
                    HapticFeedback.mediumImpact();
                    final service = await ref.read(
                      quickAuthServiceProvider.future,
                    );
                    await service.removeQuickAccount(account.uid);
                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Account removed')),
                      );
                    }
                  },
                  child: Text(
                    'Remove from Quick Login',
                    style: TextStyle(
                      color: isDark ? Colors.white38 : Colors.black38,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

