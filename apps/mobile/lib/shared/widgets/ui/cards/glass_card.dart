import 'dart:ui';
import 'package:flutter/material.dart';

class GlassCard extends StatelessWidget {
  final Widget child;
  final double blur;
  final double opacity;
  final BorderRadius? borderRadius;
  final Border? border;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? color;

  const GlassCard({
    super.key,
    required this.child,
    this.blur = 10.0,
    this.opacity = 0.05,
    this.borderRadius,
    this.border,
    this.padding,
    this.margin,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final finalBorderRadius = borderRadius ?? BorderRadius.circular(24);

    // Only apply glass effect in Dark Mode for a premium galactic feel
    if (!isDark) {
      return Container(
        padding: padding,
        margin: margin,
        decoration: BoxDecoration(
          color: color ?? Theme.of(context).cardColor,
          borderRadius: finalBorderRadius,
          border: border,
        ),
        child: child,
      );
    }

    return Container(
      margin: margin,
      child: ClipRRect(
        borderRadius: finalBorderRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: (color ?? Colors.white).withValues(alpha: opacity),
              borderRadius: finalBorderRadius,
              border:
                  border ??
                  Border.all(
                    color: Colors.white.withValues(alpha: 0.1),
                    width: 1.5,
                  ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
