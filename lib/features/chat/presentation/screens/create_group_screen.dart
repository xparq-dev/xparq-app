import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:xparq_app/shared/router/app_router.dart';
import 'package:xparq_app/features/auth/providers/auth_providers.dart';
import 'package:xparq_app/features/social/providers/orbit_providers.dart';
import 'package:xparq_app/features/chat/presentation/providers/chat_providers.dart';
import 'package:xparq_app/shared/widgets/common/xparq_image.dart';
import 'package:xparq_app/l10n/app_localizations.dart';

class CreateGroupScreen extends ConsumerStatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  ConsumerState<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends ConsumerState<CreateGroupScreen> {
  final List<String> _selectedUids = [];
  final _nameController = TextEditingController();
  bool _isCreating = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _toggleParticipant(String uid) {
    setState(() {
      if (_selectedUids.contains(uid)) {
        _selectedUids.remove(uid);
      } else {
        _selectedUids.add(uid);
      }
    });
  }

  Future<void> _createGroup() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.groupEnterName)),
      );
      return;
    }
    if (_selectedUids.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.groupSelectParticipant),
        ),
      );
      return;
    }

    setState(() => _isCreating = true);
    try {
      final myUid = ref.read(authRepositoryProvider).currentUser?.id ?? '';
      final participants = [myUid, ..._selectedUids];

      final chat = await ref
          .read(chatRepositoryProvider)
          .createGroupChat(
            participantUids: participants,
            name: _nameController.text.trim(),
          );

      if (mounted) {
        context.pushReplacement('${AppRoutes.chat}/${chat.chatId}/group');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.failedPrefix(e.toString()),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final myUid = ref.watch(authRepositoryProvider).currentUser?.id ?? '';
    final friendsAsync = ref.watch(
      orbitListProvider(OrbitListParams(myUid, 'orbiting')),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.groupNew),
        actions: [
          if (_isCreating)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else
            TextButton(
              onPressed: _createGroup,
              child: Text(
                AppLocalizations.of(context)!.groupCreate,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _nameController,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context)!.groupName,
                labelStyle: TextStyle(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.6),
                ),
                hintText: AppLocalizations.of(context)!.groupNameHint,
                hintStyle: TextStyle(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.38),
                ),
                prefixIcon: Icon(
                  Icons.group_outlined,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.54),
                ),
                filled: true,
                fillColor: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.05),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                AppLocalizations.of(context)!.groupSelectParticipants,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
          ),
          Expanded(
            child: friendsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Text(
                  AppLocalizations.of(context)!.errorPrefix(e.toString()),
                ),
              ),
              data: (friends) {
                if (friends.isEmpty) {
                  return Center(
                    child: Text(AppLocalizations.of(context)!.groupAddFriends),
                  );
                }
                return ListView.builder(
                  itemCount: friends.length,
                  itemBuilder: (ctx, idx) {
                    final friend = friends[idx];
                    final isSelected = _selectedUids.contains(friend.id);
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundImage: friend.photoUrl.isNotEmpty
                            ? XparqImage.getImageProvider(friend.photoUrl)
                            : null,
                        child: friend.photoUrl.isEmpty
                            ? const Icon(Icons.person)
                            : null,
                      ),
                      title: Text(friend.xparqName),
                      subtitle: Text(
                        '@${friend.handle ?? 'Explorer'}',
                      ),
                      trailing: Checkbox(
                        value: isSelected,
                        onChanged: (_) => _toggleParticipant(friend.id),
                        shape: const CircleBorder(),
                        activeColor: Theme.of(context).colorScheme.primary,
                        checkColor: Theme.of(context).colorScheme.onPrimary,
                      ),
                      onTap: () => _toggleParticipant(friend.id),
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

