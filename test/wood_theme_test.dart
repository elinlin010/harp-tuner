import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:harp_tuner/data/harp_presets.dart';
import 'package:harp_tuner/l10n/app_localizations.dart';
import 'package:harp_tuner/models/harp_type.dart';
import 'package:harp_tuner/providers/tuner_provider.dart';
import 'package:harp_tuner/screens/tuner_screen.dart';
import 'package:harp_tuner/theme/app_theme.dart';
import 'package:harp_tuner/theme/theme_provider.dart';
import 'package:harp_tuner/widgets/mode_toggle.dart';
import 'package:harp_tuner/widgets/string_visualizer.dart';
import 'package:harp_tuner/widgets/tuner_gauge.dart';
import 'package:harp_tuner/widgets/wood_surface.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ignore_for_file: invalid_use_of_visible_for_testing_member

const _woods = [
  TunerThemes.maple,
  TunerThemes.spruce,
  TunerThemes.mahogany,
  TunerThemes.walnut,
];

Future<bool?> _fresh() async => false;
Future<bool?> _updated() async => true;
Future<bool?> _unknown() async => null;

Future<String?> _savedThemeId() async =>
    (await SharedPreferences.getInstance()).getString('theme_id');

Widget _app(Widget home) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  locale: const Locale('en'),
  home: Scaffold(body: home),
);

class _InTuneNotifier extends TunerNotifier {
  @override
  TunerState build() => const TunerState(
    selectedHarp: HarpType.leverHarp,
    isListening: true,
    detectedHz: 415.3,
    closestNoteName: 'A♭4',
    cents: 3.0,
  );
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  // ── First-launch default: new users get Maple, existing users keep Linen ──

  group('resolveStartupTheme', () {
    test('fresh install defaults to Maple and saves it', () async {
      SharedPreferences.setMockInitialValues({});
      expect(await resolveStartupTheme(isUpgrade: _fresh), TunerThemes.maple);
      expect(await _savedThemeId(), 'maple');
    });

    test('updated install with no prefs keeps Linen and saves it', () async {
      SharedPreferences.setMockInitialValues({});
      expect(await resolveStartupTheme(isUpgrade: _updated), TunerThemes.linen);
      expect(await _savedThemeId(), 'linen');
    });

    test('unknown install state keeps Linen', () async {
      SharedPreferences.setMockInitialValues({});
      expect(await resolveStartupTheme(isUpgrade: _unknown), TunerThemes.linen);
    });

    test(
      'a prior release\'s pref keeps Linen even if the probe says fresh',
      () async {
        for (final key in [
          'app_locale',
          'tuner_a4_hz',
          'tuner_harp_type',
          'tuner_show_tuning_reminder',
        ]) {
          SharedPreferences.setMockInitialValues({
            key: key == 'tuner_a4_hz' ? 442 : 'x',
          });
          expect(
            await resolveStartupTheme(isUpgrade: _fresh),
            TunerThemes.linen,
            reason: key,
          );
        }
      },
    );

    test('a saved theme always wins', () async {
      SharedPreferences.setMockInitialValues({'theme_id': 'void'});
      expect(await resolveStartupTheme(isUpgrade: _fresh), TunerThemes.void_);
      SharedPreferences.setMockInitialValues({'theme_id': 'walnut'});
      expect(
        await resolveStartupTheme(isUpgrade: _updated),
        TunerThemes.walnut,
      );
    });

    test('an unknown saved theme falls back to Linen', () async {
      SharedPreferences.setMockInitialValues({'theme_id': 'phosphor'});
      expect(await resolveStartupTheme(isUpgrade: _fresh), TunerThemes.linen);
      expect(await _savedThemeId(), 'linen');
    });

    test('a new user stays on Maple after their next app update', () async {
      SharedPreferences.setMockInitialValues({});
      await resolveStartupTheme(isUpgrade: _fresh);
      // Next release: the platform now reports an update.
      expect(await resolveStartupTheme(isUpgrade: _updated), TunerThemes.maple);
    });

    test('an existing user stays on Linen', () async {
      SharedPreferences.setMockInitialValues({});
      await resolveStartupTheme(isUpgrade: _updated);
      expect(await resolveStartupTheme(isUpgrade: _fresh), TunerThemes.linen);
    });
  });

  group('ThemeNotifier startup', () {
    test('uses the theme resolved in main()', () {
      SharedPreferences.setMockInitialValues({});
      final c = ProviderContainer(
        overrides: [startupThemeProvider.overrideWithValue(TunerThemes.maple)],
      );
      addTearDown(c.dispose);
      expect(c.read(tunerThemeProvider), TunerThemes.maple);
    });

    test('loads a saved wood theme without a startup override', () async {
      SharedPreferences.setMockInitialValues({'theme_id': 'mahogany'});
      final c = ProviderContainer();
      addTearDown(c.dispose);
      c.read(tunerThemeProvider);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(c.read(tunerThemeProvider), TunerThemes.mahogany);
    });
  });

  group('toggleDarkMode pairs', () {
    const pairs = {
      TunerThemes.maple: TunerThemes.mahogany,
      TunerThemes.spruce: TunerThemes.walnut,
      TunerThemes.linen: TunerThemes.blueprint,
      TunerThemes.milk: TunerThemes.void_,
    };
    for (final MapEntry(key: light, value: dark) in pairs.entries) {
      test('${light.id} ↔ ${dark.id}', () async {
        SharedPreferences.setMockInitialValues({'theme_id': light.id});
        final c = ProviderContainer(
          overrides: [startupThemeProvider.overrideWithValue(light)],
        );
        addTearDown(c.dispose);
        final n = c.read(tunerThemeProvider.notifier);
        await n.toggleDarkMode();
        expect(c.read(tunerThemeProvider), dark);
        await n.toggleDarkMode();
        expect(c.read(tunerThemeProvider), light);
      });
    }
  });

  group('TunerThemes', () {
    test('picker lists woods first, four per brightness', () {
      final light = TunerThemes.all
          .where((t) => t.brightness == Brightness.light)
          .map((t) => t.id);
      final dark = TunerThemes.all
          .where((t) => t.brightness == Brightness.dark)
          .map((t) => t.id);
      expect(light, ['maple', 'spruce', 'linen', 'milk']);
      expect(dark, ['mahogany', 'walnut', 'blueprint', 'void']);
    });

    test('only the wood themes carry a wood finish', () {
      for (final t in TunerThemes.all) {
        expect(t.isWood, _woods.contains(t), reason: t.id);
      }
    });

    test('flat themes get a plain neck rail with silver pins', () {
      for (final t in [
        TunerThemes.linen,
        TunerThemes.milk,
        TunerThemes.blueprint,
        TunerThemes.void_,
      ]) {
        final neck = t.neck;
        expect(neck.grain, isFalse, reason: t.id);
        expect(neck.colors, [t.surfaceHi, t.surfaceRim], reason: t.id);
        expect(neck.pin, HarpNeck.silverGradient, reason: t.id);
      }
      for (final t in _woods) {
        expect(t.neck.grain, isTrue, reason: t.id);
        expect(t.neck.pin, WoodMaterials.goldGradient, reason: t.id);
      }
    });

    test('flat themes get a rim-coloured gauge frame and card borders', () {
      for (final t in [TunerThemes.linen, TunerThemes.blueprint]) {
        expect(t.gaugeBorder, t.surfaceRim, reason: t.id);
        expect(
          t.gaugeInnerLine,
          t.surfaceRim.withValues(alpha: 0.6),
          reason: t.id,
        );
        expect(t.gaugeShadow, isNotEmpty, reason: t.id);
        expect(t.chipBorder.color, t.surfaceRim, reason: t.id);
      }
      // Dark flat cards have no drop shadow; light ones do.
      expect(TunerThemes.linen.cardShadow, isNotEmpty);
      expect(TunerThemes.void_.cardShadow, isEmpty);
      // Wood themes keep their gold values.
      expect(
        TunerThemes.maple.gaugeBorder,
        TunerThemes.maple.wood!.gaugeBorder,
      );
    });

    test('theme ids are unique', () {
      final ids = TunerThemes.all.map((t) => t.id).toList();
      expect(ids.toSet().length, ids.length);
    });
  });

  // ── Wood rendering ─────────────────────────────────────────────────────────

  for (final theme in _woods) {
    group('${theme.displayName} renders', () {
      testWidgets('gauge in tune, sharp and idle', (tester) async {
        for (final cents in [2.0, 30.0, null]) {
          await tester.pumpWidget(
            _app(
              SizedBox(
                width: 400,
                height: 500,
                child: TunerGauge(
                  cents: cents,
                  noteName: 'A♭4',
                  isListening: true,
                  theme: theme,
                ),
              ),
            ),
          );
          await tester.pump(const Duration(milliseconds: 400));
          expect(tester.takeException(), isNull);
        }
        expect(find.byType(WoodSurface), findsWidgets);
      });

      testWidgets('string visualizer with neck and pins', (tester) async {
        final strings = HarpPresets.leverHarpWithCount(34);
        await tester.pumpWidget(
          _app(
            SizedBox(
              width: 400,
              height: 200,
              child: StringVisualizer(
                strings: strings,
                activeString: strings[10],
                onTap: (_) {},
                theme: theme,
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 300));
        expect(tester.takeException(), isNull);
        expect(find.byType(WoodSurface), findsOneWidget); // the neck rail
      });

      testWidgets('mode toggle', (tester) async {
        await tester.pumpWidget(
          _app(
            ModeToggle(
              mode: TunerMode.reference,
              onChanged: (_) {},
              theme: theme,
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 300));
        expect(tester.takeException(), isNull);
      });
    });
  }

  group('TunerScreen on a wood theme', () {
    Widget screen(TunerThemeData theme) {
      SharedPreferences.setMockInitialValues({'theme_id': theme.id});
      return ProviderScope(
        overrides: [
          startupThemeProvider.overrideWithValue(theme),
          tunerProvider.overrideWith(_InTuneNotifier.new),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: Locale('en'),
          home: TunerScreen(),
        ),
      );
    }

    for (final theme in [TunerThemes.maple, TunerThemes.walnut]) {
      testWidgets('${theme.id}: in-tune screen and settings sheet', (
        tester,
      ) async {
        await tester.pumpWidget(screen(theme));
        await tester.pump(const Duration(milliseconds: 400));
        expect(tester.takeException(), isNull);
        expect(find.byType(ThemedPageBackground), findsOneWidget);

        await tester.tap(find.byIcon(Icons.tune_rounded));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(tester.takeException(), isNull);

        // Picker shows the four themes of the current brightness, woods first.
        final names = theme.brightness == Brightness.light
            ? ['Maple', 'Spruce', 'Linen', 'Milk']
            : ['Mahogany', 'Walnut', 'Blueprint', 'Void'];
        for (final n in names) {
          expect(find.text(n), findsOneWidget, reason: n);
        }
      });
    }

    testWidgets('dark-mode switch jumps Maple → Mahogany', (tester) async {
      await tester.pumpWidget(screen(TunerThemes.maple));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.byIcon(Icons.tune_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      await tester.ensureVisible(find.text('Dark mode'));
      await tester.pump();
      await tester.tap(find.text('Dark mode'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Mahogany'), findsOneWidget);
      expect(find.text('Maple'), findsNothing);
      expect(await _savedThemeId(), 'mahogany');
    });

    testWidgets('tapping a wood swatch selects it', (tester) async {
      await tester.pumpWidget(screen(TunerThemes.maple));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.byIcon(Icons.tune_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      await tester.ensureVisible(find.text('Spruce'));
      await tester.pump();
      await tester.tap(find.text('Spruce'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(await _savedThemeId(), 'spruce');
      expect(tester.takeException(), isNull);
    });
  });
}
