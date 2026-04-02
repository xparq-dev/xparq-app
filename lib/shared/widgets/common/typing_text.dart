import 'dart:async';
import 'package:flutter/material.dart';

class TypingText extends StatefulWidget {
  final String text;

  final TextStyle? style;

  final Duration typingSpeed;
  final Duration loopDelay;

  final bool repeat; // 🔥 default = true
  final VoidCallback? onComplete;

  final bool showCursor;

  const TypingText({
    super.key,
    required this.text,
    this.style,
    this.typingSpeed = const Duration(milliseconds: 200),
    this.loopDelay = const Duration(seconds: 5),
    this.repeat = true,
    this.onComplete,
    this.showCursor = true,
  });

  @override
  State<TypingText> createState() => _TypingTextState();
}

class _TypingTextState extends State<TypingText> {
  String _display = '';
  bool _cursorVisible = true;

  Timer? _typingTimer;
  Timer? _cursorTimer;

  int _index = 0;

  @override
  void initState() {
    super.initState();
    _startTyping();

    if (widget.showCursor) {
      _cursorTimer = Timer.periodic(
        const Duration(milliseconds: 530),
        (_) {
          if (mounted) {
            setState(() => _cursorVisible = !_cursorVisible);
          }
        },
      );
    }
  }

  void _startTyping() {
    _typingTimer?.cancel();
    _index = 0;

    setState(() => _display = '');

    _typingTimer = Timer.periodic(widget.typingSpeed, (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (_index < widget.text.length) {
        setState(() {
          _display = widget.text.substring(0, _index + 1);
        });
        _index++;
      } else {
        timer.cancel();

        if (widget.repeat) {
          Future.delayed(widget.loopDelay, () {
            if (mounted) _startTyping();
          });
        } else {
          widget.onComplete?.call();
        }
      }
    });
  }

  /// 🔥 external control (optional future use)
  void restart() {
    _startTyping();
  }

  void stop() {
    _typingTimer?.cancel();
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    _cursorTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textStyle =
        widget.style ??
        TextStyle(
          color: Theme.of(context).colorScheme.onSurface,
          fontSize: 16,
        );

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          _display,
          style: textStyle.copyWith(height: 1.0),
        ),

        if (widget.showCursor)
          AnimatedOpacity(
            opacity: _cursorVisible ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 200),
            child: Container(
              width: 2,
              height: textStyle.fontSize ?? 18,
              color: textStyle.color,
              margin: const EdgeInsetsDirectional.only(start: 4, bottom: 4),
            ),
          ),
      ],
    );
  }
}