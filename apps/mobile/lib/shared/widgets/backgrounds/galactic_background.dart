import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';

/// Starfield background with smooth dark↔light transition animation.
///
/// When the theme brightness changes, the background gradient and star colors
/// cross-fade smoothly over [_themeFadeDuration] instead of snapping.
class GalacticBackground extends StatefulWidget {
  final Widget child;
  const GalacticBackground({super.key, required this.child});

  @override
  State<GalacticBackground> createState() => _GalacticBackgroundState();
}

class _GalacticBackgroundState extends State<GalacticBackground>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  // ── Star animation (orbit / tilt) ─────────────────────────────────────────
  late AnimationController _starController;

  double _tiltX = 0;
  double _tiltY = 0;
  double _targetTiltX = 0;
  double _targetTiltY = 0;

  StreamSubscription? _accelSub;
  DateTime _lastAccelUpdate = DateTime(0);
  static const _accelThrottleMs = 80;

  // ── Theme fade animation ───────────────────────────────────────────────────
  late AnimationController _themeController;
  late Animation<double> _themeAnimation; // curved version for smooth feel

  /// Null before first build so we know when to snap vs animate
  bool? _wasDark;
  bool _lowPowerMode = false;

  // ── Star data ──────────────────────────────────────────────────────────────
  late final List<StarLayer> _layers;

  // ── Shooting Stars ────────────────────────────────────────────────────────
  final List<ShootingStar> _shootingStars = [];
  Timer? _shootingStarTimer;

  // ── Gradient color sets ───────────────────────────────────────────────────
  static const _darkColors = [
    Color(0xFF020408),
    Color(0xFF050A1E),
    Color(0xFF0A1432),
  ];
  static const _lightColors = [
    Color(0xFFFFFFFF),
    Color(0xFFFAFAFA),
    Color(0xFFF5F5F5),
  ];

  @override
  void initState() {
    super.initState();

    _layers = [
      StarLayer(count: 200, size: 0.7, speed: 0.10, opacity: 0.15),
      StarLayer(count: 100, size: 1.1, speed: 0.28, opacity: 0.35),
      StarLayer(count: 50, size: 1.6, speed: 0.55, opacity: 0.60),
    ];

    _starController =
        AnimationController(vsync: this, duration: const Duration(seconds: 120))
          ..addListener(_onStarTick)
          ..repeat();

    _themeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000), // Dark → Light
      reverseDuration: const Duration(milliseconds: 1000), // Light → Dark
    );
    _themeAnimation = CurvedAnimation(
      parent: _themeController,
      curve: Curves.easeInOut, // Smooth transition on both ends
      reverseCurve: Curves.easeInOut,
    );

    // Stop star engine in Light Mode to save battery, resume in Dark Mode.
    _themeController.addListener(() {
      if (_themeController.value >= 1.0) {
        if (_starController.isAnimating) {
          _starController.stop();
        }
      } else {
        if (!_starController.isAnimating && !_lowPowerMode) {
          _starController.repeat();
        }
      }
    });

    try {
      _accelSub = accelerometerEventStream().listen(_onAccel, onError: (e) {
        debugPrint('GALACTIC_BG: Accelerometer error: $e');
      });
    } catch (e) {
      debugPrint('GALACTIC_BG: Could not initialize accelerometer: $e');
    }
    WidgetsBinding.instance.addObserver(this);

    // Trigger shooting stars every 12 seconds (user requested)
    _shootingStarTimer = Timer.periodic(const Duration(seconds: 12), (_) {
      if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
        _triggerShootingStar();
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (!_starController.isAnimating && !_lowPowerMode && (_themeController.value < 1.0)) {
        _starController.repeat();
      }
      _accelSub?.resume();
      
      setState(() {
        _shootingStars.clear();
      });
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      if (_starController.isAnimating) {
        _starController.stop();
      }
      _accelSub?.pause();
    }
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    try {
      final view = ui.PlatformDispatcher.instance.views.first;
      final viewInsets = view.viewInsets;
      // If bottom inset > 0, keyboard is likely open
      final keyboardVisible = viewInsets.bottom > 0;

      if (keyboardVisible != _lowPowerMode) {
        // We use setState solely to update the boolean UI toggle.
        // It runs ONLY ONCE when keyboard opens, and ONCE when it closes.
        setState(() {
          _setLowPowerMode(keyboardVisible);
        });
      }
    } catch (_) {}
  }

  void _setLowPowerMode(bool enabled) {
    _lowPowerMode = enabled;
    if (enabled) {
      if (_starController.isAnimating) {
        _starController.stop(canceled: false);
      }
      _accelSub?.pause();
      _shootingStars.clear();
    } else {
      if (!_starController.isAnimating) {
        _starController.repeat();
      }
      _accelSub?.resume();
    }
  }

  void _triggerShootingStar() {
    // Only spawn stars if we are NOT in Light Mode (fade < 0.5)
    if (_themeController.value > 0.5) return;

    final random = math.Random();
    // 50% chance for double star
    final isDouble = random.nextBool();

    _addShootingStar();

    if (isDouble) {
      // Stagger second star slightly
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted) _addShootingStar();
      });
    }
  }

  void _addShootingStar() {
    final random = math.Random();
    if (!mounted) return;

    // Use PlatformDispatcher to get size without MediaQuery since we might be at the root.
    final view = ui.PlatformDispatcher.instance.views.first;
    final size = view.physicalSize / view.devicePixelRatio;

    // Use a consistent base angle for "Meteor Shower" style (diagonal down-left)
    // 135 degrees = 2.356 radians
    const baseAngle = 135 * (math.pi / 180);
    // Slight variance for natural feel (+/- 2 degrees)
    final angleVariance = (random.nextDouble() - 0.5) * (4 * math.pi / 180);
    final angle = baseAngle + angleVariance;

    // Origins: Top or Right edge to ensure they cross the main viewing area
    final fromTop = random.nextBool();
    double startX, startY;

    if (fromTop) {
      startX =
          random.nextDouble() *
          size.width *
          1.2; // Allow starting slightly off-right
      startY = -20;
    } else {
      startX = size.width + 20;
      startY = random.nextDouble() * size.height * 0.6;
    }

    _shootingStars.add(
      ShootingStar(
        x: startX,
        y: startY,
        angle: angle,
        // Speed for ~1.0-1.2 second duration at 60fps
        speed: 0.014 + random.nextDouble() * 0.004,
        length:
            100 +
            random.nextDouble() * 50, // Slightly longer, more elegant trails
      ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_wasDark == null) {
      _wasDark = isDark;
      _themeController.value = isDark ? 0.0 : 1.0;
    } else if (isDark != _wasDark) {
      _wasDark = isDark;
      if (isDark) {
        // Light → Dark: reverse (1.0 → 0.0)
        _themeController.reverse();
      } else {
        // Dark → Light: forward (0.0 → 1.0)
        _themeController.forward();
      }
    }
  }

  void _onStarTick() {
    _tiltX = _tiltX + (_targetTiltX - _tiltX) * 0.05;
    _tiltY = _tiltY + (_targetTiltY - _tiltY) * 0.05;

    // Update shooting stars without setState!
    // The StarPainter listens to _starController, so it repaints every tick automatically.
    if (_shootingStars.isNotEmpty) {
      for (int i = _shootingStars.length - 1; i >= 0; i--) {
        _shootingStars[i].update();
        if (_shootingStars[i].progress >= 1.0) {
          _shootingStars.removeAt(i);
        }
      }
    }
  }

  void _onAccel(AccelerometerEvent event) {
    final now = DateTime.now();
    if (now.difference(_lastAccelUpdate).inMilliseconds < _accelThrottleMs) {
      return;
    }
    _lastAccelUpdate = now;
    _targetTiltX = (event.x * -1.5).clamp(-20.0, 20.0);
    _targetTiltY = (event.y * 1.5).clamp(-20.0, 20.0);
  }

  /// Interpolate between two color lists using the curved animation value.
  Color _lerpColor(Color dark, Color light) =>
      Color.lerp(dark, light, _themeAnimation.value)!;

  @override
  void dispose() {
    _starController.removeListener(_onStarTick);
    _starController.dispose();
    _themeController.dispose();
    _accelSub?.cancel();
    _shootingStarTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _themeAnimation, // uses curved animation
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                _lerpColor(_darkColors[0], _lightColors[0]),
                _lerpColor(_darkColors[1], _lightColors[1]),
                _lerpColor(_darkColors[2], _lightColors[2]),
              ],
            ),
          ),
          child: Stack(
            children: [
              // Star layers — repainted by star controller
              // Disable painting completely during low power mode (keyboard up)
              // to free up GPU for smooth keyboard sliding.
              if (!_lowPowerMode)
                for (int i = 0; i < _layers.length; i++)
                  CustomPaint(
                    size: Size.infinite,
                    painter: StarPainter(
                      layer: _layers[i],
                      starAnim: _starController,
                      themeAnim: _themeController,
                      layerIndex: i,
                      tiltXRef: () => _tiltX,
                      tiltYRef: () => _tiltY,
                      shootingStars: _shootingStars,
                    ),
                  ),
              // UI child is isolated — not affected by AnimatedBuilder rebuilds
              child!,
            ],
          ),
        );
      },
      child: widget.child,
    );
  }
}

// ── Data ───────────────────────────────────────────────────────────────────────

class ShootingStar {
  double x;
  double y;
  final double angle;
  final double speed;
  double progress = 0.0; // 0.0 to 1.0
  final double length;

  ShootingStar({
    required this.x,
    required this.y,
    required this.angle,
    required this.speed,
    required this.length,
  });

  void update() {
    progress += speed;
    x += math.cos(angle) * speed * 500;
    y += math.sin(angle) * speed * 500;
  }
}

class StarLayer {
  final double size;
  final double speed;
  final double opacity;
  final List<Offset> stars;

  StarLayer({
    required int count,
    required this.size,
    required this.speed,
    required this.opacity,
  }) : stars = List.generate(count, (i) {
         // Use the index as a seed for stable random positions, even if widget is recreated.
         final rand = math.Random(i + (size * 1000).toInt());
         return Offset(rand.nextDouble() * 3000.0, rand.nextDouble() * 3000.0);
       }, growable: false);
}

// ── Painter ────────────────────────────────────────────────────────────────────

class StarPainter extends CustomPainter {
  final StarLayer layer;
  final int layerIndex;
  final Animation<double> starAnim;
  final Animation<double> themeAnim;
  final double Function() tiltXRef;
  final double Function() tiltYRef;
  final List<ShootingStar> shootingStars;

  StarPainter({
    required this.layer,
    required this.layerIndex,
    required this.starAnim,
    required this.themeAnim,
    required this.tiltXRef,
    required this.tiltYRef,
    required this.shootingStars,
  }) : super(repaint: starAnim); // star anim drives repaints

  @override
  void paint(Canvas canvas, Size size) {
    final t = starAnim.value * 2 * math.pi;
    final fade = themeAnim.value; // 0=dark, 1=light

    // 1. Draw Regular Stars (Only for the actual layers)
    // We only draw regular stars once per layer, but we can draw shooting stars once.
    // Let's draw regular stars first.
    // Linear move: Earth rotation style (moves left to right)
    // Each layer has a different speed for parallax depth
    final linearX = starAnim.value * 3000.0 * (layer.speed * 0.5 + 0.5);
    final linearY =
        starAnim.value * 500.0 * (layer.speed * 0.2); // Subtle vertical drift

    final dx = (tiltXRef() * layer.speed * 50) + linearX;
    final dy = (tiltYRef() * layer.speed * 50) + linearY;

    // Use a more premium white with slight variation
    final darkStarColor = Colors.white.withValues(alpha: layer.opacity);
    final lightStarColor = Colors.white.withValues(alpha: 
      0,
    ); // Corrected to white-based transparency
    final baseColor = Color.lerp(darkStarColor, lightStarColor, fade)!;

    for (final star in layer.stars) {
      // Use fixed wrap space of 3000x3000px
      final x = (star.dx + dx) % 3000.0;
      final y = (star.dy + dy) % 3000.0;

      // Only draw if within current viewport
      if (x < size.width && y < size.height) {
        // Individual star shimmer based on its position and time
        final shimmer = 0.7 + 0.3 * math.sin(t * 3 + star.dx);
        final color = baseColor.withValues(alpha: 
          (layer.opacity * shimmer * (1.0 - fade)).clamp(0.0, 1.0),
        );

        canvas.drawCircle(
          Offset(x, y),
          (layer.size / 2) * (0.8 + 0.2 * shimmer),
          Paint()..color = color,
        );
      }
    }

    // 2. Draw Shooting Stars (Only on top-most layer to avoid redundancy)
    if (layerIndex == 2) {
      for (final ss in shootingStars) {
        if (ss.progress >= 1.0) continue;

        // Fade out as it progresses/themes
        final ssOpacity = (1.0 - ss.progress).clamp(0.0, 1.0) * (1.0 - fade);
        if (ssOpacity <= 0) continue;

        final start = Offset(ss.x, ss.y);
        final end = Offset(
          ss.x - math.cos(ss.angle) * ss.length,
          ss.y - math.sin(ss.angle) * ss.length,
        );

        final paint = Paint()
          ..shader = ui.Gradient.linear(start, end, [
            Colors.white.withValues(alpha: ssOpacity),
            Colors.white.withValues(alpha: 0),
          ])
          ..strokeWidth = 2.5
          ..strokeCap = StrokeCap.round;

        canvas.drawLine(start, end, paint);

        // Core glow
        canvas.drawCircle(
          start,
          2.0,
          Paint()
            ..color = Colors.white.withValues(alpha: ssOpacity)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant StarPainter old) => true;
}
