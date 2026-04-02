import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:xparq_app/core/widgets/xparq_image.dart';
import 'package:xparq_app/features/auth/providers/auth_providers.dart';
import 'package:xparq_app/core/router/app_router.dart';
import 'package:xparq_app/features/social/models/pulse_model.dart';
import 'package:xparq_app/features/social/providers/pulse_providers.dart';
import 'package:xparq_app/l10n/app_localizations.dart';

class SupernovaBar extends ConsumerWidget {
  const SupernovaBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final supernovaAsync = ref.watch(supernovaFeedProvider);

    return SizedBox(
      height: 110,
      child: supernovaAsync.when(
        data: (pulses) {
          // Group supernovas by user ID
          final Map<String, List<PulseModel>> grouped = {};
          for (var p in pulses) {
            grouped.putIfAbsent(p.uid, () => []).add(p);
          }

          final uniqueUsers = grouped.keys.toList();

          return ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: uniqueUsers.length + 1, // +1 for "Add" button
            itemBuilder: (context, index) {
              if (index == 0) {
                return _buildAddSupernovaButton(context, ref);
              }

              final uid = uniqueUsers[index - 1];
              final userPulses = grouped[uid]!;
              return _buildSupernovaAvatar(context, userPulses);
            },
          );
        },
        loading: () =>
            const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        error: (err, stack) => const SizedBox.shrink(),
      ),
    );
  }

  Widget _buildAddSupernovaButton(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(planetProfileProvider);
    final profile = profileAsync.valueOrNull;

    return GestureDetector(
      onTap: () => context.pushNamed('nebulaPicker'),
      child: Padding(
        padding: const EdgeInsets.only(right: 12),
        child: Column(
          children: [
            Stack(
              children: [
                Container(
                  width: 65,
                  height: 65,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Theme.of(context).colorScheme.surface,
                    border: Border.all(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withOpacity(0.2),
                      width: 2,
                    ),
                    image:
                        profile?.photoUrl != null &&
                            profile!.photoUrl.isNotEmpty
                        ? DecorationImage(
                            image: XparqImage.getImageProvider(
                              profile.photoUrl,
                            ),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: profile?.photoUrl == null || profile!.photoUrl.isEmpty
                      ? Icon(
                          Icons.person,
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withOpacity(0.5),
                        )
                      : null,
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      color: Color(0xFF00E5FF),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.add, color: Colors.black, size: 16),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              AppLocalizations.of(context)!.orbitSupernova,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSupernovaAvatar(BuildContext context, List<PulseModel> pulses) {
    final latestPulse = pulses.first; // Assuming sorted descending by date

    return GestureDetector(
      onTap: () {
        context.push(
          AppRoutes.supernovaViewer,
          extra: {'pulses': pulses, 'initialIndex': 0},
        );
      },
      child: Padding(
        padding: const EdgeInsets.only(right: 12),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(3),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Color(0xFF00E5FF), Color(0xFFFF4081)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Container(
                width: 59,
                height: 59,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Theme.of(context).scaffoldBackgroundColor,
                  image: latestPulse.authorAvatar.isNotEmpty
                      ? DecorationImage(
                          image: XparqImage.getImageProvider(
                            latestPulse.authorAvatar,
                          ),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: latestPulse.authorAvatar.isEmpty
                    ? Icon(
                        Icons.person,
                        color: Theme.of(context).colorScheme.onSurface,
                      )
                    : null,
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              width: 70, // Avoid text overflow
              child: Text(
                latestPulse.authorName,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
