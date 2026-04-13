// lib/features/profile/screens/settings/family_center_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

class FamilyCenterScreen extends StatelessWidget {
  const FamilyCenterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final textColor = Theme.of(context).colorScheme.onSurface;
    final subtitleColor = textColor.withValues(alpha: 0.55);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        surfaceTintColor: Colors.transparent,
        iconTheme: IconThemeData(color: textColor),
        title: Text(
          'Family Center',
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
          // Info Banner
          Container(
            margin: const EdgeInsets.fromLTRB(16, 20, 16, 8),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1D9BF0).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFF1D9BF0).withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.family_restroom,
                  color: Color(0xFF1D9BF0),
                  size: 32,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Family Center ช่วยให้ผู้ปกครองดูแลการใช้งานของเยาวชนใน iXPARQ ได้อย่างปลอดภัย',
                    style: TextStyle(
                      color: textColor.withValues(alpha: 0.8),
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),

          _Header(title: 'Parental Controls'),
          _ComingSoonTile(
            icon: Icons.supervised_user_circle_outlined,
            title: 'Link a Family Account',
            subtitle: 'Connect and supervise a young person\'s account',
            textColor: textColor,
            subtitleColor: subtitleColor,
          ),
          _ComingSoonTile(
            icon: Icons.content_copy_outlined,
            title: 'Content Restrictions',
            subtitle: 'Control what content a supervised account can see',
            textColor: textColor,
            subtitleColor: subtitleColor,
          ),

          _Header(title: 'Screen Time'),
          _ComingSoonTile(
            icon: Icons.access_time_outlined,
            title: 'Daily Time Limit',
            subtitle: 'Set a daily usage limit for this account',
            textColor: textColor,
            subtitleColor: subtitleColor,
          ),
          _ComingSoonTile(
            icon: Icons.do_not_disturb_on_outlined,
            title: 'Scheduled Breaks',
            subtitle: 'Take regular breaks while using iXPARQ',
            textColor: textColor,
            subtitleColor: subtitleColor,
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
