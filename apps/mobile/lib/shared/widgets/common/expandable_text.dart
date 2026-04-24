import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

class ExpandableText extends StatefulWidget {
  final String text;
  final int trimLines;
  final TextStyle? style;

  const ExpandableText({
    super.key,
    required this.text,
    this.trimLines = 3,
    this.style,
  });

  @override
  State<ExpandableText> createState() => _ExpandableTextState();
}

class _ExpandableTextState extends State<ExpandableText> {
  bool _readMore = true;

  void _onTapLink() {
    setState(() => _readMore = !_readMore);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final linkStyle = TextStyle(
      color: const Color(0xFF4FC3F7),
      fontWeight: FontWeight.bold,
      fontSize: (widget.style?.fontSize ?? 14) * 0.9,
    );

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final textStyle =
            widget.style ??
            TextStyle(
              color: theme.colorScheme.onSurface,
              fontSize: 14,
              height: 1.5,
            );

        // Create a TextSpan with the full text
        final textSpan = TextSpan(text: widget.text, style: textStyle);

        // Use a TextPainter to determine if the text exceeds the line limit
        final textPainter = TextPainter(
          text: textSpan,
          maxLines: widget.trimLines,
          textAlign: TextAlign.start,
          textDirection: TextDirection.ltr,
        );

        textPainter.layout(maxWidth: constraints.maxWidth);

        if (!textPainter.didExceedMaxLines) {
          return Text(widget.text, style: textStyle);
        }

        // Text exceeds max lines, show truncated with "More"
        if (_readMore) {
          return RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: _getTruncatedText(textPainter, constraints.maxWidth),
                  style: textStyle,
                ),
                TextSpan(
                  text: ' ...More',
                  style: linkStyle,
                  recognizer: TapGestureRecognizer()..onTap = _onTapLink,
                ),
              ],
            ),
          );
        } else {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.text, style: textStyle),
              GestureDetector(
                onTap: _onTapLink,
                child: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('Show Less', style: linkStyle),
                ),
              ),
            ],
          );
        }
      },
    );
  }

  String _getTruncatedText(TextPainter painter, double maxWidth) {
    // This is a simplified truncation.
    // For a more robust solution, we can binary search or use character positions.
    final position = painter.getPositionForOffset(
      Offset(maxWidth, painter.height),
    );
    final endOffset = position.offset;

    // Backtrack a bit to make room for " ...More"
    return widget.text
        .substring(0, (endOffset - 10).clamp(0, widget.text.length))
        .trim();
  }
}
