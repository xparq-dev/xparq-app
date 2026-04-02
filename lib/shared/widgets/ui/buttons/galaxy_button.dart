import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum GalaxyButtonVariant { primary, outline, ghost }

class GalaxyButton extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final bool isLoading;
  final double? width;
  final double height;
  final GalaxyButtonVariant variant;
  final Widget? leading;
  final Widget? trailing;

  const GalaxyButton({
    super.key,
    required this.child,
    required this.onTap,
    this.isLoading = false,
    this.width,
    this.height = 52,
    this.variant = GalaxyButtonVariant.primary,
    this.leading,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(height / 2);

    final isDisabled = isLoading || onTap == null;

    final colorScheme = Theme.of(context).colorScheme;

    Color backgroundColor;
    Color borderColor;
    Color textColor;

    switch (variant) {
      case GalaxyButtonVariant.primary:
        backgroundColor =
            isDisabled ? colorScheme.primary.withOpacity(0.4) : colorScheme.primary;
        borderColor = Colors.transparent;
        textColor = Colors.white;
        break;

      case GalaxyButtonVariant.outline:
        backgroundColor = Colors.transparent;
        borderColor = colorScheme.primary.withOpacity(0.6);
        textColor = colorScheme.primary;
        break;

      case GalaxyButtonVariant.ghost:
        backgroundColor = Colors.transparent;
        borderColor = Colors.transparent;
        textColor = colorScheme.primary;
        break;
    }

    return Opacity(
      opacity: isDisabled ? 0.6 : 1.0,
      child: Container(
        width: width ?? double.infinity,
        height: height,
        decoration: BoxDecoration(
          borderRadius: radius,
          color: backgroundColor,
          border: Border.all(color: borderColor, width: 1.5),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: radius,
            onTap: isDisabled
                ? null
                : () {
                    HapticFeedback.lightImpact();
                    onTap!();
                  },
            child: Center(
              child: isLoading
                  ? SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: textColor,
                      ),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (leading != null) ...[
                          leading!,
                          const SizedBox(width: 8),
                        ],
                        DefaultTextStyle(
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: textColor,
                          ),
                          child: child,
                        ),
                        if (trailing != null) ...[
                          const SizedBox(width: 8),
                          trailing!,
                        ],
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}