// lib/features/radar/widgets/offline_xparq_components.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:xparq_app/l10n/app_localizations.dart';

class OfflineXparqList extends StatelessWidget {
  final List<dynamic> xparqs;
  const OfflineXparqList({super.key, required this.xparqs});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textSecondary = isDark
        ? const Color(0xFF71767B)
        : const Color(0xFF536471);
    const accentColor = Color(0xFFF91880); // Pink for Bluetooth

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('📡', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 12),
          Text(
            AppLocalizations.of(context)!.radarOfflineTitle,
            style: TextStyle(color: textSecondary),
          ),
          const SizedBox(height: 4),
          Text(
            AppLocalizations.of(context)!.radarOfflineSubtitle,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            icon: const Icon(Icons.arrow_forward_rounded),
            label: Text(AppLocalizations.of(context)!.offlineDashboard),
            style: ElevatedButton.styleFrom(
              backgroundColor: accentColor,
              foregroundColor: Colors.white,
            ),
            onPressed: () => context.push('/offline/permission'),
          ),
        ],
      ),
    );
  }
}
