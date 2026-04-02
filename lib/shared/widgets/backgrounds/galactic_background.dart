import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';

class GalacticBackground extends StatefulWidget {
  final Widget child;

  final bool performanceMode; // 🔥 ลดโหลด
  final bool enableSensor;    // 🔥 เปิด/ปิด motion

  const GalacticBackground({
    super.key,
    required this.child,
    this.performanceMode = false,
    this.enableSensor = true,
  });

  @override
  State<GalacticBackground> createState() => _GalacticBackgroundState();
}

class _GalacticBackgroundState extends State<GalacticBackground>
    with TickerProviderStateMixin, WidgetsBindingObserver {

  late AnimationController _starController;
  late AnimationController _themeController;
  late Animation<double> _themeAnimation;

  StreamSubscription? _accelSub;

  double _tiltX = 0;
  double _tiltY = 0;
  double _targetTiltX = 0;
  double _targetTiltY = 0;

  DateTime _lastAccel = DateTime.now();

  bool _lowPowerMode = false;

  late List<StarLayer> _layers;
  final List<ShootingStar> _shootingStars = [];

  Timer? _shootingTimer;

  static const _dark = [
    Color(0xFF020408),
    Color(0xFF050A1E),
    Color(0xFF0A1432),
  ];

  static const _light = [
    Color(0xFFFFFFFF),
    Color(0xFFF5F5F5),
    Color(0xFFEFEFEF),
  ];

  @override
  void initState() {
    super.initState();

    _setupLayers();

    _starController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 120),
    )..addListener(_tick)..repeat();

    _themeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _themeAnimation =
        CurvedAnimation(parent: _themeController, curve: Curves.easeInOut);

    if (widget.enableSensor) {
      try {
        _accelSub = accelerometerEventStream().listen(_onAccel);
      } catch (_) {}
    }

    WidgetsBinding.instance.addObserver(this);

    _shootingTimer = Timer.periodic(
      const Duration(seconds: 12),
      (_) => _spawnShooting(),
    );
  }

  void _setupLayers() {
    _layers = widget.performanceMode
        ? [
            StarLayer(60, 0.7, 0.1, 0.1),
            StarLayer(30, 1.0, 0.2, 0.2),
            StarLayer(15, 1.5, 0.4, 0.4),
          ]
        : [
            StarLayer(200, 0.7, 0.1, 0.15),
            StarLayer(100, 1.1, 0.25, 0.35),
            StarLayer(50, 1.6, 0.5, 0.6),
          ];
  }

  void _tick() {
    _tiltX += (_targetTiltX - _tiltX) * 0.05;
    _tiltY += (_targetTiltY - _tiltY) * 0.05;

    for (int i = _shootingStars.length - 1; i >= 0; i--) {
      _shootingStars[i].update();
      if (_shootingStars[i].progress >= 1) {
        _shootingStars.removeAt(i);
      }
    }
  }

  void _onAccel(AccelerometerEvent e) {
    final now = DateTime.now();

    if (now.difference(_lastAccel).inMilliseconds < 80) return;
    _lastAccel = now;

    _targetTiltX = (e.x * -1.5).clamp(-20, 20);
    _targetTiltY = (e.y * 1.5).clamp(-20, 20);
  }

  void _spawnShooting() {
    if (_lowPowerMode) return;

    final r = math.Random();
    final view = ui.PlatformDispatcher.instance.views.first;
    final size = view.physicalSize / view.devicePixelRatio;

    _shootingStars.add(
      ShootingStar(
        x: r.nextDouble() * size.width,
        y: 0,
        angle: math.pi * 0.75,
        speed: 0.015,
        length: 120,
      ),
    );
  }

  // 🔥 lifecycle control
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _starController.stop();
      _accelSub?.pause();
    } else if (state == AppLifecycleState.resumed) {
      if (!_lowPowerMode) _starController.repeat();
      _accelSub?.resume();
    }
  }

  // 🔥 keyboard detect → low power
  @override
  void didChangeMetrics() {
    final view = ui.PlatformDispatcher.instance.views.first;
    final keyboard = view.viewInsets.bottom > 0;

    if (keyboard != _lowPowerMode) {
      setState(() => _setLowPower(keyboard));
    }
  }

  void _setLowPower(bool enable) {
    _lowPowerMode = enable;

    if (enable) {
      _starController.stop();
      _accelSub?.pause();
      _shootingStars.clear();
    } else {
      _starController.repeat();
      if (widget.enableSensor) _accelSub?.resume();
    }
  }

  Color _lerp(Color a, Color b) =>
      Color.lerp(a, b, _themeAnimation.value)!;

  @override
  void dispose() {
    _starController.dispose();
    _themeController.dispose();
    _accelSub?.cancel();
    _shootingTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;

    dark ? _themeController.reverse() : _themeController.forward();

    return AnimatedBuilder(
      animation: _themeAnimation,
      builder: (_, child) {
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                _lerp(_dark[0], _light[0]),
                _lerp(_dark[1], _light[1]),
                _lerp(_dark[2], _light[2]),
              ],
            ),
          ),
          child: Stack(
            children: [
              if (!_lowPowerMode)
                CustomPaint(
                  size: Size.infinite,
                  painter: StarPainter(
                    _layers,
                    _starController,
                    _themeController,
                    _tiltX,
                    _tiltY,
                    _shootingStars,
                  ),
                ),
              child!,
            ],
          ),
        );
      },
      child: widget.child,
    );
  }
}

// ======================

class ShootingStar {
  double x, y;
  final double angle, speed, length;
  double progress = 0;

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
  final double size, speed, opacity;
  final List<Offset> stars;

  StarLayer(int count, this.size, this.speed, this.opacity)
      : stars = List.generate(
          count,
          (i) => Offset(
            math.Random(i).nextDouble() * 3000,
            math.Random(i + 1).nextDouble() * 3000,
          ),
        );
}

// ======================

class StarPainter extends CustomPainter {
  final List<StarLayer> layers;
  final Animation<double> starAnim;
  final Animation<double> themeAnim;
  final double tiltX, tiltY;
  final List<ShootingStar> shootingStars;

  StarPainter(
    this.layers,
    this.starAnim,
    this.themeAnim,
    this.tiltX,
    this.tiltY,
    this.shootingStars,
  ) : super(repaint: starAnim);

  @override
  void paint(Canvas canvas, Size size) {
    final fade = themeAnim.value;

    for (final layer in layers) {
      final paint = Paint();

      for (final star in layer.stars) {
        final x = (star.dx + tiltX) % size.width;
        final y = (star.dy + tiltY) % size.height;

        paint.color =
            Colors.white.withOpacity(layer.opacity * (1 - fade));

        canvas.drawCircle(Offset(x, y), layer.size, paint);
      }
    }

    for (final s in shootingStars) {
      final paint = Paint()
        ..color = Colors.white.withOpacity(1 - s.progress)
        ..strokeWidth = 2;

      canvas.drawLine(
        Offset(s.x, s.y),
        Offset(
          s.x - math.cos(s.angle) * s.length,
          s.y - math.sin(s.angle) * s.length,
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant StarPainter oldDelegate) => false;
}