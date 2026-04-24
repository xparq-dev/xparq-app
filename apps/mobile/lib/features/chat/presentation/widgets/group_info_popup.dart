import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:xparq_app/shared/widgets/ui/cards/glass_card.dart';
import 'package:xparq_app/features/chat/domain/models/chat_model.dart';
import 'package:xparq_app/features/chat/presentation/providers/chat_providers.dart';
import 'package:xparq_app/features/auth/providers/auth_providers.dart';
import 'package:xparq_app/features/chat/presentation/widgets/mini_profile_popup.dart';
import 'package:xparq_app/shared/widgets/common/xparq_image.dart';
import 'member_search_popup.dart';
import 'silence_cluster_dialog.dart';
import 'package:xparq_app/features/auth/models/planet_model.dart';

class ClusterCorePopup extends ConsumerWidget {
  final ChatModel chat;

  const ClusterCorePopup({super.key, required this.chat});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = const Color(0xFF1D9BF0);
    final myUid = ref.watch(authRepositoryProvider).currentUser?.id ?? '';
    final isAdmin = chat.admins.contains(myUid);

    final chatSettings = ref.watch(chatSettingsProvider).valueOrNull ?? {};
    final isSilenced =
        chatSettings[chat.chatId]?['silenced_until'] != null &&
        DateTime.parse(
          chatSettings[chat.chatId]!['silenced_until'],
        ).isAfter(DateTime.now());

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
        child: Material(
          color: Colors.transparent,
          child: GlassCard(
            borderRadius: BorderRadius.circular(24),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.7,
              ),
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Group Avatar
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: 90,
                            height: 90,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: primaryColor.withValues(alpha: 0.3),
                                  blurRadius: 20,
                                  spreadRadius: 5,
                                ),
                              ],
                            ),
                          ),
                          CircleAvatar(
                            radius: 40,
                            backgroundColor: isDark
                                ? Colors.white10
                                : Colors.black12,
                            backgroundImage:
                                chat.groupAvatar?.isNotEmpty == true
                                ? XparqImage.getImageProvider(chat.groupAvatar!)
                                : null,
                            child: (chat.groupAvatar?.isEmpty ?? true)
                                ? Icon(
                                    Icons.group,
                                    size: 40,
                                    color: isDark
                                        ? Colors.white54
                                        : Colors.black54,
                                  )
                                : null,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Group Name
                      Text(
                        chat.name ?? 'Cluster',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${chat.participants.length} Sparqs in this Cluster',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white60 : Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Actions Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _ActionButton(
                            icon: Icons.person_add_outlined,
                            label: 'Add Sparqs',
                            onTap: () {
                              Navigator.pop(context);
                              showDialog(
                                context: context,
                                builder: (context) =>
                                    MemberSearchPopup(chat: chat),
                              );
                            },
                          ),
                          _ActionButton(
                            icon: isSilenced
                                ? Icons.notifications_off
                                : Icons.notifications_none_outlined,
                            label: isSilenced ? 'Unsilence' : 'Silence',
                            onTap: () {
                              Navigator.pop(context);
                              showDialog(
                                context: context,
                                builder: (context) =>
                                    SilenceClusterDialog(chatId: chat.chatId),
                              );
                            },
                          ),
                          _ActionButton(
                            icon: Icons.exit_to_app,
                            label: 'Exit Orbit',
                            color: Colors.redAccent,
                            onTap: () => _confirmLeave(context, ref, myUid),
                          ),
                        ],
                      ),
                      const Divider(height: 48, color: Colors.white10),

                      // Members List
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'SPARQS',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                            color: Colors.white38,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: chat.participants.length,
                        itemBuilder: (context, index) {
                          final uid = chat.participants[index];
                          return _MemberTile(
                            uid: uid,
                            chatId: chat.chatId,
                            isGroupAdmin: chat.admins.contains(uid),
                            showAdminTools: isAdmin,
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmLeave(
    BuildContext context,
    WidgetRef ref,
    String myUid,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Warp Out?'),
        content: const Text(
          'Are you sure you want to exit this cluster orbit?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Exit Orbit',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ref.read(chatRepositoryProvider).leaveGroup(chat.chatId, myUid);
      if (context.mounted) {
        Navigator.pop(context); // Close Popup
        context.pop(); // Exit Chat Screen
      }
    }
  }
}

class _MemberTile extends ConsumerWidget {
  final String uid;
  final String chatId;
  final bool isGroupAdmin;
  final bool showAdminTools;

  const _MemberTile({
    required this.uid,
    required this.chatId,
    required this.isGroupAdmin,
    required this.showAdminTools,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(chatProfileProvider(uid));

    return profileAsync.when(
      data: (profile) {
        if (profile == null) return const SizedBox.shrink();
        final myUid = ref.read(authRepositoryProvider).currentUser?.id;
        final isSelf = uid == myUid;

        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: CircleAvatar(
            radius: 16,
            backgroundColor: Colors.white10,
            backgroundImage: profile.photoUrl.isNotEmpty
                ? CachedNetworkImageProvider(profile.photoUrl)
                : null,
            child: profile.photoUrl.isEmpty
                ? const Icon(Icons.person, size: 16, color: Colors.white54)
                : null,
          ),
          title: Row(
            children: [
              Text(
                isSelf ? '${profile.xparqName} (You)' : profile.xparqName,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (isGroupAdmin) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1D9BF0).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: const Color(0xFF1D9BF0),
                      width: 0.5,
                    ),
                  ),
                  child: const Text(
                    'Admin',
                    style: TextStyle(
                      fontSize: 8,
                      color: Color(0xFF1D9BF0),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
          subtitle: Text(
            '@${profile.handle}',
            style: const TextStyle(fontSize: 11, color: Colors.white38),
          ),
          trailing: (showAdminTools && !isGroupAdmin)
              ? IconButton(
                  icon: const Icon(
                    Icons.shield_outlined,
                    size: 18,
                    color: Colors.white38,
                  ),
                  tooltip: 'Promote to Admin',
                  onPressed: () => _confirmPromote(context, ref, profile),
                )
              : (showAdminTools && isGroupAdmin && !isSelf)
              ? const Icon(
                  Icons.verified_user,
                  size: 18,
                  color: Color(0xFF1D9BF0),
                )
              : null,
          onTap: () {
            showDialog(
              context: context,
              builder: (ctx) =>
                  MiniProfilePopup(profile: profile, chatId: chatId),
            );
          },
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (__, _) => const SizedBox.shrink(),
    );
  }

  Future<void> _confirmPromote(
    BuildContext context,
    WidgetRef ref,
    PlanetModel profile,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Promote Sparq?'),
        content: Text(
          'Make ${profile.xparqName} an administrator of this Cluster?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Promote',
              style: TextStyle(color: Color(0xFF1D9BF0)),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ref.read(chatRepositoryProvider).promoteToAdmin(chatId, profile.id);
    }
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final primaryColor = color ?? const Color(0xFF1D9BF0);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          children: [
            Icon(icon, color: primaryColor, size: 24),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(fontSize: 11, color: Colors.white60),
            ),
          ],
        ),
      ),
    );
  }
}
