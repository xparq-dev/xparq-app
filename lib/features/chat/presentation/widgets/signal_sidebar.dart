import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:xparq_app/core/router/app_router.dart';
import 'package:xparq_app/core/widgets/xparq_image.dart';
import 'package:xparq_app/features/auth/providers/auth_providers.dart';
import 'package:xparq_app/features/chat/presentation/providers/chat_providers.dart';
import 'package:xparq_app/features/social/providers/orbit_providers.dart';
import 'qr_invite_dialog.dart';

class SignalSidebar extends ConsumerWidget {
  final String myUid;
  final bool isDrawer;

  const SignalSidebar({
    super.key,
    required this.myUid,
    this.isDrawer = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(planetProfileProvider);

    Widget content = profileAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (profile) {
        if (profile == null) return const SizedBox.shrink();

        return Column(
          children: [
            // 1. Profile Header
            Stack(
              children: [
                Container(
                  padding: const EdgeInsets.only(top: 60, left: 20, right: 20, bottom: 20),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface.withOpacity(0.05),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GestureDetector(
                        onTap: () => context.push(AppRoutes.createPulse),
                        child: Stack(
                          children: [
                            CircleAvatar(
                              radius: 35,
                              backgroundImage: profile.photoUrl.isNotEmpty
                                  ? XparqImage.getImageProvider(profile.photoUrl)
                                  : null,
                              child: profile.photoUrl.isEmpty ? const Icon(Icons.person, size: 40) : null,
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
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Text(
                            profile.xparqName,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                          if (profile.blueOrbit) ...[
                            const SizedBox(width: 4),
                            const Icon(Icons.verified, color: Color(0xFF4FC3F7), size: 16),
                          ],
                        ],
                      ),
                      Text(
                        profile.handle != null ? '@${profile.handle}' : '',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
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
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                      ),
                      onPressed: () => context.push(AppRoutes.settings),
                      tooltip: 'Settings',
                    ),
                  ),
              ],
            ),

            // 2. Menu Items
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  _drawerItem(
                    context: context,
                    icon: Icons.group_add_outlined,
                    label: 'New Group',
                    onTap: () {
                      if (isDrawer) Navigator.pop(context);
                      context.push(AppRoutes.createGroup);
                    },
                  ),
                  _drawerItem(
                    context: context,
                    icon: Icons.people_outline,
                    label: 'Friends List',
                    onTap: () {
                      if (isDrawer) Navigator.pop(context);
                      _showFriendsList(context, ref, myUid);
                    },
                  ),
                  _drawerItem(
                    context: context,
                    icon: Icons.bookmark_outline,
                    label: 'Saved (Me)',
                    onTap: () async {
                      if (isDrawer) Navigator.pop(context);
                      final repo = ref.read(chatRepositoryProvider);
                      final c = await repo.getOrCreateChat(myUid: myUid, otherUid: myUid);
                      if (context.mounted) {
                        context.push('${AppRoutes.chat}/${c.chatId}/$myUid');
                      }
                    },
                  ),
                  _drawerItem(
                    context: context,
                    icon: Icons.qr_code_2,
                    label: 'Invite to Signal',
                    onTap: () {
                      if (isDrawer) Navigator.pop(context);
                      showDialog(
                        context: context,
                        builder: (_) => QRInviteDialog(uid: myUid, xparqName: profile.xparqName),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );

    final theme = Theme.of(context);
    final bgColor = theme.colorScheme.surface.withOpacity(theme.brightness == Brightness.dark ? 0.96 : 1.0);

    if (isDrawer) {
      return Drawer(width: MediaQuery.sizeOf(context).width * 0.75, backgroundColor: bgColor, child: content);
    } else {
      return Container(width: 280, color: bgColor, child: content);
    }
  }

  Widget _drawerItem({required BuildContext context, required IconData icon, required String label, required VoidCallback onTap}) {
    return ListTile(
      leading: Icon(icon, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
      title: Text(label, style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 16)),
      onTap: onTap,
    );
  }

  void _showFriendsList(BuildContext context, WidgetRef ref, String uid) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0D1B2A),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.6,
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(20),
              child: Text('My Orbit (Friends)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            Expanded(
              child: Consumer(
                builder: (context, ref, child) {
                  final friendsAsync = ref.watch(orbitListProvider(OrbitListParams(uid, 'orbiting')));
                  return friendsAsync.when(
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Center(child: Text('Error: $e')),
                    data: (friends) {
                      if (friends.isEmpty) return const Center(child: Text('No friends yet 🛰️', style: TextStyle(color: Colors.white30)));
                      return ListView.builder(
                        itemCount: friends.length,
                        itemBuilder: (ctx, idx) {
                          final friend = friends[idx];
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundImage: friend.photoUrl.isNotEmpty ? XparqImage.getImageProvider(friend.photoUrl) : null,
                              child: friend.photoUrl.isEmpty ? const Icon(Icons.person) : null,
                            ),
                            title: Text(friend.xparqName, style: const TextStyle(color: Colors.white)),
                            subtitle: Text('@${friend.handle ?? friend.id.substring(0, 8)}', style: const TextStyle(color: Colors.white30)),
                            onTap: () async {
                              Navigator.pop(ctx);
                              final repo = ref.read(chatRepositoryProvider);
                              final c = await repo.getOrCreateChat(myUid: uid, otherUid: friend.id);
                              if (context.mounted) {
                                context.push('${AppRoutes.chat}/${c.chatId}/${friend.id}');
                              }
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
      ),
    );
  }
}
