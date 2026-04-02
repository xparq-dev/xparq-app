// lib/features/chat/widgets/sidebar_components.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:xparq_app/core/router/app_router.dart';
import 'package:xparq_app/core/widgets/xparq_image.dart';
import 'package:xparq_app/features/auth/models/planet_model.dart';
import 'package:xparq_app/features/chat/presentation/providers/chat_providers.dart';
import 'package:xparq_app/features/chat/presentation/widgets/qr_invite_dialog.dart';
import 'package:xparq_app/features/social/providers/orbit_providers.dart';

class SidebarProfileHeader extends StatelessWidget {
  final PlanetModel profile;
  final bool isDrawer;

  const SidebarProfileHeader({
    super.key,
    required this.profile,
    required this.isDrawer,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Stack(
      children: [
        Container(
          padding: const EdgeInsets.only(
            top: 60,
            left: 20,
            right: 20,
            bottom: 20,
          ),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface.withOpacity(0.05),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () => unawaited(context.push(AppRoutes.createPulse)),
                child: _buildAvatar(context),
              ),
              const SizedBox(height: 12),
              _buildNameSection(theme),
              Text(
                profile.handle != null ? '@${profile.handle}' : '',
                style: TextStyle(
                  color: theme.colorScheme.onSurface.withOpacity(0.5),
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
        if (!isDrawer)
          Positioned(
            top: 55,
            right: 10,
            child: IconButton(
              icon: Icon(
                Icons.settings_outlined,
                color: theme.colorScheme.onSurface.withOpacity(0.7),
              ),
              onPressed: () => unawaited(context.push(AppRoutes.settings)),
              tooltip: 'Settings',
            ),
          ),
      ],
    );
  }

  Widget _buildAvatar(BuildContext context) {
    return Stack(
      children: [
        CircleAvatar(
          radius: 35,
          backgroundImage: profile.photoUrl.isNotEmpty
              ? XparqImage.getImageProvider(profile.photoUrl)
              : null,
          child: profile.photoUrl.isEmpty
              ? const Icon(Icons.person, size: 40)
              : null,
        ),
        if (!isDrawer)
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: const Color(0xFF4FC3F7),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Theme.of(context).colorScheme.surface,
                  width: 2,
                ),
              ),
              child: const Icon(Icons.add, size: 16, color: Colors.white),
            ),
          ),
      ],
    );
  }

  Widget _buildNameSection(ThemeData theme) {
    return Row(
      children: [
        Text(
          profile.xparqName,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
        if (profile.blueOrbit) ...[
          const SizedBox(width: 4),
          const Icon(Icons.verified, color: Color(0xFF4FC3F7), size: 16),
        ],
        if (profile.isAdultVerified) ...[
          const SizedBox(width: 4),
          const Icon(
            Icons.eighteen_up_rating,
            color: Colors.redAccent,
            size: 16,
          ),
        ],
      ],
    );
  }
}

class SidebarMenu extends ConsumerWidget {
  final String myUid;
  final bool isDrawer;
  final String xparqName;
  final Future<void> Function(BuildContext) onShowFriends;

  const SidebarMenu({
    super.key,
    required this.myUid,
    required this.isDrawer,
    required this.xparqName,
    required this.onShowFriends,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        _item(context, Icons.group_add_outlined, 'New Group', () {
          if (isDrawer) Navigator.pop(context);
          unawaited(context.push(AppRoutes.createGroup));
        }),
        _item(
          context,
          Icons.people_outline,
          'Friends List',
          () => onShowFriends(context),
        ),
        _item(context, Icons.bookmark_outline, 'Saved (Me)', () async {
          if (isDrawer) Navigator.pop(context);
          final repo = ref.read(chatBaseRepositoryProvider);
          final chat = await repo.getOrCreateChat(
            myUid: myUid,
            otherUid: myUid,
          );
          if (context.mounted) {
            unawaited(context.push('${AppRoutes.chat}/${chat.chatId}/$myUid'));
          }
        }),
        _item(context, Icons.qr_code_2, 'Invite to Signal', () {
          if (isDrawer) Navigator.pop(context);
          showDialog<void>(
            context: context,
            builder: (_) => QRInviteDialog(uid: myUid, xparqName: xparqName),
          );
        }),
        _item(context, Icons.archive_outlined, 'Archive', () {
          if (isDrawer) Navigator.pop(context);
          unawaited(context.push(AppRoutes.archivedChats));
        }),
      ],
    );
  }

  Widget _item(
    BuildContext context,
    IconData icon,
    String label,
    VoidCallback onTap,
  ) {
    return ListTile(
      leading: Icon(
        icon,
        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
      ),
      title: Text(
        label,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurface,
          fontSize: 16,
        ),
      ),
      onTap: onTap,
    );
  }
}

class FriendsListSheet extends ConsumerWidget {
  final String myUid;

  const FriendsListSheet({super.key, required this.myUid});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.6,
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(20),
            child: Text(
              'My Orbit (Friends)',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: ref
                .watch(orbitListProvider(OrbitListParams(myUid, 'orbiting')))
                .when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('Error: $e')),
                  data: (friends) {
                    if (friends.isEmpty) {
                      return const Center(
                        child: Text(
                          'No friends yet 🛰️',
                          style: TextStyle(color: Colors.white30),
                        ),
                      );
                    }
                    return ListView.builder(
                      itemCount: friends.length,
                      itemBuilder: (ctx, idx) {
                        final friend = friends[idx];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundImage: friend.photoUrl.isNotEmpty
                                ? XparqImage.getImageProvider(friend.photoUrl)
                                : null,
                            child: friend.photoUrl.isEmpty
                                ? const Icon(Icons.person)
                                : null,
                          ),
                          title: Text(
                            friend.xparqName,
                            style: const TextStyle(color: Colors.white),
                          ),
                          subtitle: Text(
                            '@${friend.handle ?? friend.id.substring(0, 8)}',
                            style: const TextStyle(color: Colors.white30),
                          ),
                          onTap: () async {
                            Navigator.pop(ctx);
                            final repo = ref.read(chatBaseRepositoryProvider);
                            final chat = await repo.getOrCreateChat(
                              myUid: myUid,
                              otherUid: friend.id,
                            );
                            if (context.mounted) {
                              unawaited(
                                context.push(
                                  '${AppRoutes.chat}/${chat.chatId}/${friend.id}',
                                ),
                              );
                            }
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
