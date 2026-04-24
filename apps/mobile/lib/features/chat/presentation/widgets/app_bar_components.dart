// lib/features/chat/widgets/app_bar_components.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:xparq_app/features/auth/models/planet_model.dart';
import 'package:xparq_app/features/chat/domain/models/chat_model.dart';

class ChatAppBarTitle extends StatelessWidget {
  final bool isGroup;
  final ChatModel? chat;
  final PlanetModel? otherProfile;
  final PlanetModel? otherPresence;
  final ThemeData theme;

  const ChatAppBarTitle({
    super.key,
    required this.isGroup,
    this.chat,
    this.otherProfile,
    this.otherPresence,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final profile = otherProfile;
    final presence = otherPresence;
    final isOnline = presence?.isOnline ?? false;
    final displayName = isGroup
        ? (chat?.groupName ?? 'Cluster')
        : (profile != null
              ? (profile.handle != null && profile.handle!.isNotEmpty
                  ? '${profile.xparqName} (@${profile.handle})'
                  : profile.xparqName)
              : 'Explorer');

    return Row(
      children: [
        _buildAvatar(isOnline),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                displayName,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              if (!isGroup)
                Text(
                  isOnline
                      ? 'Active on Orbit'
                      : _getLastSeenText(otherPresence?.lastSeen),
                  style: TextStyle(
                    fontSize: 11,
                    color: isOnline
                        ? const Color(0xFF4FC3F7)
                        : theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    fontWeight: isOnline ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              if (isGroup)
                Text(
                  '${chat?.participants.length ?? 0} iXPARQs',
                  style: TextStyle(
                    fontSize: 11,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAvatar(bool isOnline) {
    final avatarUrl = isGroup ? chat?.groupIcon : otherProfile?.photoUrl;
    return Stack(
      children: [
        CircleAvatar(
          radius: 18,
          backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
              ? NetworkImage(avatarUrl)
              : null,
          child: avatarUrl == null || avatarUrl.isEmpty
              ? Icon(isGroup ? Icons.groups : Icons.person, size: 20)
              : null,
        ),
        if (!isGroup && isOnline)
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: Colors.green,
                shape: BoxShape.circle,
                border: Border.all(
                  color: theme.scaffoldBackgroundColor,
                  width: 2,
                ),
              ),
            ),
          ),
      ],
    );
  }

  String _getLastSeenText(DateTime? lastSeen) {
    if (lastSeen == null) return '';
    final now = DateTime.now().toUtc();
    final diff = now.difference(lastSeen);
    if (diff.inMinutes < 1) return '- Just now';
    if (diff.inMinutes < 60) return '- Last seen: ${diff.inMinutes}m ago';
    final midnight = DateTime(now.year, now.month, now.day);
    if (lastSeen.isAfter(midnight)) {
      return '- Last seen: ${DateFormat('HH:mm').format(lastSeen.toLocal())}';
    }
    final yesterday = midnight.subtract(const Duration(days: 1));
    if (lastSeen.isAfter(yesterday)) {
      return '- Last seen: Yesterday ${DateFormat('HH:mm').format(lastSeen.toLocal())}';
    }
    return '- Last seen: ${DateFormat('d MMM HH:mm').format(lastSeen.toLocal())}';
  }
}
