// lib/features/profile/screens/settings/password_security_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:xparq_app/features/auth/providers/auth_providers.dart';

class PasswordAndSecurityScreen extends ConsumerWidget {
  const PasswordAndSecurityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final textColor = Theme.of(context).colorScheme.onSurface;
    final subtitleColor = textColor.withOpacity(0.55);
    final currentUser = ref.watch(supabaseAuthStateProvider).valueOrNull;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text(
          'Password & Security',
          style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
        ),
        backgroundColor: bgColor,
        surfaceTintColor: Colors.transparent,
        iconTheme: IconThemeData(color: textColor),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            HapticFeedback.lightImpact();
            context.pop();
          },
        ),
      ),
      body: ListView(
        children: [
          // ── Login ────────────────────────────────────────────────────
          _SectionHeader(title: 'Login & Recovery'),
          _ComingSoonTile(
            icon: Icons.key_outlined,
            title: 'Change Password',
            subtitle: currentUser?.email != null
                ? 'For: ${currentUser!.email}'
                : 'Update your account password',
            textColor: textColor,
            subtitleColor: subtitleColor,
          ),
          _ComingSoonTile(
            icon: Icons.email_outlined,
            title: 'Update Email',
            subtitle: currentUser?.email ?? 'No email linked',
            textColor: textColor,
            subtitleColor: subtitleColor,
          ),
          _ComingSoonTile(
            icon: Icons.phone_outlined,
            title: 'Update Phone Number',
            subtitle: currentUser?.phone ?? 'No phone linked',
            textColor: textColor,
            subtitleColor: subtitleColor,
          ),

          // ── Two-Factor Auth ───────────────────────────────────────────
          _SectionHeader(title: 'Two-Factor Authentication'),
          _ComingSoonTile(
            icon: Icons.verified_user_outlined,
            title: 'Two-Factor Authentication',
            subtitle: 'Add an extra layer of security via email or app',
            textColor: textColor,
            subtitleColor: subtitleColor,
          ),

          // ── Devices ──────────────────────────────────────────────────
          _SectionHeader(title: 'Active Sessions'),
          _ComingSoonTile(
            icon: Icons.devices_outlined,
            title: 'Devices Logged In',
            subtitle: 'View and manage all active sessions',
            textColor: textColor,
            subtitleColor: subtitleColor,
          ),
          _ComingSoonTile(
            icon: Icons.notifications_active_outlined,
            title: 'Login Alerts',
            subtitle: 'Get notified of unrecognised login attempts',
            textColor: textColor,
            subtitleColor: subtitleColor,
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          color: Color(0xFF1D9BF0),
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _ComingSoonTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Color textColor;
  final Color subtitleColor;

  const _ComingSoonTile({
    required this.icon,
    required this.title,
    required this.textColor,
    required this.subtitleColor,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: subtitleColor),
      title: Text(title, style: TextStyle(color: textColor)),
      subtitle: subtitle != null
          ? Text(
              subtitle!,
              style: TextStyle(color: subtitleColor, fontSize: 12),
            )
          : null,
      trailing: Icon(Icons.chevron_right, color: subtitleColor),
      onTap: () {
        HapticFeedback.lightImpact();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Coming soon ✨')));
      },
    );
  }
}
