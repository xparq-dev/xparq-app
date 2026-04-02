import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

class ExpandableText extends StatefulWidget {
  final String text;
  final int trimLines;
  final TextStyle? style;

  final String expandText;
  final String collapseText;

  final Duration animationDuration;

  const ExpandableText({
    super.key,
    required this.text,
    this.trimLines = 3,
    this.style,
    this.expandText = 'More',
    this.collapseText = 'Show less',
    this.animationDuration = const Duration(milliseconds: 200),
  });

  @override
  State<ExpandableText> createState() => _ExpandableTextState();
}

class _ExpandableTextState extends State<ExpandableText>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;

  void _toggle() => setState(() => _expanded = !_expanded);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final textStyle =
        widget.style ??
        TextStyle(
          color: theme.colorScheme.onSurface,
          fontSize: 14,
          height: 1.5,
        );

    final linkStyle = textStyle.copyWith(
      color: theme.colorScheme.primary,
      fontWeight: FontWeight.w600,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final span = TextSpan(text: widget.text, style: textStyle);

        final tp = TextPainter(
          text: span,
          maxLines: widget.trimLines,
          textDirection: TextDirection.ltr,
        );

        tp.layout(maxWidth: constraints.maxWidth);

        final exceeds = tp.didExceedMaxLines;

        if (!exceeds) {
          return Text(widget.text, style: textStyle);
        }

        return AnimatedSize(
          duration: widget.animationDuration,
          curve: Curves.easeInOut,
          child: _expanded
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.text, style: textStyle),
                    const SizedBox(height: 4),
                    GestureDetector(
                      onTap: _toggle,
                      child: Text(widget.collapseText, style: linkStyle),
                    ),
                  ],
                )
              : RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: _truncateText(
                          widget.text,
                          tp,
                          constraints.maxWidth,
                          widget.expandText,
                        ),
                        style: textStyle,
                      ),
                      TextSpan(
                        text: ' ...${widget.expandText}',
                        style: linkStyle,
                        recognizer: TapGestureRecognizer()..onTap = _toggle,
                      ),
                    ],
                  ),
                ),
        );
      },
    );
  }

  String _truncateText(
    String text,
    TextPainter tp,
    double maxWidth,
    String expandText,
  ) {
    int low = 0;
    int high = text.length;

    while (low < high) {
      final mid = (low + high) ~/ 2;

      final span = TextSpan(
        text: text.substring(0, mid) + ' ...$expandText',
        style: tp.text!.style,
      );

      final testPainter = TextPainter(
        text: span,
        maxLines: tp.maxLines,
        textDirection: TextDirection.ltr,
      );

      testPainter.layout(maxWidth: maxWidth);

      if (testPainter.didExceedMaxLines) {
        high = mid;
      } else {
        low = mid + 1;
      }
    }

    return text.substring(0, low).trim();
  }
}