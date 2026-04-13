import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_providers.dart';
import '../../../../shared/router/app_router.dart';
import '../../../../l10n/app_localizations.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final TextEditingController _emailController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(authNotifierProvider.notifier).resetToForgotPassword();
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final notifier = ref.read(authNotifierProvider.notifier);
    final l10n = AppLocalizations.of(context)!;

    final isSent = authState.step == AuthStep.forgotPasswordEmailSent;

    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isSent ? l10n.authConfirm : l10n.forgotPasswordHint,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                isSent
                    ? l10n.forgotPasswordEmailSent
                    : l10n.forgotPasswordEmailHint,
                style: const TextStyle(color: Colors.white70, fontSize: 16),
              ),
              const SizedBox(height: 32),
              if (!isSent) ...[
                _buildEmailInput(notifier, authState, l10n),
              ] else ...[
                _buildSuccessState(l10n),
              ],
              if (authState.errorMessage != null) ...[
                const SizedBox(height: 20),
                Text(
                  _getErrorMessage(context, authState.errorMessage!),
                  style: const TextStyle(color: Color(0xFFFF6B6B)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmailInput(
    AuthNotifier notifier,
    AuthState authState,
    AppLocalizations l10n,
  ) {
    return Column(
      children: [
        TextField(
          controller: _emailController,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: l10n.emailHint,
            hintStyle: const TextStyle(color: Colors.white30),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.05),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: authState.isLoading
                ? null
                : () {
                    if (_emailController.text.isNotEmpty) {
                      notifier.sendRealPasswordResetEmail(
                        _emailController.text.trim(),
                      );
                    }
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1D9BF0),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: authState.isLoading
                ? const CircularProgressIndicator(color: Colors.white)
                : Text(
                    l10n.authSendOtp, // Reusing "Send" label
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildSuccessState(AppLocalizations l10n) {
    return Column(
      children: [
        const Icon(
          Icons.mark_email_read_outlined,
          color: Color(0xFF00BA7C),
          size: 80,
        ),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: () {
              context.go(AppRoutes.emailAuth);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00BA7C),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              l10n.okBtn,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _getErrorMessage(BuildContext context, String code) {
    final l10n = AppLocalizations.of(context)!;
    switch (code) {
      case 'authErrorGeneric':
        return l10n.authErrorGeneric;
      default:
        return code;
    }
  }
}
