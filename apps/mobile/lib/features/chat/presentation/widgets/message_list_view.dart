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

  bool _shouldShowDateDivider(List<MessageModel> messages, int index) {
    final realIndex = messages.length - 1 - index;
    final current = messages[realIndex];
    if (realIndex == 0) return true;
    final previous = messages[realIndex - 1];
    final curr = current.timestamp.toLocal();
    final prev = previous.timestamp.toLocal();
    return curr.year != prev.year ||
        curr.month != prev.month ||
        curr.day != prev.day;
  }

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
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.38),
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
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: MediaQuery.paddingOf(context).top + kToolbarHeight,
                  bottom: 8,
                ),
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final message = messages[messages.length - 1 - index];
                  final isPinned =
                      chat?.pinnedMessages.contains(message.messageId) ?? false;
                  final showDivider = _shouldShowDateDivider(messages, index);

                  return RepaintBoundary(
                    key: ValueKey(message.messageId),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (showDivider)
                          _DateDivider(date: message.timestamp),
                        MessageBubble(
                          message: message,
                          isMe: message.senderUid == myUid,
                          chatId: chatId,
                          callerAgeGroup: ageGroup,
                          otherUid: otherUid,
                          isPinned: isPinned,
                          onReply: onReply,
                          onLongPress: onLongPress,
                        ),
                      ],
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

class _DateDivider extends StatelessWidget {
  const _DateDivider({required this.date});
  final DateTime date;

  String _label() {
    final now = DateTime.now();
    final local = date.toLocal();
    final today = DateTime(now.year, now.month, now.day);
    final msgDay = DateTime(local.year, local.month, local.day);
    final diff = today.difference(msgDay).inDays;

    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    if (diff < 7) {
      const days = ['Monday','Tuesday','Wednesday','Thursday','Friday','Saturday','Sunday'];
      return days[local.weekday - 1];
    }
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    final showYear = local.year != now.year;
    return '${local.day} ${months[local.month - 1]}${showYear ? ' ${local.year}' : ''}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark
        ? const Color(0xFF1A1A2E).withValues(alpha: 0.85)
        : const Color(0xFFEEEBFF).withValues(alpha: 0.90);
    final textColor = isDark ? const Color(0xFF9B8FCC) : const Color(0xFF6D28D9);
    final lineColor = isDark ? const Color(0xFF2A2A4A) : const Color(0xFFCBC0F0);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 0.5,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [Colors.transparent, lineColor]),
              ),
            ),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 10),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: lineColor, width: 0.5),
            ),
            child: Text(
              _label(),
              style: TextStyle(
                color: textColor,
                fontSize: 11,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.3,
              ),
            ),
          ),
          Expanded(
            child: Container(
              height: 0.5,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [lineColor, Colors.transparent]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
