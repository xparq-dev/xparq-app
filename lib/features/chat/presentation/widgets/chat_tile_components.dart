// lib/features/chat/widgets/chat_tile_components.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xparq_app/shared/widgets/common/xparq_image.dart';
import 'package:xparq_app/features/chat/domain/models/chat_model.dart';
import 'package:xparq_app/features/chat/presentation/providers/chat_providers.dart';

class ChatAvatar extends StatelessWidget {
  final String? avatarUrl;
  final bool hasAvatar;
  final String avatarInitials;
  final bool isGroup;
  final bool isOnline;

  const ChatAvatar({
    super.key,
    required this.avatarUrl,
    required this.hasAvatar,
    required this.avatarInitials,
    required this.isGroup,
    required this.isOnline,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        CircleAvatar(
          radius: 26,
          backgroundColor: theme.colorScheme.onSurface.withValues(alpha: 0.1),
          backgroundImage: hasAvatar
              ? XparqImage.getImageProvider(avatarUrl!)
              : null,
          child: !hasAvatar
              ? (isGroup
                    ? const Icon(Icons.group, color: Colors.white70)
                    : Text(
                        avatarInitials,
                        style: TextStyle(
                          color: theme.colorScheme.onSurface,
                          fontWeight: FontWeight.bold,
                        ),
                      ))
              : null,
        ),
        if (isOnline)
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: const Color(0xFF4CAF50),
                shape: BoxShape.circle,
                border: Border.all(color: theme.colorScheme.surface, width: 2),
              ),
            ),
          ),
      ],
    );
  }
}

class ChatTileTitle extends StatelessWidget {
  final ChatModel chat;
  final String displayName;

  const ChatTileTitle({
    super.key,
    required this.chat,
    required this.displayName,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (chat.isPinned)
          const Padding(
            padding: EdgeInsets.only(right: 6),
            child: Icon(Icons.star, color: Color(0xFFFF9800), size: 16),
          ),
        Expanded(
          child: Text(
            displayName,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.bold,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (chat.isSensitive)
          const Padding(
            padding: EdgeInsetsDirectional.only(start: 6),
            child: Icon(
              Icons.warning_amber_rounded,
              color: Color(0xFFFF6B6B),
              size: 14,
            ),
          ),
        if (chat.unreadCount > 0)
          Container(
            margin: const EdgeInsets.only(left: 8),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFFFF4444),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              chat.unreadCount.toString(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
      ],
    );
  }
}

class ActionMenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? iconColor;
  final Color? labelColor;

  const ActionMenuItem({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.iconColor,
    this.labelColor,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: iconColor),
      title: Text(label, style: TextStyle(color: labelColor)),
      onTap: onTap,
    );
  }
}

class SilenceOption extends ConsumerWidget {
  final String chatId;
  final String label;
  final int hours;

  const SilenceOption({
    super.key,
    required this.chatId,
    required this.label,
    required this.hours,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      title: Text(label),
      onTap: () {
        final until = hours == -1
            ? null
            : DateTime.now().add(Duration(hours: hours));
        unawaited(
          ref.read(chatSettingsRepositoryProvider).silenceChat(chatId, until),
        );
        Navigator.pop(context);
      },
    );
  }
}

class ConfirmationDialog extends StatelessWidget {
  final String title;
  final String content;
  final String confirmLabel;
  final bool isDangerous;

  const ConfirmationDialog({
    super.key,
    required this.title,
    required this.content,
    required this.confirmLabel,
    this.isDangerous = false,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(title),
      content: Text(content),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(
            confirmLabel,
            style: TextStyle(
              color: isDangerous ? const Color(0xFFFF4444) : null,
            ),
          ),
        ),
      ],
    );
  }
}
