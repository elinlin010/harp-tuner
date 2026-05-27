import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harp_tuner/l10n/app_localizations.dart';
import 'package:harp_tuner/theme/app_theme.dart';
import 'package:harp_tuner/widgets/tuner_gauge.dart';

// ignore_for_file: prefer_function_declarations_over_variables

Widget _gauge({
  double? cents,
  String? noteName,
  bool isListening = true,
  TunerThemeData theme = TunerThemes.linen,
}) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('en'),
    home: Scaffold(
      body: SizedBox(
        width: 400,
        height: 500,
        child: TunerGauge(
          cents: cents,
          noteName: noteName,
          isListening: isListening,
          theme: theme,
        ),
      ),
    ),
  );
}

/// Finds a [Semantics] widget whose [SemanticsProperties.label] matches [label].
Finder _bySemLabel(String label) => find.byWidgetPredicate(
      (w) => w is Semantics && w.properties.label == label,
    );

/// Returns the [SemanticsProperties.value] of the single [Semantics] widget
/// whose label matches [label].
String _semValue(WidgetTester tester, String label) {
  final widget = tester.widget<Semantics>(_bySemLabel(label));
  return widget.properties.value ?? '';
}

void main() {
  group('TunerGauge — in-tune / flat / sharp state derivation', () {
    testWidgets('cents=0 → in-tune: both bulbs inactive', (tester) async {
      await tester.pumpWidget(_gauge(cents: 0, noteName: 'C4'));
      await tester.pump();

      expect(_semValue(tester, 'Flat'), 'inactive');
      expect(_semValue(tester, 'Sharp'), 'inactive');
    });

    testWidgets('cents=-20 → flat: flat bulb active, sharp inactive',
        (tester) async {
      await tester.pumpWidget(_gauge(cents: -20, noteName: 'C4'));
      await tester.pump();

      expect(_semValue(tester, 'Flat'), 'active');
      expect(_semValue(tester, 'Sharp'), 'inactive');
    });

    testWidgets('cents=20 → sharp: sharp bulb active, flat inactive',
        (tester) async {
      await tester.pumpWidget(_gauge(cents: 20, noteName: 'C4'));
      await tester.pump();

      expect(_semValue(tester, 'Flat'), 'inactive');
      expect(_semValue(tester, 'Sharp'), 'active');
    });

    testWidgets('cents=-15 → in-tune boundary: both bulbs inactive',
        (tester) async {
      // cRound = -15, cRound.abs() == 15 → isInTune=true
      await tester.pumpWidget(_gauge(cents: -15.0, noteName: 'A4'));
      await tester.pump();

      expect(_semValue(tester, 'Flat'), 'inactive',
          reason: '-15¢ should be in-tune, not flat');
    });

    testWidgets('cents=-16 → flat: just outside in-tune zone', (tester) async {
      await tester.pumpWidget(_gauge(cents: -16.0, noteName: 'A4'));
      await tester.pump();

      expect(_semValue(tester, 'Flat'), 'active',
          reason: '-16¢ should be flat');
    });

    testWidgets('cents=15 → in-tune boundary: both bulbs inactive',
        (tester) async {
      await tester.pumpWidget(_gauge(cents: 15.0, noteName: 'G3'));
      await tester.pump();

      expect(_semValue(tester, 'Sharp'), 'inactive',
          reason: '+15¢ should be in-tune, not sharp');
    });

    testWidgets('cents=16 → sharp: just outside in-tune zone', (tester) async {
      await tester.pumpWidget(_gauge(cents: 16.0, noteName: 'G3'));
      await tester.pump();

      expect(_semValue(tester, 'Sharp'), 'active',
          reason: '+16¢ should be sharp');
    });
  });

  group('TunerGauge — no-signal / idle state', () {
    testWidgets('cents=null → idle readout shown without error',
        (tester) async {
      await tester.pumpWidget(_gauge(cents: null, noteName: null));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('isListening=false → idle readout renders', (tester) async {
      await tester.pumpWidget(
          _gauge(cents: null, noteName: null, isListening: false));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });

  group('TunerGauge — dark theme', () {
    testWidgets('Blueprint (dark) theme renders without error', (tester) async {
      await tester.pumpWidget(_gauge(
        cents: 5,
        noteName: 'F♯3',
        theme: TunerThemes.blueprint,
      ));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('Void (dark) theme renders without error', (tester) async {
      await tester.pumpWidget(_gauge(
        cents: -30,
        noteName: 'B♭2',
        theme: TunerThemes.void_,
      ));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });

  group('TunerGauge — note name display', () {
    testWidgets('note letter is visible in signal readout', (tester) async {
      await tester.pumpWidget(_gauge(cents: 0, noteName: 'G♯4'));
      await tester.pump();

      expect(find.text('G'), findsOneWidget);
    });

    testWidgets('note name with accidental renders accidental separately',
        (tester) async {
      await tester.pumpWidget(_gauge(cents: 5, noteName: 'B♭3'));
      await tester.pump();

      expect(find.text('B'), findsOneWidget);
      expect(find.text('♭'), findsWidgets); // symbol + bulb both have ♭
    });

    testWidgets('em-dash fallback renders without error', (tester) async {
      // Covers the case where noteName is '—' (pitch not yet resolved)
      await tester.pumpWidget(_gauge(cents: 0, noteName: '—'));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });

  // ── TunerGauge — disabled animations path ─────────────────────────────────────

  Widget _gaugeNoAnim({double? cents, String? noteName, bool isListening = true}) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      home: Scaffold(
        body: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: SizedBox(
              width: 400,
              height: 500,
              child: TunerGauge(
                cents: cents,
                noteName: noteName,
                isListening: isListening,
                theme: TunerThemes.linen,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── TunerGauge — didChangeDependencies re-enables animation ─────────────────
  // Covers line 92: _pulseCtrl.repeat() in the else-if branch.
  // Reached when: disableAnimations was true (pulseCtrl stopped), then becomes false.

  group('TunerGauge — didChangeDependencies re-enable animation', () {
    testWidgets(
        'switching from disableAnimations=true to false restarts pulse animation',
        (tester) async {
      // The key: keep TunerGauge at the SAME position in the widget tree.
      // pumpWidget twice with only MediaQuery.disableAnimations changing —
      // the State is reused, so didChangeDependencies fires on the live controller.
      Future<void> build(bool disable) async {
        await tester.pumpWidget(MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: Scaffold(
            body: MediaQuery(
              data: const MediaQueryData().copyWith(disableAnimations: disable),
              child: const SizedBox(
                width: 400,
                height: 500,
                child: TunerGauge(
                  cents: 0,
                  noteName: 'C4',
                  isListening: true,
                  theme: TunerThemes.linen,
                ),
              ),
            ),
          ),
        ));
      }

      // Build with animations disabled — pulse controller stopped (line 85).
      await build(true);
      await tester.pump();

      // Rebuild with animations enabled — _pulseCtrl.isAnimating==false
      // → didChangeDependencies fires the else-if branch → _pulseCtrl.repeat() (line 92).
      await build(false);
      await tester.pump();

      expect(tester.takeException(), isNull);
    });
  });

  group('TunerGauge — disableAnimations path', () {
    testWidgets('renders with disableAnimations=true without error',
        (tester) async {
      await tester.pumpWidget(_gaugeNoAnim(cents: null, noteName: null));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('with cents set, needle snaps immediately to value',
        (tester) async {
      await tester.pumpWidget(_gaugeNoAnim(cents: -25, noteName: 'D♭4'));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('sharp cents with disableAnimations renders sharp color path',
        (tester) async {
      await tester.pumpWidget(_gaugeNoAnim(cents: 25, noteName: 'G♯3'));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('updating cents triggers didUpdateWidget disabled path',
        (tester) async {
      await tester.pumpWidget(_gaugeNoAnim(cents: -20, noteName: 'A♭4'));
      await tester.pump();

      await tester.pumpWidget(_gaugeNoAnim(cents: 20, noteName: 'G♯4'));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('updating cents to null triggers disabled null path',
        (tester) async {
      await tester.pumpWidget(_gaugeNoAnim(cents: 15, noteName: 'E4'));
      await tester.pump();

      await tester.pumpWidget(_gaugeNoAnim(cents: null, noteName: null));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });

  // ── TunerGauge — animation update paths ──────────────────────────────────────

  group('TunerGauge — animation update paths', () {
    testWidgets('updating cents from null triggers spring animation',
        (tester) async {
      await tester.pumpWidget(_gauge(cents: null, noteName: null));
      await tester.pump();

      // Update cents — triggers didUpdateWidget → animateWith → addListener
      await tester.pumpWidget(_gauge(cents: 30, noteName: 'F♯4'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull);
    });

    testWidgets('updating cents from value to null springs needle back',
        (tester) async {
      await tester.pumpWidget(_gauge(cents: 20, noteName: 'A♯4'));
      await tester.pump();

      await tester.pumpWidget(_gauge(cents: null, noteName: null));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull);
    });

    testWidgets('updating from one cents value to another re-animates',
        (tester) async {
      await tester.pumpWidget(_gauge(cents: 10, noteName: 'C4'));
      await tester.pump();

      await tester.pumpWidget(_gauge(cents: -30, noteName: 'B3'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull);
    });

    testWidgets('three-step update hits EMA smoothing branch (line 114)',
        (tester) async {
      // null → 10 sets _smoothedTarget; 10 → -30 with non-null target hits EMA
      await tester.pumpWidget(_gauge(cents: null, noteName: null));
      await tester.pump();

      await tester.pumpWidget(_gauge(cents: 10, noteName: 'C4'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      await tester.pumpWidget(_gauge(cents: -30, noteName: 'B3'));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('stale flag with cents renders correctly', (tester) async {
      await tester.pumpWidget(MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: Scaffold(
          body: SizedBox(
            width: 400,
            height: 500,
            child: TunerGauge(
              cents: 5,
              noteName: 'C4',
              isListening: true,
              isStale: true,
              theme: TunerThemes.linen,
            ),
          ),
        ),
      ));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });
}
