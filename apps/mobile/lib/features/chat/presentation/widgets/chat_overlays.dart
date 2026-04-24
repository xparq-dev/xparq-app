// lib/features/chat/widgets/chat_overlays.dart

import 'package:flutter/material.dart';
import 'package:xparq_app/shared/widgets/ui/cards/glass_card.dart';
import 'package:xparq_app/features/auth/models/planet_model.dart';
import 'package:xparq_app/features/chat/domain/models/chat_model.dart';

class MentionSuggestionsOverlay extends StatelessWidget {
  final List<PlanetModel> suggestions;
  final void Function(PlanetModel) onMentionSelected;

  const MentionSuggestionsOverlay({
    super.key,
    required this.suggestions,
    required this.onMentionSelected,
  });

  @override
  Widget build(BuildContext context) {
    if (suggestions.isEmpty) return const SizedBox.shrink();

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: GlassCard(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        child: Container(
          constraints: const BoxConstraints(maxHeight: 200),
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: suggestions.length,
            itemBuilder: (ctx, index) {
              final user = suggestions[index];
              return ListTile(
                leading: CircleAvatar(
                  radius: 14,
                  backgroundImage: user.photoUrl.isNotEmpty
                      ? NetworkImage(user.photoUrl)
                      : null,
                  child: user.photoUrl.isEmpty
                      ? const Icon(Icons.person)
                      : null,
                ),
                title: Text(user.xparqName),
                subtitle: Text('@${user.handle}'),
                onTap: () => onMentionSelected(user),
              );
            },
          ),
        ),
      ),
    );
  }
}

class ReplyPreviewOverlay extends StatelessWidget {
  final MessageModel? replyingTo;
  final VoidCallback onCancel;

  const ReplyPreviewOverlay({
    super.key,
    this.replyingTo,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    if (replyingTo == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.1),
        border: Border(
          top: BorderSide(
            color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 32,
            decoration: BoxDecoration(
              color: const Color(0xFF4FC3F7),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  (replyingTo!.metadata['sender_name'] as String?) ?? 'Sparq',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF4FC3F7),
                  ),
                ),
                Text(
                  replyingTo!.decryptedContent ?? replyingTo!.content,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            onPressed: onCancel,
          ),
        ],
      ),
    );
  }
}
