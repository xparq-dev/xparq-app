import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xparq_app/core/widgets/xparq_image.dart';
import 'package:xparq_app/features/social/models/pulse_model.dart';

class PulseHeader extends ConsumerWidget {
  final PulseModel pulse;

  const PulseHeader({super.key, required this.pulse});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final avatarUrl = pulse.authorAvatar;
    final displayName = pulse.authorName;

    return Row(
      children: [
        CircleAvatar(
          backgroundImage: avatarUrl.isNotEmpty
              ? XparqImage.getImageProvider(avatarUrl)
              : null,
          backgroundColor: Theme.of(
            context,
          ).colorScheme.onSurface.withOpacity(0.1),
          radius: 20,
          child: avatarUrl.isEmpty
              ? Icon(
                  Icons.person,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withOpacity(0.54),
                )
              : null,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                displayName,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              Text(
                '${pulse.authorPlanetType} • ${pulse.createdAt.toString()}',
                style: TextStyle(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withOpacity(0.54),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        if (pulse.isNsfw)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.2),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: Colors.redAccent.withOpacity(0.5),
              ),
            ),
            child: const Text(
              'NSFW',
              style: TextStyle(color: Colors.redAccent, fontSize: 10),
            ),
          ),
      ],
    );
  }
}
