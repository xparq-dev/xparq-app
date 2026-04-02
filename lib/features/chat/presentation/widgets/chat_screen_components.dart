// lib/features/chat/widgets/chat_screen_components.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xparq_app/core/enums/age_group.dart';
import 'package:xparq_app/features/chat/domain/models/chat_model.dart';
import 'package:xparq_app/features/chat/presentation/providers/chat_providers.dart';
import 'package:xparq_app/features/chat/presentation/widgets/message_bubble.dart';

class ChatMessagesList extends ConsumerWidget {
  final String chatId;
  final String myUid;
  final String otherUid;
  final ScrollController scrollController;
  final AgeGroup ageGroup;
  final ChatModel? chat;
  final void Function(String) onPlanetTap;
  final void Function(MessageModel) onReply;
  final void Function(Offset, MessageModel)? onLongPress;

  const ChatMessagesList({
    super.key,
    required this.chatId,
    required this.myUid,
    required this.otherUid,
    required this.scrollController,
    required this.ageGroup,
    this.chat,
    required this.onPlanetTap,
    required this.onReply,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final messagesAsync = ref.watch(displayMessagesProvider(chatId));

    return messagesAsync.when(
      skipLoadingOnReload: true,
      loading: () => const Center(
        child: CircularProgressIndicator(color: Color(0xFF4FC3F7)),
      ),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (messages) {
        if (messages.isEmpty) {
          return Center(
            child: Text(
              'Send the first signal 📡',
              style: TextStyle(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withOpacity(0.38),
              ),
            ),
          );
        }

        return ListView.builder(
          controller: scrollController,
          reverse: true,
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: messages.length,
          itemBuilder: (context, index) {
            final message = messages[messages.length - 1 - index];
            final isPinned =
                chat?.pinnedMessages.contains(message.messageId) ?? false;

            return RepaintBoundary(
              key: ValueKey(message.messageId),
              child: MessageBubble(
                message: message,
                isMe: message.senderUid == myUid,
                chatId: chatId,
                callerAgeGroup: ageGroup,
                otherUid: otherUid,
                isPinned: isPinned,
                onPlanetTap: () => onPlanetTap(message.senderUid),
                onReply: onReply,
                onLongPress: onLongPress,
              ),
            );
          },
        );
      },
    );
  }
}

class ChatTypingIndicator extends ConsumerWidget {
  final String chatId;
  final String otherUid;
  final bool isLandscape;
  final bool isSpamMode;

  const ChatTypingIndicator({
    super.key,
    required this.chatId,
    required this.otherUid,
    required this.isLandscape,
    this.isSpamMode = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (isSpamMode) return const SizedBox.shrink();

    final typers = ref.watch(typingStateProvider(chatId));
    if (typers.isEmpty) return const SizedBox.shrink();

    String text = 'กำลังพิมพ์...';
    if (otherUid == 'group') {
      if (typers.length == 1) {
        final name =
            ref
                .watch(chatProfileProvider(typers.first))
                .valueOrNull
                ?.xparqName ??
            'มีคน';
        text = '$name กำลังพิมพ์...';
      } else {
        text = '${typers.length} คน กำลังพิมพ์...';
      }
    }

    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Text(
          text,
          style: TextStyle(
            fontSize: isLandscape ? 10 : 12,
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withOpacity(0.5),
            fontStyle: FontStyle.italic,
          ),
        ),
      ),
    );
  }
}
