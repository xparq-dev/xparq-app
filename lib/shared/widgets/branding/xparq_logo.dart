import 'dart:math' as math;
import 'package:flutter/material.dart';

class XparqLogo extends StatefulWidget {
  final double size;
  final Color? color;
  final bool animated;
  final VoidCallback? onTap;

  const XparqLogo({
    super.key,
    this.size = 80,
    this.color,
    this.animated = true,
    this.onTap,
  });

  @override
  State<XparqLogo> createState() => _XparqLogoState();
}

class _XparqLogoState extends State<XparqLogo>
    with TickerProviderStateMixin {
  static const double _floatRange = 8.0;
  static const double _glowMin = 0.2;
  static const double _glowMax = 0.8;
  static const double _glowScale = 1.8;
  static const double _outerGlowScale = 2.2;

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
    );

    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    _floatAnimation = Tween<double>(
      begin: -_floatRange,
      end: _floatRange,
    ).animate(
      CurvedAnimation(
        parent: _floatController,
        curve: Curves.easeInOutSine,
      ),
    );

    _glowAnimation = Tween<double>(
      begin: _glowMin,
      end: _glowMax,
    ).animate(
      CurvedAnimation(
        parent: _floatController,
        curve: Curves.easeInOutSine,
      ),
    );

    _spinAnimation = Tween<double>(
      begin: 0,
      end: 6 * 2 * math.pi,
    ).animate(
      CurvedAnimation(
        parent: _spinController,
        curve: Curves.easeInOutExpo,
      ),
    );

    if (widget.animated) {
      _floatController.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _floatController.dispose();
    _spinController.dispose();
    super.dispose();
  }

  void _handleTap() async {
    widget.onTap?.call();

    if (!widget.animated) return;

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
    final wrapperSize = widget.size * 1.4;

    Widget content = SizedBox(
      width: wrapperSize,
      height: wrapperSize,
      child: AnimatedBuilder(
        animation: Listenable.merge([
          _floatController,
          _spinController,
        ]),
        builder: (context, child) {
          final offsetY = widget.animated ? _floatAnimation.value : 0.0;

          return Transform.translate(
            offset: Offset(0, offsetY),
            child: Stack(
              alignment: Alignment.center,
              children: [
                _buildGlow(context, logoColor),
                _buildIcon(logoColor),
              ],
            ),
          );
        },
      ),
    );

    return GestureDetector(
      onTap: _handleTap,
      behavior: HitTestBehavior.opaque,
      child: content,
    );
  }

  Widget _buildGlow(BuildContext context, Color logoColor) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final glowOpacity =
        widget.animated ? _glowAnimation.value : 0.4;

    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: widget.size * _glowScale,
          height: widget.size * _glowScale,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                logoColor.withOpacity(
                  isDark ? 0.3 * glowOpacity : 0.1 * glowOpacity,
                ),
                logoColor.withOpacity(
                  isDark ? 0.1 * glowOpacity : 0.02 * glowOpacity,
                ),
                Colors.transparent,
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
        ),
        if (isDark)
          Container(
            width: widget.size * _outerGlowScale,
            height: widget.size * _outerGlowScale,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: logoColor.withOpacity(0.05 * glowOpacity),
                  blurRadius: widget.size * 0.8,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildIcon(Color logoColor) {
    return Transform(
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
            color: logoColor.withOpacity(0.6),
            blurRadius: 4,
          ),
          Shadow(
            color: logoColor.withOpacity(0.3),
            blurRadius: 12,
          ),
        ],
      ),
    );
  }
}