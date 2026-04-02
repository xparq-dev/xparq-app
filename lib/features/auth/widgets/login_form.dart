import 'package:flutter/material.dart';
import 'package:xparq_app/shared/widgets/ui/buttons/galaxy_button.dart';
import 'package:xparq_app/shared/widgets/ui/inputs/galaxy_text_field.dart';
import 'package:xparq_app/shared/widgets/ui/cards/glass_card.dart';
import 'package:xparq_app/features/auth/widgets/galaxy_error_banner.dart';
import 'package:xparq_app/core/security/input_validator.dart';

class LoginForm extends StatefulWidget {
  const LoginForm({
    super.key,
    required this.emailController,
    required this.passwordController,
    required this.isLoading,
    required this.onSubmit,
    this.errorMessage,
    this.onForgotPassword,
  });

  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool isLoading;
  final VoidCallback onSubmit;
  final String? errorMessage;
  final VoidCallback? onForgotPassword;

  @override
  State<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<LoginForm> {
  final _formKey = GlobalKey<FormState>();

  void _handleSubmit() {
    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid) return;

    widget.onSubmit();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GlassCard(
      padding: const EdgeInsets.all(24),
      borderRadius: BorderRadius.circular(28),
      opacity: 0.08,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Welcome back',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),

            const SizedBox(height: 8),

            Text(
              'Log in to continue your XPARQ journey.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.72),
              ),
            ),

            if (widget.errorMessage != null) ...[
              const SizedBox(height: 20),
              GalaxyErrorBanner(message: widget.errorMessage!),
            ],

            const SizedBox(height: 24),

            // 🔥 Email
            GalaxyTextField(
              controller: widget.emailController,
              label: 'Email',
              keyboardType: TextInputType.emailAddress,
              enabled: !widget.isLoading,
              validator: InputValidator.email,
            ),

            const SizedBox(height: 16),

            // 🔥 Password
            GalaxyTextField(
              controller: widget.passwordController,
              label: 'Password',
              obscureText: true,
              enabled: !widget.isLoading,
              validator: InputValidator.password,
            ),

            if (widget.onForgotPassword != null) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed:
                      widget.isLoading ? null : widget.onForgotPassword,
                  child: const Text('Forgot password?'),
                ),
              ),
            ] else
              const SizedBox(height: 8),

            const SizedBox(height: 16),

            // 🔥 Button (fix API)
            GalaxyButton(
              isLoading: widget.isLoading,
              onTap: widget.isLoading ? null : _handleSubmit,
              child: const Text('Log In'),
            ),
          ],
        ),
      ),
    );
  }
}