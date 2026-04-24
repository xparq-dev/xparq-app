import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xparq_app/shared/enums/age_group.dart';
import 'package:xparq_app/features/chat/presentation/providers/signal_chat_controller.dart';
import 'package:xparq_app/features/chat/presentation/providers/chat_providers.dart';

class ChatInputBar extends ConsumerWidget {
  final String chatId;
  final String otherUid;
  final AgeGroup ageGroup;
  final bool isSpamMode;
  final TextEditingController textController;

  const ChatInputBar({
    super.key,
    required this.chatId,
    required this.otherUid,
    required this.ageGroup,
    this.isSpamMode = false,
    required this.textController,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (isSpamMode) return const SizedBox.shrink();

    final state = ref.watch(signalChatControllerProvider(chatId));
    final controller = ref.read(signalChatControllerProvider(chatId).notifier);
    final settingsMap = ref.watch(chatSettingsProvider).valueOrNull ?? {};
    final isLandscape = MediaQuery.orientationOf(context) == Orientation.landscape;

    return RepaintBoundary(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16, 
          0, 
          16, 
          state.isKeyboardWarped ? 8 : (MediaQuery.viewPaddingOf(context).bottom + 8)
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.white.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(32),
                border: Border.all(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white.withValues(alpha: 0.1)
                      : Colors.black.withValues(alpha: 0.08),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: Theme.of(context).brightness == Brightness.dark ? 0.3 : 0.08),
                    blurRadius: 25,
                    spreadRadius: -5,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              padding: EdgeInsets.symmetric(
                horizontal: 12,
                vertical: isLandscape ? 6 : 10,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Quick Actions: Silent, Spark, Echo
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _QuickActionButton(
                          icon: (settingsMap[chatId]?['silenced_until'] != null)
                              ? Icons.notifications_off
                              : Icons.notifications_none,
                          label: 'Silent',
                          isActive: settingsMap[chatId]?['silenced_until'] != null,
                          onTap: () {
                            HapticFeedback.lightImpact();
                            final isMuted = settingsMap[chatId]?['silenced_until'] != null;
                            if (isMuted) {
                              controller.toggleMute(duration: null); // Unmute
                            } else {
                              controller.toggleMute(duration: const Duration(hours: 1)); // Default 1h
                            }
                          },
                          onLongPress: () {
                            HapticFeedback.mediumImpact();
                            _showMuteOptions(context, controller);
                          },
                        ),
                        _QuickActionButton(
                          icon: Icons.bolt,
                          label: 'Spark',
                          onTap: () {
                            HapticFeedback.lightImpact();
                            controller.sendSticker('⚡');
                          },
                          onLongPress: () {
                            HapticFeedback.mediumImpact();
                            _showStickerPicker(context, controller);
                          },
                        ),
                        _QuickActionButton(
                          icon: Icons.reply,
                          label: 'Echo',
                          isActive: state.replyingTo != null,
                          onTap: () {
                            HapticFeedback.lightImpact();
                            controller.echoLastMessage();
                          },
                        ),
                      ],
                    ),
                  ),

                  // Editing Indicator
                  if (state.editingMessage != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      child: Row(
                        children: [
                          Icon(
                            Icons.edit_outlined,
                            size: 14,
                            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.7),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Editing Signal',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.7),
                              letterSpacing: 0.5,
                            ),
                          ),
                          const Spacer(),
                          GestureDetector(
                            onTap: () {
                              HapticFeedback.lightImpact();
                              controller.setEditingMessage(null);
                              textController.clear();
                            },
                            child: Icon(
                              Icons.close_rounded,
                              size: 16,
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                            ),
                          ),
                        ],
                      ),
                    ),

                  Row(
                    children: [
                      if (ageGroup == AgeGroup.explorer)
                        IconButton(
                          icon: Icon(
                            Icons.do_not_disturb_on,
                            color: state.isSensitive
                                ? const Color(0xFF7C4DFF)
                                : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38),
                            size: isLandscape ? 20 : 22,
                          ),
                          tooltip: 'Flag as sensitive (Black Hole Zone)',
                          onPressed: () => controller.toggleSensitive(!state.isSensitive),
                        ),
                      IconButton(
                        icon: Icon(
                          Icons.image_outlined,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                          size: isLandscape ? 20 : 22,
                        ),
                        tooltip: 'Attach Image',
                        onPressed: state.isUploadingMedia ? null : () => controller.pickAndSendImage(otherUid),
                      ),
                      Expanded(
                        child: TextField(
                          controller: textController,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontSize: isLandscape ? 14 : 15,
                          ),
                          maxLines: isLandscape ? 2 : null,
                          keyboardType: TextInputType.multiline,
                          decoration: InputDecoration(
                            hintText: state.editingMessage != null ? 'Recraft your signal…' : 'Transmit a signal…',
                            hintStyle: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38),
                              fontSize: isLandscape ? 13 : 15,
                            ),
                            filled: true,
                            fillColor: (Theme.of(context).brightness == Brightness.dark 
                                ? Colors.white.withValues(alpha: 0.05) 
                                : Colors.black.withValues(alpha: 0.02)),
                            isDense: isLandscape,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          onSubmitted: (_) => controller.sendMessage(textController.text, otherUid, textController),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          controller.sendMessage(textController.text, otherUid, textController);
                        },
                        child: Container(
                          width: isLandscape ? 36 : 44,
                          height: isLandscape ? 36 : 44,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: state.isSensitive
                                ? const Color(0xFF7C4DFF)
                                : const Color(0xFF4FC3F7),
                            boxShadow: [
                              BoxShadow(
                                color: (state.isSensitive ? const Color(0xFF7C4DFF) : const Color(0xFF4FC3F7)).withValues(alpha: 0.45),
                                blurRadius: 12,
                                spreadRadius: -2,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: state.isUploadingMedia
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Icon(
                                  state.editingMessage != null ? Icons.check_rounded : Icons.send_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool isActive;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.onLongPress,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive
              ? const Color(0xFF4FC3F7).withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: isActive
              ? Border.all(
                  color: const Color(0xFF4FC3F7).withValues(alpha: 0.5),
                  width: 0.5,
                )
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 20,
              color: isActive
                  ? const Color(0xFF4FC3F7)
                  : theme.colorScheme.onSurface.withValues(alpha: 
                      theme.brightness == Brightness.dark ? 0.6 : 0.8
                    ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: isActive
                    ? const Color(0xFF4FC3F7)
                    : theme.colorScheme.onSurface.withValues(alpha: 
                        theme.brightness == Brightness.dark ? 0.6 : 0.8
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

void _showMuteOptions(BuildContext context, SignalChatController controller) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text(
              'Mute Notifications',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          _MuteOption(
            icon: Icons.timer_outlined,
            title: '1 Hour',
            onTap: () {
              controller.toggleMute(duration: const Duration(hours: 1));
              Navigator.pop(context);
            },
          ),
          _MuteOption(
            icon: Icons.timer_outlined,
            title: '8 Hours',
            onTap: () {
              controller.toggleMute(duration: const Duration(hours: 8));
              Navigator.pop(context);
            },
          ),
          _MuteOption(
            icon: Icons.calendar_today_outlined,
            title: '1 Day',
            onTap: () {
              controller.toggleMute(duration: const Duration(days: 1));
              Navigator.pop(context);
            },
          ),
          _MuteOption(
            icon: Icons.calendar_month_outlined,
            title: '7 Days',
            onTap: () {
              controller.toggleMute(duration: const Duration(days: 7));
              Navigator.pop(context);
            },
          ),
          _MuteOption(
            icon: Icons.notifications_off_outlined,
            title: 'Always',
            onTap: () {
              controller.toggleMute(duration: const Duration(days: 3650)); // ~10 years
              Navigator.pop(context);
            },
          ),
        ],
      ),
    ),
  );
}

class _MuteOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _MuteOption({required this.icon, required this.title, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, size: 22, color: const Color(0xFF4FC3F7)),
      title: Text(title, style: const TextStyle(fontSize: 14)),
      onTap: onTap,
    );
  }
}

void _showStickerPicker(BuildContext context, SignalChatController controller) {
  final stickers = [
    '✨', '🔥', '❤️', '👍', '😂', 
    '⚡', '🎉', '💡', '💯', '🚀',
    '😍', '🙌', '🌟', '💎', '🫠',
    '👻', '👽', '👾', '🌈', '🍭'
  ];
  
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.3),
    isScrollControlled: true,
    builder: (context) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        left: 16,
        right: 16,
      ),
      child: TweenAnimationBuilder<double>(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutBack,
        tween: Tween(begin: 0.0, end: 1.0),
        builder: (context, value, child) {
          return Transform.scale(
            scale: 0.8 + (value * 0.2),
            child: Opacity(
              opacity: value.clamp(0.0, 1.0),
              child: Material(
                type: MaterialType.transparency,
                child: child ?? const SizedBox.shrink(),
              ),
            ),
          );
        },
        child: Container(
          constraints: BoxConstraints(
            maxHeight: (MediaQuery.maybeOf(context)?.size.height ?? 800) * 0.45,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 24,
                spreadRadius: -8,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(32),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: (Theme.of(context).brightness == Brightness.dark 
                      ? Colors.white.withValues(alpha: 0.08) 
                      : Colors.white.withValues(alpha: 0.92)),
                  borderRadius: BorderRadius.circular(32),
                  border: Border.all(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white.withValues(alpha: 0.1)
                        : Colors.black.withValues(alpha: 0.08),
                    width: 1.5,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: Theme.of(context).brightness == Brightness.dark 
                            ? Colors.white.withValues(alpha: 0.2)
                            : Colors.black.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Text(
                      'Spark Sticker',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Flexible(
                      child: GridView.builder(
                        shrinkWrap: true,
                        physics: const BouncingScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 5,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                        ),
                        itemCount: stickers.length,
                        itemBuilder: (context, index) {
                          return TweenAnimationBuilder<double>(
                            duration: Duration(milliseconds: 150 + (index * 15)),
                            curve: Curves.easeOutBack,
                            tween: Tween(begin: 0.0, end: 1.0),
                            builder: (context, anim, child) => Transform.scale(
                              scale: anim,
                              child: child ?? const SizedBox.shrink(),
                            ),
                            child: GestureDetector(
                              onTap: () {
                                controller.sendSticker(stickers[index]);
                                Navigator.pop(context);
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.1),
                                      blurRadius: 8,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  stickers[index],
                                  style: const TextStyle(fontSize: 26),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
