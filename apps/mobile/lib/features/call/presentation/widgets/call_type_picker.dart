import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:xparq_app/features/call/domain/models/call_type.dart';
import 'package:xparq_app/shared/widgets/common/xparq_image.dart';

/// Shows a premium bottom sheet to choose Voice or Video call.
/// Returns [CallType] or null if dismissed.
Future<CallType?> showCallTypePicker({
  required BuildContext context,
  required String peerName,
  required String peerAvatarUrl,
}) {
  return showModalBottomSheet<CallType>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _CallTypePickerSheet(
      peerName: peerName,
      peerAvatarUrl: peerAvatarUrl,
    ),
  );
}

class _CallTypePickerSheet extends StatelessWidget {
  const _CallTypePickerSheet({
    required this.peerName,
    required this.peerAvatarUrl,
  });

  final String peerName;
  final String peerAvatarUrl;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0D0D1F) : const Color(0xFFF4F0FF);
    final border = isDark ? const Color(0xFF2A2A4A) : const Color(0xFFD4C8FF);
    final nameColor = isDark ? Colors.white : const Color(0xFF1A0533);
    final subColor = isDark ? const Color(0xFF9B8FCC) : const Color(0xFF7C3AED);
    final divColor = isDark ? const Color(0xFF1E1E3A) : const Color(0xFFE8E0FF);

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            border: Border(
              top: BorderSide(color: border, width: 0.5),
              left: BorderSide(color: border, width: 0.5),
              right: BorderSide(color: border, width: 0.5),
            ),
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).padding.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 24),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF3A3A5A) : const Color(0xFFCBC0F0),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Avatar
              _GalacticAvatar(
                avatarUrl: peerAvatarUrl,
                size: 72,
                isDark: isDark,
              ),
              const SizedBox(height: 14),

              // Name
              Text(
                peerName,
                style: TextStyle(
                  color: nameColor,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Choose call type',
                style: TextStyle(
                  color: subColor,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 28),

              // Divider
              Container(height: 0.5, color: divColor, margin: const EdgeInsets.symmetric(horizontal: 24)),
              const SizedBox(height: 20),

              // Buttons
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    Expanded(
                      child: _PickerButton(
                        icon: Icons.mic_none_rounded,
                        label: 'Voice Call',
                        isDark: isDark,
                        onTap: () => Navigator.pop(context, CallType.voice),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _PickerButton(
                        icon: Icons.videocam_outlined,
                        label: 'Video Call',
                        isDark: isDark,
                        onTap: () => Navigator.pop(context, CallType.video),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Cancel
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Cancel',
                  style: TextStyle(
                    color: subColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PickerButton extends StatelessWidget {
  const _PickerButton({
    required this.icon,
    required this.label,
    required this.isDark,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? const Color(0xFF16163A) : const Color(0xFFEDE9FF);
    final border = isDark ? const Color(0xFF3A3A6A) : const Color(0xFFCFBFFF);
    final iconColor = isDark ? const Color(0xFFA78BFA) : const Color(0xFF6D28D9);
    final labelColor = isDark ? const Color(0xFFE9D5FF) : const Color(0xFF4C1D95);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: border, width: 0.5),
        ),
        child: Column(
          children: [
            Icon(icon, color: iconColor, size: 28),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: labelColor,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Reusable galactic avatar widget used across call screens
class _GalacticAvatar extends StatelessWidget {
  const _GalacticAvatar({
    required this.avatarUrl,
    required this.size,
    required this.isDark,
    this.showRipple = false,
  });

  final String avatarUrl;
  final double size;
  final bool isDark;
  final bool showRipple;

  @override
  Widget build(BuildContext context) {
    final innerBg = isDark ? const Color(0xFF120A2E) : const Color(0xFFEDE9FE);
    final fallbackColor = isDark ? const Color(0xFFE9D5FF) : const Color(0xFF4C1D95);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const SweepGradient(
          colors: [
            Color(0xFF7C3AED),
            Color(0xFFA78BFA),
            Color(0xFF38BDF8),
            Color(0xFF818CF8),
            Color(0xFF7C3AED),
          ],
        ),
      ),
      padding: const EdgeInsets.all(2),
      child: Container(
        decoration: BoxDecoration(shape: BoxShape.circle, color: innerBg),
        clipBehavior: Clip.antiAlias,
        child: avatarUrl.isNotEmpty
            ? XparqImage(imageUrl: avatarUrl, fit: BoxFit.cover)
            : Center(
                child: Icon(Icons.person_rounded, size: size * 0.42, color: fallbackColor),
              ),
      ),
    );
  }
}
