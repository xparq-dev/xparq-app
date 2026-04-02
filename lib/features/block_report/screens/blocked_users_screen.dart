// lib/features/block_report/screens/blocked_users_screen.dart
//
// Shows the list of blocked users with option to unblock.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/block_report_providers.dart';
import '../../../l10n/app_localizations.dart';

class BlockedUsersScreen extends ConsumerWidget {
  const BlockedUsersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final blockedAsync = ref.watch(blockedUidsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context)!.blockedSparqs)),
      body: blockedAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: Color(0xFF4FC3F7)),
        ),
        error: (e, _) => Center(
          child: Text(
            AppLocalizations.of(context)!.errorPrefix(e.toString()),
            style: const TextStyle(color: Colors.red),
          ),
        ),
        data: (uids) {
          if (uids.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('🛡️', style: TextStyle(fontSize: 48)),
                  SizedBox(height: 12),
                  Text(
                    AppLocalizations.of(context)!.noBlockedSparqs,
                    style: TextStyle(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withOpacity(0.54),
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            itemCount: uids.length,
            separatorBuilder: (_, _) => Divider(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withOpacity(0.10),
              height: 1,
            ),
            itemBuilder: (context, index) {
              final uid = uids[index];
              return ListTile(
                leading: CircleAvatar(
                  radius: 22,
                  backgroundColor: const Color(0xFF1E3A5F),
                  child: Text(
                    uid.substring(0, 2).toUpperCase(),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                title: Text(
                  uid.substring(0, 8),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  AppLocalizations.of(context)!.blocked,
                  style: TextStyle(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withOpacity(0.38),
                    fontSize: 12,
                  ),
                ),
                trailing: TextButton(
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (_) => AlertDialog(
                        backgroundColor: const Color(0xFF0D1B2A),
                        title: Text(
                          'Unblock',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        content: Text(
                          AppLocalizations.of(context)!.unblockConfirmDesc,
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withOpacity(0.7),
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: Text(
                              AppLocalizations.of(context)!.cancel,
                              style: TextStyle(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurface.withOpacity(0.54),
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: Text(
                              AppLocalizations.of(context)!.unblock,
                              style: TextStyle(color: Color(0xFF4FC3F7)),
                            ),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      await ref
                          .read(blockNotifierProvider.notifier)
                          .unblock(uid);
                    }
                  },
                  child: Text(
                    'Unblock',
                    style: TextStyle(color: Color(0xFF4FC3F7)),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
