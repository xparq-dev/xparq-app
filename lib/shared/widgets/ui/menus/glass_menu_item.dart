import 'package:flutter/material.dart';

class GlassMenuItem extends StatelessWidget {
  final Widget leading;
  final String label;
  final VoidCallback? onTap;

  final Widget? trailing;
  final Color? color;
  final bool isDangerous;

  const GlassMenuItem({
    super.key,
    required this.leading,
    required this.label,
    required this.onTap,
    this.trailing,
    this.color,
    this.isDangerous = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final baseColor = isDangerous
        ? colorScheme.error
        : (color ?? colorScheme.onSurface);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        hoverColor: colorScheme.primary.withOpacity(0.05),
        splashColor: colorScheme.primary.withOpacity(0.1),
        highlightColor: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              IconTheme(
                data: IconThemeData(
                  size: 20,
                  color: baseColor.withOpacity(0.8),
                ),
                child: leading,
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: baseColor,
                  ),
                ),
              ),

              if (trailing != null) ...[
                const SizedBox(width: 8),
                trailing!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}