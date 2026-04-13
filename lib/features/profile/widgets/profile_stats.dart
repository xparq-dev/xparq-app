// lib/features/profile/widgets/profile_stats.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:xparq_app/features/auth/models/planet_model.dart';
import 'package:xparq_app/l10n/app_localizations.dart';
import 'package:xparq_app/features/social/providers/orbit_providers.dart';
import 'package:xparq_app/shared/router/app_router.dart';

class ProfileStats extends ConsumerWidget {
  final PlanetModel profile;

  const ProfileStats({super.key, required this.profile});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.transparent,
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.04),
            width: 0.5,
          ),
          bottom: BorderSide(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.04),
            width: 0.5,
          ),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _ProfileStatItem(
            label: AppLocalizations.of(context)!.signals,
            uid: profile.id,
            collection: 'orbited_by',
          ),
          _StatColumnItem(
            label: AppLocalizations.of(context)!.lightYears,
            value: '1,205',
          ),
          _ProfileStatItem(
            label: AppLocalizations.of(context)!.planets,
            uid: profile.id,
            collection: 'orbiting',
          ),
        ],
      ),
    );
  }
}

class _ProfileStatItem extends ConsumerWidget {
  final String label;
  final String uid;
  final String collection;

  const _ProfileStatItem({
    required this.label,
    required this.uid,
    required this.collection,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final countAsync = ref.watch(
      orbitCountProvider(OrbitListParams(uid, collection)),
    );

    return GestureDetector(
      onTap: () {
        context.push(
          AppRoutes.orbitList,
          extra: {'uid': uid, 'collection': collection, 'title': label},
        );
      },
      child: Column(
        children: [
          Text(
            countAsync.when(
              data: (count) => count.toString(),
              loading: () => '...',
              error: (err, stack) => '0',
            ),
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.54),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatColumnItem extends StatelessWidget {
  final String label;
  final String value;
  const _StatColumnItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.54),
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

