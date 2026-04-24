import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class GalaxyButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final bool isPrimary;
  final bool isLoading;
  final double? width;
  final double height;

  const GalaxyButton({
    super.key,
    required this.label,
    required this.onTap,
    this.isPrimary = true,
    this.isLoading = false,
    this.width,
    this.height = 52,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: (isLoading || onTap == null) ? 0.6 : 1.0,
      child: Container(
        width: width ?? double.infinity,
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(height / 2),
          color: isPrimary && onTap != null
              ? const Color(0xFF1D9BF0)
              : Colors.transparent,
          border: isPrimary
              ? null
              : Border.all(
                  color: const Color(0xFF1D9BF0).withValues(alpha: 0.5),
                  width: 1.5,
                ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: (isLoading || onTap == null)
                ? null
                : () {
                    HapticFeedback.lightImpact();
                    onTap!();
                  },
            borderRadius: BorderRadius.circular(height / 2),
            child: Center(
              child: isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      label,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: isPrimary
                            ? Colors.white
                            : const Color(0xFF4FC3F7),
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
