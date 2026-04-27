import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:xparq_app/shared/widgets/common/xparq_image.dart';

class GalacticCallPalette {
  final Color backgroundBase;
  final Color backgroundTop;
  final Color backgroundBottom;
  final Color orbPrimary;
  final Color orbSecondary;
  final Color orbTertiary;
  final Color accent;
  final Color accentSoft;
  final Color accentStrong;
  final Color textPrimary;
  final Color textSecondary;
  final Color line;
  final Color glassFill;
  final Color glassStroke;
  final Color utilityFill;
  final Color utilityActiveFill;
  final Color utilityIcon;
  final Color dangerStart;
  final Color dangerEnd;
  final Color acceptStart;
  final Color acceptEnd;
  final Color closeFill;

  const GalacticCallPalette({
    required this.backgroundBase,
    required this.backgroundTop,
    required this.backgroundBottom,
    required this.orbPrimary,
    required this.orbSecondary,
    required this.orbTertiary,
    required this.accent,
    required this.accentSoft,
    required this.accentStrong,
    required this.textPrimary,
    required this.textSecondary,
    required this.line,
    required this.glassFill,
    required this.glassStroke,
    required this.utilityFill,
    required this.utilityActiveFill,
    required this.utilityIcon,
    required this.dangerStart,
    required this.dangerEnd,
    required this.acceptStart,
    required this.acceptEnd,
    required this.closeFill,
  });

  factory GalacticCallPalette.of(ThemeData theme) {
    final isLight = theme.brightness == Brightness.light;
    if (isLight) {
      return const GalacticCallPalette(
        backgroundBase: Color(0xFFF5F8FF),
        backgroundTop: Color(0xFFFDFEFF),
        backgroundBottom: Color(0xFFE7EEF9),
        orbPrimary: Color(0x554AB7FF),
        orbSecondary: Color(0x33C5E4FF),
        orbTertiary: Color(0x26A98CFF),
        accent: Color(0xFF2F7BFF),
        accentSoft: Color(0xFF77B4FF),
        accentStrong: Color(0xFF0F4DE0),
        textPrimary: Color(0xFF10182C),
        textSecondary: Color(0xFF61708E),
        line: Color(0x3365789F),
        glassFill: Color(0x99FFFFFF),
        glassStroke: Color(0x66FFFFFF),
        utilityFill: Color(0xCCFFFFFF),
        utilityActiveFill: Color(0x1F2F7BFF),
        utilityIcon: Color(0xFF142242),
        dangerStart: Color(0xFFFF6A7E),
        dangerEnd: Color(0xFFE03652),
        acceptStart: Color(0xFF4DDEB1),
        acceptEnd: Color(0xFF1FAE88),
        closeFill: Color(0x14FFFFFF),
      );
    }

    return const GalacticCallPalette(
      backgroundBase: Color(0xFF040814),
      backgroundTop: Color(0xFF091225),
      backgroundBottom: Color(0xFF02050C),
      orbPrimary: Color(0x3326B7FF),
      orbSecondary: Color(0x1FA177FF),
      orbTertiary: Color(0x22A361FF),
      accent: Color(0xFF69C7FF),
      accentSoft: Color(0xFF91E0FF),
      accentStrong: Color(0xFF1E8DFF),
      textPrimary: Color(0xFFF5F8FF),
      textSecondary: Color(0xFF96A3C4),
      line: Color(0x33CFE8FF),
      glassFill: Color(0x1AFFFFFF),
      glassStroke: Color(0x1FFFFFFF),
      utilityFill: Color(0x14FFFFFF),
      utilityActiveFill: Color(0x2069C7FF),
      utilityIcon: Color(0xFFF5F8FF),
      dangerStart: Color(0xFFFF667A),
      dangerEnd: Color(0xFFBE2346),
      acceptStart: Color(0xFF47D9A9),
      acceptEnd: Color(0xFF1F9D78),
      closeFill: Color(0x12FFFFFF),
    );
  }
}

class GalacticCallBackground extends StatelessWidget {
  final GalacticCallPalette palette;

  const GalacticCallBackground({
    super.key,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: palette.backgroundBase,
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              palette.backgroundTop,
              palette.backgroundBase,
              palette.backgroundBottom,
            ],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -120,
              left: -40,
              child: _GlowOrb(
                size: 280,
                color: palette.orbPrimary,
              ),
            ),
            Positioned(
              top: 110,
              right: -40,
              child: _GlowOrb(
                size: 220,
                color: palette.orbSecondary,
              ),
            ),
            Positioned(
              bottom: -80,
              left: 30,
              child: _GlowOrb(
                size: 240,
                color: palette.orbTertiary,
              ),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0, -0.2),
                    radius: 1.1,
                    colors: [
                      Colors.white.withValues(alpha: 0.02),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class GalacticCallHeader extends StatelessWidget {
  final GalacticCallPalette palette;
  final bool canDismiss;
  final VoidCallback onDismiss;

  const GalacticCallHeader({
    super.key,
    required this.palette,
    required this.canDismiss,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _GlassCapsule(
          palette: palette,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: palette.accent,
                  boxShadow: [
                    BoxShadow(
                      color: palette.accent.withValues(alpha: 0.35),
                      blurRadius: 12,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'XPARQ Signal',
                style: TextStyle(
                  color: palette.textSecondary,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
        const Spacer(),
        AnimatedOpacity(
          opacity: canDismiss ? 1 : 0.42,
          duration: const Duration(milliseconds: 220),
          child: IgnorePointer(
            ignoring: !canDismiss,
            child: _GlassIconButton(
              palette: palette,
              icon: Icons.close,
              onTap: onDismiss,
            ),
          ),
        ),
      ],
    );
  }
}

class GalacticCallAvatar extends StatefulWidget {
  final GalacticCallPalette palette;
  final String avatarUrl;
  final String displayName;

  const GalacticCallAvatar({
    super.key,
    required this.palette,
    required this.avatarUrl,
    required this.displayName,
  });

  @override
  State<GalacticCallAvatar> createState() => _GalacticCallAvatarState();
}

class _GalacticCallAvatarState extends State<GalacticCallAvatar>
    with TickerProviderStateMixin {
  late final AnimationController _ringController;
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _ringController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _ringController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = widget.palette;

    return SizedBox(
      width: 228,
      height: 228,
      child: AnimatedBuilder(
        animation: Listenable.merge([_ringController, _pulseController]),
        builder: (context, _) {
          return Stack(
            alignment: Alignment.center,
            children: [
              _RippleRing(
                progress: _pulseController.value,
                color: palette.accent.withValues(alpha: 0.15),
                baseSize: 158,
              ),
              _RippleRing(
                progress: (_pulseController.value + 0.42) % 1,
                color: palette.accentSoft.withValues(alpha: 0.12),
                baseSize: 172,
              ),
              Transform.rotate(
                angle: _ringController.value * math.pi * 2,
                child: Container(
                  width: 172,
                  height: 172,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: SweepGradient(
                      colors: [
                        palette.accent.withValues(alpha: 0.16),
                        palette.accentSoft,
                        palette.acceptStart.withValues(alpha: 0.75),
                        palette.accentStrong,
                        palette.accent.withValues(alpha: 0.16),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: palette.accent.withValues(alpha: 0.16),
                        blurRadius: 36,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: palette.backgroundBase.withValues(alpha: 0.72),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              palette.glassFill.withValues(alpha: 0.7),
                              palette.backgroundBottom.withValues(alpha: 0.8),
                            ],
                          ),
                        ),
                        child: ClipOval(
                          child: widget.avatarUrl.trim().isEmpty
                              ? _AvatarFallback(
                                  palette: palette,
                                  displayName: widget.displayName,
                                )
                              : DecoratedBox(
                                  decoration: BoxDecoration(
                                    image: DecorationImage(
                                      fit: BoxFit.cover,
                                      image: XparqImage.getImageProvider(
                                        widget.avatarUrl,
                                      ),
                                    ),
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class GalacticDividerLabel extends StatelessWidget {
  final GalacticCallPalette palette;
  final Widget child;

  const GalacticDividerLabel({
    super.key,
    required this.palette,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _FadeLine(palette: palette)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: child,
        ),
        Expanded(
          child: _FadeLine(
            palette: palette,
            reverse: true,
          ),
        ),
      ],
    );
  }
}

class GalacticGlassBadge extends StatelessWidget {
  final GalacticCallPalette palette;
  final String text;
  final IconData? icon;

  const GalacticGlassBadge({
    super.key,
    required this.palette,
    required this.text,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return _GlassCapsule(
      palette: palette,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: palette.accent),
            const SizedBox(width: 8),
          ],
          Text(
            text,
            style: TextStyle(
              color: palette.textPrimary,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

class GalacticCameraPreview extends StatelessWidget {
  final GalacticCallPalette palette;
  final RTCVideoRenderer renderer;

  const GalacticCameraPreview({
    super.key,
    required this.palette,
    required this.renderer,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          width: 124,
          height: 164,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: palette.glassFill.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: palette.glassStroke),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 20,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              fit: StackFit.expand,
              children: [
                RTCVideoView(
                  renderer,
                  objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                  mirror: true,
                ),
                Align(
                  alignment: Alignment.topLeft,
                  child: Container(
                    margin: const EdgeInsets.all(8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.26),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'Live Camera',
                      style: TextStyle(
                        color: palette.textPrimary,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class GalacticUtilityButton extends StatelessWidget {
  final GalacticCallPalette palette;
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const GalacticUtilityButton({
    super.key,
    required this.palette,
    required this.icon,
    required this.label,
    required this.onTap,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    final fill = isSelected ? palette.utilityActiveFill : palette.utilityFill;
    final iconColor = isSelected ? palette.accent : palette.utilityIcon;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: fill,
              border: Border.all(
                color: palette.glassStroke
                    .withValues(alpha: isSelected ? 0.9 : 0.55),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 18,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Icon(icon, size: 22, color: iconColor),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            color: palette.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class GalacticEndCallButton extends StatelessWidget {
  final GalacticCallPalette palette;
  final VoidCallback onTap;

  const GalacticEndCallButton({
    super.key,
    required this.palette,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(40),
      child: Ink(
        width: 78,
        height: 78,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [palette.dangerStart, palette.dangerEnd],
          ),
          boxShadow: [
            BoxShadow(
              color: palette.dangerEnd.withValues(alpha: 0.34),
              blurRadius: 26,
              offset: const Offset(0, 16),
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned(
              top: 10,
              left: 14,
              right: 14,
              child: Container(
                height: 18,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white.withValues(alpha: 0.42),
                      Colors.white.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
            const Icon(
              Icons.call_end_rounded,
              color: Colors.white,
              size: 28,
            ),
          ],
        ),
      ),
    );
  }
}

class GalacticDecisionButton extends StatelessWidget {
  final GalacticCallPalette palette;
  final IconData icon;
  final String label;
  final List<Color> colors;
  final VoidCallback onTap;

  const GalacticDecisionButton({
    super.key,
    required this.palette,
    required this.icon,
    required this.label,
    required this.colors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(34),
          child: Ink(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: colors,
              ),
              boxShadow: [
                BoxShadow(
                  color: colors.last.withValues(alpha: 0.26),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 28),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          label,
          style: TextStyle(
            color: palette.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class GalacticSecondaryButton extends StatelessWidget {
  final GalacticCallPalette palette;
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const GalacticSecondaryButton({
    super.key,
    required this.palette,
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: _GlassCapsule(
        palette: palette,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: palette.textPrimary),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: palette.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GlassCapsule extends StatelessWidget {
  final GalacticCallPalette palette;
  final EdgeInsetsGeometry padding;
  final Widget child;

  const _GlassCapsule({
    required this.palette,
    required this.padding,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: palette.glassFill,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: palette.glassStroke),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _GlassIconButton extends StatelessWidget {
  final GalacticCallPalette palette;
  final IconData icon;
  final VoidCallback onTap;

  const _GlassIconButton({
    required this.palette,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: palette.closeFill,
          border: Border.all(color: palette.glassStroke),
        ),
        child: Icon(icon, size: 18, color: palette.textPrimary),
      ),
    );
  }
}

class _FadeLine extends StatelessWidget {
  final GalacticCallPalette palette;
  final bool reverse;

  const _FadeLine({
    required this.palette,
    this.reverse = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: reverse ? Alignment.centerRight : Alignment.centerLeft,
          end: reverse ? Alignment.centerLeft : Alignment.centerRight,
          colors: [
            Colors.transparent,
            palette.line,
          ],
        ),
      ),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  final double size;
  final Color color;

  const _GlowOrb({
    required this.size,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color,
            Colors.transparent,
          ],
        ),
      ),
    );
  }
}

class _RippleRing extends StatelessWidget {
  final double progress;
  final Color color;
  final double baseSize;

  const _RippleRing({
    required this.progress,
    required this.color,
    required this.baseSize,
  });

  @override
  Widget build(BuildContext context) {
    final scale = 0.86 + (progress * 0.62);
    final opacity = (1 - progress).clamp(0.0, 1.0) * 0.7;

    return Transform.scale(
      scale: scale,
      child: Container(
        width: baseSize,
        height: baseSize,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: color.withValues(alpha: opacity),
            width: 1.1,
          ),
        ),
      ),
    );
  }
}

class _AvatarFallback extends StatelessWidget {
  final GalacticCallPalette palette;
  final String displayName;

  const _AvatarFallback({
    required this.palette,
    required this.displayName,
  });

  @override
  Widget build(BuildContext context) {
    final initial = displayName.trim().isEmpty
        ? 'X'
        : displayName.trim().characters.first.toUpperCase();

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            palette.accent.withValues(alpha: 0.22),
            palette.acceptStart.withValues(alpha: 0.18),
            palette.backgroundBottom.withValues(alpha: 0.88),
          ],
        ),
      ),
      child: Center(
        child: Text(
          initial,
          style: TextStyle(
            color: palette.textPrimary,
            fontSize: 50,
            fontWeight: FontWeight.w800,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }
}
