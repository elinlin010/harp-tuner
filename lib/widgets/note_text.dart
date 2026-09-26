import 'package:flutter/material.dart';

/// Text containing note names (e.g. "3A♭", "G2–E♭7 · E♭ maj") with every
/// ♭ / ♮ / ♯ set as a superscript at the top right of its letter, the way a
/// web page's `<sup>` does. Use it wherever a note name appears, the gauge's
/// big note included, so accidentals look the same everywhere in the app.
///
/// The glyphs come from the bundled `NoteAccidentals` font (a Noto Sans TC
/// subset) rather than whatever fallback font the platform picks, so they have
/// the same shape and metrics on iOS, Android and in tests. Each one is:
/// - shrunk to [accidentalScale] of the text size,
/// - trimmed of its full-width side bearings (the ink is only ~40–50% of the
///   advance), keeping a small gap either side,
/// - raised so its ink top sits just above the letters' cap top.
///   Aligning the glyph's em box instead drops ♯ too low: its ink sits lower
///   in the box than ♭'s.
///
/// [style] is merged over the ambient [DefaultTextStyle], so it also follows
/// an enclosing AnimatedDefaultTextStyle.
class NoteText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final TextAlign textAlign;

  /// Accidental size relative to the surrounding text.
  final double accidentalScale;

  static const fontFamily = 'NoteAccidentals';
  static const defaultAccidentalScale = 0.58;

  // Outfit's cap height and NoteAccidentals' line metrics, in em.
  static const _textCapHeight = 0.694;
  static const _accAscentShare = 1160 / (1160 + 288); // at height 1.0
  // Ink bounds of each glyph: (left, right) and top, in em (weight 400; the
  // other weights differ by <1%).
  static const _inkX = {
    '♭': (0.348, 0.741),
    '♮': (0.328, 0.678),
    '♯': (0.236, 0.760),
  };
  static const _inkTop = 0.818;
  // Ink top above the cap top, and the gap either side, as fractions of the
  // text size.
  static const _lift = 0.04;
  static const _gap = 0.03;

  static final _accidental = RegExp('[♭♮♯]');

  const NoteText(
    this.text, {
    super.key,
    this.style,
    this.textAlign = TextAlign.start,
    this.accidentalScale = defaultAccidentalScale,
  });

  @override
  Widget build(BuildContext context) {
    final base = DefaultTextStyle.of(context).style.merge(style);
    if (!_accidental.hasMatch(text)) {
      return Text(text, style: style, textAlign: textAlign);
    }

    final size = base.fontSize ?? 14;
    final acc = size * accidentalScale;
    final accStyle = TextStyle(
      fontFamily: fontFamily,
      fontSize: acc,
      fontWeight: base.fontWeight,
      color: base.color,
      height: 1.0,
    );
    // Glyph baseline height above the text baseline, putting the ink top
    // _lift above the cap top.
    final raise = (_textCapHeight + _lift) * size - _inkTop * acc;
    final gap = _gap * size;

    final spans = <InlineSpan>[];
    var start = 0;
    for (final m in _accidental.allMatches(text)) {
      if (m.start > start) {
        spans.add(TextSpan(text: text.substring(start, m.start)));
      }
      final glyph = m.group(0)!;
      final (left, right) = _inkX[glyph]!;
      // A box sitting on the baseline, as tall as the raised ink, as wide as
      // the ink plus the gaps. The glyph is placed inside it by its ink.
      final boxHeight = raise + _inkTop * acc;
      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.aboveBaseline,
          baseline: TextBaseline.alphabetic,
          child: SizedBox(
            width: (right - left) * acc + 2 * gap,
            height: boxHeight,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  left: gap - left * acc,
                  top: boxHeight - raise - _accAscentShare * acc,
                  child: Text(glyph, style: accStyle),
                ),
              ],
            ),
          ),
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
