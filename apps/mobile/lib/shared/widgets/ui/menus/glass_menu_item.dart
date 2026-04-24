import 'package:flutter/material.dart';

class GlassMenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;
  final bool isDangerous;

  const GlassMenuItem({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
    this.isDangerous = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final displayColor = isDangerous ? const Color(0xFFFF6B6B) : (color ?? theme.colorScheme.onSurface);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 20, color: displayColor.withValues(alpha: 0.8)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: displayColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
