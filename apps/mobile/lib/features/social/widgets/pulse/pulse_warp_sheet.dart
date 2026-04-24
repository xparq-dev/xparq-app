import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xparq_app/features/social/models/pulse_model.dart';

class PulseWarpSheet extends ConsumerStatefulWidget {
  final PulseModel pulse;
  const PulseWarpSheet({super.key, required this.pulse});

  @override
  ConsumerState<PulseWarpSheet> createState() => _PulseWarpSheetState();
}

class _PulseWarpSheetState extends ConsumerState<PulseWarpSheet> {
  final TextEditingController _commentController = TextEditingController();
  bool _isSending = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.rocket_launch, color: Color(0xFF4FC3F7)),
              const SizedBox(width: 12),
              Text(
                'Warp Pulse',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _commentController,
            decoration: InputDecoration(
              hintText: 'Add a thought to this warp...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: theme.colorScheme.onSurface.withValues(alpha: 0.05),
            ),
            maxLines: 3,
            textInputAction: TextInputAction.send,
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _isSending ? null : _handleWarp,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4FC3F7),
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _isSending
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.black,
                    ),
                  )
                : const Text(
                    'Warp to Orbit',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
          ),
        ],
      ),
    );
  }

  void _handleWarp() async {
    setState(() => _isSending = true);
    // Mimic API delay
    await Future.delayed(const Duration(milliseconds: 800));
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Warped successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }
}
