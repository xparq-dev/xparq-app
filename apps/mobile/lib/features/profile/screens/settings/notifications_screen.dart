// lib/features/profile/screens/settings/notifications_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xparq_app/shared/router/app_router.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  bool _showPreview = false;
  bool _showActions = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = ref.read(sharedPreferencesProvider);
    setState(() {
      _showPreview = prefs.getBool('show_notification_preview') ?? false;
      _showActions = prefs.getBool('show_notification_actions') ?? false;
    });
  }

  Future<void> _togglePreview(bool value) async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setBool('show_notification_preview', value);
    setState(() => _showPreview = value);
  }

  Future<void> _toggleActions(bool value) async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setBool('show_notification_actions', value);
    setState(() => _showActions = value);
  }

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
          'Notifications',
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
          _Header(title: 'Pulses & Social'),
          _ComingSoonTile(
            icon: Icons.favorite_outline,
            title: 'Likes',
            subtitle: 'Notify when someone likes your Pulse',
            textColor: textColor,
            subtitleColor: subtitleColor,
          ),
          _ComingSoonTile(
            icon: Icons.comment_outlined,
            title: 'Comments',
            subtitle: 'Notify when someone comments on your Pulse',
            textColor: textColor,
            subtitleColor: subtitleColor,
          ),
          _ComingSoonTile(
            icon: Icons.people_outline,
            title: 'New Orbits',
            subtitle: 'Notify when someone starts orbiting you',
            textColor: textColor,
            subtitleColor: subtitleColor,
          ),
          _ComingSoonTile(
            icon: Icons.alternate_email,
            title: 'Mentions & Tags',
            subtitle: 'Notify when someone mentions or tags you',
            textColor: textColor,
            subtitleColor: subtitleColor,
          ),

          _Header(title: 'Signal (DM)'),
          _ComingSoonTile(
            icon: Icons.chat_bubble_outline,
            title: 'Direct Messages',
            subtitle: 'Notify for new Signal messages',
            textColor: textColor,
            subtitleColor: subtitleColor,
          ),
          _ComingSoonTile(
            icon: Icons.group_outlined,
            title: 'Group Messages',
            subtitle: 'Notify for new group Signal messages',
            textColor: textColor,
            subtitleColor: subtitleColor,
          ),

          _Header(title: 'Privacy & Preview'),
          SwitchListTile(
            secondary: Icon(Icons.visibility_outlined, color: subtitleColor),
            title: Text(
              'Show Message Preview',
              style: TextStyle(
                color: textColor,
                fontSize: 15,
                fontWeight: FontWeight.normal,
              ),
            ),
            subtitle: Text(
              'Show message content in notifications',
              style: TextStyle(color: subtitleColor, fontSize: 12),
            ),
            value: _showPreview,
            onChanged: (val) {
              HapticFeedback.selectionClick();
              _togglePreview(val);
            },
            activeThumbColor: const Color(0xFF1D9BF0),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
          ),
          SwitchListTile(
            secondary: Icon(Icons.view_agenda_outlined, color: subtitleColor),
            title: Text(
              'Interactive Notifications',
              style: TextStyle(
                color: textColor,
                fontSize: 15,
                fontWeight: FontWeight.normal,
              ),
            ),
            subtitle: Text(
              'Show quick actions: Spark, Echo, and Silence',
              style: TextStyle(color: subtitleColor, fontSize: 12),
            ),
            value: _showActions,
            onChanged: (val) {
              HapticFeedback.selectionClick();
              _toggleActions(val);
            },
            activeThumbColor: const Color(0xFF1D9BF0),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
          ),

          _Header(title: 'Schedule'),
          _ComingSoonTile(
            icon: Icons.bedtime_outlined,
            title: 'Quiet Hours',
            subtitle: 'Silence notifications during set hours',
            textColor: textColor,
            subtitleColor: subtitleColor,
          ),
          _ComingSoonTile(
            icon: Icons.phone_android_outlined,
            title: 'Push Notifications',
            subtitle: 'Manage device-level push settings',
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

