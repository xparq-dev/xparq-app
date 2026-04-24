import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:xparq_app/shared/router/app_router.dart';
import 'package:xparq_app/features/auth/providers/auth_providers.dart';
import 'package:xparq_app/features/chat/domain/models/chat_model.dart';
import 'package:xparq_app/features/chat/presentation/providers/chat_providers.dart';
import 'package:xparq_app/features/chat/data/services/message_encryption_service.dart';
import 'package:xparq_app/features/chat/presentation/screens/signal_chat_screen.dart';
import 'package:xparq_app/features/chat/presentation/screens/spam_list_screen.dart';
import 'package:xparq_app/features/chat/presentation/widgets/signal_sidebar.dart';
import 'package:xparq_app/shared/widgets/common/xparq_image.dart';
import 'package:xparq_app/features/social/providers/orbit_providers.dart';
import 'package:xparq_app/features/offline/providers/connectivity_provider.dart';
import 'package:xparq_app/features/social/widgets/supernova_bar.dart';
import 'package:xparq_app/features/auth/models/planet_model.dart';
import 'package:xparq_app/features/block_report/providers/block_report_providers.dart';
import 'package:xparq_app/l10n/app_localizations.dart';

class ChatListScreen extends ConsumerStatefulWidget {
  const ChatListScreen({super.key});

  @override
  ConsumerState<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends ConsumerState<ChatListScreen>
    with AutomaticKeepAliveClientMixin {
  bool _isSidebarCollapsed = false;

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final myUid = ref.watch(authRepositoryProvider).currentUser?.id ?? '';

    return OrientationBuilder(
      builder: (context, orientation) {
        final isLandscape = orientation == Orientation.landscape;

        if (isLandscape) {
          return Scaffold(
            body: Row(
              children: [
                _SidebarRail(
                  myUid: myUid,
                  isCollapsed: _isSidebarCollapsed,
                  onToggle: () => setState(
                    () => _isSidebarCollapsed = !_isSidebarCollapsed,
                  ),
                ),
                Expanded(
                  child: Scaffold(
                    appBar: _ChatListAppBar(myUid: myUid, isLandscape: true),
                    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                    body: _ChatListBody(myUid: myUid),
                  ),
                ),
              ],
            ),
          );
        }

        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: _ChatListAppBar(myUid: myUid, isLandscape: false),
          drawer: SignalSidebar(myUid: myUid, isDrawer: true),
          body: _ChatListBody(myUid: myUid),
        );
      },
    );
  }
}

class _SidebarRail extends StatelessWidget {
  final String myUid;
  final bool isCollapsed;
  final VoidCallback onToggle;

  const _SidebarRail({
    required this.myUid,
    required this.isCollapsed,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          width: isCollapsed ? 151.5 : 300,
          child: ClipRect(
            child: OverflowBox(
              minWidth: 300,
              maxWidth: 300,
              alignment: AlignmentDirectional.centerStart,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 300),
                opacity: isCollapsed ? 0.4 : 1.0,
                child: SignalSidebar(myUid: myUid, isDrawer: false),
              ),
            ),
          ),
        ),
        GestureDetector(
          onTap: onToggle,
          behavior: HitTestBehavior.opaque,
          child: Stack(
            alignment: Alignment.center,
            children: [
              VerticalDivider(
                width: 24,
                thickness: 1,
                color: Theme.of(context).dividerColor,
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 16,
                  horizontal: 2,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Theme.of(context).dividerColor,
                    width: 0.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(
                  isCollapsed ? Icons.chevron_right : Icons.chevron_left,
                  size: 16,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ChatListAppBar extends ConsumerWidget implements PreferredSizeWidget {
  final String myUid;
  final bool isLandscape;

  const _ChatListAppBar({required this.myUid, required this.isLandscape});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return AppBar(
      backgroundColor: theme.scaffoldBackgroundColor,
      surfaceTintColor: Colors.transparent,
      titleSpacing: isLandscape ? 0 : 16,
      centerTitle: false,
      automaticallyImplyLeading: false,
      leading: isLandscape
          ? const SizedBox.shrink()
          : Builder(
              builder: (context) => IconButton(
                icon: const Icon(Icons.menu),
                onPressed: () => Scaffold.of(context).openDrawer(),
              ),
            ),
      leadingWidth: isLandscape ? 0 : null,
      title: Padding(
        padding: isLandscape
            ? const EdgeInsets.only(left: 16)
            : EdgeInsets.zero,
        child: Text(
          l10n.chatListTitle,
          style: TextStyle(
            color: theme.colorScheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.bookmark_outline),
          tooltip: l10n.chatListSavedMe,
          onPressed: () => _navigateToSavedMe(context, ref, myUid),
        ),
        IconButton(
          icon: const Icon(Icons.edit_outlined),
          tooltip: l10n.chatListCreateChat,
          onPressed: () => _showCreateChatSheet(context, myUid),
        ),
      ],
    );
  }

  Future<void> _navigateToSavedMe(
    BuildContext context,
    WidgetRef ref,
    String myUid,
  ) async {
    if (myUid.isEmpty) return;
    try {
      final repo = ref.read(chatRepositoryProvider);
      final chat = await repo.getOrCreateChat(myUid: myUid, otherUid: myUid);
      if (context.mounted) {
        context.push('${AppRoutes.chat}/${chat.chatId}/$myUid');
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.errorPrefix(e.toString()),
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  void _showCreateChatSheet(BuildContext context, String myUid) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _CreateChatSheet(myUid: myUid),
    );
  }
}

class _ChatListBody extends ConsumerWidget {
  final String myUid;

  const _ChatListBody({required this.myUid});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chatsAsync = ref.watch(myChatsProvider);
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    final chats = chatsAsync.valueOrNull ?? [];
    final hasUnread = chats.any((c) => c.unreadCount > 0);
    final tabCount = hasUnread ? 3 : 2;

    return Column(
      children: [
        if (!isLandscape) const SupernovaBar(),
        const Divider(height: 1, color: Colors.transparent),
        DefaultTabController(
          key: ValueKey('chat_tabs_$tabCount'),
          length: tabCount,
          child: Expanded(
            child: Column(
              children: [
                _ChatTabBar(hasUnread: hasUnread),
                Expanded(
                  child: chatsAsync.maybeWhen(
                    orElse: () => const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF4FC3F7),
                      ),
                    ),
                    error: (e, _) {
                      final connectivity = ref.watch(
                        connectivityNotifierProvider,
                      );
                      final isOnline = connectivity.maybeWhen(
                        data: (results) => ref
                            .read(connectivityNotifierProvider.notifier)
                            .isConnected(results),
                        orElse: () => true,
                      );

                      if (chatsAsync.hasValue || isOnline) {
                        final chats = chatsAsync.value ?? [];
                        return _ChatTabBarView(
                          chats: chats,
                          myUid: myUid,
                          hasUnread: hasUnread,
                          isReconnecting: true,
                        );
                      }
                      return const _OfflineErrorView();
                    },
                    data: (chats) => _ChatTabBarView(
                      chats: chats,
                      myUid: myUid,
                      hasUnread: hasUnread,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ChatTabBar extends StatelessWidget {
  final bool hasUnread;

  const _ChatTabBar({required this.hasUnread});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return TabBar(
      labelColor: const Color(0xFF4FC3F7),
      unselectedLabelColor: theme.colorScheme.onSurface.withValues(alpha: 0.54),
      indicatorColor: const Color(0xFF4FC3F7),
      indicatorSize: TabBarIndicatorSize.tab,
      dividerColor: theme.dividerColor,
      tabs: [
        Tab(text: l10n.chatListTabXparqs),
        Tab(text: l10n.chatListTabGroups),
        if (hasUnread) Tab(text: l10n.chatListTabUnread),
      ],
    );
  }
}

class _ChatTabBarView extends StatelessWidget {
  final List<ChatModel> chats;
  final String myUid;
  final bool hasUnread;
  final bool isReconnecting;

  const _ChatTabBarView({
    required this.chats,
    required this.myUid,
    required this.hasUnread,
    this.isReconnecting = false,
  });

  @override
  Widget build(BuildContext context) {
    return TabBarView(
      children: [
        _ChatListView(
          chats: chats.where((c) => !c.isGroup).toList(),
          myUid: myUid,
          isReconnecting: isReconnecting,
        ),
        _ChatListView(
          chats: chats.where((c) => c.isGroup).toList(),
          myUid: myUid,
          isReconnecting: isReconnecting,
          showSystemItems: false,
        ),
        if (hasUnread)
          _ChatListView(
            chats: chats.where((c) => c.unreadCount > 0).toList(),
            myUid: myUid,
            isReconnecting: isReconnecting,
            showSystemItems: false,
          ),
      ],
    );
  }
}

class _OfflineErrorView extends ConsumerWidget {
  const _OfflineErrorView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_rounded, size: 64, color: Colors.amber),
            const SizedBox(height: 16),
            Text(
              l10n.chatListOfflineTitle,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.chatListOfflineSubtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => ref.invalidate(myChatsProvider),
              icon: const Icon(Icons.refresh),
              label: Text(l10n.chatListRetry),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatListView extends ConsumerWidget {
  final List<ChatModel> chats;
  final String myUid;
  final bool isReconnecting;
  final bool showSystemItems;

  const _ChatListView({
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
          _SignalRequestsTile(requests: requestChats, myUid: myUid),
        _SpamFolderTile(myUid: myUid),
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
          Widget w when w.toString().contains('SizedBox') =>
            const SizedBox.shrink(),
          _ => Divider(
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.10),
            height: 1,
          ),
        };
      },
      itemBuilder: (context, index) {
        final item = displayItems[index];

        return switch (item) {
          #banner => _ReconnectingBanner(),
          #empty => _EmptyStateView(),
          Widget w => w,
          ChatModel chat => _ChatTile(chat: chat, myUid: myUid),
          _ => const SizedBox.shrink(),
        };
      },
    );
  }
}

class _ReconnectingBanner extends StatelessWidget {
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

class _EmptyStateView extends StatelessWidget {
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

class _ChatTile extends ConsumerWidget {
  final ChatModel chat;
  final String myUid;

  const _ChatTile({required this.chat, required this.myUid});

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
              : (profile != null
                    ? (profile.handle != null && profile.handle!.isNotEmpty
                        ? '${profile.xparqName} (@${profile.handle})'
                        : profile.xparqName)
                    : 'Explorer'));

    final avatarInitials = chat.isGroup
        ? (chat.name?.isNotEmpty == true
              ? chat.name!.substring(0, 1).toUpperCase()
              : 'G')
        : (isSelfChat
              ? 'ME'
              : (profile?.xparqName.isNotEmpty == true
                    ? profile!.xparqName.substring(0, 1).toUpperCase()
                    : '?'));

    final hasAvatar = chat.isGroup
        ? (chat.groupAvatar?.isNotEmpty ?? false)
        : (!isSelfChat && (profile?.photoUrl.isNotEmpty ?? false));

    final avatarUrl = chat.isGroup ? chat.groupAvatar : profile?.photoUrl;
    final isOnline =
        !chat.isGroup && !isSelfChat && (profile?.isActuallyOnline ?? false);

    return RepaintBoundary(
      child: FutureBuilder<String>(
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
            leading: _ChatAvatar(
              avatarUrl: avatarUrl,
              hasAvatar: hasAvatar,
              avatarInitials: avatarInitials,
              isGroup: chat.isGroup,
              isOnline: isOnline,
            ),
            title: _ChatTileTitle(chat: chat, displayName: displayName),
            subtitle: Text(
              showPreview,
              style: TextStyle(
                color: chat.isSensitive
                    ? const Color(0xFFFF6B6B).withValues(alpha: 0.7)
                    : theme.colorScheme.onSurface.withValues(alpha: 0.38),
                fontSize: 13,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
            trailing: chat.lastAt != null
                ? Text(
                    DateFormat('HH:mm').format(chat.lastAt!),
                    style: TextStyle(
                      color: theme.colorScheme.onSurface.withValues(alpha: 
                        0.38,
                      ),
                      fontSize: 11,
                    ),
                  )
                : null,
            onTap: () => context.push(
              '${AppRoutes.chat}/${chat.chatId}/${chat.isGroup ? 'group' : otherUid}',
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
            _ActionMenuItem(
              icon: chat.isPinned ? Icons.star_border : Icons.star,
              label: chat.isPinned ? 'Unpin Star' : 'Pin Star',
              iconColor: const Color(0xFFFF9800),
              onTap: () {
                Navigator.pop(ctx);
                _togglePin(context, ref, chat);
              },
            ),
            _ActionMenuItem(
              icon: Icons.archive_outlined,
              label: 'Archive',
              onTap: () {
                Navigator.pop(ctx);
                ref
                    .read(chatRepositoryProvider)
                    .toggleChatArchive(chat.chatId, true);
              },
            ),
            _ActionMenuItem(
              icon: Icons.notifications_off_outlined,
              label: 'Silence',
              onTap: () {
                Navigator.pop(ctx);
                _showSilenceDialog(context, ref, chat.chatId);
              },
            ),
            if (!chat.isGroup &&
                otherUid != ref.read(authRepositoryProvider).currentUser?.id)
              _ActionMenuItem(
                icon: Icons.block,
                label: 'Black Hole (Block User)',
                labelColor: const Color(0xFFFF4444),
                onTap: () {
                  Navigator.pop(ctx);
                  _confirmBlock(context, ref, otherUid);
                },
              ),
            if (chat.isGroup)
              _ActionMenuItem(
                icon: Icons.exit_to_app,
                label: 'Leave Group',
                labelColor: const Color(0xFFFF4444),
                onTap: () {
                  Navigator.pop(ctx);
                  _confirmLeaveGroup(context, ref, chat.chatId);
                },
              )
            else
              _ActionMenuItem(
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
        .read(chatRepositoryProvider)
        .toggleChatPin(chat.chatId, !chat.isPinned);
  }

  void _showSilenceDialog(BuildContext context, WidgetRef ref, String chatId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Silence Chat'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _SilenceOption(chatId: chatId, label: '1 hour', hours: 1),
            _SilenceOption(chatId: chatId, label: '8 hours', hours: 8),
            _SilenceOption(chatId: chatId, label: '1 day', hours: 24),
            _SilenceOption(chatId: chatId, label: '7 days', hours: 168),
            _SilenceOption(chatId: chatId, label: 'Forever', hours: -1),
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
      builder: (_) => const _ConfirmationDialog(
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
      builder: (_) => const _ConfirmationDialog(
        title: 'Delete Chat?',
        content:
            'This will erase the entire star system of this conversation. It cannot be recovered.',
        confirmLabel: 'Delete',
        isDangerous: true,
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
      builder: (_) => const _ConfirmationDialog(
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
        await ref.read(chatRepositoryProvider).leaveGroup(chatId, myUid);
      }
    }
  }
}

class _ChatAvatar extends StatelessWidget {
  final String? avatarUrl;
  final bool hasAvatar;
  final String avatarInitials;
  final bool isGroup;
  final bool isOnline;

  const _ChatAvatar({
    required this.avatarUrl,
    required this.hasAvatar,
    required this.avatarInitials,
    required this.isGroup,
    required this.isOnline,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        CircleAvatar(
          radius: 26,
          backgroundColor: theme.colorScheme.onSurface.withValues(alpha: 0.1),
          backgroundImage: hasAvatar
              ? XparqImage.getImageProvider(avatarUrl!)
              : null,
          child: !hasAvatar
              ? (isGroup
                    ? const Icon(Icons.group, color: Colors.white70)
                    : Text(
                        avatarInitials,
                        style: TextStyle(
                          color: theme.colorScheme.onSurface,
                          fontWeight: FontWeight.bold,
                        ),
                      ))
              : null,
        ),
        if (isOnline)
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: const Color(0xFF4CAF50),
                shape: BoxShape.circle,
                border: Border.all(color: theme.colorScheme.surface, width: 2),
              ),
            ),
          ),
      ],
    );
  }
}

class _ChatTileTitle extends StatelessWidget {
  final ChatModel chat;
  final String displayName;

  const _ChatTileTitle({required this.chat, required this.displayName});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (chat.isPinned)
          const Padding(
            padding: EdgeInsets.only(right: 6),
            child: Icon(Icons.star, color: Color(0xFFFF9800), size: 16),
          ),
        Expanded(
          child: Text(
            displayName,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.bold,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (chat.isSensitive)
          const Padding(
            padding: EdgeInsetsDirectional.only(start: 6),
            child: Icon(
              Icons.warning_amber_rounded,
              color: Color(0xFFFF6B6B),
              size: 14,
            ),
          ),
        if (chat.unreadCount > 0)
          Container(
            margin: const EdgeInsets.only(left: 8),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFFFF4444),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              chat.unreadCount.toString(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
      ],
    );
  }
}

class _ActionMenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? iconColor;
  final Color? labelColor;

  const _ActionMenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.iconColor,
    this.labelColor,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: iconColor),
      title: Text(label, style: TextStyle(color: labelColor)),
      onTap: onTap,
    );
  }
}

class _SilenceOption extends ConsumerWidget {
  final String chatId;
  final String label;
  final int hours;

  const _SilenceOption({
    required this.chatId,
    required this.label,
    required this.hours,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
}

class _ConfirmationDialog extends StatelessWidget {
  final String title;
  final String content;
  final String confirmLabel;
  final bool isDangerous;

  const _ConfirmationDialog({
    required this.title,
    required this.content,
    required this.confirmLabel,
    this.isDangerous = false,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(title),
      content: Text(content),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(
            confirmLabel,
            style: TextStyle(
              color: isDangerous ? const Color(0xFFFF4444) : null,
            ),
          ),
        ),
      ],
    );
  }
}

class _SignalRequestsTile extends StatelessWidget {
  final List<ChatModel> requests;
  final String myUid;

  const _SignalRequestsTile({required this.requests, required this.myUid});

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
      onTap: () => _RequestsSheet.show(context, requests, myUid),
    );
  }
}

class _RequestsSheet extends StatelessWidget {
  final List<ChatModel> requests;
  final String myUid;

  const _RequestsSheet({required this.requests, required this.myUid});

  static void show(
    BuildContext context,
    List<ChatModel> requests,
    String myUid,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _RequestsSheet(requests: requests, myUid: myUid),
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
                _RequestTile(chat: requests[idx], myUid: myUid),
          ),
        ),
      ],
    );
  }
}

class _RequestTile extends ConsumerWidget {
  final ChatModel chat;
  final String myUid;

  const _RequestTile({required this.chat, required this.myUid});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final otherUid = chat.participants.firstWhere(
      (p) => p != myUid,
      orElse: () => '',
    );
    final profileAsync = ref.watch(chatProfileProvider(otherUid));
    final profile = profileAsync.valueOrNull;
    final displayName = profile != null
        ? (profile.handle != null && profile.handle!.isNotEmpty
            ? '${profile.xparqName} (@${profile.handle})'
            : profile.xparqName)
        : 'Explorer';
    final hasAvatar = profile?.photoUrl.isNotEmpty ?? false;
    final l10n = AppLocalizations.of(context)!;

    return ListTile(
      leading: CircleAvatar(
        backgroundImage: hasAvatar
            ? XparqImage.getImageProvider(profile!.photoUrl)
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
        MaterialPageRoute(
          builder: (_) =>
              SignalChatScreen(chatId: chat.chatId, otherUid: otherUid),
        ),
      );
    }
  }
}

class _SpamFolderTile extends ConsumerWidget {
  final String myUid;
  const _SpamFolderTile({required this.myUid});

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
            MaterialPageRoute(builder: (_) => const SpamListScreen()),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (__, _) => const SizedBox.shrink(),
    );
  }
}

class _CreateChatSheet extends ConsumerStatefulWidget {
  final String myUid;
  const _CreateChatSheet({required this.myUid});

  @override
  ConsumerState<_CreateChatSheet> createState() => _CreateChatSheetState();
}

class _CreateChatSheetState extends ConsumerState<_CreateChatSheet> {
  final _controller = TextEditingController();
  List<PlanetModel> _results = [];
  bool _isSearching = false;
  String? _lastQuery;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onSearch(String query) async {
    final trimmed = query.trim();
    if (trimmed == _lastQuery) return;
    _lastQuery = trimmed;

    if (trimmed.isEmpty) {
      setState(() {
        _results = [];
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);
    try {
      final repo = ref.read(chatRepositoryProvider);
      final users = await repo.searchUsers(trimmed);
      if (mounted) {
        setState(() {
          _results = users.where((u) => u.id != widget.myUid).toList();
          _isSearching = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 20,
        right: 20,
        top: 20,
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Create Chat',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            autofocus: true,
            onChanged: (val) {
              _onSearch(val);
            },
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            decoration: InputDecoration(
              hintText: 'Search by xparqName or Handle...',
              prefixIcon: const Icon(Icons.search, size: 20),
              filled: true,
              fillColor: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.05),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              suffixIcon: _isSearching
                  ? Container(
                      padding: const EdgeInsets.all(12),
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 20),
          if (_results.isEmpty && !_isSearching && _controller.text.isNotEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  'No users found ðŸŒŒ',
                  style: TextStyle(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.54),
                  ),
                ),
              ),
            ),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _results.length,
              itemBuilder: (context, index) {
                final user = _results[index];
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundImage: user.photoUrl.isNotEmpty
                        ? XparqImage.getImageProvider(user.photoUrl)
                        : null,
                    child: user.photoUrl.isEmpty
                        ? const Icon(Icons.person)
                        : null,
                  ),
                  title: Text(
                    user.xparqName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    user.id == widget.myUid
                        ? 'SAVED (ME)'
                        : (user.handle != null && user.handle!.isNotEmpty
                            ? '@${user.handle}'
                            : 'Explorer'),
                    style: TextStyle(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                  onTap: () async {
                    Navigator.pop(context);
                    final repo = ref.read(chatRepositoryProvider);
                    final chat = await repo.getOrCreateChat(
                      myUid: widget.myUid,
                      otherUid: user.id,
                    );
                    if (context.mounted) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => SignalChatScreen(
                            chatId: chat.chatId,
                            otherUid: user.id,
                          ),
                        ),
                      );
                    }
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

