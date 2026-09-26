import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harp_tuner/widgets/note_text.dart';

Widget _wrap(Widget child) => MaterialApp(
  home: Scaffold(body: Center(child: child)),
);

Iterable<Text> _accidentalGlyphs(WidgetTester tester) => tester
    .widgetList<Text>(find.byType(Text))
    .where((t) => t.style?.fontFamily == NoteText.fontFamily);

void main() {
  testWidgets('plain text without accidentals renders as a normal Text', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(const NoteText('4G')));
    expect(find.text('4G'), findsOneWidget);
    expect(_accidentalGlyphs(tester), isEmpty);
  });

  testWidgets('♭ ♮ ♯ use the bundled font at the given scale', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const NoteText(
          'B♭ A♮ A♯',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          accidentalScale: 0.5,
        ),
      ),
    );
    final glyphs = _accidentalGlyphs(tester).toList();
    expect(glyphs.map((t) => t.data), ['♭', '♮', '♯']);
    for (final g in glyphs) {
      expect(g.style!.fontSize, 10);
      expect(g.style!.fontWeight, FontWeight.w700);
    }
  });

  testWidgets('accidentals are raised above the baseline, not beside it', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(const NoteText('A♯', style: TextStyle(fontSize: 100))),
    );
    final rich = tester.widget<RichText>(find.byType(RichText).first);
    WidgetSpan? span;
    rich.text.visitChildren((s) {
      if (s is WidgetSpan) span = s;
      return true;
    });
    expect(span!.alignment, PlaceholderAlignment.aboveBaseline);
    // The box sits on the baseline and reaches just above the cap top
    // (0.694 em), so the glyph reads as a superscript.
    final box = span!.child as SizedBox;
    expect(box.height, closeTo((0.694 + 0.04) * 100, 0.5));
    // Side bearings trimmed: much narrower than the glyph's full-width advance.
    expect(box.width, lessThan(0.58 * 100 * 0.7));
  });

  testWidgets('reads as one label for screen readers', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_wrap(const NoteText('3A♭')));
    expect(find.bySemanticsLabel('3A♭'), findsOneWidget);
    handle.dispose();
  });
}
