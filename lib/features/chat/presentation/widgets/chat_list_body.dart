// lib/features/chat/widgets/chat_list_body.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:xparq_app/l10n/app_localizations.dart';
import 'package:xparq_app/features/chat/domain/models/chat_model.dart';
import 'package:xparq_app/features/chat/presentation/providers/chat_providers.dart';
import 'package:xparq_app/features/social/widgets/supernova_bar.dart';
import 'package:xparq_app/features/offline/providers/connectivity_provider.dart';
import 'package:xparq_app/features/chat/presentation/widgets/chat_list_view.dart';

class ChatListBody extends ConsumerWidget {
  final String myUid;

  const ChatListBody({super.key, required this.myUid});

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
                ChatTabBar(hasUnread: hasUnread),
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
                        data: (List<ConnectivityResult> results) => ref
                            .read(connectivityNotifierProvider.notifier)
                            .isConnected(results),
                        orElse: () => true,
                      );

                      if (chatsAsync.hasValue || isOnline) {
                        final chats = chatsAsync.value ?? [];
                        return ChatTabBarView(
                          chats: chats,
                          myUid: myUid,
                          hasUnread: hasUnread,
                          isReconnecting: true,
                        );
                      }
                      return const OfflineErrorView();
                    },
                    data: (chats) => ChatTabBarView(
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

class ChatTabBar extends StatelessWidget {
  final bool hasUnread;

  const ChatTabBar({super.key, required this.hasUnread});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return TabBar(
      labelColor: const Color(0xFF4FC3F7),
      unselectedLabelColor: theme.colorScheme.onSurface.withOpacity(0.54),
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

class ChatTabBarView extends StatelessWidget {
  final List<ChatModel> chats;
  final String myUid;
  final bool hasUnread;
  final bool isReconnecting;

  const ChatTabBarView({
    super.key,
    required this.chats,
    required this.myUid,
    required this.hasUnread,
    this.isReconnecting = false,
  });

  @override
  Widget build(BuildContext context) {
    return TabBarView(
      children: [
        ChatListView(
          chats: chats.where((c) => !c.isGroup).toList(),
          myUid: myUid,
          isReconnecting: isReconnecting,
        ),
        ChatListView(
          chats: chats.where((c) => c.isGroup).toList(),
          myUid: myUid,
          isReconnecting: isReconnecting,
          showSystemItems: false,
        ),
        if (hasUnread)
          ChatListView(
            chats: chats.where((c) => c.unreadCount > 0).toList(),
            myUid: myUid,
            isReconnecting: isReconnecting,
            showSystemItems: false,
          ),
      ],
    );
  }
}

class OfflineErrorView extends ConsumerWidget {
  const OfflineErrorView({super.key});

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
                color: theme.colorScheme.onSurface.withOpacity(0.6),
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
