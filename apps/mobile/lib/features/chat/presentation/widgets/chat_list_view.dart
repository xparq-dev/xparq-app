// lib/features/chat/widgets/chat_list_view.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xparq_app/l10n/app_localizations.dart';
import 'package:xparq_app/features/chat/domain/models/chat_model.dart';
import 'package:xparq_app/features/chat/presentation/providers/chat_providers.dart';
import 'package:xparq_app/features/social/providers/orbit_providers.dart';
import 'package:xparq_app/features/chat/presentation/widgets/chat_tile.dart';
import 'package:xparq_app/features/chat/presentation/screens/signal_chat_screen.dart';
import 'package:xparq_app/features/chat/presentation/screens/spam_list_screen.dart';
import 'package:xparq_app/features/chat/presentation/utils/chat_identity_resolver.dart';
import 'package:xparq_app/shared/widgets/common/xparq_image.dart';

class ChatListView extends ConsumerWidget {
  final List<ChatModel> chats;
  final String myUid;
  final bool isReconnecting;
  final bool showSystemItems;

  const ChatListView({
    super.key,
    required this.chats,
    required this.myUid,
    this.isReconnecting = false,
    this.showSystemItems = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orbitStatus = ref.watch(myOrbitingStatusProvider).valueOrNull ?? {};
    final requestChats = <ChatModel>[];
    final regularChats = <ChatModel>[];

    for (final chat in chats) {
      final otherUid = chat.participants.firstWhere(
        (p) => p != myUid,
        orElse: () => myUid,
      );
      if (chat.isGroup || otherUid == myUid) {
        regularChats.add(chat);
        continue;
      }

      final isFriend = orbitStatus[otherUid] == 'accepted';
      (isFriend ? regularChats : requestChats).add(chat);
    }

    final displayItems = [
      if (isReconnecting) #banner,
      if (chats.isEmpty) #empty,
      if (showSystemItems) ...[
        if (requestChats.isNotEmpty)
          SignalRequestsTile(requests: requestChats, myUid: myUid),
        SpamFolderTile(myUid: myUid),
      ],
      ...regularChats,
    ];

    return ListView.separated(
      padding: EdgeInsets.zero,
      itemCount: displayItems.length,
      separatorBuilder: (context, index) {
        final item = displayItems[index];
        return switch (item) {
          #banner || #empty => const SizedBox.shrink(),
          final Widget w when w.toString().contains('SizedBox') =>
            const SizedBox.shrink(),
          _ => Divider(
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.1),
            height: 1,
          ),
        };
      },
      itemBuilder: (context, index) {
        final item = displayItems[index];

        return switch (item) {
          #banner => const ReconnectingBanner(),
          #empty => const EmptyStateView(),
          final Widget w => w,
          final ChatModel chat => ChatTile(chat: chat, myUid: myUid),
          _ => const SizedBox.shrink(),
        };
      },
    );
  }
}

class ReconnectingBanner extends StatelessWidget {
  const ReconnectingBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      color: Colors.amber.withValues(alpha: 0.1),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Row(
        children: [
          const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.amber,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            l10n.chatListReconnecting,
            style: TextStyle(
              color: Colors.amber.shade700,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class EmptyStateView extends StatelessWidget {
  const EmptyStateView({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 100),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('ðŸ“¡', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 12),
            Text(
              l10n.chatListEmptyTitle,
              style: TextStyle(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.chatListEmptySubtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SignalRequestsTile extends StatelessWidget {
  final List<ChatModel> requests;
  final String myUid;

  const SignalRequestsTile({
    super.key,
    required this.requests,
    required this.myUid,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return ListTile(
      tileColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.05),
      leading: CircleAvatar(
        radius: 26,
        backgroundColor: Colors.amber.withValues(alpha: 0.1),
        child: const Icon(Icons.mark_chat_unread_outlined, color: Colors.amber),
      ),
      title: Text(
        l10n.chatListRequestsTitle,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          color: Colors.amber,
        ),
      ),
      subtitle: Text(
        l10n.chatListRequestsSubtitle(requests.length),
        style: TextStyle(
          color: Colors.amber.withValues(alpha: 0.6),
          fontSize: 13,
        ),
      ),
      trailing: const Icon(Icons.chevron_right, color: Colors.white24),
      onTap: () => RequestsSheet.show(context, requests, myUid),
    );
  }
}

class RequestsSheet extends StatelessWidget {
  final List<ChatModel> requests;
  final String myUid;

  const RequestsSheet({super.key, required this.requests, required this.myUid});

  static void show(
    BuildContext context,
    List<ChatModel> requests,
    String myUid,
  ) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => RequestsSheet(requests: requests, myUid: myUid),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            l10n.chatListRequestsTitle,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: requests.length,
            itemBuilder: (ctx, idx) =>
                RequestTile(chat: requests[idx], myUid: myUid),
          ),
        ),
      ],
    );
  }
}

class RequestTile extends ConsumerWidget {
  final ChatModel chat;
  final String myUid;

  const RequestTile({super.key, required this.chat, required this.myUid});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final otherUid = chat.participants.firstWhere(
      (p) => p != myUid,
      orElse: () => '',
    );
    final profileAsync = ref.watch(chatProfileProvider(otherUid));
    final profile = profileAsync.valueOrNull;
    final l10n = AppLocalizations.of(context)!;
    final fallbackIdentity = ref
        .watch(
          chatPeerFallbackIdentityProvider(
            ChatPeerIdentityParams(chatId: chat.chatId, currentUid: myUid),
          ),
        )
        .valueOrNull;
    final displayName = resolveDirectChatDisplayName(
      chat: chat,
      myUid: myUid,
      otherUid: otherUid,
      savedMeLabel: l10n.chatListSavedMe.toUpperCase(),
      profile: profile,
      fallbackIdentity: fallbackIdentity,
    );
    final avatarUrl = resolveDirectChatAvatarUrl(
      chat: chat,
      otherUid: otherUid,
      profile: profile,
      fallbackIdentity: fallbackIdentity,
    );
    final hasAvatar = avatarUrl?.isNotEmpty ?? false;

    return ListTile(
      leading: CircleAvatar(
        backgroundImage: hasAvatar
            ? XparqImage.getImageProvider(avatarUrl!)
            : null,
        child: !hasAvatar ? const Icon(Icons.person) : null,
      ),
      title: Text(
        displayName,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurface,
          fontWeight: FontWeight.bold,
        ),
      ),
      subtitle: Text(
        l10n.chatListRequestsSubtitle(1),
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
        ),
      ),
      onTap: () => _handleTap(context, otherUid),
    );
  }

  Future<void> _handleTap(BuildContext context, String otherUid) async {
    final l10n = AppLocalizations.of(context)!;
    final accept = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(l10n.readRequest),
        content: const Text('Do you want to read signals from this iXPARQ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.notNow),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              l10n.read,
              style: const TextStyle(color: Color(0xFF4FC3F7)),
            ),
          ),
        ],
      ),
    );

    if (accept == true && context.mounted) {
      Navigator.pop(context); // Close sheet
      Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) =>
              SignalChatScreen(chatId: chat.chatId, otherUid: otherUid),
        ),
      ).ignore();
    }
  }
}

class SpamFolderTile extends ConsumerWidget {
  final String myUid;
  const SpamFolderTile({super.key, required this.myUid});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spamChatsAsync = ref.watch(spamChatsProvider);
    final theme = Theme.of(context);

    return spamChatsAsync.when(
      data: (chats) {
        if (chats.isEmpty) return const SizedBox.shrink();
        return ListTile(
          tileColor: Colors.transparent,
          leading: CircleAvatar(
            radius: 26,
            backgroundColor: theme.colorScheme.onSurface.withValues(alpha: 0.1),
            child: Icon(
              Icons.mark_email_read_outlined,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.54),
            ),
          ),
          title: Text(
            'Spam Signals',
            style: TextStyle(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              fontWeight: FontWeight.bold,
            ),
          ),
          subtitle: Text(
            '${chats.length} signals from high-risk creators',
            style: TextStyle(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.38),
              fontSize: 13,
            ),
          ),
          trailing: Icon(
            Icons.chevron_right,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.24),
          ),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute<void>(builder: (_) => const SpamListScreen()),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (__, _) => const SizedBox.shrink(),
    );
  }
}
