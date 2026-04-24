// lib/features/chat/screens/archived_list_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xparq_app/features/auth/providers/auth_providers.dart';
import 'package:go_router/go_router.dart';
import 'package:xparq_app/shared/router/app_router.dart';
import 'package:xparq_app/features/chat/presentation/providers/chat_providers.dart';
import 'package:xparq_app/features/chat/domain/models/chat_model.dart';
import 'package:xparq_app/shared/widgets/common/xparq_image.dart';
import 'package:xparq_app/features/chat/data/services/message_encryption_service.dart';

class ArchivedListScreen extends ConsumerWidget {
  const ArchivedListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chatsAsync = ref.watch(archivedChatsProvider);
    final myUid = ref.watch(authRepositoryProvider).currentUser?.id ?? '';

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Archived Signals',
          style: TextStyle(
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.7),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: chatsAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: Color(0xFF4FC3F7)),
        ),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (chats) {
          if (chats.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('📦', style: TextStyle(fontSize: 48)),
                  const SizedBox(height: 12),
                  Text(
                    'No archived signals',
                    style: TextStyle(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.38),
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: chats.length,
            itemBuilder: (context, index) {
              final chat = chats[index];
              final otherUid = chat.participants.firstWhere(
                (p) => p != myUid,
                orElse: () => chat.participants.first,
              );

              return Consumer(
                builder: (context, ref, _) {
                  final profileAsync = ref.watch(chatProfileProvider(otherUid));
                  final profile = profileAsync.valueOrNull;

                  final displayName = chat.isGroup
                      ? (chat.name ?? 'Group')
                      : (profile?.xparqName ?? 'Cluster');

                  final hasAvatar = chat.isGroup
                      ? (chat.groupAvatar?.isNotEmpty ?? false)
                      : (profile?.photoUrl.isNotEmpty ?? false);

                  final avatarUrl = chat.isGroup
                      ? chat.groupAvatar
                      : profile?.photoUrl;

                  return Dismissible(
                    key: Key(chat.chatId),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      color: const Color(0xFF4FC3F7),
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      child: const Icon(Icons.unarchive, color: Colors.white),
                    ),
                    onDismissed: (_) {
                      ref
                          .read(chatRepositoryProvider)
                          .toggleChatArchive(chat.chatId, false);
                    },
                    child: ListTile(
                      leading: CircleAvatar(
                        radius: 24,
                        backgroundColor: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.1),
                        backgroundImage: hasAvatar
                            ? XparqImage.getImageProvider(avatarUrl!)
                            : null,
                        child: !hasAvatar
                            ? Icon(
                                chat.isGroup ? Icons.group : Icons.person,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurface.withValues(alpha: 0.38),
                              )
                            : null,
                      ),
                      title: Text(
                        displayName,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: FutureBuilder<String>(
                        future: chat.lastMessage.isEmpty
                            ? Future.value('')
                            : MessageEncryptionService.decrypt(
                                chat.lastMessage,
                                chat.chatId,
                              ),
                        builder: (context, snapshot) {
                          final preview = snapshot.data ?? '...';
                          return Text(
                            preview.isNotEmpty ? preview : 'No messages',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurface.withValues(alpha: 0.5),
                              fontSize: 13,
                            ),
                          );
                        },
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.unarchive_outlined),
                        onPressed: () {
                          ref
                              .read(chatRepositoryProvider)
                              .toggleChatArchive(chat.chatId, false);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Signal unarchived')),
                          );
                        },
                      ),
                      onTap: () {
                        context.push(
                          '${AppRoutes.chat}/${chat.chatId}/${chat.isGroup ? 'group' : otherUid}',
                        );
                      },
                      onLongPress: () =>
                          _showChatActionMenu(context, ref, chat, otherUid),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  void _showChatActionMenu(
    BuildContext context,
    WidgetRef ref,
    ChatModel chat,
    String otherUid,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.unarchive_outlined),
              title: const Text('Unarchive'),
              onTap: () {
                Navigator.pop(ctx);
                ref
                    .read(chatRepositoryProvider)
                    .toggleChatArchive(chat.chatId, false);
              },
            ),
            ListTile(
              leading: const Icon(Icons.notifications_off_outlined),
              title: const Text('Silence'),
              onTap: () {
                Navigator.pop(ctx);
                _showSilenceDialog(context, ref, chat.chatId);
              },
            ),
            if (chat.isGroup)
              ListTile(
                leading: const Icon(
                  Icons.exit_to_app,
                  color: Color(0xFFFF4444),
                ),
                title: const Text(
                  'Leave Group',
                  style: TextStyle(color: Color(0xFFFF4444)),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _confirmLeaveGroup(context, ref, chat.chatId);
                },
              )
            else
              ListTile(
                leading: const Icon(
                  Icons.delete_outline,
                  color: Color(0xFFFF4444),
                ),
                title: const Text(
                  'Delete Chat',
                  style: TextStyle(color: Color(0xFFFF4444)),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _confirmDeleteChat(context, ref, chat.chatId);
                },
              ),
          ],
        ),
      ),
    );
  }

  void _showSilenceDialog(BuildContext context, WidgetRef ref, String chatId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Silence Chat'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _silenceOption(context, ref, chatId, '1 hour', 1),
            _silenceOption(context, ref, chatId, '8 hours', 8),
            _silenceOption(context, ref, chatId, '1 day', 24),
            _silenceOption(context, ref, chatId, '7 days', 168),
            _silenceOption(context, ref, chatId, 'Forever', -1),
          ],
        ),
      ),
    );
  }

  Widget _silenceOption(
    BuildContext context,
    WidgetRef ref,
    String chatId,
    String label,
    int hours,
  ) {
    return ListTile(
      title: Text(label),
      onTap: () {
        final until = hours == -1
            ? null
            : DateTime.now().add(Duration(hours: hours));
        ref.read(chatRepositoryProvider).silenceChat(chatId, until);
        Navigator.pop(context);
      },
    );
  }

  Future<void> _confirmDeleteChat(
    BuildContext context,
    WidgetRef ref,
    String chatId,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Chat?'),
        content: const Text(
          'This will erase the entire star system of this conversation. It cannot be recovered.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Delete',
              style: TextStyle(color: Color(0xFFFF4444)),
            ),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await ref.read(chatRepositoryProvider).deleteChat(chatId);
    }
  }

  Future<void> _confirmLeaveGroup(
    BuildContext context,
    WidgetRef ref,
    String chatId,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Leave Group?'),
        content: const Text(
          'Are you sure you want to leave this group star system? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Leave',
              style: TextStyle(color: Color(0xFFFF4444)),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final myUid = ref.read(authRepositoryProvider).currentUser?.id ?? '';
      if (myUid.isNotEmpty) {
        await ref.read(chatRepositoryProvider).leaveGroup(chatId, myUid);
      }
    }
  }
}

