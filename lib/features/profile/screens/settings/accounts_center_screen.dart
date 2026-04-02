// lib/features/profile/screens/settings/accounts_center_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:xparq_app/core/router/app_router.dart';
import 'package:xparq_app/features/auth/providers/auth_providers.dart';

class AccountsCenterScreen extends ConsumerWidget {
  const AccountsCenterScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final textColor = Theme.of(context).colorScheme.onSurface;
    final subtitleColor = textColor.withOpacity(0.55);
    final profile = ref.watch(planetProfileProvider).valueOrNull;
    final currentUser = ref.watch(supabaseAuthStateProvider).valueOrNull;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text(
          'My Account',
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
          // Profile Summary Mini Card
          if (profile != null) ...[
            Container(
              margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.surfaceContainerHighest.withOpacity(0.4),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: Colors.blueGrey.shade800,
                    backgroundImage: profile.photoUrl.isNotEmpty
                        ? NetworkImage(profile.photoUrl)
                        : null,
                    child: profile.photoUrl.isEmpty
                        ? const Icon(Icons.person, color: Colors.white54)
                        : null,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          profile.xparqName,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: textColor,
                          ),
                        ),
                        if (currentUser?.email != null)
                          Text(
                            currentUser!.email!,
                            style: TextStyle(
                              color: subtitleColor,
                              fontSize: 12,
                            ),
                          ),
                        if (currentUser?.phone != null)
                          Text(
                            currentUser!.phone!,
                            style: TextStyle(
                              color: subtitleColor,
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],

          // ── Login & Security ─────────────────────────────────────────
          _SectionHeader(title: 'Login & Security'),
          ListTile(
            leading: Icon(Icons.lock_outline, color: subtitleColor),
            title: Text(
              'Password & Security',
              style: TextStyle(color: textColor),
            ),
            subtitle: Text(
              'Password, 2FA, trusted devices',
              style: TextStyle(color: subtitleColor, fontSize: 12),
            ),
            trailing: Icon(Icons.chevron_right, color: subtitleColor),
            onTap: () {
              HapticFeedback.lightImpact();
              context.push(AppRoutes.passwordSecurity);
            },
          ),
          ListTile(
            leading: Icon(Icons.bolt_rounded, color: subtitleColor),
            title: Text('Quick Login', style: TextStyle(color: textColor)),
            subtitle: Text(
              'PIN login from the Welcome screen',
              style: TextStyle(color: subtitleColor, fontSize: 12),
            ),
            trailing: Icon(Icons.chevron_right, color: subtitleColor),
            onTap: () {
              HapticFeedback.lightImpact();
              context.push(AppRoutes.quickLogin);
            },
          ),

          // ── Account Management ────────────────────────────────────────
          _SectionHeader(title: 'Account Management'),
          _ComingSoonTile(
            icon: Icons.person_add_alt_outlined,
            title: 'Switch Account',
            subtitle: 'Manage multiple iXPARQ accounts',
            textColor: textColor,
            subtitleColor: subtitleColor,
          ),
          _ComingSoonTile(
            icon: Icons.workspace_premium_outlined,
            title: 'Switch to Creator / Business',
            subtitle: 'Access advanced tools and analytics',
            textColor: textColor,
            subtitleColor: subtitleColor,
          ),
          _ComingSoonTile(
            icon: Icons.download_outlined,
            title: 'Download Your Data',
            subtitle: 'Export your posts, messages and info',
            textColor: textColor,
            subtitleColor: subtitleColor,
          ),

          // ── Danger Zone ───────────────────────────────────────────────
          _SectionHeader(title: 'Account Actions'),
          _ComingSoonTile(
            icon: Icons.pause_circle_outline,
            title: 'Deactivate Account',
            subtitle: 'Temporarily hide your account',
            textColor: textColor,
            subtitleColor: subtitleColor,
          ),
          ListTile(
            leading: const Icon(
              Icons.delete_forever_outlined,
              color: Colors.redAccent,
            ),
            title: const Text(
              'Delete Account',
              style: TextStyle(color: Colors.redAccent),
            ),
            subtitle: Text(
              'Permanently delete your account and data',
              style: TextStyle(color: subtitleColor, fontSize: 12),
            ),
            trailing: Icon(Icons.chevron_right, color: subtitleColor),
            onTap: () => _showDeleteConfirmation(context, ref),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, WidgetRef ref) {
    HapticFeedback.heavyImpact();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Account?'),
        content: const Text(
          'This action is permanent. All your Pulses, Orbits, and data will be erased forever.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(authNotifierProvider.notifier).deleteAccount();
            },
            child: const Text('Delete Forever'),
          ),
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
