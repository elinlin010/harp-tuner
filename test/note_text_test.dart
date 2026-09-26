import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harp_tuner/widgets/note_text.dart';

Widget _wrap(Widget child) => MaterialApp(
  home: Scaffold(body: Center(child: child)),
);

void main() {
  testWidgets('plain text without accidentals renders as a normal Text', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(const NoteText('4G')));
    expect(find.text('4G'), findsOneWidget);
  });

  testWidgets('♭ and ♯ are raised, top-aligned and 68% size', (tester) async {
    await tester.pumpWidget(
      _wrap(const NoteText('B♭ instead of A♯', style: TextStyle(fontSize: 20))),
    );
    final rich = tester.widget<RichText>(find.byType(RichText).first);
    final spans = <InlineSpan>[];
    rich.text.visitChildren((s) {
      spans.add(s);
      return true;
    });
    final accidentals = spans.whereType<WidgetSpan>().toList();
    expect(accidentals, hasLength(2));
    for (final w in accidentals) {
      expect(w.alignment, PlaceholderAlignment.top);
      final t = w.child as Text;
      expect(t.style!.fontSize, closeTo(20 * NoteText.accidentalScale, 0.01));
    }
    expect((accidentals[0].child as Text).data, '♭');
    expect((accidentals[1].child as Text).data, '♯');
  });

  testWidgets('reads as one label for screen readers', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_wrap(const NoteText('3A♭')));
    expect(find.bySemanticsLabel('3A♭'), findsOneWidget);
    handle.dispose();
  });
}
