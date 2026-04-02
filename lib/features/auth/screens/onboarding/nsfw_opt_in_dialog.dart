// lib/features/auth/screens/onboarding/nsfw_opt_in_dialog.dart
//
// Shown to Explorer users (18+) after profile creation.
// Allows them to opt into adult (Black Hole Zone) content.
// Cadets never see this dialog.

import 'package:flutter/material.dart';
import 'package:xparq_app/l10n/app_localizations.dart';

class NsfwOptInDialog extends StatelessWidget {
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  const NsfwOptInDialog({
    super.key,
    required this.onAccept,
    required this.onDecline,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF0D1B2A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('🕳️', style: TextStyle(fontSize: 48)),
            SizedBox(height: 16),
            Text(
              AppLocalizations.of(context)!.nsfwDialogTitle,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 12),
            Text(
              AppLocalizations.of(context)!.nsfwDialogContent,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withOpacity(0.6),
                height: 1.5,
                fontSize: 14,
              ),
            ),
            SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  onAccept();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7C4DFF),
                  foregroundColor: Theme.of(context).colorScheme.onSurface,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(
                  AppLocalizations.of(context)!.nsfwDialogEnable,
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
            SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  onDecline();
                },
                child: Text(
                  AppLocalizations.of(context)!.nsfwDialogCancel,
                  style: TextStyle(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withOpacity(0.38),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
