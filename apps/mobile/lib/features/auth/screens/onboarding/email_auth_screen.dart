// lib/features/auth/screens/onboarding/email_auth_screen.dart
//
// Step 1: Phone number input + OTP verification.
// Step 2: DOB input with age validation.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:xparq_app/features/auth/providers/auth_providers.dart';
import 'package:xparq_app/shared/router/app_router.dart';
import 'package:xparq_app/shared/widgets/ui/inputs/galaxy_text_field.dart';
import 'package:xparq_app/shared/widgets/ui/buttons/galaxy_button.dart';
import 'package:xparq_app/l10n/app_localizations.dart';
import 'package:xparq_app/features/auth/widgets/galaxy_error_banner.dart';

class PhoneAuthScreen extends ConsumerStatefulWidget {
  final bool isLogin;
  const PhoneAuthScreen({super.key, this.isLogin = true});

  @override
  ConsumerState<PhoneAuthScreen> createState() => _PhoneAuthScreenState();
}

class _PhoneAuthScreenState extends ConsumerState<PhoneAuthScreen>
    with SingleTickerProviderStateMixin {
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..forward();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final notifier = ref.read(authNotifierProvider.notifier);

    // Navigate to DOB screen after OTP verified
    ref.listen(authNotifierProvider, (prev, next) {
      if (next.step == AuthStep.otpVerified) {
        context.go(AppRoutes.dobInput);
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

    if (authState.step == AuthStep.complete) {
      return Scaffold(
        backgroundColor: bgColor,
        body: const Center(
          child: CircularProgressIndicator(color: Color(0xFF1D9BF0)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: bgColor,
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        backgroundColor: bgColor,
        surfaceTintColor: Colors.transparent,
        foregroundColor: textColor,
        iconTheme: IconThemeData(color: textColor),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            HapticFeedback.lightImpact();
            if (authState.step == AuthStep.otpSent) {
              notifier.signOut();
            } else {
              context.pop();
            }
          },
        ),
        title: Text(
          widget.isLogin
              ? AppLocalizations.of(context)!.signInTitle
              : AppLocalizations.of(context)!.joinGalaxy,
          style: TextStyle(fontWeight: FontWeight.bold, color: textColor),
        ),
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverFillRemaining(
                hasScrollBody: false,
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildAnimatedMember(
                          interval: const Interval(0.1, 0.7),
                          child:
                              (authState.step == AuthStep.initial ||
                                  authState.step == AuthStep.otpSent)
                              ? Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      AppLocalizations.of(context)!.enterPhone,
                                      style: TextStyle(
                                        color: textColor,
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      AppLocalizations.of(
                                        context,
                                      )!.sendPhoneOtpDesc,
                                      style: TextStyle(color: textSecondary),
                                    ),
                                    const SizedBox(height: 28),
                                    GalaxyTextField(
                                      controller: _phoneController,
                                      label: AppLocalizations.of(
                                        context,
                                      )!.phonePlaceholder,
                                      keyboardType: TextInputType.phone,
                                      enabled:
                                          authState.step == AuthStep.initial,
                                      validator: (v) {
                                        if (v == null || v.trim().isEmpty) {
                                          return AppLocalizations.of(
                                            context,
                                          )!.phoneErrorEmpty;
                                        }
                                        if (!v.startsWith('+')) {
                                          return AppLocalizations.of(
                                            context,
                                          )!.phoneErrorInvalid;
                                        }
                                        return null;
                                      },
                                    ),
                                    if (authState.step == AuthStep.otpSent) ...[
                                      const SizedBox(height: 24),
                                      _buildAnimatedMember(
                                        interval: const Interval(0.4, 0.9),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              AppLocalizations.of(
                                                context,
                                              )!.enterOtp,
                                              style: TextStyle(
                                                color: textColor,
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            GalaxyTextField(
                                              controller: _otpController,
                                              label: AppLocalizations.of(
                                                context,
                                              )!.otpPlaceholder,
                                              keyboardType:
                                                  TextInputType.number,
                                              maxLength: 8,
                                              validator: (v) {
                                                if (v == null ||
                                                    v.length != 8) {
                                                  return AppLocalizations.of(
                                                    context,
                                                  )!.otpError;
                                                }
                                                return null;
                                              },
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ],
                                )
                              : const SizedBox.shrink(),
                        ),
                        if (authState.errorMessage != null) ...[
                          _buildAnimatedMember(
                            interval: const Interval(0.2, 0.8),
                            child: GalaxyErrorBanner(
                              message: _getErrorMessage(
                                context,
                                authState.errorMessage!,
                              ),
                            ),
                          ),
                        ],
                        const Spacer(),
                        _buildAnimatedMember(
                          interval: const Interval(0.3, 1.0),
                          child: GalaxyButton(
                            isLoading: authState.isLoading,
                            onTap: () {
                              if (!_formKey.currentState!.validate()) return;
                              if (authState.step == AuthStep.initial) {
                                notifier.sendPhoneOtp(
                                  _phoneController.text.trim(),
                                );
                              } else {
                                notifier.verifyPhoneOtp(
                                  _otpController.text.trim(),
                                );
                              }
                            },
                            label: authState.step == AuthStep.initial
                                ? AppLocalizations.of(context)!.sendOtpBtn
                                : AppLocalizations.of(
                                    context,
                                  )!.verifyContinueBtn,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
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

  String _getErrorMessage(BuildContext context, String code) {
    final l10n = AppLocalizations.of(context)!;
    switch (code) {
      case 'authErrorInvalidEmail':
        return l10n.emailError;
      case 'authErrorInvalidPhone':
        return l10n.authErrorInvalidPhone;
      case 'authErrorInvalidOtp':
        return l10n.authErrorInvalidOtp;
      case 'authErrorEmailInUse':
        return l10n.authErrorEmailInUse;
      case 'authErrorWeakPassword':
        return l10n.authErrorWeakPassword;
      case 'authErrorInvalidCredentials':
        return l10n.authErrorInvalidCredentials;
      case 'authErrorTooManyRequests':
        return 'Network error. Please check your connection.';
      default:
        if (code.startsWith('authError')) {
          return l10n.authErrorGeneric;
        }
        return code;
    }
  }
}

class EmailAuthScreen extends ConsumerStatefulWidget {
  final bool isLogin;
  const EmailAuthScreen({super.key, this.isLogin = true});

  @override
  ConsumerState<EmailAuthScreen> createState() => _EmailAuthScreenState();
}

class _EmailAuthScreenState extends ConsumerState<EmailAuthScreen>
    with SingleTickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _otpController = TextEditingController(); // Reintroduced for Signup OTP
  final _formKey = GlobalKey<FormState>();
  final _emailFocusNode = FocusNode();
  final _layerLink = LayerLink();
  late AnimationController _animationController;
  OverlayEntry? _overlayEntry;
  bool _isLogin = true;

  final List<String> _domains = [
    '@xparq.io',
    '@gmail.com',
    '@hotmail.com',
    '@outlook.com',
    '@yahoo.com',
    '@icloud.com',
  ];

  @override
  void initState() {
    super.initState();
    _isLogin = widget.isLogin;
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..forward();
  }

  @override
  void dispose() {
    _hideSuggestions();
    _emailController.dispose();
    _passwordController.dispose();
    _otpController.dispose();
    _emailFocusNode.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _onEmailChanged(String text) {
    if (text.contains('@')) {
      final parts = text.split('@');
      if (parts.length == 2) {
        _showSuggestions('@${parts[1].toLowerCase()}');
      } else {
        _hideSuggestions();
      }
    } else {
      _hideSuggestions();
    }
  }

  void _showSuggestions(String query) {
    _hideSuggestions();
    final filteredDomains = _domains
        .where((d) => d.toLowerCase().startsWith(query))
        .toList();
    if (filteredDomains.isEmpty || !_emailFocusNode.hasFocus) return;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF16181C) : const Color(0xFFFFFFFF);
    final borderColor = isDark
        ? const Color(0xFF2F3336)
        : const Color(0xFFCFD9DE);
    final textColor = isDark
        ? const Color(0xFFE7E9EA)
        : const Color(0xFF0F1419);

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        width: _layerLink.leaderSize?.width,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: const Offset(0, 60),
          child: Material(
            elevation: 8,
            color: bgColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(color: borderColor),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200),
              child: ListView.separated(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: filteredDomains.length,
                separatorBuilder: (context, index) =>
                    Divider(height: 1, color: borderColor),
                itemBuilder: (context, index) {
                  final domain = filteredDomains[index];
                  return ListTile(
                    title: Text(
                      domain,
                      style: TextStyle(color: textColor, fontSize: 14),
                    ),
                    onTap: () {
                      HapticFeedback.lightImpact();
                      _selectDomain(domain);
                    },
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _hideSuggestions() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _selectDomain(String domain) {
    final text = _emailController.text;
    final atIndex = text.indexOf('@');
    if (atIndex != -1) {
      _emailController.text = text.substring(0, atIndex) + domain;
      _emailController.selection = TextSelection.fromPosition(
        TextPosition(offset: _emailController.text.length),
      );
    }
    _hideSuggestions();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final notifier = ref.read(authNotifierProvider.notifier);
    final l10n = AppLocalizations.of(context)!;

    ref.listen(authNotifierProvider, (prev, next) {
      final isForgotFlow =
          next.step == AuthStep.forgotPasswordEmailInput ||
          next.step == AuthStep.forgotPasswordEmailSent;
      final isVerificationFlow = next.step == AuthStep.emailVerificationSent;

      if (!isForgotFlow &&
          !isVerificationFlow &&
          next.step == AuthStep.complete) {
        context.go(AppRoutes.dobInput);
      } else if (next.step == AuthStep.otpVerified) {
        context.go(AppRoutes.dobInput);
      }
    });

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark
        ? Theme.of(context).scaffoldBackgroundColor
        : const Color(0xFFFFFFFF);
    final textColor = isDark
        ? const Color(0xFFE7E9EA)
        : const Color(0xFF0F1419);
    final primaryColor = const Color(0xFF1D9BF0);

    if (authState.step == AuthStep.complete) {
      return Scaffold(
        backgroundColor: bgColor,
        body: const Center(
          child: CircularProgressIndicator(color: Color(0xFF1D9BF0)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: bgColor,
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        backgroundColor: bgColor,
        surfaceTintColor: Colors.transparent,
        foregroundColor: textColor,
        iconTheme: IconThemeData(color: textColor),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            HapticFeedback.lightImpact();
            if (authState.step == AuthStep.emailVerificationSent) {
              notifier.signOut();
            } else {
              context.pop();
            }
          },
        ),
        title: Text(
          _isLogin ? l10n.signInTitle : l10n.joinGalaxy,
          style: TextStyle(fontWeight: FontWeight.bold, color: textColor),
        ),
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverFillRemaining(
                hasScrollBody: false,
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildAnimatedMember(
                          interval: const Interval(0.1, 0.7),
                          child:
                              authState.step == AuthStep.emailVerificationSent
                              ? Column(
                                  key: const ValueKey('email_otp_form'),
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      l10n.enterOtp,
                                      style: TextStyle(
                                        color: textColor,
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      AppLocalizations.of(
                                        context,
                                      )!.emailOtpSentDesc,
                                      style: TextStyle(
                                        color: textColor.withValues(alpha: 0.7),
                                      ),
                                    ),
                                    const SizedBox(height: 28),
                                    GalaxyTextField(
                                      controller: _otpController,
                                      label: l10n.otpPlaceholder,
                                      keyboardType: TextInputType.number,
                                      maxLength: 8,
                                      validator: (v) {
                                        if (v == null || v.length != 8) {
                                          return l10n.otpError;
                                        }
                                        return null;
                                      },
                                    ),
                                  ],
                                )
                              : Column(
                                  key: const ValueKey('email_password_form'),
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _isLogin
                                          ? l10n.welcomeBack
                                          : l10n.createAccount,
                                      style: TextStyle(
                                        color: textColor,
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 28),
                                    CompositedTransformTarget(
                                      link: _layerLink,
                                      child: GalaxyTextField(
                                        controller: _emailController,
                                        focusNode: _emailFocusNode,
                                        label: l10n.emailPlaceholder,
                                        keyboardType:
                                            TextInputType.emailAddress,
                                        onChanged: _onEmailChanged,
                                        validator: (v) =>
                                            (v == null || !v.contains('@'))
                                            ? l10n.emailError
                                            : null,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    GalaxyTextField(
                                      controller: _passwordController,
                                      label: l10n.passwordPlaceholder,
                                      obscureText: true,
                                      validator: (v) {
                                        if (v == null || v.length < 6) {
                                          return l10n.authErrorWeakPassword;
                                        }
                                        return null;
                                      },
                                    ),
                                    if (_isLogin)
                                      Align(
                                        alignment:
                                            AlignmentDirectional.centerEnd,
                                        child: TextButton(
                                          onPressed: () => context.push(
                                            AppRoutes.forgotPassword,
                                          ),
                                          child: Text(
                                            l10n.forgotPasswordBtn,
                                            style: TextStyle(
                                              color: primaryColor,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                        ),
                        if (authState.errorMessage != null) ...[
                          const SizedBox(height: 16),
                          _buildAnimatedMember(
                            interval: const Interval(0.2, 0.8),
                            child: GalaxyErrorBanner(
                              message: _getErrorMessage(
                                context,
                                authState.errorMessage!,
                              ),
                            ),
                          ),
                        ],
                        const Spacer(),
                        _buildAnimatedMember(
                          interval: const Interval(0.3, 1.0),
                          child: GalaxyButton(
                            isLoading: authState.isLoading,
                            onTap: () {
                              if (!_formKey.currentState!.validate()) return;

                              if (authState.step ==
                                  AuthStep.emailVerificationSent) {
                                notifier.verifyEmailOtpSignup(
                                  _emailController.text.trim(),
                                  _otpController.text.trim(),
                                );
                              } else {
                                if (_isLogin) {
                                  notifier.signInWithEmailPassword(
                                    email: _emailController.text.trim(),
                                    password: _passwordController.text,
                                  );
                                } else {
                                  notifier.registerWithEmailPassword(
                                    email: _emailController.text.trim(),
                                    password: _passwordController.text,
                                  );
                                }
                              }
                            },
                            label:
                                authState.step == AuthStep.emailVerificationSent
                                ? l10n.verifyContinueBtn
                                : (_isLogin
                                      ? l10n.signInTitle
                                      : l10n.registerBtn),
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (authState.step != AuthStep.emailVerificationSent)
                          Center(
                            child: TextButton(
                              onPressed: () {
                                HapticFeedback.lightImpact();
                                setState(() => _isLogin = !_isLogin);
                              },
                              child: Text(
                                _isLogin
                                    ? l10n.newXparqPromo
                                    : l10n.alreadyXparqPromo,
                                style: TextStyle(color: primaryColor),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
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

  String _getErrorMessage(BuildContext context, String code) {
    final l10n = AppLocalizations.of(context)!;
    switch (code) {
      case 'authErrorInvalidEmail':
        return l10n.authErrorInvalidEmail;
      case 'authErrorInvalidPhone':
        return l10n.authErrorInvalidPhone;
      case 'authErrorInvalidOtp':
        return l10n.authErrorInvalidOtp;
      case 'authErrorEmailInUse':
        return l10n.authErrorEmailInUse;
      case 'authErrorWeakPassword':
        return l10n.authErrorWeakPassword;
      case 'authErrorInvalidCredentials':
        return l10n.authErrorInvalidCredentials;
      case 'authErrorTooManyRequests':
        return l10n.authErrorTooManyRequests.isNotEmpty
            ? l10n.authErrorTooManyRequests
            : 'Too many requests. Please wait before trying again.';
      case 'authErrorNetwork':
        return l10n.authErrorNetwork;
      case 'authErrorNameTaken':
        return l10n.authErrorNameTaken;
      default:
        // Try to match other common keys or return generic
        if (code.startsWith('authError')) {
          return l10n.authErrorGeneric;
        }
        return code;
    }
  }
}

