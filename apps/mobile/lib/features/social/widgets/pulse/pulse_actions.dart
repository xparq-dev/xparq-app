import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xparq_app/features/social/models/pulse_model.dart';

class PulseActions extends ConsumerWidget {
  final PulseModel pulse;
  final bool isSparked;
  final int sparkCount;
  final VoidCallback onSpark;
  final VoidCallback onWarp;

  const PulseActions({
    super.key,
    required this.pulse,
    required this.isSparked,
    required this.sparkCount,
    required this.onSpark,
    required this.onWarp,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      children: [
        IconButton(
          icon: Icon(
            isSparked ? Icons.favorite : Icons.favorite_border,
            color: isSparked
                ? Colors.redAccent
                : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54),
          ),
          onPressed: onSpark,
        ),
        Text(
          sparkCount.toString(),
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54),
          ),
        ),
        const SizedBox(width: 16),
        IconButton(
          icon: Icon(
            Icons.rocket_launch_outlined,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54),
          ),
          onPressed: onWarp,
        ),
        Text(
          pulse.warpCount.toString(),
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54),
          ),
        ),
      ],
    );
  }
}
