import 'dart:ui';
import 'package:flutter/material.dart';

enum GlassCardVariant { soft, strong }

class GlassCard extends StatelessWidget {
  final Widget child;

  final double blur;
  final double opacity;

  final BorderRadius? borderRadius;
  final Border? border;

  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;

  final Color? color;

  final bool enableBlur;
  final GlassCardVariant variant;

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
    this.enableBlur = true,
    this.variant = GlassCardVariant.soft,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final radius = borderRadius ?? BorderRadius.circular(24);

    // 🔹 LIGHT MODE (fallback + shadow)
    if (!isDark) {
      return Container(
        margin: margin,
        padding: padding,
        decoration: BoxDecoration(
          color: color ?? theme.cardColor,
          borderRadius: radius,
          border: border,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: child,
      );
    }

    // 🔹 DARK MODE (glass effect)
    final effectiveOpacity = variant == GlassCardVariant.strong
        ? opacity * 1.8
        : opacity;

    final effectiveBlur = variant == GlassCardVariant.strong
        ? blur * 1.5
        : blur;

    Widget content = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: (color ?? Colors.white).withOpacity(effectiveOpacity),
        borderRadius: radius,
        border: border ??
            Border.all(
              color: Colors.white.withOpacity(0.1),
              width: 1.5,
            ),
      ),
      child: child,
    );

    // 🔥 performance guard
    if (!enableBlur) {
      return Container(
        margin: margin,
        child: content,
      );
    }

    return Container(
      margin: margin,
      child: ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: effectiveBlur,
            sigmaY: effectiveBlur,
          ),
          child: content,
        ),
      ),
    );
  }
}