// lib/features/chat/widgets/chat_banners.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xparq_app/features/chat/presentation/providers/chat_providers.dart';

class PinnedMessagesBar extends ConsumerWidget {
  final String chatId;
  final VoidCallback? onClose;

  const PinnedMessagesBar({super.key, required this.chatId, this.onClose});

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
                      'PINNED MESSAGE${count > 1 ? ' ($count)' : ''}',
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
              if (onClose != null)
                IconButton(
                  icon: const Icon(
                    Icons.close,
                    size: 16,
                    color: Colors.white38,
                  ),
                  onPressed: onClose,
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

class SpamWarningBanner extends StatelessWidget {
  final bool isLandscape;
  final VoidCallback onDelete;
  final VoidCallback onAccept;

  const SpamWarningBanner({
    super.key,
    required this.isLandscape,
    required this.onDelete,
    required this.onAccept,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 12,
        vertical: isLandscape ? 6 : 12,
      ),
      color: Colors.red.withValues(alpha: 0.1),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Guardian Shield: This signal is from a high-risk creator.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.redAccent,
              fontSize: isLandscape ? 11 : 13,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (!isLandscape) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildAction('Delete', Colors.redAccent, isLandscape, onDelete),
                const SizedBox(width: 16),
                _buildAction(
                  'Accept',
                  const Color(0xFF4FC3F7),
                  isLandscape,
                  onAccept,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAction(
    String label,
    Color color,
    bool isLandscape,
    VoidCallback onPressed,
  ) {
    return SizedBox(
      height: isLandscape ? 30 : 36,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: color.withValues(alpha: 0.1),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          elevation: 0,
        ),
        onPressed: onPressed,
        child: Text(label, style: TextStyle(color: color, fontSize: 12)),
      ),
    );
  }
}

class NSFWSensitiveBanner extends StatelessWidget {
  final bool isLandscape;

  const NSFWSensitiveBanner({super.key, required this.isLandscape});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: const Color(0xFF7C4DFF).withValues(alpha: 0.15),
      padding: EdgeInsets.symmetric(
        horizontal: 16,
        vertical: isLandscape ? 4 : 6,
      ),
      child: Text(
        'âš ï¸ Black Hole Zone active',
        style: TextStyle(
          color: const Color(0xFF7C4DFF),
          fontSize: isLandscape ? 10 : 12,
        ),
      ),
    );
  }
}
