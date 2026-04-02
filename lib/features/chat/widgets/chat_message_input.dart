import 'package:flutter/material.dart';
import 'package:xparq_app/core/widgets/galaxy_button.dart';
import 'package:xparq_app/core/widgets/glass_card.dart';

class ChatMessageInput extends StatelessWidget {
  const ChatMessageInput({
    super.key,
    required this.controller,
    required this.isSending,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool isSending;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(12),
      borderRadius: BorderRadius.circular(24),
      opacity: 0.08,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              minLines: 1,
              maxLines: 4,
              enabled: !isSending,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => onSend(),
              decoration: const InputDecoration(
                hintText: 'Type a message...',
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 14,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 110,
            child: GalaxyButton(
              label: 'Send',
              isLoading: isSending,
              onTap: isSending ? null : onSend,
            ),
          ),
        ],
      ),
    );
  }
}
