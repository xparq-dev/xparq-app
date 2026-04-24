// lib/features/profile/widgets/orbit_button.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xparq_app/features/social/providers/orbit_providers.dart';
import 'package:xparq_app/features/auth/providers/auth_providers.dart';
import 'package:xparq_app/l10n/app_localizations.dart';

class OrbitButton extends ConsumerWidget {
  final String targetUid;

  const OrbitButton({super.key, required this.targetUid});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusMapAsync = ref.watch(myOrbitingStatusProvider);
    final currentUser = ref.watch(supabaseAuthStateProvider).valueOrNull;

    return statusMapAsync.when(
      data: (statusMap) {
        final status = statusMap[targetUid]; // 'pending', 'accepted', or null
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;

        if (status == 'accepted') {
          return ElevatedButton.icon(
            onPressed: () =>
                _showUnorbitDialog(context, ref, currentUser!.id, targetUid),
            icon: const Icon(Icons.check_circle, size: 18),
            label: Text(AppLocalizations.of(context)!.orbiting),
            style: ElevatedButton.styleFrom(
              backgroundColor: isDark
                  ? Colors.blueGrey.shade800
                  : Colors.blue.shade100,
              foregroundColor: isDark ? Colors.white : Colors.blue.shade900,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(vertical: 12),
              elevation: 0,
            ),
          );
        } else if (status == 'pending') {
          return ElevatedButton.icon(
            onPressed: () => ref
                .read(orbitRepositoryProvider)
                .removeOrbit(currentUser!.id, targetUid),
            icon: const Icon(Icons.hourglass_empty, size: 18),
            label: Text(AppLocalizations.of(context)!.requested),
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.onSurface.withValues(alpha: 0.1),
              foregroundColor: theme.colorScheme.onSurface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(vertical: 12),
              elevation: 0,
            ),
          );
        } else {
          return ElevatedButton.icon(
            onPressed: () {
              if (currentUser != null) {
                ref
                    .read(orbitRepositoryProvider)
                    .sendOrbitRequest(currentUser.id, targetUid);
              }
            },
            icon: const Icon(Icons.rocket_launch, size: 18),
            label: Text(AppLocalizations.of(context)!.orbit),
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.onSurface,
              foregroundColor: theme.colorScheme.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          );
        }
      },
      loading: () => const ElevatedButton(
        onPressed: null,
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
      error: (__, _) => const SizedBox.shrink(),
    );
  }

  void _showUnorbitDialog(
    BuildContext context,
    WidgetRef ref,
    String currentUid,
    String targetUid,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.disconnectConfirmTitle),
        content: Text(
          AppLocalizations.of(context)!.orbitDisconnectDesc('this user'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          TextButton(
            onPressed: () async {
              try {
                await ref
                    .read(orbitRepositoryProvider)
                    .removeOrbit(currentUid, targetUid);
                if (context.mounted) Navigator.pop(context);
              } catch (e) {
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        AppLocalizations.of(
                          context,
                        )!.failedPrefix(e.toString()),
                      ),
                    ),
                  );
                }
              }
            },
            child: Text(
              AppLocalizations.of(context)!.disconnect,
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }
}
