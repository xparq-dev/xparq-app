// lib/features/chat/screens/spam_list_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xparq_app/features/auth/providers/auth_providers.dart';
import 'package:go_router/go_router.dart';
import 'package:xparq_app/core/router/app_router.dart';
import 'package:xparq_app/features/chat/presentation/providers/chat_providers.dart';
import 'package:xparq_app/core/widgets/xparq_image.dart';

class SpamListScreen extends ConsumerWidget {
  const SpamListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chatsAsync = ref.watch(spamChatsProvider);
    final myUid = ref.watch(authRepositoryProvider).currentUser?.id ?? '';

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Spam Signals',
          style: TextStyle(
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withOpacity(0.7),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.red.withOpacity(0.05),
            child: Row(
              children: [
                const Icon(
                  Icons.shield_outlined,
                  color: Colors.redAccent,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'These signals are from creators with a high NSFW threshold. Be cautious.',
                    style: TextStyle(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withOpacity(0.54),
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: chatsAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: Color(0xFF4FC3F7)),
              ),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (chats) {
                if (chats.isEmpty) {
                  return Center(
                    child: Text(
                      'No spam signals found',
                      style: TextStyle(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withOpacity(0.38),
                      ),
                    ),
                  );
                }
                return ListView.builder(
                  itemCount: chats.length,
                  itemBuilder: (context, index) {
                    final chat = chats[index];
                    final otherUid = chat.participants.firstWhere(
                      (p) => p != myUid,
                      orElse: () => '',
                    );

                    return Consumer(
                      builder: (context, ref, _) {
                        final profileAsync = ref.watch(
                          chatProfileProvider(otherUid),
                        );
                        final profile = profileAsync.valueOrNull;
                        final hasAvatar = profile?.photoUrl.isNotEmpty ?? false;

                        return ListTile(
                          leading: CircleAvatar(
                            radius: 24,
                            backgroundColor: Theme.of(
                              context,
                            ).colorScheme.onSurface.withOpacity(0.1),
                            backgroundImage: hasAvatar
                                ? XparqImage.getImageProvider(profile!.photoUrl)
                                : null,
                            child: !hasAvatar
                                ? Icon(
                                    Icons.person,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withOpacity(0.38),
                                  )
                                : null,
                          ),
                          title: Text(profile?.xparqName ?? 'Cluster'),
                          subtitle: Text(
                            'High-risk signal',
                            style: TextStyle(
                              color: Theme.of(
                                context,
                              ).colorScheme.error.withOpacity(0.7),
                              fontSize: 12,
                            ),
                          ),
                          trailing: Icon(
                            Icons.chevron_right,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withOpacity(0.24),
                          ),
                          onTap: () {
                            context.push(
                              '${AppRoutes.chat}/${chat.chatId}/$otherUid',
                              extra: {'isSpamMode': true},
                            );
                          },
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
