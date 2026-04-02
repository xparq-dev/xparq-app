// lib/features/chat/widgets/chat_tile.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:xparq_app/l10n/app_localizations.dart';
import 'package:xparq_app/features/chat/domain/models/chat_model.dart';
import 'package:xparq_app/features/chat/presentation/providers/chat_providers.dart';
import 'package:xparq_app/features/chat/data/services/message_encryption_service.dart';
import 'package:xparq_app/features/auth/providers/auth_providers.dart';
import 'package:xparq_app/core/router/app_router.dart';
import 'package:go_router/go_router.dart';
import 'package:xparq_app/features/block_report/providers/block_report_providers.dart';
import 'chat_tile_components.dart';

class ChatTile extends ConsumerWidget {
  final ChatModel chat;
  final String myUid;

  const ChatTile({super.key, required this.chat, required this.myUid});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSelfChat = chat.participants.every((p) => p == myUid);
    final otherUid = chat.participants.firstWhere(
      (p) => p != myUid,
      orElse: () => chat.participants.first,
    );

    final profileAsync = ref.watch(chatProfileProvider(otherUid));
    final profile =
        profileAsync.valueOrNull ?? ref.watch(profileCacheProvider)[otherUid];

    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    final displayName = chat.isGroup
        ? (chat.name ?? l10n.chatListGroupDefaultName)
        : (isSelfChat
              ? l10n.chatListSavedMe.toUpperCase()
              : (profile?.xparqName ??
                    (otherUid.length > 8
                        ? otherUid.substring(0, 8)
                        : otherUid)));

    final avatarInitials = chat.isGroup
        ? (chat.name?.isNotEmpty == true
              ? chat.name!.substring(0, 1).toUpperCase()
              : 'G')
        : (isSelfChat
              ? 'ME'
              : (profile?.xparqName.isNotEmpty == true
                    ? profile!.xparqName.substring(0, 1).toUpperCase()
                    : (otherUid.length > 2
                          ? otherUid.substring(0, 2).toUpperCase()
                          : otherUid.toUpperCase())));

    final hasAvatar = chat.isGroup
        ? (chat.groupAvatar?.isNotEmpty ?? false)
        : (!isSelfChat && (profile?.photoUrl.isNotEmpty ?? false));

    final avatarUrl = chat.isGroup ? chat.groupAvatar : profile?.photoUrl;
    final isOnline =
        !chat.isGroup && !isSelfChat && (profile?.isActuallyOnline ?? false);

    return RepaintBoundary(
      child: FutureBuilder<String>(
        // Optimization: Use a constant key or memoize the future if needed,
        // but ChatModel.lastMessage change will trigger a rebuild anyway.
        future: chat.lastMessage.isEmpty
            ? Future.value('')
            : MessageEncryptionService.decrypt(chat.lastMessage, chat.chatId),
        builder: (context, snapshot) {
          final preview = snapshot.data ?? '\u2026';
          final showPreview =
              preview.isNotEmpty && preview != l10n.chatListEncryptedMessage
              ? preview
              : preview.isEmpty
              ? l10n.chatListStartConversation
              : l10n.chatListEncryptedMessage;

          return ListTile(
            tileColor: Colors.transparent,
            leading: ChatAvatar(
              avatarUrl: avatarUrl,
              hasAvatar: hasAvatar,
              avatarInitials: avatarInitials,
              isGroup: chat.isGroup,
              isOnline: isOnline,
            ),
            title: ChatTileTitle(chat: chat, displayName: displayName),
            subtitle: Text(
              showPreview,
              style: TextStyle(
                color: chat.isSensitive
                    ? const Color(0xFFFF6B6B).withOpacity(0.7)
                    : theme.colorScheme.onSurface.withOpacity(0.38),
                fontSize: 13,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
            trailing: chat.lastAt != null
                ? Text(
                    DateFormat('HH:mm').format(chat.lastAt!),
                    style: TextStyle(
                      color: theme.colorScheme.onSurface.withOpacity(
                        0.38,
                      ),
                      fontSize: 11,
                    ),
                  )
                : null,
            onTap: () => unawaited(
              context.push(
                '${AppRoutes.chat}/${chat.chatId}/${chat.isGroup ? 'group' : otherUid}',
              ),
            ),
            onLongPress: () =>
                _showChatActionMenu(context, ref, chat, otherUid),
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
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ActionMenuItem(
              icon: chat.isPinned ? Icons.star_border : Icons.star,
              label: chat.isPinned ? 'Unpin Star' : 'Pin Star',
              iconColor: const Color(0xFFFF9800),
              onTap: () {
                Navigator.pop(ctx);
                _togglePin(context, ref, chat);
              },
            ),
            ActionMenuItem(
              icon: Icons.archive_outlined,
              label: 'Archive',
              onTap: () {
                Navigator.pop(ctx);
                unawaited(
                  ref
                      .read(chatSettingsRepositoryProvider)
                      .toggleChatArchive(chat.chatId, !chat.isArchived),
                );
              },
            ),
            ActionMenuItem(
              icon: Icons.notifications_off_outlined,
              label: 'Silence',
              onTap: () {
                Navigator.pop(ctx);
                _showSilenceDialog(context, ref, chat.chatId);
              },
            ),
            if (!chat.isGroup &&
                otherUid != ref.read(authRepositoryProvider).currentUser?.id)
              ActionMenuItem(
                icon: Icons.block,
                label: 'Black Hole (Block User)',
                labelColor: const Color(0xFFFF4444),
                onTap: () {
                  Navigator.pop(ctx);
                  _confirmBlock(context, ref, otherUid);
                },
              ),
            if (chat.isGroup)
              ActionMenuItem(
                icon: Icons.exit_to_app,
                label: 'Leave Group',
                labelColor: const Color(0xFFFF4444),
                onTap: () {
                  Navigator.pop(ctx);
                  _confirmLeaveGroup(context, ref, chat.chatId);
                },
              )
            else
              ActionMenuItem(
                icon: Icons.delete_outline,
                label: 'Delete Chat',
                labelColor: const Color(0xFFFF4444),
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

  Future<void> _togglePin(
    BuildContext context,
    WidgetRef ref,
    ChatModel chat,
  ) async {
    if (!chat.isPinned) {
      final pinnedCount =
          ref
              .read(myChatsProvider)
              .valueOrNull
              ?.where((c) => c.isPinned)
              .length ??
          0;
      if (pinnedCount >= 5) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('You can only pin up to 5 chats.')),
          );
        }
        return;
      }
    }
    await ref
        .read(chatSettingsRepositoryProvider)
        .toggleChatPin(chat.chatId, !chat.isPinned);
  }

  void _showSilenceDialog(BuildContext context, WidgetRef ref, String chatId) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Silence Chat'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SilenceOption(chatId: chatId, label: '1 hour', hours: 1),
            SilenceOption(chatId: chatId, label: '8 hours', hours: 8),
            SilenceOption(chatId: chatId, label: '1 day', hours: 24),
            SilenceOption(chatId: chatId, label: '7 days', hours: 168),
            SilenceOption(chatId: chatId, label: 'Forever', hours: -1),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmBlock(
    BuildContext context,
    WidgetRef ref,
    String targetUid,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => const ConfirmationDialog(
        title: 'Black Hole (Block User)?',
        content:
            'This user will disappear into the void. They won\'t be able to contact you or see your presence in Radar.',
        confirmLabel: 'Block',
        isDangerous: true,
      ),
    );
    if (confirm == true) {
      await ref.read(blockNotifierProvider.notifier).block(targetUid);
    }
  }

  Future<void> _confirmDeleteChat(
    BuildContext context,
    WidgetRef ref,
    String chatId,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => const ConfirmationDialog(
        title: 'Delete Chat?',
        content:
            'This will erase the entire star system of this conversation. It cannot be recovered.',
        confirmLabel: 'Delete',
        isDangerous: true,
      ),
    );
    if (confirm == true) {
      await ref.read(chatBaseRepositoryProvider).deleteChat(chatId);
    }
  }

  Future<void> _confirmLeaveGroup(
    BuildContext context,
    WidgetRef ref,
    String chatId,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => const ConfirmationDialog(
        title: 'Leave Group?',
        content:
            'Are you sure you want to leave this group star system? This action cannot be undone.',
        confirmLabel: 'Leave',
        isDangerous: true,
      ),
    );

    if (confirm == true) {
      final myUid = ref.read(authRepositoryProvider).currentUser?.id ?? '';
      if (myUid.isNotEmpty) {
        await ref.read(chatBaseRepositoryProvider).leaveGroup(chatId, myUid);
      }
    }
  }
}
