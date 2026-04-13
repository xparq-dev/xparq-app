import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:xparq_app/features/chat/domain/models/chat_model.dart';
import 'package:xparq_app/features/chat/presentation/providers/chat_providers.dart';
import 'package:xparq_app/features/chat/presentation/widgets/member_search_popup.dart';
import 'package:xparq_app/features/block_report/widgets/report_bottom_sheet.dart';
import 'package:xparq_app/l10n/app_localizations.dart';
import 'package:xparq_app/features/auth/providers/auth_providers.dart';
import 'package:xparq_app/features/chat/presentation/widgets/mini_profile_popup.dart';
import 'dart:ui';
import 'package:xparq_app/shared/widgets/ui/cards/glass_card.dart';
import 'package:xparq_app/shared/widgets/ui/menus/glass_menu_item.dart';
import 'app_bar_components.dart';

class SignalChatAppBar extends ConsumerWidget implements PreferredSizeWidget {
  final String chatId;
  final String otherUid;
  final ChatModel? chat;
  final bool isGroup;
  final VoidCallback onVanishingDialog;
  final VoidCallback onDeleteChat;
  final VoidCallback onRepairSession;
  final void Function(String, ChatModel) onGroupAction;

  const SignalChatAppBar({
    super.key,
    required this.chatId,
    required this.otherUid,
    this.chat,
    required this.isGroup,
    required this.onVanishingDialog,
    required this.onDeleteChat,
    required this.onRepairSession,
    required this.onGroupAction,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final otherProfile = !isGroup
        ? (ref.watch(chatProfileProvider(otherUid)).valueOrNull ?? 
           ref.watch(profileCacheProvider)[otherUid])
        : null;
    final otherPresence = !isGroup
        ? ref.watch(userPresenceProvider(otherUid))
        : null;

    return AppBar(
      elevation: 0,
      backgroundColor: theme.scaffoldBackgroundColor,
      titleSpacing: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => context.pop(),
      ),
      title: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          if (!isGroup && otherProfile != null) {
            showDialog(
              context: context,
              builder: (context) => MiniProfilePopup(
                profile: otherProfile,
                chatId: chatId,
              ),
            );
          }
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: ChatAppBarTitle(
            isGroup: isGroup,
            chat: chat,
            otherProfile: otherProfile,
            otherPresence: otherPresence,
            theme: theme,
          ),
        ),
      ),
      actions: [
        if (isGroup && chat != null) ...[
          IconButton(
            icon: Icon(
              Icons.call_outlined,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
            onPressed: () {},
          ),
          IconButton(
            icon: Icon(
              Icons.person_add_outlined,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
            onPressed: () => showDialog<void>(
              context: context,
              builder: (context) => MemberSearchPopup(chat: chat!),
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.more_vert,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
            onPressed: () => _showGlassMenu(context, ref, isGroupMenu: true),
          ),
        ] else ...[
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () => _showGlassMenu(context, ref, isGroupMenu: false),
          ),
        ],
      ],
    );
  }

  Future<void> _showBlockDialog(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Block XPARQ?'),
        content: const Text('They will no longer be able to contact you.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Block',
              style: TextStyle(color: Color(0xFFFF6B6B)),
            ),
          ),
        ],
      ),
    );
    if (confirm == true && context.mounted) {
      // Logic handled in screen
    }
  }

  void _showGlassMenu(BuildContext context, WidgetRef ref, {required bool isGroupMenu}) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black.withValues(alpha: 0.4),
      transitionDuration: const Duration(milliseconds: 250),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(opacity: animation, child: ScaleTransition(scale: animation, alignment: Alignment.topRight, child: child));
      },
      pageBuilder: (context, animation, secondaryAnimation) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Stack(
            children: [
              Positioned(
                top: kToolbarHeight + MediaQuery.of(context).padding.top - 10,
                right: 12,
                child: Material(
                  color: Colors.transparent,
                  child: SizedBox(
                    width: 240,
                    child: GlassCard(
                      borderRadius: BorderRadius.circular(20),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: isGroupMenu ? _buildGroupItems(context, ref) : _buildPrivateItems(context, ref),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _buildGroupItems(BuildContext context, WidgetRef ref) {
    return [
      GlassMenuItem(
        icon: Icons.notifications_off_outlined,
        label: 'Silence Cluster',
        onTap: () {
          Navigator.pop(context);
          onGroupAction('silence', chat!);
        },
      ),
      GlassMenuItem(
        icon: Icons.info_outline,
        label: 'Cluster Core',
        onTap: () {
          Navigator.pop(context);
          onGroupAction('info', chat!);
        },
      ),
      GlassMenuItem(
        icon: Icons.person_add_outlined,
        label: 'Add iXPARQs',
        onTap: () {
          Navigator.pop(context);
          onGroupAction('add', chat!);
        },
      ),
      GlassMenuItem(
        icon: Icons.timer_outlined,
        label: 'Whisper Cluster',
        onTap: () {
          Navigator.pop(context);
          onGroupAction('whisper', chat!);
        },
      ),
      const Divider(color: Colors.white10),
      GlassMenuItem(
        icon: Icons.report_problem_outlined,
        label: 'Alert Anomaly',
        isDangerous: true,
        onTap: () {
          Navigator.pop(context);
          onGroupAction('report', chat!);
        },
      ),
    ];
  }

  List<Widget> _buildPrivateItems(BuildContext context, WidgetRef ref) {
    return [
      GlassMenuItem(
        icon: Icons.block,
        label: 'Block',
        onTap: () {
          Navigator.pop(context);
          _showBlockDialog(context, ref);
        },
      ),
      GlassMenuItem(
        icon: Icons.report_problem_outlined,
        label: 'Report',
        isDangerous: true,
        onTap: () {
          Navigator.pop(context);
          unawaited(
            showReportSheet(
              context,
              ref,
              targetUid: otherUid,
              chatId: chatId,
              reportContext: 'chat',
            ),
          );
        },
      ),
      const Divider(color: Colors.white10),
      GlassMenuItem(
        icon: Icons.history_toggle_off,
        label: AppLocalizations.of(context)!.vanishingMessages,
        onTap: () {
          Navigator.pop(context);
          onVanishingDialog();
        },
      ),
      GlassMenuItem(
        icon: Icons.delete_outline,
        label: 'Delete Chat',
        isDangerous: true,
        onTap: () {
          Navigator.pop(context);
          onDeleteChat();
        },
      ),
      const Divider(color: Colors.white10),
      GlassMenuItem(
        icon: Icons.build_outlined,
        label: 'Repair Discussion',
        onTap: () {
          Navigator.pop(context);
          onRepairSession();
        },
      ),
    ];
  }
}
