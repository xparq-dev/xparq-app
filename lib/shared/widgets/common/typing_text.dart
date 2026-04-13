import 'dart:async';
import 'package:flutter/material.dart';

/// Animates `text` character by character, then waits [loopDelay] and loops.
class TypingText extends StatefulWidget {
  final String text;
  final TextStyle style;
  final Duration typingSpeed;
  final Duration loopDelay;

  const TypingText({
    super.key,
    required this.text,
    required this.style,
    this.typingSpeed = const Duration(milliseconds: 200),
    this.loopDelay = const Duration(seconds: 5),
  });

  @override
  State<TypingText> createState() => _TypingTextState();
}

class _TypingTextState extends State<TypingText> {
  String _displayString = '';
  bool _showCursor = true;
  Timer? _typingTimer;
  Timer? _cursorTimer;

  @override
  void initState() {
    super.initState();
    _startTyping();
    _cursorTimer = Timer.periodic(const Duration(milliseconds: 530), (_) {
      if (mounted) setState(() => _showCursor = !_showCursor);
    });
  }

  void _startTyping() {
    int index = 0;
    if (mounted) setState(() => _displayString = '');

    _typingTimer?.cancel();
    _typingTimer = Timer.periodic(widget.typingSpeed, (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (index < widget.text.length) {
        setState(() => _displayString = widget.text.substring(0, index + 1));
        index++;
      } else {
        timer.cancel();
        Future.delayed(widget.loopDelay, () {
          if (mounted) _startTyping();
        });
      }
    });
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    _cursorTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textColor =
        widget.style.color ?? Theme.of(context).colorScheme.onSurface;

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          _displayString,
          style: widget.style.copyWith(color: textColor, height: 1.0),
        ),
        Opacity(
          opacity: _showCursor ? 1.0 : 0.0,
          child: Container(
            width: 2,
            height: widget.style.fontSize ?? 20,
            color: textColor,
            margin: const EdgeInsetsDirectional.only(start: 4, bottom: 4),
          ),
        ),
      ],
    );
  }
}
