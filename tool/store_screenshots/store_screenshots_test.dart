// Renders App Store / Google Play screenshots of the real TunerScreen.
//
// Not part of the regular suite (it needs real fonts on disk). Run through
// tool/store_screenshots/generate.sh, which downloads the fonts and passes:
//   --dart-define=FONT_DIR=...     Outfit + Noto Sans TC/SC TTFs
//   --dart-define=ICON_FONT=...    Flutter's MaterialIcons-Regular.otf
//   --dart-define=OUT_DIR=...      where raw PNGs are written
//   --dart-define=LOCALE=en        one of the app's locales (en, de, fr, it, zh, zh_TW)
//   --dart-define=DEVICES=...      optional comma list of device ids (default: all)

// ignore_for_file: invalid_use_of_visible_for_testing_member

import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:harp_tuner/data/harp_presets.dart';
import 'package:harp_tuner/l10n/app_localizations.dart';
import 'package:harp_tuner/models/harp_string_model.dart';
import 'package:harp_tuner/models/harp_type.dart';
import 'package:harp_tuner/providers/locale_provider.dart';
import 'package:harp_tuner/providers/tuner_provider.dart';
import 'package:harp_tuner/screens/tuner_screen.dart';
import 'package:harp_tuner/services/feedback_service.dart';
import 'package:harp_tuner/theme/app_theme.dart';
import 'package:harp_tuner/theme/theme_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _fontDir = String.fromEnvironment('FONT_DIR');
const _iconFont = String.fromEnvironment('ICON_FONT');
const _outDir = String.fromEnvironment('OUT_DIR');
const _localeArg = String.fromEnvironment('LOCALE', defaultValue: 'en');
const _devicesArg = String.fromEnvironment('DEVICES');

// ── Devices ───────────────────────────────────────────────────────────────────

enum _Os { ios, android }

class _Device {
  final String id;
  final _Os os;
  final Size physical;
  final double dpr;
  final double topInset;
  final double bottomInset;

  const _Device(
    this.id,
    this.os,
    this.physical,
    this.dpr,
    this.topInset,
    this.bottomInset,
  );

  Size get logical => physical / dpr;
}

const _devices = [
  // App Store Connect: 6.9" iPhone (required), 6.5" iPhone, 13" iPad.
  _Device('ios_iphone_6.9', _Os.ios, Size(1320, 2868), 3, 62, 34),
  _Device('ios_iphone_6.5', _Os.ios, Size(1284, 2778), 3, 47, 34),
  _Device('ios_ipad_13', _Os.ios, Size(2064, 2752), 2, 24, 20),
  // Google Play phone: 9:16, 1080×1920.
  _Device('android_phone', _Os.android, Size(1080, 1920), 2.625, 24, 20),
];

// ── Scenes ────────────────────────────────────────────────────────────────────

class _Scene {
  final String id;
  final TunerThemeData theme;
  final TunerState state;
  final bool openSettings;

  const _Scene(this.id, this.theme, this.state, {this.openSettings = false});
}

List<HarpStringModel> _lever34() => HarpPresets.leverHarpWithCount(34);

// Nearest string to [hz] — labels use harp register numbering, so select by
// pitch instead.
HarpStringModel _string(List<HarpStringModel> s, double hz) => s.reduce(
  (a, b) => (a.frequency - hz).abs() <= (b.frequency - hz).abs() ? a : b,
);

TunerState _detected(
  HarpStringModel s,
  double cents, {
  HarpType? harp,
  bool reminder = false,
}) => TunerState(
  selectedHarp: harp ?? HarpType.leverHarp,
  preferFlats: true,
  isListening: true,
  showTuningReminder: reminder,
  detectedHz: s.frequency * pow(2, cents / 1200),
  closestNoteName: s.label,
  cents: cents,
);

List<_Scene> _scenes() {
  final lever = _lever34();
  final pedal = HarpPresets.pedalHarp;
  final ab4 = _string(lever, 415.30);
  final e5 = _string(lever, 622.25);
  final c5 = _string(lever, 523.25);
  final eb4 = _string(pedal, 311.13);
  return [
    _Scene('01_maple_in_tune', TunerThemes.maple, _detected(ab4, 2)),
    _Scene('02_mahogany_flat', TunerThemes.mahogany, _detected(e5, -24)),
    _Scene(
      '03_spruce_reference',
      TunerThemes.spruce,
      TunerState(
        selectedHarp: HarpType.leverHarp,
        preferFlats: true,
        isListening: true,
        showTuningReminder: false,
        tunerMode: TunerMode.reference,
        referenceString: c5,
        detectedHz: c5.frequency * pow(2, 19 / 1200),
        closestNoteName: c5.label,
        cents: 19,
      ),
    ),
    _Scene(
      '04_maple_themes',
      TunerThemes.maple,
      _detected(ab4, 2, reminder: true),
      openSettings: true,
    ),
    _Scene(
      '05_walnut_pedal_in_tune',
      TunerThemes.walnut,
      _detected(eb4, -3, harp: HarpType.pedalHarp),
    ),
  ];
}

// Starts idle, then switches to the scene state so the string visualizer
// scrolls its active string into view (it only scrolls on change).
class _SceneNotifier extends TunerNotifier {
  _SceneNotifier(this.target);
  final TunerState target;

  @override
  TunerState build() {
    Future.microtask(() => setStateForTest(target));
    // Same listening/reminder flags as the target, so the switch doesn't
    // trigger the tuning-reminder snackbar.
    return TunerState(
      selectedHarp: target.selectedHarp,
      tunerMode: target.tunerMode,
      preferFlats: true,
      isListening: target.isListening,
      showTuningReminder: target.showTuningReminder,
    );
  }
}

class _FixedLocale extends LocaleNotifier {
  _FixedLocale(this.locale);
  final Locale locale;

  @override
  Locale build() => locale;
}

// ── Status bars ───────────────────────────────────────────────────────────────

class _StatusBar extends StatelessWidget {
  final _Os os;
  final double height;
  final TunerThemeData theme;

  const _StatusBar(this.os, this.height, this.theme);

  @override
  Widget build(BuildContext context) {
    final c = theme.textPrimary;
    final time = Text(
      '9:41',
      style: theme.sans(
        os == _Os.ios ? 17 : 14,
        weight: os == _Os.ios ? FontWeight.w600 : FontWeight.w500,
        color: c,
      ),
    );
    if (os == _Os.android) {
      return SizedBox(
        height: height,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              time,
              const Spacer(),
              Icon(Icons.wifi_rounded, size: 16, color: c),
              const SizedBox(width: 4),
              Icon(Icons.signal_cellular_4_bar_rounded, size: 15, color: c),
              const SizedBox(width: 4),
              Icon(Icons.battery_full_rounded, size: 16, color: c),
            ],
          ),
        ),
      );
    }
    return SizedBox(
      height: height,
      child: Padding(
        padding: EdgeInsets.only(
          left: height > 40 ? 52 : 24,
          right: height > 40 ? 36 : 20,
        ),
        child: Row(
          children: [
            time,
            const Spacer(),
            Icon(Icons.signal_cellular_alt_rounded, size: 18, color: c),
            const SizedBox(width: 5),
            Icon(Icons.wifi_rounded, size: 18, color: c),
            const SizedBox(width: 6),
            _IosBattery(c),
          ],
        ),
      ),
    );
  }
}

class _IosBattery extends StatelessWidget {
  final Color color;
  const _IosBattery(this.color);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 25,
          height: 12,
          padding: const EdgeInsets.all(1.5),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(3.5),
            border: Border.all(color: color.withValues(alpha: 0.4), width: 1),
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        const SizedBox(width: 1),
        Container(
          width: 1.5,
          height: 4,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(1),
          ),
        ),
      ],
    );
  }
}

class _HomeIndicator extends StatelessWidget {
  final _Device device;
  final TunerThemeData theme;
  const _HomeIndicator(this.device, this.theme);

  @override
  Widget build(BuildContext context) {
    final ios = device.os == _Os.ios;
    return SizedBox(
      height: device.bottomInset,
      child: Align(
        alignment: ios ? const Alignment(0, 0.55) : Alignment.center,
        child: Container(
          width: ios ? 140 : 108,
          height: ios ? 5 : 4,
          decoration: BoxDecoration(
            color: theme.textPrimary.withValues(alpha: ios ? 0.9 : 0.6),
            borderRadius: BorderRadius.circular(3),
          ),
        ),
      ),
    );
  }
}

// ── Harness ───────────────────────────────────────────────────────────────────

Locale _parseLocale(String s) {
  final parts = s.split('_');
  return parts.length == 1 ? Locale(parts[0]) : Locale(parts[0], parts[1]);
}

// Serves the downloaded Outfit files as bundled assets, so google_fonts loads
// them exactly as it would its own pre-bundled fonts (it throws in tests
// otherwise, since runtime fetching is off).
void _serveOutfitAsAssets() {
  const names = {
    300: 'Light',
    400: 'Regular',
    500: 'Medium',
    600: 'SemiBold',
    700: 'Bold',
  };
  final files = {
    for (final MapEntry(key: w, value: name) in names.entries)
      'google_fonts/Outfit-$name.ttf': '$_fontDir/Outfit-$w.ttf',
  };
  final manifest = const StandardMessageCodec().encodeMessage({
    for (final key in files.keys)
      key: [
        {'asset': key},
      ],
  });
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMessageHandler('flutter/assets', (message) async {
        final key = utf8.decode(
          message!.buffer.asUint8List(
            message.offsetInBytes,
            message.lengthInBytes,
          ),
        );
        if (key == 'AssetManifest.bin') return manifest;
        final path = files[key];
        if (path == null) return null;
        return ByteData.sublistView(await File(path).readAsBytes());
      });
}

Future<void> _loadFallbackFonts() async {
  Future<ByteData> read(String path) async =>
      ByteData.sublistView(await File(path).readAsBytes());

  // google_fonts styles fall back to the bare family name. Registering a CJK
  // face there supplies ♭/♯ and Chinese glyphs, as the OS fallback does on
  // device.
  final cjk = _localeArg == 'zh' ? 'NotoSansSC' : 'NotoSansTC';
  final fallback = FontLoader('Outfit');
  for (final w in [400, 500, 700]) {
    fallback.addFont(read('$_fontDir/$cjk-$w.ttf'));
  }
  await fallback.load();
  await (FontLoader('MaterialIcons')..addFont(read(_iconFont))).load();
}

void main() {
  final locale = _parseLocale(_localeArg);
  final wanted = _devicesArg.isEmpty ? null : _devicesArg.split(',').toSet();

  setUpAll(() async {
    if (_fontDir.isEmpty || _iconFont.isEmpty || _outDir.isEmpty) {
      fail('Run via tool/store_screenshots/generate.sh');
    }
    GoogleFonts.config.allowRuntimeFetching = false;
    FeedbackService.instance.availableForTest = true;
    _serveOutfitAsAssets();
    // Load every weight up front, in the real zone: loads started inside a
    // testWidgets body can't complete there.
    for (final w in [300, 400, 500, 600, 700]) {
      GoogleFonts.outfit(fontWeight: FontWeight.values[w ~/ 100 - 1]);
    }
    await GoogleFonts.pendingFonts();
    await _loadFallbackFonts();
  });

  for (final device in _devices) {
    if (wanted != null && !wanted.contains(device.id)) continue;
    for (final scene in _scenes()) {
      testWidgets('${device.id} $_localeArg ${scene.id}', (tester) async {
        final view = tester.view;
        view.physicalSize = device.physical;
        view.devicePixelRatio = device.dpr;
        final insets = FakeViewPadding(
          top: device.topInset * device.dpr,
          bottom: device.bottomInset * device.dpr,
        );
        view.padding = insets;
        view.viewPadding = insets;
        // Pins the needle and every pulse to a steady frame.
        tester.platformDispatcher.accessibilityFeaturesTestValue =
            const FakeAccessibilityFeatures(disableAnimations: true);
        addTearDown(() {
          view.reset();
          tester.platformDispatcher.clearAccessibilityFeaturesTestValue();
        });

        SharedPreferences.setMockInitialValues({
          'theme_id': scene.theme.id,
          'app_locale': _localeArg,
        });

        final boundary = GlobalKey();
        final theme = scene.theme;
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              startupThemeProvider.overrideWithValue(theme),
              tunerProvider.overrideWith(() => _SceneNotifier(scene.state)),
              localeProvider.overrideWith(() => _FixedLocale(locale)),
            ],
            child: RepaintBoundary(
              key: boundary,
              child: MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: AppTheme.dark,
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                locale: locale,
                builder: (context, child) => Material(
                  type: MaterialType.transparency,
                  child: Stack(
                    children: [
                      child!,
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: _StatusBar(device.os, device.topInset, theme),
                      ),
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: _HomeIndicator(device, theme),
                      ),
                    ],
                  ),
                ),
                home: const TunerScreen(),
              ),
            ),
          ),
        );
        // Let the string rail finish scrolling to the active string.
        for (var i = 0; i < 4; i++) {
          await tester.pump(const Duration(milliseconds: 200));
        }

        if (scene.openSettings) {
          await tester.tap(find.byIcon(Icons.tune_rounded));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 600));
          // Scroll so the sheet opens on the Tuning Reminder row, with Note
          // display, A4 and the theme picker below it. (Scrolling further
          // runs out of sheet on the shorter phones and cuts a row in half.)
          final l10n = AppLocalizations.of(
            tester.element(find.byType(TunerScreen)),
          )!;
          final anchor = find.text(l10n.settingsShowReminderToggle);
          await tester.runAsync(
            () => Scrollable.ensureVisible(tester.element(anchor)),
          );
          await tester.pump();
          // Back off to the row's top padding. (A drag this short would
          // register as a tap on whatever row sits under it.)
          final position = tester
              .state<ScrollableState>(find.byType(Scrollable).last)
              .position;
          position.jumpTo(max(0.0, position.pixels - 14));
          await tester.pump(const Duration(milliseconds: 300));
        }
        expect(tester.takeException(), isNull);

        final render =
            boundary.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        // Start the capture in the test zone, await it in the real one — the
        // same split flutter_test's golden matcher uses (starting it inside
        // runAsync never completes).
        final capture = render.toImage(pixelRatio: device.dpr);
        final bytes = await tester.runAsync(() async {
          final image = await capture;
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          image.dispose();
          return data!.buffer.asUint8List();
        });
        final file = File('$_outDir/${device.id}/$_localeArg/${scene.id}.png');
        // Sync IO: async IO never completes inside the fake-async test zone.
        file.parent.createSync(recursive: true);
        file.writeAsBytesSync(bytes!);
      });
    }
  }
}
