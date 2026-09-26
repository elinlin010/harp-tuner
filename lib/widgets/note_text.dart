import 'package:flutter/material.dart';

/// Text containing note names (e.g. "3A♭", "G2–E♭7 · E♭ maj") with every
/// ♭ / ♯ set small and raised to the top right of its letter. This is the same
/// convention as the tuner's big note readout. Use it wherever a note name
/// appears so accidentals look the same everywhere in the app.
///
/// [style] is merged over the ambient [DefaultTextStyle], so it also follows
/// an enclosing AnimatedDefaultTextStyle.
class NoteText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final TextAlign textAlign;

  /// Accidental size relative to the surrounding text.
  static const accidentalScale = 0.68;

  static final _accidental = RegExp('[♭♯]');

  const NoteText(
    this.text, {
    super.key,
    this.style,
    this.textAlign = TextAlign.start,
  });

  @override
  Widget build(BuildContext context) {
    final base = DefaultTextStyle.of(context).style.merge(style);
    if (!_accidental.hasMatch(text)) {
      return Text(text, style: style, textAlign: textAlign);
    }

    final accStyle = base.copyWith(
      fontSize: (base.fontSize ?? 14) * accidentalScale,
      height: 1.0,
    );
    final spans = <InlineSpan>[];
    var start = 0;
    for (final m in _accidental.allMatches(text)) {
      if (m.start > start) {
        spans.add(TextSpan(text: text.substring(start, m.start)));
      }
      // Top-aligned placeholder: the symbol sits up at the letter's shoulder.
      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.top,
          child: Text(m.group(0)!, style: accStyle),
        ),
      );
      start = m.end;
    }
    if (start < text.length) spans.add(TextSpan(text: text.substring(start)));

    // Read as one label ("3A♭"), not as separate spans.
    return Semantics(
      label: text,
      child: ExcludeSemantics(
        child: Text.rich(
          TextSpan(style: base, children: spans),
          textAlign: textAlign,
        ),
      ),
    );
  }
}
