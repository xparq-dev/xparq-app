import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xparq_app/features/chat/presentation/providers/chat_providers.dart';

class TypingIndicator extends ConsumerWidget {
  final String chatId;
  final String otherUid;

  const TypingIndicator({
    super.key,
    required this.chatId,
    required this.otherUid,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final typers = ref.watch(typingStateProvider(chatId));
    if (typers.isEmpty) return const SizedBox.shrink();

    final isGroup = otherUid == 'group';
    final isLandscape = MediaQuery.orientationOf(context) == Orientation.landscape;
    String typingText = 'กำลังพิมพ์...';

    if (isGroup) {
      if (typers.length == 1) {
        final typerProfile = ref.watch(chatProfileProvider(typers.first)).valueOrNull;
        final name = typerProfile?.xparqName ?? 'มีคน';
        typingText = '$name กำลังพิมพ์...';
      } else {
        typingText = '${typers.length} คน กำลังพิมพ์...';
      }
    }

    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Text(
          typingText,
          style: TextStyle(
            fontSize: isLandscape ? 10 : 12,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
            fontStyle: FontStyle.italic,
          ),
        ),
      ),
    );
  }
}
