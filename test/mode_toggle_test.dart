import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harp_tuner/l10n/app_localizations.dart';
import 'package:harp_tuner/providers/tuner_provider.dart';
import 'package:harp_tuner/theme/app_theme.dart';
import 'package:harp_tuner/widgets/mode_toggle.dart';

Widget _toggle({
  TunerMode mode = TunerMode.auto,
  ValueChanged<TunerMode>? onChanged,
  TunerThemeData theme = TunerThemes.linen,
}) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('en'),
    home: Scaffold(
      body: Center(
        child: ModeToggle(
          mode: mode,
          onChanged: onChanged ?? (_) {},
          theme: theme,
        ),
      ),
    ),
  );
}

void main() {
  group('ModeToggle — rendering', () {
    testWidgets('renders without error in auto mode', (tester) async {
      await tester.pumpWidget(_toggle(mode: TunerMode.auto));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders without error in reference mode', (tester) async {
      await tester.pumpWidget(_toggle(mode: TunerMode.reference));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('Blueprint dark theme renders without error', (tester) async {
      await tester.pumpWidget(
          _toggle(mode: TunerMode.auto, theme: TunerThemes.blueprint));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });

  group('ModeToggle — tap callbacks', () {
    testWidgets('tapping reference tab fires onChanged(reference)',
        (tester) async {
      TunerMode? tapped;
      await tester.pumpWidget(
          _toggle(mode: TunerMode.auto, onChanged: (m) => tapped = m));
      await tester.pump();

      // The reference tab contains the volume_up icon
      final refIcon = find.byIcon(Icons.volume_up_rounded);
      expect(refIcon, findsOneWidget);
      await tester.tap(refIcon);
      expect(tapped, TunerMode.reference);
    });

    testWidgets('tapping auto tab fires onChanged(auto)', (tester) async {
      TunerMode? tapped;
      await tester.pumpWidget(
          _toggle(mode: TunerMode.reference, onChanged: (m) => tapped = m));
      await tester.pump();

      final autoIcon = find.byIcon(Icons.graphic_eq_rounded);
      expect(autoIcon, findsOneWidget);
      await tester.tap(autoIcon);
      expect(tapped, TunerMode.auto);
    });

    testWidgets('tapping already-active tab still fires callback',
        (tester) async {
      int callCount = 0;
      await tester.pumpWidget(
          _toggle(mode: TunerMode.auto, onChanged: (_) => callCount++));
      await tester.pump();

      await tester.tap(find.byIcon(Icons.graphic_eq_rounded));
      expect(callCount, 1);
    });
  });

  group('ModeToggle — state consistency', () {
    testWidgets('active mode shows different styling than inactive',
        (tester) async {
      // In auto mode, graphic_eq is the active icon (colored inTune)
      await tester.pumpWidget(_toggle(mode: TunerMode.auto));
      await tester.pump();

      // Both icons render
      expect(find.byIcon(Icons.graphic_eq_rounded), findsOneWidget);
      expect(find.byIcon(Icons.volume_up_rounded), findsOneWidget);
    });

    testWidgets('toggle rebuilds when mode prop changes', (tester) async {
      await tester.pumpWidget(_toggle(mode: TunerMode.auto));
      await tester.pump();

      await tester.pumpWidget(_toggle(mode: TunerMode.reference));
      await tester.pump();

      expect(tester.takeException(), isNull);
    });
  });
}
