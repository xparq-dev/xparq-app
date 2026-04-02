// lib/features/profile/screens/settings/help_support_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  // App version — update with your actual version
  static const _appVersion = '1.0.0';

  @override
  Widget build(BuildContext context) {
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final textColor = Theme.of(context).colorScheme.onSurface;
    final subtitleColor = textColor.withOpacity(0.55);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        surfaceTintColor: Colors.transparent,
        iconTheme: IconThemeData(color: textColor),
        title: Text(
          'Help & Support',
          style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
        ),
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
          _Header(title: 'Support'),
          _ComingSoonTile(
            icon: Icons.help_center_outlined,
            title: 'Help Center',
            subtitle: 'Browse FAQs, guides and tips',
            textColor: textColor,
            subtitleColor: subtitleColor,
          ),
          _ComingSoonTile(
            icon: Icons.bug_report_outlined,
            title: 'Report a Problem',
            subtitle: 'Found a bug? Let us know',
            textColor: textColor,
            subtitleColor: subtitleColor,
          ),
          _ComingSoonTile(
            icon: Icons.mail_outline,
            title: 'Contact Us',
            subtitle: 'Get in touch with the iXPARQ team',
            textColor: textColor,
            subtitleColor: subtitleColor,
          ),

          _Header(title: 'About iXPARQ'),
          ListTile(
            leading: Icon(Icons.info_outline, color: subtitleColor),
            title: Text('App Version', style: TextStyle(color: textColor)),
            trailing: Text(
              _appVersion,
              style: TextStyle(color: subtitleColor, fontSize: 13),
            ),
          ),
          _ComingSoonTile(
            icon: Icons.gavel_outlined,
            title: 'Terms of Service',
            textColor: textColor,
            subtitleColor: subtitleColor,
          ),
          _ComingSoonTile(
            icon: Icons.privacy_tip_outlined,
            title: 'Privacy Policy',
            textColor: textColor,
            subtitleColor: subtitleColor,
          ),
          _ComingSoonTile(
            icon: Icons.description_outlined,
            title: 'Open Source Licenses',
            textColor: textColor,
            subtitleColor: subtitleColor,
          ),

          const SizedBox(height: 48),
          Center(
            child: Column(
              children: [
                Text(
                  'iXPARQ',
                  style: TextStyle(
                    color: const Color(0xFF1D9BF0).withOpacity(0.5),
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Made with ♥ in the galaxy',
                  style: TextStyle(
                    color: subtitleColor.withOpacity(0.5),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final String title;
  const _Header({required this.title});

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
