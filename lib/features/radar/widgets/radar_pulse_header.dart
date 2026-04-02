// lib/features/radar/widgets/radar_pulse_header.dart

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:xparq_app/l10n/app_localizations.dart';
import 'package:xparq_app/features/radar/models/radar_xparq_model.dart';
import 'package:xparq_app/features/radar/providers/radar_providers.dart';

class RadarPulseHeader extends StatelessWidget {
  final AnimationController controller;
  final RadarMode mode;
  final int count;
  final double radiusKm;
  final bool isLoading;
  final List<RadarXparq> xparqs;

  const RadarPulseHeader({
    super.key,
    required this.controller,
    required this.mode,
    required this.count,
    required this.radiusKm,
    required this.isLoading,
    this.xparqs = const [],
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 160,
      alignment: Alignment.center,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Pulse rings
          AnimatedBuilder(
            animation: controller,
            builder: (_, child) => RepaintBoundary(
              child: CustomPaint(
                size: const Size(200, 200),
                painter: PulsePainter(
                  progress: controller.value,
                  mode: mode,
                  xparqs: xparqs,
                  maxRadiusKm: radiusKm,
                ),
              ),
            ),
          ),
          // Center info
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                mode == RadarMode.online ? '🛸' : '📡',
                style: const TextStyle(fontSize: 28),
              ),
              Text(
                '$count ${AppLocalizations.of(context)!.radarXparqsCount}',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              Text(
                mode == RadarMode.online
                    ? '${radiusKm < 1000 ? "${radiusKm.toStringAsFixed(0)}km" : AppLocalizations.of(context)!.radarRadiusGlobal} ${AppLocalizations.of(context)!.radarRadiusLabel}'
                    : AppLocalizations.of(context)!.radarBluetoothRange,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.54),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class PulsePainter extends CustomPainter {
  final double progress;
  final RadarMode mode;
  final List<RadarXparq> xparqs;
  final double maxRadiusKm;

  PulsePainter({
    required this.progress,
    required this.mode,
    this.xparqs = const [],
    required this.maxRadiusKm,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final color = mode == RadarMode.online
        ? const Color(0xFF1D9BF0)
        : const Color(0xFFF91880);
    final center = Offset(size.width / 2, size.height / 2);
    final baseRadius = size.width / 2;

    // 1. Draw Pulsing Rings
    for (int i = 0; i < 3; i++) {
      final r = baseRadius * ((i + progress) / 3);
      final opacity = (1 - (i + progress) / 3).clamp(0.0, 1.0);
      canvas.drawCircle(
        center,
        r,
        Paint()
          ..color = color.withOpacity(opacity * 0.4)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }

    // 2. Draw Xparq Particles (Icon Layer)
    if (mode == RadarMode.online && xparqs.isNotEmpty) {
      for (final xparq in xparqs) {
        // Deterministic angle based on UID
        final angle = xparq.planet.id.hashCode.toDouble();
        // Normalized distance (0.0 to 1.0)
        final distanceRatio = (xparq.distanceMeters / 1000 / maxRadiusKm).clamp(
          0.0,
          1.0,
        );
        final r = baseRadius * 0.3 + (distanceRatio * baseRadius * 0.6);

        final offset = Offset(
          center.dx + r * math.cos(angle),
          center.dy + r * math.sin(angle),
        );

        // Particle shadow/glow
        canvas.drawCircle(
          offset,
          4,
          Paint()
            ..color = color.withOpacity(0.3)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
        );

        // Particle core
        canvas.drawCircle(offset, 2.5, Paint()..color = color);
      }
    }
  }

  @override
  bool shouldRepaint(PulsePainter old) =>
      old.progress != progress || old.xparqs != xparqs;
}
