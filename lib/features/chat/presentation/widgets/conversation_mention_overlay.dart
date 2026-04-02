import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/signal_chat_controller.dart';
import 'package:xparq_app/core/widgets/glass_card.dart';

class MentionOverlay extends ConsumerWidget {
  final String chatId;
  final TextEditingController textController;

  const MentionOverlay({
    super.key,
    required this.chatId,
    required this.textController,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(signalChatControllerProvider(chatId));
    final controller = ref.read(signalChatControllerProvider(chatId).notifier);

    if (state.mentionSuggestions.isEmpty) return const SizedBox.shrink();

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
            itemCount: state.mentionSuggestions.length,
            itemBuilder: (ctx, index) {
              final user = state.mentionSuggestions[index];
              return ListTile(
                leading: CircleAvatar(
                  radius: 14,
                  backgroundImage: user.photoUrl.isNotEmpty ? NetworkImage(user.photoUrl) : null,
                  child: user.photoUrl.isEmpty ? const Icon(Icons.person) : null,
                ),
                title: Text(user.xparqName),
                subtitle: Text('@${user.handle}'),
                onTap: () {
                  final text = textController.text;
                  final selection = textController.selection;
                  final query = text.substring(0, selection.baseOffset);
                  final lastAt = query.lastIndexOf('@');

                  final newText = '${text.substring(0, lastAt)}@${user.handle} ${text.substring(selection.baseOffset)}';

                  textController.text = newText;
                  textController.selection = TextSelection.collapsed(
                    offset: lastAt + (user.handle?.length ?? 0) + 2,
                  );

                  controller.addMention(user.id);
                  controller.setMentionSuggestions([]);
                },
              );
            },
          ),
        ),
      ),
    );
  }
}
