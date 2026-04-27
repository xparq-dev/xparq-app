import 'package:flutter/material.dart';

enum OutgoingCallType {
  voice,
  video,
}

Future<OutgoingCallType?> showCallTypePickerSheet(BuildContext context) {
  final theme = Theme.of(context);
  final isLight = theme.brightness == Brightness.light;

  return showModalBottomSheet<OutgoingCallType>(
    context: context,
    useRootNavigator: true,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (sheetContext) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isLight
                    ? const [
                        Color(0xFFF8FBFF),
                        Color(0xFFE9F1FC),
                      ]
                    : const [
                        Color(0xFF101828),
                        Color(0xFF070D17),
                      ],
              ),
              border: Border.all(
                color:
                    isLight ? const Color(0x40FFFFFF) : const Color(0x1FFFFFFF),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isLight ? 0.10 : 0.28),
                  blurRadius: 26,
                  offset: const Offset(0, 14),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color:
                            theme.colorScheme.onSurface.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Choose call type',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Select whether you want to start a voice call or a VDO call.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color:
                          theme.colorScheme.onSurface.withValues(alpha: 0.68),
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 18),
                  _CallTypeOption(
                    icon: Icons.call_rounded,
                    title: 'Voice Call',
                    subtitle: 'Audio-first call with the current call flow',
                    accent: isLight
                        ? const Color(0xFF2E78FF)
                        : const Color(0xFF7ACBFF),
                    onTap: () {
                      Navigator.of(sheetContext).pop(OutgoingCallType.voice);
                    },
                  ),
                  const SizedBox(height: 12),
                  _CallTypeOption(
                    icon: Icons.videocam_rounded,
                    title: 'VDO Call',
                    subtitle: 'Starts with camera intent enabled for the call',
                    accent: isLight
                        ? const Color(0xFF0E9E8C)
                        : const Color(0xFF53D9B4),
                    onTap: () {
                      Navigator.of(sheetContext).pop(OutgoingCallType.video);
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

class _CallTypeOption extends StatelessWidget {
  const _CallTypeOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLight = theme.brightness == Brightness.light;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          color: theme.colorScheme.surface
              .withValues(alpha: isLight ? 0.76 : 0.18),
          border: Border.all(
            color: accent.withValues(alpha: isLight ? 0.24 : 0.32),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accent.withValues(alpha: isLight ? 0.14 : 0.18),
                ),
                child: Icon(icon, color: accent, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color:
                            theme.colorScheme.onSurface.withValues(alpha: 0.66),
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.42),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
