import 'package:flutter/material.dart';
import 'package:xparq_app/shared/widgets/ui/buttons/galaxy_button.dart';
import 'package:xparq_app/shared/widgets/ui/cards/glass_card.dart';

class BlockReportForm extends StatelessWidget {
  const BlockReportForm({
    super.key,
    required this.reasonController,
    required this.isBlocking,
    required this.isReporting,
    required this.onBlock,
    required this.onReport,
    required this.targetDisplayName,
  });

  final TextEditingController reasonController;
  final bool isBlocking;
  final bool isReporting;
  final VoidCallback onBlock;
  final VoidCallback onReport;
  final String targetDisplayName;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(24),
      borderRadius: BorderRadius.circular(28),
      opacity: 0.08,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Safety Actions',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            'Manage block and report actions for $targetDisplayName.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.72),
            ),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: reasonController,
            enabled: !isReporting,
            minLines: 3,
            maxLines: 5,
            maxLength: 500,
            decoration: InputDecoration(
              labelText: 'Report reason',
              alignLabelWithHint: true,
              hintText: 'Describe why you are reporting this user.',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          const SizedBox(height: 16),
          GalaxyButton(
            label: 'Block User',
            isLoading: isBlocking,
            onTap: isBlocking || isReporting ? null : onBlock,
          ),
          const SizedBox(height: 12),
          GalaxyButton(
            label: 'Report User',
            isPrimary: false,
            isLoading: isReporting,
            onTap: isBlocking || isReporting ? null : onReport,
          ),
        ],
      ),
    );
  }
}
