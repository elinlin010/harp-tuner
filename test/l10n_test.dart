import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harp_tuner/l10n/app_localizations.dart';

Future<AppLocalizations> _l10n(String languageCode, [String? countryCode]) =>
    AppLocalizations.delegate.load(
      countryCode != null ? Locale(languageCode, countryCode) : Locale(languageCode),
    );

void _allKeys(AppLocalizations l) {
  expect(l.tunerTitle, isNotEmpty);
  expect(l.settingsTitle, isNotEmpty);
  expect(l.settingsInstrumentLabel, isNotEmpty);
  expect(l.settingsInstrumentNone, isNotEmpty);
  expect(l.settingsNoteDisplayLabel, isNotEmpty);
  expect(l.settingsAlwaysShowFlatsToggle, isNotEmpty);
  expect(l.settingsAlwaysShowFlatsHint, isNotEmpty);
  expect(l.settingsOctaveNumberLabel, isNotEmpty);
  expect(l.settingsShowOctaveToggle, isNotEmpty);
  expect(l.settingsShowOctaveHint, isNotEmpty);
  expect(l.settingsA4CalibLabel, isNotEmpty);
  expect(l.settingsA4CalibStandard, isNotEmpty);
  expect(l.harpTypeLapHarp, isNotEmpty);
  expect(l.harpTypeLapHarpSubtitle, isNotEmpty);
  expect(l.harpTypeLeverHarp, isNotEmpty);
  expect(l.harpTypeLeverHarpSubtitle, isNotEmpty);
  expect(l.harpTypePedalHarp, isNotEmpty);
  expect(l.harpTypePedalHarpSubtitle, isNotEmpty);
  expect(l.settingsDarkModeToggle, isNotEmpty);
  expect(l.settingsThemeLabel, isNotEmpty);
  expect(l.settingsLanguageLabel, isNotEmpty);
  expect(l.selectYourInstrument, isNotEmpty);
  expect(l.tunerStartBtn, isNotEmpty);
  expect(l.tunerStopBtn, isNotEmpty);
  expect(l.gaugeListeningMsg, isNotEmpty);
  expect(l.gaugeTapToBeginMsg, isNotEmpty);
  expect(l.gaugeStaleSemantics, isNotEmpty);
  expect(l.modeAuto, isNotEmpty);
  expect(l.modeReference, isNotEmpty);
  expect(l.referenceTapHint, isNotEmpty);
  expect(l.pitchLightFlatLabel, isNotEmpty);
  expect(l.pitchLightInTuneLabel, isNotEmpty);
  expect(l.pitchLightSharpLabel, isNotEmpty);
  expect(l.errorMicDeniedTitle, isNotEmpty);
  expect(l.errorMicDeniedMsg, isNotEmpty);
  expect(l.errorMicDeniedBtn, isNotEmpty);
  expect(l.tapToDismiss, isNotEmpty);
  expect(l.errorMicUnavailableMsg('some error'), isNotEmpty);
  expect(l.harpTypeLeverHarpSubtitleFmt(34, 'G2', 'E♭7'), isNotEmpty);
  expect(l.settingsLeverStringCountLabel, isNotEmpty);
  expect(l.settingsLeverStringCountValue(34), isNotEmpty);
  expect(l.settingsShowReminderToggle, isNotEmpty);
  expect(l.settingsShowReminderToggleHint, isNotEmpty);
  expect(l.reminderPedalSnack, isNotEmpty);
  expect(l.reminderLeverSnack, isNotEmpty);
  expect(l.reminderDismissBtn, isNotEmpty);
  expect(l.settingsDisplayLabelInstrument, isNotEmpty);
  expect(l.settingsDisplayLabelA4, isNotEmpty);
  expect(l.settingsDisplayLabelStrings, isNotEmpty);
  expect(l.settingsDisplayHarpLever, isNotEmpty);
  expect(l.settingsDisplayHarpPedal, isNotEmpty);
}

void main() {
  // ── English ───────────────────────────────────────────────────────────────────

  group('AppLocalizations — English (en)', () {
    late AppLocalizations l10n;
    setUpAll(() async { l10n = await _l10n('en'); });
    test('all keys are non-empty', () => _allKeys(l10n));
    test('parametric: errorMicUnavailableMsg interpolates message', () {
      expect(l10n.errorMicUnavailableMsg('No device'), contains('No device'));
    });
    test('parametric: harpTypeLeverHarpSubtitleFmt contains count', () {
      expect(l10n.harpTypeLeverHarpSubtitleFmt(36, 'A♭1', 'E♭7'), contains('36'));
    });
    test('parametric: settingsLeverStringCountValue contains count', () {
      expect(l10n.settingsLeverStringCountValue(28), contains('28'));
    });
  });

  // ── German ────────────────────────────────────────────────────────────────────

  group('AppLocalizations — German (de)', () {
    late AppLocalizations l10n;
    setUpAll(() async { l10n = await _l10n('de'); });
    test('all keys are non-empty', () => _allKeys(l10n));
    test('parametric: errorMicUnavailableMsg interpolates message', () {
      expect(l10n.errorMicUnavailableMsg('Fehler'), contains('Fehler'));
    });
    test('parametric: harpTypeLeverHarpSubtitleFmt contains count', () {
      expect(l10n.harpTypeLeverHarpSubtitleFmt(34, 'G2', 'E♭7'), contains('34'));
    });
    test('parametric: settingsLeverStringCountValue contains count', () {
      expect(l10n.settingsLeverStringCountValue(34), contains('34'));
    });
  });

  // ── French ────────────────────────────────────────────────────────────────────

  group('AppLocalizations — French (fr)', () {
    late AppLocalizations l10n;
    setUpAll(() async { l10n = await _l10n('fr'); });
    test('all keys are non-empty', () => _allKeys(l10n));
    test('parametric: errorMicUnavailableMsg interpolates message', () {
      expect(l10n.errorMicUnavailableMsg('erreur'), contains('erreur'));
    });
    test('parametric: harpTypeLeverHarpSubtitleFmt contains count', () {
      expect(l10n.harpTypeLeverHarpSubtitleFmt(34, 'G2', 'E♭7'), contains('34'));
    });
    test('parametric: settingsLeverStringCountValue contains count', () {
      expect(l10n.settingsLeverStringCountValue(34), contains('34'));
    });
  });

  // ── Italian ───────────────────────────────────────────────────────────────────

  group('AppLocalizations — Italian (it)', () {
    late AppLocalizations l10n;
    setUpAll(() async { l10n = await _l10n('it'); });
    test('all keys are non-empty', () => _allKeys(l10n));
    test('parametric: errorMicUnavailableMsg interpolates message', () {
      expect(l10n.errorMicUnavailableMsg('errore'), contains('errore'));
    });
    test('parametric: harpTypeLeverHarpSubtitleFmt contains count', () {
      expect(l10n.harpTypeLeverHarpSubtitleFmt(34, 'G2', 'E♭7'), contains('34'));
    });
    test('parametric: settingsLeverStringCountValue contains count', () {
      expect(l10n.settingsLeverStringCountValue(34), contains('34'));
    });
  });

  // ── Chinese Simplified ────────────────────────────────────────────────────────

  group('AppLocalizations — Chinese Simplified (zh)', () {
    late AppLocalizations l10n;
    setUpAll(() async { l10n = await _l10n('zh'); });
    test('all keys are non-empty', () => _allKeys(l10n));
    test('parametric: errorMicUnavailableMsg interpolates message', () {
      expect(l10n.errorMicUnavailableMsg('错误'), contains('错误'));
    });
    test('parametric: harpTypeLeverHarpSubtitleFmt contains count', () {
      expect(l10n.harpTypeLeverHarpSubtitleFmt(34, 'G2', 'E♭7'), contains('34'));
    });
    test('parametric: settingsLeverStringCountValue contains count', () {
      expect(l10n.settingsLeverStringCountValue(34), contains('34'));
    });
  });

  // ── Chinese Traditional ───────────────────────────────────────────────────────

  group('AppLocalizations — Chinese Traditional (zh_TW)', () {
    late AppLocalizations l10n;
    setUpAll(() async { l10n = await _l10n('zh', 'TW'); });
    test('all keys are non-empty', () => _allKeys(l10n));
    test('parametric: errorMicUnavailableMsg interpolates message', () {
      expect(l10n.errorMicUnavailableMsg('錯誤'), contains('錯誤'));
    });
    test('parametric: harpTypeLeverHarpSubtitleFmt contains count', () {
      expect(l10n.harpTypeLeverHarpSubtitleFmt(34, 'G2', 'E♭7'), contains('34'));
    });
    test('parametric: settingsLeverStringCountValue contains count', () {
      expect(l10n.settingsLeverStringCountValue(34), contains('34'));
    });
  });

  // ── Delegate edge cases ───────────────────────────────────────────────────────

  group('AppLocalizations.delegate', () {
    test('isSupported returns true for en', () {
      expect(AppLocalizations.delegate.isSupported(const Locale('en')), isTrue);
    });
    test('isSupported returns true for zh_TW', () {
      expect(AppLocalizations.delegate.isSupported(const Locale('zh', 'TW')), isTrue);
    });
    test('isSupported returns false for unsupported locale', () {
      expect(AppLocalizations.delegate.isSupported(const Locale('ja')), isFalse);
    });
    test('unsupported locale load throws FlutterError', () {
      expect(
        () => AppLocalizations.delegate.load(const Locale('ja')),
        throwsA(isA<FlutterError>()),
      );
    });
  });
}
