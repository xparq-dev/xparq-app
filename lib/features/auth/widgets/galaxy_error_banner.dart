import 'dart:ui';
import 'package:flutter/material.dart';

enum GalaxyBannerVariant { error, warning, info, success }

class GalaxyErrorBanner extends StatelessWidget {
  final String message;
  final String? title;
  final VoidCallback? onDismiss;

  final GalaxyBannerVariant variant;
  final bool enableBlur;
  final Widget? icon;

  const GalaxyErrorBanner({
    super.key,
    required this.message,
    this.title,
    this.onDismiss,
    this.variant = GalaxyBannerVariant.error,
    this.enableBlur = true,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final colors = _resolveColors(theme);

    Widget content = Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border, width: 1.5),
        boxShadow: [
          if (isDark)
            BoxShadow(
              color: colors.main.withOpacity(0.15),
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
              color: colors.main.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: icon ??
                Icon(
                  _resolveIcon(),
                  color: colors.main,
                  size: 20,
                ),
          ),

          const SizedBox(width: 16),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (title != null)
                  Text(
                    title!,
                    style: TextStyle(
                      color: colors.main,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                if (title != null) const SizedBox(height: 2),
                Text(
                  message,
                  style: TextStyle(
                    color: theme.colorScheme.onSurface.withOpacity(0.9),
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
              color: colors.main.withOpacity(0.6),
            ),
        ],
      ),
    );

    if (!enableBlur) return content;

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: content,
      ),
    );
  }

  // ======================
  // Helpers
  // ======================

  IconData _resolveIcon() {
    switch (variant) {
      case GalaxyBannerVariant.error:
        return Icons.error_outline;
      case GalaxyBannerVariant.warning:
        return Icons.warning_amber_rounded;
      case GalaxyBannerVariant.info:
        return Icons.info_outline;
      case GalaxyBannerVariant.success:
        return Icons.check_circle_outline;
    }
  }

  _BannerColors _resolveColors(ThemeData theme) {
    final scheme = theme.colorScheme;

    switch (variant) {
      case GalaxyBannerVariant.error:
        return _BannerColors(
          main: scheme.error,
          background: scheme.error.withOpacity(0.08),
          border: scheme.error.withOpacity(0.3),
        );

      case GalaxyBannerVariant.warning:
        return _BannerColors(
          main: Colors.orange,
          background: Colors.orange.withOpacity(0.08),
          border: Colors.orange.withOpacity(0.3),
        );

      case GalaxyBannerVariant.info:
        return _BannerColors(
          main: scheme.primary,
          background: scheme.primary.withOpacity(0.08),
          border: scheme.primary.withOpacity(0.3),
        );

      case GalaxyBannerVariant.success:
        return _BannerColors(
          main: Colors.green,
          background: Colors.green.withOpacity(0.08),
          border: Colors.green.withOpacity(0.3),
        );
    }
  }
}

class _BannerColors {
  final Color main;
  final Color background;
  final Color border;

  _BannerColors({
    required this.main,
    required this.background,
    required this.border,
  });
}