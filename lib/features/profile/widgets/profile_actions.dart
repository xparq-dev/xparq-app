// lib/features/profile/widgets/profile_actions.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:xparq_app/l10n/app_localizations.dart';
import 'package:xparq_app/features/auth/providers/auth_providers.dart';
import 'package:xparq_app/features/chat/presentation/providers/chat_providers.dart';
import 'package:xparq_app/features/profile/widgets/orbit_button.dart';

class ProfileActions extends ConsumerWidget {
  final String viewingUid;
  final bool isOwnProfile;

  const ProfileActions({
    super.key,
    required this.viewingUid,
    required this.isOwnProfile,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (isOwnProfile) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: OrbitButton(targetUid: viewingUid)),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _handleMessage(context, ref),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.24),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: Text(
                    AppLocalizations.of(context)!.message,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _handleRequestContact(context, ref),
              icon: const Icon(Icons.contact_page_outlined, size: 18),
              label: Text(AppLocalizations.of(context)!.requestContact),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF4FC3F7),
                side: const BorderSide(color: Color(0xFF4FC3F7), width: 1),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleMessage(BuildContext context, WidgetRef ref) async {
    final myUid = ref.read(authRepositoryProvider).currentUser?.id;
    if (myUid == null) return;

    try {
      final chat = await ref
          .read(chatBaseRepositoryProvider)
          .getOrCreateChat(myUid: myUid, otherUid: viewingUid);

      if (context.mounted) {
        context.push('/chat/${chat.chatId}/$viewingUid');
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(
                context,
              )!.profileErrorOpeningChat(e.toString()),
            ),
          ),
        );
      }
    }
  }

  Future<void> _handleRequestContact(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final currentUser = ref.read(supabaseAuthStateProvider).valueOrNull;
    if (currentUser == null) return;
    final myProfile = ref.read(planetProfileProvider).valueOrNull;
    if (myProfile == null) return;

    try {
      final chat = await ref
          .read(chatBaseRepositoryProvider)
          .getOrCreateChat(myUid: currentUser.id, otherUid: viewingUid);
      await ref
          .read(contactRequestRepositoryProvider)
          .sendContactRequest(
            chatId: chat.chatId,
            senderProfile: myProfile,
            targetUid: viewingUid,
          );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.contactRequestSent),
            backgroundColor: const Color(0xFF4FC3F7),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.error(e.toString())),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
