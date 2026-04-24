// lib/features/chat/widgets/message_bubble_components.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:xparq_app/l10n/app_localizations.dart';
import 'package:xparq_app/features/chat/domain/models/chat_model.dart';
import 'package:xparq_app/features/chat/data/services/signal/encrypted_image_widget.dart';

class MessageReplyHeader extends StatelessWidget {
  final MessageModel message;
  final bool isMe;

  const MessageReplyHeader({
    super.key,
    required this.message,
    required this.isMe,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 4, left: 4, right: 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: (isMe ? Colors.white10 : Colors.black12).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border(
          left: BorderSide(
            color: const Color(0xFF4FC3F7).withValues(alpha: 0.7),
            width: 3,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message.replyToName ?? 'Sparq',
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Color(0xFF4FC3F7),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            message.replyToPreview ?? '',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              color: (isDark ? Colors.white60 : Colors.black54),
            ),
          ),
        ],
      ),
    );
  }
}

class MessageNSFWWarning extends StatelessWidget {
  final bool isRevealed;
  final VoidCallback onTap;

  const MessageNSFWWarning({
    super.key,
    required this.isRevealed,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4, left: 4),
      child: GestureDetector(
        onTap: onTap,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              color: Color(0xFFFF6B6B),
              size: 12,
            ),
            const SizedBox(width: 4),
            Text(
              isRevealed
                  ? AppLocalizations.of(context)!.sensitiveTapToHide
                  : AppLocalizations.of(context)!.sensitiveTapToReveal,
              style: const TextStyle(color: Color(0xFFFF6B6B), fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

class MessageImageContent extends StatelessWidget {
  final String displayContent;

  const MessageImageContent({super.key, required this.displayContent});

  @override
  Widget build(BuildContext context) {
    try {
      final payload = jsonDecode(displayContent);
      return Padding(
        padding: const EdgeInsets.only(bottom: 8.0),
        child: EncryptedImageWidget(
          url: (payload['url'] as String?) ?? '',
          storagePath: (payload['storage_path'] as String?) ?? '',
          mediaKeyBase64: (payload['media_key'] as String?) ?? '',
        ),
      );
    } catch (_) {
      return const Text(
        '🔒 [Encrypted Media Error]',
        style: TextStyle(fontStyle: FontStyle.italic),
      );
    }
  }
}

class MessageStatus extends StatelessWidget {
  final MessageModel message;
  final bool isMe;
  static final DateFormat _timeFormatter = DateFormat('HH:mm');

  const MessageStatus({super.key, required this.message, required this.isMe});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _timeFormatter.format(message.timestamp),
          style: TextStyle(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.38),
            fontSize: 10,
          ),
        ),
        if (isMe) ...[
          const SizedBox(width: 4),
          Icon(
            message.read
                ? Icons.done_all
                : message.delivered
                ? Icons.done_all
                : Icons.done,
            size: 12,
            color: message.read
                ? const Color(0xFF4FC3F7)
                : theme.colorScheme.onSurface.withValues(alpha: 0.38),
          ),
        ],
        if (message.isOfflineRelay)
          const Padding(
            padding: EdgeInsetsDirectional.only(start: 4),
            child: Icon(Icons.bluetooth, size: 10, color: Color(0xFF7C4DFF)),
          ),
      ],
    );
  }
}

class MessageSparkBadge extends StatelessWidget {
  final int count;
  final VoidCallback onTap;

  const MessageSparkBadge({
    super.key,
    required this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.amber.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Colors.amber.withValues(alpha: 0.3),
              width: 0.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.bolt, size: 10, color: Colors.amber),
              const SizedBox(width: 2),
              Text(
                '$count',
                style: const TextStyle(
                  color: Colors.amber,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
