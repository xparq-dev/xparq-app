import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xparq_app/features/chat/presentation/providers/chat_providers.dart';

class SilenceClusterDialog extends ConsumerWidget {
  final String chatId;

  const SilenceClusterDialog({super.key, required this.chatId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AlertDialog(
      title: const Text('Silence Cluster'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildOption(context, ref, '1 Hour', const Duration(hours: 1)),
          _buildOption(context, ref, '8 Hours', const Duration(hours: 8)),
          _buildOption(context, ref, '1 Day', const Duration(days: 1)),
          _buildOption(context, ref, '7 Days', const Duration(days: 7)),
          _buildOption(context, ref, 'Forever', null),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ],
    );
  }

  Widget _buildOption(
    BuildContext context,
    WidgetRef ref,
    String label,
    Duration? duration,
  ) {
    return ListTile(
      title: Text(label),
      onTap: () async {
        final until = duration != null ? DateTime.now().add(duration) : null;
        await ref.read(chatRepositoryProvider).silenceChat(chatId, until);
        if (context.mounted) Navigator.pop(context);
      },
    );
  }
}
