import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:xparq_app/shared/widgets/common/xparq_image.dart';
import 'package:xparq_app/l10n/app_localizations.dart';
import 'package:xparq_app/features/social/models/pulse_model.dart';

class PulseMedia extends StatelessWidget {
  final PulseModel pulse;
  final bool isCensored;

  const PulseMedia({super.key, required this.pulse, this.isCensored = false});

  @override
  Widget build(BuildContext context) {
    if (pulse.imageUrl == null && pulse.videoUrl == null) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            _buildMedia(context),
            if (isCensored) _buildCensorOverlay(context),
          ],
        ),
      ),
    );
  }

  Widget _buildMedia(BuildContext context) {
    if (pulse.imageUrl != null) {
      return ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 400),
        child: XparqImage(
          imageUrl: pulse.imageUrl!,
          fit: BoxFit.cover,
          width: double.infinity,
        ),
      );
    }
    // Video placeholder (actual video handled by PulseCard)
    return Container(
      width: double.infinity,
      height: 200,
      color: Colors.black,
      child: const Center(
        child: Icon(Icons.play_circle_outline, color: Colors.white, size: 48),
      ),
    );
  }

  Widget _buildCensorOverlay(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Positioned.fill(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          color: Colors.black.withValues(alpha: 0.4),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.visibility_off, color: Colors.white, size: 32),
                const SizedBox(height: 8),
                Text(
                  l10n.sensitiveContentCadet,
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
