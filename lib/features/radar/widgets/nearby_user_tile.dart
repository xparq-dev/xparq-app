import 'package:flutter/material.dart';
import 'package:xparq_app/core/widgets/glass_card.dart';
import 'package:xparq_app/features/radar/models/nearby_user_model.dart';

class NearbyUserTile extends StatelessWidget {
  const NearbyUserTile({super.key, required this.user});

  final NearbyUser user;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(16),
      borderRadius: BorderRadius.circular(20),
      opacity: 0.08,
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: const Color(0xFF1D9BF0).withValues(alpha: 0.16),
            child: Text(
              user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
              style: const TextStyle(
                color: Color(0xFF1D9BF0),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.name,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatDistance(user.distance),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.72),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDistance(double distanceKm) {
    if (distanceKm < 1) {
      return '${(distanceKm * 1000).toStringAsFixed(0)} m away';
    }

    if (distanceKm < 10) {
      return '${distanceKm.toStringAsFixed(2)} km away';
    }

    return '${distanceKm.toStringAsFixed(1)} km away';
  }
}
