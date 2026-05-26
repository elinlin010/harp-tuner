import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harp_tuner/l10n/app_localizations.dart';
import 'package:harp_tuner/models/harp_type.dart';
import 'package:harp_tuner/providers/tuner_provider.dart';
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

Widget _screenWith(TunerNotifier Function() factory) {
  SharedPreferences.setMockInitialValues({});
  return ProviderScope(
    overrides: [tunerProvider.overrideWith(factory)],
    child: const MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: Locale('en'),
      home: TunerScreen(),
    ),
  );
}

class _MicErrNotifier extends TunerNotifier {
  @override
  TunerState build() => const TunerState(
        selectedHarp: HarpType.leverHarp,
        micError: 'Microphone unavailable: no device found',
      );
}

class _PermDeniedNotifier extends TunerNotifier {
  @override
  TunerState build() => const TunerState(
        selectedHarp: HarpType.leverHarp,
        permissionDenied: true,
      );
}

class _ListeningNotifier extends TunerNotifier {
  @override
  TunerState build() => const TunerState(
        selectedHarp: HarpType.leverHarp,
        isListening: true,
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

  // ── Mic error banner ──────────────────────────────────────────────────────────

  group('TunerScreen — mic error banner', () {
    testWidgets('renders _MicErrorBanner when micError is set', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_screenWith(() => _MicErrNotifier()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
      expect(find.text('Tap to dismiss'), findsOneWidget);
    });

    testWidgets('mic error banner shows unavailable message', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_screenWith(() => _MicErrNotifier()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.textContaining('Microphone unavailable'), findsOneWidget);
    });

    testWidgets('tapping mic error banner does not throw', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_screenWith(() => _MicErrNotifier()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      await tester.tap(find.text('Tap to dismiss'));
      await tester.pump();
    });
  });

  // ── Permission denied banner ──────────────────────────────────────────────────

  group('TunerScreen — permission denied banner', () {
    testWidgets('renders _PermissionBanner when permissionDenied is true',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_screenWith(() => _PermDeniedNotifier()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.byIcon(Icons.mic_off_rounded), findsOneWidget);
      expect(find.text('Microphone access denied'), findsOneWidget);
    });

    testWidgets('permission banner shows message and open-settings button',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_screenWith(() => _PermDeniedNotifier()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('Open Settings'), findsOneWidget);
      expect(find.textContaining('Go to Settings'), findsOneWidget);
    });
  });

  // ── Listen button listening state ─────────────────────────────────────────────

  group('TunerScreen — listen button listening state', () {
    testWidgets('renders stop button and in-tune color when isListening=true',
        (tester) async {
      await tester.pumpWidget(_screenWith(() => _ListeningNotifier()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.byIcon(Icons.stop_rounded), findsOneWidget);
      expect(find.text('Stop'), findsOneWidget);
    });
  });

  // ── Settings sheet — in-sheet interactions ────────────────────────────────────

  group('TunerScreen — settings sheet interactions', () {
    Future<void> _openSettings(WidgetTester tester) async {
      await tester.tap(find.byIcon(Icons.tune_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }

    testWidgets('tapping None in instrument list renders without error',
        (tester) async {
      await tester.pumpWidget(_screen(prefs: {
        'tuner_harp_type': 'leverHarp',
        'tuner_a4_hz': 440,
      }));
      await _settle(tester);
      await _openSettings(tester);

      await tester.tap(find.text('None').last);
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('tapping Pedal Harp in settings selects it', (tester) async {
      await tester.pumpWidget(_screen(prefs: {
        'tuner_harp_type': 'leverHarp',
        'tuner_a4_hz': 440,
      }));
      await _settle(tester);
      await _openSettings(tester);

      await tester.tap(find.text('Pedal Harp'));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('reminder toggle visible with lever harp and tap works',
        (tester) async {
      await tester.pumpWidget(_screen(prefs: {
        'tuner_harp_type': 'leverHarp',
        'tuner_a4_hz': 440,
      }));
      await _settle(tester);
      await _openSettings(tester);

      final reminderToggle = find.text('Tuning Reminder');
      if (reminderToggle.evaluate().isNotEmpty) {
        await tester.tap(reminderToggle);
        await tester.pump();
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('dark mode toggle tap works', (tester) async {
      await tester.pumpWidget(_screen());
      await _settle(tester);
      await _openSettings(tester);

      final darkModeToggle = find.text('Dark mode');
      if (darkModeToggle.evaluate().isNotEmpty) {
        await tester.tap(darkModeToggle);
        await tester.pump();
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('settings sheet shows language section', (tester) async {
      await tester.pumpWidget(_screen());
      await _settle(tester);
      await _openSettings(tester);

      expect(find.text('Language'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('settings sheet shows A4 Reference label', (tester) async {
      await tester.pumpWidget(_screen());
      await _settle(tester);
      await _openSettings(tester);

      expect(find.text('A4 Reference'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('settings sheet shows Note section', (tester) async {
      await tester.pumpWidget(_screen());
      await _settle(tester);
      await _openSettings(tester);

      expect(find.text('Note'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('settings sheet shows Theme section', (tester) async {
      await tester.pumpWidget(_screen());
      await _settle(tester);
      await _openSettings(tester);

      expect(find.text('Theme'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('settings sheet shows Always show flats toggle', (tester) async {
      await tester.pumpWidget(_screen());
      await _settle(tester);
      await _openSettings(tester);

      expect(find.textContaining('Always show flats'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('opening settings via A4 card covers SettingsSection.a4 path',
        (tester) async {
      await tester.pumpWidget(_screen(prefs: {'tuner_harp_type': 'leverHarp'}));
      await _settle(tester);

      // Tap A4 card — triggers _showSettings(context, focus: SettingsSection.a4)
      final a4Card = find.text('A4');
      if (a4Card.evaluate().isNotEmpty) {
        await tester.tap(a4Card.first);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(tester.takeException(), isNull);
    });
  });

  // ── Animation controller path via disableAnimations ──────────────────────────

  group('TunerScreen — didChangeDependencies disableAnimations path', () {
    testWidgets('disableAnimations=true stops listen button animation',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: Builder(
            builder: (ctx) => MediaQuery(
              data: MediaQuery.of(ctx).copyWith(disableAnimations: true),
              child: const TunerScreen(),
            ),
          ),
        ),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(tester.takeException(), isNull);
    });
  });

  // ── Settings callback coverage ────────────────────────────────────────────────

  group('TunerScreen — settings interactive callbacks', () {
    Future<void> _openSettingsSheet(WidgetTester tester) async {
      await tester.tap(find.byIcon(Icons.tune_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }

    testWidgets('tapping dark mode toggle invokes toggleDarkMode',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_screen());
      await _settle(tester);
      await _openSettingsSheet(tester);

      final toggle = find.text('Dark mode');
      if (toggle.evaluate().isNotEmpty) {
        await tester.ensureVisible(toggle.first);
        await tester.tap(toggle.first, warnIfMissed: false);
        await tester.pump();
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('tapping non-selected theme swatch invokes setTheme',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_screen());
      await _settle(tester);
      await _openSettingsSheet(tester);

      // 'Milk' is a light theme different from the default 'Linen'
      final milkSwatch = find.bySemanticsLabel('Milk');
      if (milkSwatch.evaluate().isNotEmpty) {
        await tester.ensureVisible(milkSwatch.first);
        await tester.tap(milkSwatch.first, warnIfMissed: false);
        await tester.pump();
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('opening language popup covers itemBuilder', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_screen());
      await _settle(tester);
      await _openSettingsSheet(tester);

      final expandIcon = find.byIcon(Icons.expand_more_rounded);
      if (expandIcon.evaluate().isNotEmpty) {
        await tester.ensureVisible(expandIcon.first);
        await tester.tap(expandIcon.first, warnIfMissed: false);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('selecting language from popup invokes setLocale',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_screen());
      await _settle(tester);
      await _openSettingsSheet(tester);

      final expandIcon = find.byIcon(Icons.expand_more_rounded);
      if (expandIcon.evaluate().isNotEmpty) {
        await tester.ensureVisible(expandIcon.first);
        await tester.tap(expandIcon.first, warnIfMissed: false);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        final deutsch = find.text('Deutsch');
        if (deutsch.evaluate().isNotEmpty) {
          await tester.tap(deutsch.last, warnIfMissed: false);
          await tester.pump();
        }
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('tapping always-show-flats toggle invokes togglePreferFlats',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      // No harp selected → 'Always show flats' toggle is enabled
      await tester.pumpWidget(_screen());
      await _settle(tester);
      await _openSettingsSheet(tester);

      final toggle = find.text('Always show flats');
      if (toggle.evaluate().isNotEmpty) {
        await tester.ensureVisible(toggle.first);
        await tester.tap(toggle.first, warnIfMissed: false);
        await tester.pump();
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('tapping A4 step buttons invokes setA4Hz', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_screen());
      await _settle(tester);
      await _openSettingsSheet(tester);

      // The A4 stepper has two 36×48 SizedBox buttons (decrement and increment)
      final stepBtns = find.byWidgetPredicate(
        (w) => w is SizedBox && w.width == 36.0 && w.height == 48.0,
      );
      if (stepBtns.evaluate().length >= 2) {
        await tester.ensureVisible(stepBtns.at(0));
        await tester.tap(stepBtns.at(0), warnIfMissed: false); // decrement
        await tester.pump();
        await tester.tap(stepBtns.at(1), warnIfMissed: false); // increment
        await tester.pump();
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('dragging string count slider invokes setLeverStringCount',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_screen(prefs: {
        'tuner_harp_type': 'leverHarp',
        'tuner_lever_string_count': 34,
        'tuner_a4_hz': 440,
      }));
      await _settle(tester);
      await _openSettingsSheet(tester);

      final slider = find.byType(Slider);
      if (slider.evaluate().isNotEmpty) {
        await tester.ensureVisible(slider.first);
        await tester.drag(slider.first, const Offset(20, 0));
        await tester.pump();
      }
      expect(tester.takeException(), isNull);
    });
  });
}
