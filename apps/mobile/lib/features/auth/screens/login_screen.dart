import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:xparq_app/features/auth/models/user_model.dart';
import 'package:xparq_app/features/auth/providers/auth_providers.dart';
import 'package:xparq_app/features/auth/widgets/login_form.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key, this.onLoginSuccess, this.onForgotPassword});

  final ValueChanged<UserModel>? onLoginSuccess;
  final VoidCallback? onForgotPassword;

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  late final TextEditingController _emailController;
  late final TextEditingController _passwordController;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController();
    _passwordController = TextEditingController();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() {
    FocusScope.of(context).unfocus();
    ref
        .read(authNotifierProvider.notifier)
        .signInWithEmailPassword(
          email: _emailController.text,
          password: _passwordController.text,
        );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authNotifierProvider, (previous, next) {
      final hasCompleted =
          previous?.step != AuthStep.complete && next.step == AuthStep.complete;
      if (!hasCompleted) {
        return;
      }

      final user = Supabase.instance.client.auth.currentUser;
      final session = Supabase.instance.client.auth.currentSession;
      if (user == null || session == null || session.accessToken.isEmpty) {
        return;
      }

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('Logged in as ${user.email}')));

      widget.onLoginSuccess?.call(
        UserModel(
          id: user.id,
          email: user.email ?? '',
          token: session.accessToken,
        ),
      );
    });

    final state = ref.watch(authNotifierProvider);

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        appBar: AppBar(title: const Text('Login')),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: LoginForm(
                  emailController: _emailController,
                  passwordController: _passwordController,
                  isLoading: state.isLoading,
                  errorMessage: state.errorMessage,
                  onSubmit: _submit,
                  onForgotPassword: widget.onForgotPassword,
                  onChanged: ref.read(authNotifierProvider.notifier).clearError,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
