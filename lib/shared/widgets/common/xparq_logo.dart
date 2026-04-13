import 'dart:math' as math;
import 'package:flutter/material.dart';

class XparqLogo extends StatefulWidget {
  final double size;
  final Color? color;

  const XparqLogo({super.key, this.size = 80, this.color});

  @override
  State<XparqLogo> createState() => _XparqLogoState();
}

class _XparqLogoState extends State<XparqLogo> with TickerProviderStateMixin {
  late AnimationController _floatController;
  late AnimationController _spinController;

  late Animation<double> _floatAnimation;
  late Animation<double> _glowAnimation;
  late Animation<double> _spinAnimation;

  @override
  void initState() {
    super.initState();

    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    _floatAnimation = Tween<double>(begin: -8.0, end: 8.0).animate(
      CurvedAnimation(parent: _floatController, curve: Curves.easeInOutSine),
    );

    _glowAnimation = Tween<double>(begin: 0.2, end: 0.8).animate(
      CurvedAnimation(parent: _floatController, curve: Curves.easeInOutSine),
    );

    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    _spinAnimation = Tween<double>(begin: 0, end: 6 * 2 * math.pi).animate(
      CurvedAnimation(parent: _spinController, curve: Curves.easeInOutExpo),
    );
  }

  @override
  void dispose() {
    _floatController.dispose();
    _spinController.dispose();
    super.dispose();
  }

  void _handleTap() async {
    if (!_spinController.isAnimating) {
      await Future.delayed(const Duration(milliseconds: 200));
      if (mounted) {
        _spinController.forward(from: 0.0);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final logoColor = widget.color ?? const Color(0xFF1D9BF0);
    // Use a tighter wrapper to prevent excessive vertical spacing
    final wrapperSize = widget.size * 1.4;

    return GestureDetector(
      onTap: _handleTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: wrapperSize,
        height: wrapperSize,
        child: AnimatedBuilder(
          animation: Listenable.merge([_floatController, _spinController]),
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(0, _floatAnimation.value),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // 1. Multi-layered Aura Glow
                  Builder(
                    builder: (ctx) {
                      final isDark =
                          Theme.of(ctx).brightness == Brightness.dark;
                      final glowOpacity = _glowAnimation.value;

                      return Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: widget.size * 1.8,
                            height: widget.size * 1.8,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  logoColor.withValues(alpha: 
                                    isDark
                                        ? 0.3 * glowOpacity
                                        : 0.1 * glowOpacity,
                                  ),
                                  logoColor.withValues(alpha: 
                                    isDark
                                        ? 0.1 * glowOpacity
                                        : 0.02 * glowOpacity,
                                  ),
                                  Colors.transparent,
                                ],
                                stops: const [0.0, 0.5, 1.0],
                              ),
                            ),
                          ),
                          if (isDark)
                            Container(
                              width: widget.size * 2.2,
                              height: widget.size * 2.2,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: logoColor.withValues(alpha: 
                                      0.05 * glowOpacity,
                                    ),
                                    blurRadius: widget.size * 0.8,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                  // 2. The Bolt Icon
                  Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()
                      ..setEntry(3, 2, 0.001)
                      ..rotateY(_spinAnimation.value),
                    child: Icon(
                      Icons.bolt_rounded,
                      color: logoColor,
                      size: widget.size,
                      shadows: [
                        Shadow(
                          color: logoColor.withValues(alpha: 0.6),
                          blurRadius: 4,
                        ),
                        Shadow(
                          color: logoColor.withValues(alpha: 0.3),
                          blurRadius: 12,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
