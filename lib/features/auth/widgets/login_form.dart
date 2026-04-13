import 'package:flutter/material.dart';
import 'package:xparq_app/shared/widgets/ui/buttons/galaxy_button.dart';
import 'package:xparq_app/shared/widgets/ui/inputs/galaxy_text_field.dart';
import 'package:xparq_app/shared/widgets/ui/cards/glass_card.dart';
import 'package:xparq_app/features/auth/widgets/galaxy_error_banner.dart';

class LoginForm extends StatelessWidget {
  const LoginForm({
    super.key,
    required this.emailController,
    required this.passwordController,
    required this.isLoading,
    required this.onSubmit,
    this.errorMessage,
    this.onForgotPassword,
    this.onChanged,
  });

  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool isLoading;
  final VoidCallback onSubmit;
  final String? errorMessage;
  final VoidCallback? onForgotPassword;
  final VoidCallback? onChanged;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(24),
      borderRadius: BorderRadius.circular(28),
      opacity: 0.08,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Welcome back',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            'Log in to continue your XPARQ journey.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.72),
            ),
          ),
          if (errorMessage != null) ...[
            const SizedBox(height: 20),
            GalaxyErrorBanner(message: errorMessage!),
          ],
          const SizedBox(height: 24),
          GalaxyTextField(
            controller: emailController,
            label: 'Email',
            keyboardType: TextInputType.emailAddress,
            enabled: !isLoading,
            onChanged: (_) => onChanged?.call(),
          ),
          const SizedBox(height: 16),
          GalaxyTextField(
            controller: passwordController,
            label: 'Password',
            obscureText: true,
            enabled: !isLoading,
            onChanged: (_) => onChanged?.call(),
          ),
          if (onForgotPassword != null) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: isLoading ? null : onForgotPassword,
                child: const Text('Forgot password?'),
              ),
            ),
          ] else
            const SizedBox(height: 8),
          const SizedBox(height: 8),
          GalaxyButton(
            label: 'Log In',
            isLoading: isLoading,
            onTap: isLoading ? null : onSubmit,
          ),
        ],
      ),
    );
  }
}
