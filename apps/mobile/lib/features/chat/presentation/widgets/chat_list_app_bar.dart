// lib/features/chat/widgets/chat_list_app_bar.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:xparq_app/l10n/app_localizations.dart';
import 'package:xparq_app/shared/router/app_router.dart';
import 'package:xparq_app/features/chat/presentation/providers/chat_providers.dart';
import 'package:xparq_app/features/auth/models/planet_model.dart';
import 'package:xparq_app/shared/widgets/common/xparq_image.dart';
import 'package:xparq_app/features/chat/presentation/screens/signal_chat_screen.dart';

class ChatListAppBar extends ConsumerWidget implements PreferredSizeWidget {
  final String myUid;
  final bool isLandscape;

  const ChatListAppBar({
    super.key,
    required this.myUid,
    required this.isLandscape,
  });

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
          onPressed: () => unawaited(_navigateToSavedMe(context, ref, myUid)),
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
      final repo = ref.read(chatBaseRepositoryProvider);
      final chat = await repo.getOrCreateChat(myUid: myUid, otherUid: myUid);
      if (context.mounted) {
        context.push('${AppRoutes.chat}/${chat.chatId}/$myUid').ignore();
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
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => CreateChatSheet(myUid: myUid),
    );
  }
}

class CreateChatSheet extends ConsumerStatefulWidget {
  final String myUid;
  const CreateChatSheet({super.key, required this.myUid});

  @override
  ConsumerState<CreateChatSheet> createState() => _CreateChatSheetState();
}

class _CreateChatSheetState extends ConsumerState<CreateChatSheet> {
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
      final repo = ref.read(chatSearchRepositoryProvider);
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
                  'No users found 🌌',
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
                    final repo = ref.read(chatBaseRepositoryProvider);
                    final chat = await repo.getOrCreateChat(
                      myUid: widget.myUid,
                      otherUid: user.id,
                    );
                    if (context.mounted) {
                      Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => SignalChatScreen(
                            chatId: chat.chatId,
                            otherUid: user.id,
                          ),
                        ),
                      ).ignore();
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

