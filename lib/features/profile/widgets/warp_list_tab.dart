// lib/features/profile/widgets/warp_list_tab.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xparq_app/features/social/providers/pulse_providers.dart';
import 'package:xparq_app/features/social/widgets/pulse_card.dart';

class WarpListTab extends ConsumerWidget {
  final String uid;
  const WarpListTab({super.key, required this.uid});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final warpsAsync = ref.watch(userWarpsProvider(uid));

    return warpsAsync.when(
      data: (pulses) {
        if (pulses.isEmpty) {
          return Center(
            child: Text(
              'No warps yet.',
              style: TextStyle(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withOpacity(0.38),
              ),
            ),
          );
        }
        return ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          itemCount: pulses.length,
          itemBuilder: (context, index) => PulseCard(pulse: pulses[index]),
        );
      },
      loading: () => Center(
        child: CircularProgressIndicator(
          color: Theme.of(
            context,
          ).colorScheme.onSurface.withOpacity(0.24),
        ),
      ),
      error: (e, _) => Center(
        child: Text(
          'Error: $e',
          style: TextStyle(
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withOpacity(0.38),
          ),
        ),
      ),
    );
  }
}
