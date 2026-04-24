// lib/features/block_report/widgets/report_bottom_sheet.dart
//
// A bottom sheet used across Chat and Profile to submit a report + block.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/block_report_models.dart';
import '../providers/block_report_providers.dart';

/// Show the report bottom sheet.
/// [context] is used to pop the sheet.
/// [ref] is the Riverpod WidgetRef.
/// [targetUid] is the UID of the user being reported.
/// [chatId] is optional — pass when reporting from a chat.
/// [reportContext] is "chat" | "profile" | "radar".
Future<void> showReportSheet(
  BuildContext context,
  WidgetRef ref, {
  required String targetUid,
  String? chatId,
  String reportContext = 'chat',
}) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: const Color(0xFF0D1B2A),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    isScrollControlled: true,
    builder: (_) => _ReportSheet(
      targetUid: targetUid,
      chatId: chatId,
      reportContext: reportContext,
      ref: ref,
    ),
  );
}

class _ReportSheet extends StatefulWidget {
  final String targetUid;
  final String? chatId;
  final String reportContext;
  final WidgetRef ref;

  const _ReportSheet({
    required this.targetUid,
    required this.chatId,
    required this.reportContext,
    required this.ref,
  });

  @override
  State<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<_ReportSheet> {
  ReportReason? _selectedReason;
  final _detailController = TextEditingController();
  bool _alsoBlock = true;
  bool _submitting = false;

  @override
  void dispose() {
    _detailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_selectedReason == null) return;
    setState(() => _submitting = true);

    final notifier = widget.ref.read(blockNotifierProvider.notifier);

    await notifier.report(
      targetUid: widget.targetUid,
      reason: _selectedReason!,
      chatId: widget.chatId,
      detail: _detailController.text.trim().isEmpty
          ? null
          : _detailController.text.trim(),
      context: widget.reportContext,
    );

    if (_alsoBlock) {
      await notifier.block(widget.targetUid);
    }

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Report submitted. Thank you for keeping the galaxy safe. 🛡️',
          ),
          backgroundColor: Color(0xFF1E3A5F),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle Bar
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.24),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          SizedBox(height: 20),

          Text(
            'Report Sparq',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Why are you reporting this Sparq?',
            style: TextStyle(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.54),
              fontSize: 13,
            ),
          ),
          SizedBox(height: 20),

          // Reason Chips
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: ReportReason.values.map((reason) {
              final selected = _selectedReason == reason;
              return ChoiceChip(
                label: Text(
                  reason.displayName,
                  style: TextStyle(
                    color: selected
                        ? Colors.black
                        : Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.7),
                    fontSize: 13,
                  ),
                ),
                selected: selected,
                onSelected: (_) => setState(() => _selectedReason = reason),
                selectedColor: const Color(0xFFFF6B6B),
                backgroundColor: const Color(0xFF1A2A40),
                side: BorderSide(
                  color: selected
                      ? const Color(0xFFFF6B6B)
                      : Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.12),
                ),
              );
            }).toList(),
          ),
          SizedBox(height: 20),

          // Optional detail
          TextField(
            controller: _detailController,
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            maxLines: 2,
            decoration: InputDecoration(
              hintText: 'Additional details (optional)',
              hintStyle: TextStyle(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.38),
              ),
              filled: true,
              fillColor: const Color(0xFF1A2A40),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          SizedBox(height: 16),

          // Also block toggle
          Row(
            children: [
              Switch(
                value: _alsoBlock,
                onChanged: (v) => setState(() => _alsoBlock = v),
                activeThumbColor: const Color(0xFFFF6B6B),
              ),
              SizedBox(width: 8),
              Text(
                'Also block this Sparq',
                style: TextStyle(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
          SizedBox(height: 20),

          // Submit
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: (_selectedReason == null || _submitting)
                  ? null
                  : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF6B6B),
                disabledBackgroundColor: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.12),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _submitting
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    )
                  : Text(
                      'Submit Report',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
