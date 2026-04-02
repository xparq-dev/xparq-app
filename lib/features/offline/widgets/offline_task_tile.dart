import 'package:flutter/material.dart';
import 'package:xparq_app/core/widgets/glass_card.dart';
import 'package:xparq_app/features/offline/models/offline_task_model.dart';

class OfflineTaskTile extends StatelessWidget {
  const OfflineTaskTile({super.key, required this.task});

  final OfflineTask task;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GlassCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      borderRadius: BorderRadius.circular(20),
      opacity: 0.08,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.sync_problem_outlined),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Task ${task.id}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(14),
            ),
            child: SelectableText(
              task.prettyPayload,
              style: theme.textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
