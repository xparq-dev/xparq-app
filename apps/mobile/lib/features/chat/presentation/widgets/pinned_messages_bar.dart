import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xparq_app/features/chat/presentation/providers/chat_providers.dart';

class PinnedMessagesBar extends ConsumerWidget {
  final String chatId;

  const PinnedMessagesBar({
    super.key,
    required this.chatId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pinnedAsync = ref.watch(pinnedMessagesProvider(chatId));

    return pinnedAsync.when(
      data: (messages) {
        if (messages.isEmpty) return const SizedBox.shrink();

        final latest = messages.last;
        final count = messages.length;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF1E3A5F).withValues(alpha: 0.5),
            border: const Border(
              bottom: BorderSide(color: Colors.white10, width: 0.5),
            ),
          ),
          child: Row(
            children: [
              const Icon(Icons.push_pin, size: 16, color: Color(0xFF4FC3F7)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PINNED MESSAGE${count > 1 ? " ($count)" : ""}',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF4FC3F7),
                        letterSpacing: 1.2,
                      ),
                    ),
                    Text(
                      latest.content,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (__, _) => const SizedBox.shrink(),
    );
  }
}
