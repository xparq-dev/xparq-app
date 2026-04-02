import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:xparq_app/core/widgets/glass_card.dart';
import 'package:xparq_app/features/chat/models/message_model.dart';

class ChatMessageTile extends StatelessWidget {
  ChatMessageTile({super.key, required this.message, required this.isMe});

  final MessageModel message;
  final bool isMe;

  final DateFormat _timeFormat = DateFormat('HH:mm');

  @override
  Widget build(BuildContext context) {
    final bubbleColor = isMe
        ? const Color(0xFF1D9BF0)
        : Theme.of(context).cardColor;
    final textColor = isMe
        ? Colors.white
        : Theme.of(context).colorScheme.onSurface;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: GlassCard(
          color: bubbleColor,
          opacity: isMe ? 0.9 : 0.06,
          borderRadius: BorderRadius.circular(20),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                message.content,
                style: TextStyle(color: textColor, fontSize: 15, height: 1.4),
              ),
              const SizedBox(height: 8),
              Text(
                _timeFormat.format(message.timestamp.toLocal()),
                style: TextStyle(
                  color: textColor.withValues(alpha: 0.72),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
