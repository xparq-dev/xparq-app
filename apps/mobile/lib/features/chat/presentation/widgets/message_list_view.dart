import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xparq_app/shared/enums/age_group.dart';
import 'package:xparq_app/l10n/app_localizations.dart';
import 'package:xparq_app/features/chat/domain/models/chat_model.dart';
import 'package:xparq_app/features/chat/presentation/providers/chat_providers.dart';
import 'message_bubble.dart';

class MessageListView extends ConsumerWidget {
  final String chatId;
  final String myUid;
  final String otherUid;
  final AgeGroup ageGroup;
  final ChatModel? chat;
  final ScrollController scrollController;
  final void Function(MessageModel) onReply;
  final void Function(Offset, MessageModel)? onLongPress;
  final VoidCallback? onTap;

  const MessageListView({
    super.key,
    required this.chatId,
    required this.myUid,
    required this.otherUid,
    required this.ageGroup,
    this.chat,
    required this.scrollController,
    required this.onReply,
    this.onLongPress,
    this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final messagesAsync = ref.watch(displayMessagesProvider(chatId));

    return messagesAsync.when(
      skipLoadingOnReload: true,
      loading: () => const Center(
        child: CircularProgressIndicator(color: Color(0xFF4FC3F7)),
      ),
      error: (e, _) => Center(
        child: Text(AppLocalizations.of(context)!.errorPrefix(e.toString())),
      ),
      data: (messages) {
        if (messages.isEmpty) {
          return Center(
            child: Text(
              'Send the first signal 📡',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38),
              ),
            ),
          );
        }

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Align(
            alignment: Alignment.topCenter,
            child: MediaQuery.removeViewInsets(
              context: context,
              removeBottom: true,
              child: ListView.builder(
                controller: scrollController,
                reverse: true,
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: MediaQuery.paddingOf(context).top + kToolbarHeight,
                  bottom: 8,
                ),
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final message = messages[messages.length - 1 - index];
                  final isPinned = chat?.pinnedMessages.contains(message.messageId) ?? false;
                  return RepaintBoundary(
                    key: ValueKey(message.messageId),
                    child: MessageBubble(
                      message: message,
                      isMe: message.senderUid == myUid,
                      chatId: chatId,
                      callerAgeGroup: ageGroup,
                      otherUid: otherUid,
                      isPinned: isPinned,
                      onReply: onReply,
                      onLongPress: onLongPress,
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}
