import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:xparq_app/features/auth/providers/auth_providers.dart';
import 'package:xparq_app/core/widgets/galaxy_text_field.dart';
import 'package:xparq_app/core/widgets/galaxy_button.dart';
import 'package:xparq_app/l10n/app_localizations.dart';
import 'package:xparq_app/features/auth/widgets/galaxy_error_banner.dart';

class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  ConsumerState<ResetPasswordScreen> createState() =>
      _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen>
    with SingleTickerProviderStateMixin {
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
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
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final notifier = ref.read(authNotifierProvider.notifier);
    final l10n = AppLocalizations.of(context)!;

    // Listen for success and go back to login
    ref.listen(authNotifierProvider, (prev, next) {
      if (next.step == AuthStep.complete && prev?.step != AuthStep.complete) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              l10n.authErrorGeneric == 'Error'
                  ? 'Password updated successfully!'
                  : 'Password updated!',
            ),
            backgroundColor: Colors.green,
          ),
        );
        context.go('/welcome/auth/email');
      }
    });

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark
        ? Theme.of(context).scaffoldBackgroundColor
        : const Color(0xFFFFFFFF);
    final textColor = isDark
        ? const Color(0xFFE7E9EA)
        : const Color(0xFF0F1419);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        surfaceTintColor: Colors.transparent,
        foregroundColor: textColor,
        title: Text(
          'Reset Password',
          style: TextStyle(fontWeight: FontWeight.bold, color: textColor),
        ),
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildAnimatedMember(
                    interval: const Interval(0.1, 0.7),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Create New Password',
                          style: TextStyle(
                            color: textColor,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Please enter your new secure password below.',
                          style: TextStyle(
                            color: textColor.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  _buildAnimatedMember(
                    interval: const Interval(0.2, 0.8),
                    child: GalaxyTextField(
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
                  ),
                  const SizedBox(height: 16),
                  _buildAnimatedMember(
                    interval: const Interval(0.3, 0.9),
                    child: GalaxyTextField(
                      controller: _confirmPasswordController,
                      label: 'Confirm Password',
                      obscureText: true,
                      validator: (v) {
                        if (v != _passwordController.text) {
                          return 'Passwords do not match';
                        }
                        return null;
                      },
                    ),
                  ),
                  if (authState.errorMessage != null) ...[
                    const SizedBox(height: 24),
                    _buildAnimatedMember(
                      interval: const Interval(0.4, 1.0),
                      child: GalaxyErrorBanner(
                        message: authState.errorMessage!,
                      ),
                    ),
                  ],
                  const Spacer(),
                  _buildAnimatedMember(
                    interval: const Interval(0.5, 1.0),
                    child: GalaxyButton(
                      isLoading: authState.isLoading,
                      onTap: () {
                        if (!_formKey.currentState!.validate()) return;
                        HapticFeedback.mediumImpact();
                        notifier.updatePassword(_passwordController.text);
                      },
                      label: 'Update Password',
                    ),
                  ),
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
        position: Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero)
            .animate(
              CurvedAnimation(parent: _animationController, curve: interval),
            ),
        child: child,
      ),
    );
  }
}
