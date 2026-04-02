import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:xparq_app/core/widgets/glass_card.dart';
import 'package:xparq_app/features/chat_signal/models/signal_event_model.dart';

class SignalEventTile extends StatelessWidget {
  const SignalEventTile({super.key, required this.event});

  final SignalEvent event;
  final JsonEncoder _encoder = const JsonEncoder.withIndent('  ');

  @override
  Widget build(BuildContext context) {
    final payloadText = _encoder.convert(event.payload);

    return GlassCard(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(16),
      borderRadius: BorderRadius.circular(20),
      opacity: 0.08,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF1D9BF0).withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              event.type,
              style: const TextStyle(
                color: Color(0xFF1D9BF0),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 12),
          SelectableText(
            payloadText,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              height: 1.45,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }
}
