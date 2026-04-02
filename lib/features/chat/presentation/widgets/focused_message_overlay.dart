import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xparq_app/features/auth/providers/auth_providers.dart';
import 'package:xparq_app/features/chat/domain/models/chat_model.dart';

class FocusedMessageOverlay extends ConsumerStatefulWidget {
  final MessageModel message;
  final Offset messageGlobalPosition;
  final Size messageSize;
  final Widget messageWidget;
  final VoidCallback onDismiss;
  final void Function(MessageModel)? onReply;
  final void Function(MessageModel)? onDelete;
  final void Function(MessageModel)? onPin;
  final void Function(MessageModel)? onRecall;
  final void Function(MessageModel)? onEdit;
  final void Function(String)? onReaction;

  const FocusedMessageOverlay({
    super.key,
    required this.message,
    required this.messageGlobalPosition,
    required this.messageSize,
    required this.messageWidget,
    required this.onDismiss,
    this.onReply,
    this.onDelete,
    this.onPin,
    this.onRecall,
    this.onEdit,
    this.onReaction,
  });

  @override
  ConsumerState<FocusedMessageOverlay> createState() => _FocusedMessageOverlayState();
}

class _FocusedMessageOverlayState extends ConsumerState<FocusedMessageOverlay> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeOutBack);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.sizeOf(context);
    final myUid = ref.watch(authRepositoryProvider).currentUser?.id ?? '';
    final isMe = widget.message.senderUid == myUid;
    
    final bool showAbove = widget.messageGlobalPosition.dy > screenSize.height * 0.4;
    
    return Stack(
      children: [
        // 1. Animated Blurred Background
        GestureDetector(
          onTap: () async {
            await _controller.reverse();
            widget.onDismiss();
          },
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return BackdropFilter(
                filter: ImageFilter.blur(
                  sigmaX: _controller.value * 8, // Further reduced blur per user request
                  sigmaY: _controller.value * 8,
                ),
                child: Container(
                  color: Colors.black.withOpacity((_controller.value * 0.5).clamp(0.0, 1.0)), // Lighter background
                ),
              );
            },
          ),
        ),
        
        // 2. Focused Content
        Positioned(
          top: showAbove ? null : widget.messageGlobalPosition.dy,
          bottom: showAbove ? screenSize.height - (widget.messageGlobalPosition.dy + widget.messageSize.height) : null,
          left: 0,
          right: 0,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (showAbove) ...[
                  _EmojiBar(
                    animation: _animation,
                    onReaction: (code) {
                      widget.onReaction?.call(code);
                      _controller.reverse().then((_) => widget.onDismiss());
                    },
                  ),
                  const SizedBox(height: 12),
                  ScaleTransition(
                    scale: _animation,
                    child: _buildHorizontalMenu(context, isMe),
                  ),
                  const SizedBox(height: 12),
                ],
                
                // The Message Bubble
                ScaleTransition(
                  scale: Tween<double>(begin: 0.95, end: 1.0).animate(_animation),
                  child: IgnorePointer(
                    child: widget.messageWidget,
                  ),
                ),
                
                if (!showAbove) ...[
                  const SizedBox(height: 12),
                  ScaleTransition(
                    scale: _animation,
                    child: _buildHorizontalMenu(context, isMe),
                  ),
                  const SizedBox(height: 12),
                  _EmojiBar(
                    animation: _animation,
                    onReaction: (code) {
                      widget.onReaction?.call(code);
                      _controller.reverse().then((_) => widget.onDismiss());
                    },
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHorizontalMenu(BuildContext context, bool isMe) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _MenuButton(
          icon: Icons.reply_rounded,
          label: 'Echo',
          onTap: () {
            widget.onReply?.call(widget.message);
            widget.onDismiss();
          },
        ),
        const SizedBox(width: 10),
        _MenuButton(
          icon: Icons.push_pin_outlined,
          label: 'Pin',
          onTap: () {
            widget.onPin?.call(widget.message);
            widget.onDismiss();
          },
        ),
        if (isMe) ...[
          // Only show Recall/Edit if within the 5-minute Signal Window (300 seconds)
          if (DateTime.now().difference(widget.message.timestamp).inSeconds < 300) ...[
            const SizedBox(width: 10),
            _MenuButton(
              icon: Icons.undo_rounded,
              label: 'Recall',
              onTap: () {
                widget.onRecall?.call(widget.message);
                widget.onDismiss();
              },
            ),
            if (widget.message.messageType == MessageType.text) ...[
              const SizedBox(width: 10),
              _MenuButton(
                icon: Icons.edit_outlined,
                label: 'Edit',
                onTap: () {
                  widget.onEdit?.call(widget.message);
                  widget.onDismiss();
                },
              ),
            ],
          ],
        ],
        const SizedBox(width: 10),
        _MenuButton(
          icon: Icons.delete_outline,
          label: 'Delete',
          color: const Color(0xFFFF5252), // Red Accent
          onTap: () {
            widget.onDelete?.call(widget.message);
            widget.onDismiss();
          },
        ),
      ],
    );
  }
}

class _MenuButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  const _MenuButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label, // Show label on long-press/tooltip
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: color?.withOpacity(0.15) ?? Colors.white.withOpacity(0.12),
            borderRadius: BorderRadius.circular(22), // Circular
            border: Border.all(
              color: color?.withOpacity(0.3) ?? Colors.white.withOpacity(0.08),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: (color ?? Colors.black).withOpacity(0.15),
                blurRadius: 8,
                spreadRadius: 1,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Icon(icon, size: 20, color: color ?? Colors.white.withOpacity(0.9)),
        ),
      ),
    );
  }
}

class _EmojiBar extends StatelessWidget {
  final Animation<double> animation;
  final void Function(String) onReaction;
  
  const _EmojiBar({required this.animation, required this.onReaction});

  @override
  Widget build(BuildContext context) {
    final emojis = ['⚡', '😂', '😭', '😮', '😡', '❤️', '👍', '🙏', '🎉', '💡'];
    
    return ScaleTransition(
      scale: animation,
      child: Container(
        height: 60,
        constraints: const BoxConstraints(maxWidth: 350),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        decoration: const BoxDecoration(
          color: Colors.transparent,
        ),
        child: ShaderMask(
          shaderCallback: (Rect bounds) {
            return const LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                Colors.transparent,
                Colors.white,
                Colors.white,
                Colors.transparent,
              ],
              stops: [0.0, 0.15, 0.85, 1.0],
            ).createShader(bounds);
          },
          blendMode: BlendMode.dstIn,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: emojis.length,
            itemBuilder: (context, index) {
              final e = emojis[index];
              return TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: Duration(milliseconds: 150 + (index * 15)),
                curve: Curves.easeOutBack,
                builder: (context, value, child) {
                  return Transform.scale(
                    scale: value,
                    child: child,
                  );
                },
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    onReaction(e);
                  },
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    child: Text(
                      e,
                      style: TextStyle(
                        fontSize: e == '⚡' ? 20 : 24,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
