import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:xparq_app/l10n/app_localizations.dart';

class GalaxyErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback? onDismiss;

  const GalaxyErrorBanner({super.key, required this.message, this.onDismiss});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryError = const Color(0xFFFF6B6B);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: primaryError.withValues(alpha: isDark ? 0.1 : 0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.fromBorderSide(
                BorderSide(
                  color: primaryError.withValues(alpha: 0.3),
                  width: 1.5,
                ),
              ),
              boxShadow: [
                if (isDark)
                  BoxShadow(
                    color: primaryError.withValues(alpha: 0.1),
                    blurRadius: 20,
                    spreadRadius: -5,
                  ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: primaryError.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.warning_amber_rounded,
                    color: Color(0xFFFF6B6B),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        AppLocalizations.of(context)!.authErrorGeneric
                            .split('.')
                            .first, // "An error occurred"
                        style: const TextStyle(
                          color: Color(0xFFFF6B6B),
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        message,
                        style: TextStyle(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.9)
                              : Colors.black87,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                if (onDismiss != null)
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: onDismiss,
                    color: primaryError.withValues(alpha: 0.5),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
