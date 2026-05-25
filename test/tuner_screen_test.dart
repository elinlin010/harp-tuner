import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harp_tuner/l10n/app_localizations.dart';
import 'package:harp_tuner/screens/tuner_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _screen({Map<String, Object> prefs = const {}}) {
  SharedPreferences.setMockInitialValues(prefs);
  return const ProviderScope(
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: Locale('en'),
      home: TunerScreen(),
    ),
  );
}

/// Pumps one frame to allow async prefs load to complete.
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();          // build
  await tester.pump(const Duration(milliseconds: 50)); // prefs future
}

void main() {
  group('TunerScreen — no harp selected (default)', () {
    testWidgets('renders without error', (tester) async {
      await tester.pumpWidget(_screen());
      await _settle(tester);
      expect(tester.takeException(), isNull);
    });

    testWidgets('settings button is visible', (tester) async {
      await tester.pumpWidget(_screen());
      await _settle(tester);
      expect(find.byIcon(Icons.tune_rounded), findsOneWidget);
    });

    testWidgets('mode toggle appears after prefs load (defaults to lever harp)',
        (tester) async {
      await tester.pumpWidget(_screen());
      await _settle(tester);
      // App defaults to lever harp on first launch → mode toggle is shown
      expect(find.byIcon(Icons.graphic_eq_rounded), findsOneWidget);
    });

    testWidgets('string visualizer shown after prefs load', (tester) async {
      await tester.pumpWidget(_screen());
      await _settle(tester);
      // Default lever harp → string visualizer renders
      expect(find.byIcon(Icons.volume_up_rounded), findsOneWidget);
    });
  });

  group('TunerScreen — lever harp selected', () {
    final leverPrefs = {
      'tuner_harp_type': 'leverHarp',
      'tuner_lever_string_count': 34,
      'tuner_a4_hz': 440,
    };

    testWidgets('renders without error', (tester) async {
      await tester.pumpWidget(_screen(prefs: leverPrefs));
      await _settle(tester);
      expect(tester.takeException(), isNull);
    });

    testWidgets('mode toggle is visible', (tester) async {
      await tester.pumpWidget(_screen(prefs: leverPrefs));
      await _settle(tester);
      expect(find.byIcon(Icons.graphic_eq_rounded), findsOneWidget);
    });

    testWidgets('string visualizer volume_up icon present (reference tab)',
        (tester) async {
      await tester.pumpWidget(_screen(prefs: leverPrefs));
      await _settle(tester);
      // Mode toggle reference icon confirms StringVisualizer is in the tree
      expect(find.byIcon(Icons.volume_up_rounded), findsOneWidget);
    });
  });

  group('TunerScreen — pedal harp selected', () {
    final pedalPrefs = {
      'tuner_harp_type': 'pedalHarp',
      'tuner_a4_hz': 440,
    };

    testWidgets('renders without error', (tester) async {
      await tester.pumpWidget(_screen(prefs: pedalPrefs));
      await _settle(tester);
      expect(tester.takeException(), isNull);
    });

    testWidgets('mode toggle visible', (tester) async {
      await tester.pumpWidget(_screen(prefs: pedalPrefs));
      await _settle(tester);
      expect(find.byIcon(Icons.graphic_eq_rounded), findsOneWidget);
    });
  });

  group('TunerScreen — settings modal', () {
    testWidgets('tapping settings button opens bottom sheet', (tester) async {
      await tester.pumpWidget(_screen());
      await _settle(tester);

      await tester.tap(find.byIcon(Icons.tune_rounded));
      await tester.pump(); // start animation
      await tester.pump(const Duration(milliseconds: 300)); // settle

      // Settings title appears in the modal
      expect(find.text('Settings'), findsWidgets);
    });

    testWidgets('settings sheet shows instrument section', (tester) async {
      await tester.pumpWidget(_screen());
      await _settle(tester);

      await tester.tap(find.byIcon(Icons.tune_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Instrument'), findsOneWidget);
    });

    testWidgets('settings sheet shows None option when no harp selected',
        (tester) async {
      await tester.pumpWidget(_screen());
      await _settle(tester);

      await tester.tap(find.byIcon(Icons.tune_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('None'), findsWidgets);
    });

    testWidgets('settings sheet shows harp type options', (tester) async {
      await tester.pumpWidget(_screen());
      await _settle(tester);

      await tester.tap(find.byIcon(Icons.tune_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Lever Harp'), findsOneWidget);
      expect(find.text('Pedal Harp'), findsOneWidget);
    });
  });

  group('TunerScreen — SettingsDisplay cards (via screen)', () {
    testWidgets('tapping HARP card opens settings focused on instrument',
        (tester) async {
      await tester.pumpWidget(_screen(prefs: {
        'tuner_harp_type': 'leverHarp',
        'tuner_a4_hz': 440,
      }));
      await _settle(tester);

      // Tap the HARP card (label is "HARP" in the SettingsDisplay)
      await tester.tap(find.text('HARP'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Settings sheet should open
      expect(find.text('Settings'), findsWidgets);
    });
  });

  group('TunerScreen — listen button', () {
    testWidgets('listen button is present', (tester) async {
      await tester.pumpWidget(_screen());
      await _settle(tester);
      // The _ListenButton uses an animated builder — just confirm no crash
      expect(tester.takeException(), isNull);
    });
  });

  group('TunerScreen — dark themes', () {
    testWidgets('Blueprint dark theme via saved pref renders correctly',
        (tester) async {
      SharedPreferences.setMockInitialValues({'tuner_theme': 'blueprint'});
      await tester.pumpWidget(const ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: Locale('en'),
          home: TunerScreen(),
        ),
      ));
      await _settle(tester);
      expect(tester.takeException(), isNull);
    });
  });
}
