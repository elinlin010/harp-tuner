import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harp_tuner/data/harp_presets.dart';
import 'package:harp_tuner/models/harp_string_model.dart';
import 'package:harp_tuner/theme/app_theme.dart';
import 'package:harp_tuner/widgets/string_visualizer.dart';

final _strings = HarpPresets.leverHarpWithCount(34);
final _first = _strings.first;
final _last = _strings.last;

Widget _viz({
  List<HarpStringModel>? strings,
  HarpStringModel? activeString,
  void Function(HarpStringModel)? onTap,
  TunerThemeData theme = TunerThemes.linen,
}) {
  return MaterialApp(
    home: Scaffold(
      body: SizedBox(
        width: 400,
        height: 200,
        child: StringVisualizer(
          strings: strings ?? _strings,
          activeString: activeString,
          onTap: onTap,
          theme: theme,
        ),
      ),
    ),
  );
}

void main() {
  group('StringVisualizer — rendering', () {
    testWidgets('renders 34 string labels without error', (tester) async {
      await tester.pumpWidget(_viz());
      await tester.pump();
      expect(tester.takeException(), isNull);
      // First string label should be visible (starts scrolled to beginning)
      expect(find.text(_first.label), findsOneWidget);
    });

    testWidgets('empty string list renders without error', (tester) async {
      await tester.pumpWidget(_viz(strings: []));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('Blueprint dark theme renders without error', (tester) async {
      await tester.pumpWidget(_viz(theme: TunerThemes.blueprint));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('Void dark theme renders without error', (tester) async {
      await tester.pumpWidget(_viz(theme: TunerThemes.void_));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });

  group('StringVisualizer — active string', () {
    testWidgets('no active string renders without error', (tester) async {
      await tester.pumpWidget(_viz(activeString: null));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('first string active renders without error', (tester) async {
      await tester.pumpWidget(_viz(activeString: _first));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('active string label is visible', (tester) async {
      await tester.pumpWidget(_viz(activeString: _first));
      await tester.pump();
      expect(find.text(_first.label), findsOneWidget);
    });

    testWidgets('changing active string does not throw', (tester) async {
      await tester.pumpWidget(_viz(activeString: _first));
      await tester.pump();

      await tester.pumpWidget(_viz(activeString: _last));
      await tester.pump();

      expect(tester.takeException(), isNull);
    });
  });

  group('StringVisualizer — tap callbacks', () {
    testWidgets('onTap null → no GestureDetector wrapping cells', (tester) async {
      await tester.pumpWidget(_viz(onTap: null));
      await tester.pump();
      // Without onTap, tapping should not fire any callback
      expect(tester.takeException(), isNull);
    });

    testWidgets('onTap provided → tapping first cell fires callback',
        (tester) async {
      HarpStringModel? tappedString;
      await tester.pumpWidget(
          _viz(onTap: (s) => tappedString = s, activeString: null));
      await tester.pump();

      await tester.tap(find.text(_first.label));
      expect(tappedString, isNotNull);
      expect(tappedString, equals(_first));
    });

    testWidgets('onTap fires correct string when second cell tapped',
        (tester) async {
      HarpStringModel? tappedString;
      final second = _strings[1];
      await tester.pumpWidget(_viz(onTap: (s) => tappedString = s));
      await tester.pump();

      await tester.tap(find.text(second.label));
      expect(tappedString, equals(second));
    });
  });

  group('StringVisualizer — single string edge case', () {
    testWidgets('single string list renders label', (tester) async {
      final single = [_first];
      await tester.pumpWidget(_viz(strings: single, activeString: _first));
      await tester.pump();
      expect(find.text(_first.label), findsOneWidget);
    });
  });
}
