import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harp_tuner/l10n/app_localizations.dart';

/// Loads [AppLocalizations] for a given locale synchronously via the delegate.
Future<AppLocalizations> _l10n(String languageCode) =>
    AppLocalizations.delegate.load(Locale(languageCode));

void main() {
  group('AppLocalizations — German (de)', () {
    late AppLocalizations l10n;
    setUpAll(() async { l10n = await _l10n('de'); });

    test('tunerTitle is not empty', () => expect(l10n.tunerTitle, isNotEmpty));
    test('settingsTitle is not empty', () => expect(l10n.settingsTitle, isNotEmpty));
    test('settingsInstrumentLabel is not empty', () => expect(l10n.settingsInstrumentLabel, isNotEmpty));
    test('pitchLightFlatLabel is not empty', () => expect(l10n.pitchLightFlatLabel, isNotEmpty));
    test('pitchLightSharpLabel is not empty', () => expect(l10n.pitchLightSharpLabel, isNotEmpty));
    test('gaugeStaleSemantics is not empty', () => expect(l10n.gaugeStaleSemantics, isNotEmpty));
    test('modeAuto is not empty', () => expect(l10n.modeAuto, isNotEmpty));
    test('modeReference is not empty', () => expect(l10n.modeReference, isNotEmpty));
    test('harpTypeLeverHarp is not empty', () => expect(l10n.harpTypeLeverHarp, isNotEmpty));
    test('harpTypePedalHarp is not empty', () => expect(l10n.harpTypePedalHarp, isNotEmpty));
    test('settingsNoteDisplayLabel is not empty', () => expect(l10n.settingsNoteDisplayLabel, isNotEmpty));
    test('settingsAlwaysShowFlatsToggle is not empty', () => expect(l10n.settingsAlwaysShowFlatsToggle, isNotEmpty));
    test('reminderDismissBtn is not empty', () => expect(l10n.reminderDismissBtn, isNotEmpty));
  });

  group('AppLocalizations — French (fr)', () {
    late AppLocalizations l10n;
    setUpAll(() async { l10n = await _l10n('fr'); });

    test('tunerTitle is not empty', () => expect(l10n.tunerTitle, isNotEmpty));
    test('settingsTitle is not empty', () => expect(l10n.settingsTitle, isNotEmpty));
    test('settingsInstrumentLabel is not empty', () => expect(l10n.settingsInstrumentLabel, isNotEmpty));
    test('pitchLightFlatLabel is not empty', () => expect(l10n.pitchLightFlatLabel, isNotEmpty));
    test('pitchLightSharpLabel is not empty', () => expect(l10n.pitchLightSharpLabel, isNotEmpty));
    test('modeAuto is not empty', () => expect(l10n.modeAuto, isNotEmpty));
    test('modeReference is not empty', () => expect(l10n.modeReference, isNotEmpty));
    test('harpTypeLeverHarp is not empty', () => expect(l10n.harpTypeLeverHarp, isNotEmpty));
    test('reminderDismissBtn is not empty', () => expect(l10n.reminderDismissBtn, isNotEmpty));
  });

  group('AppLocalizations — Italian (it)', () {
    late AppLocalizations l10n;
    setUpAll(() async { l10n = await _l10n('it'); });

    test('tunerTitle is not empty', () => expect(l10n.tunerTitle, isNotEmpty));
    test('settingsTitle is not empty', () => expect(l10n.settingsTitle, isNotEmpty));
    test('settingsInstrumentLabel is not empty', () => expect(l10n.settingsInstrumentLabel, isNotEmpty));
    test('pitchLightFlatLabel is not empty', () => expect(l10n.pitchLightFlatLabel, isNotEmpty));
    test('pitchLightSharpLabel is not empty', () => expect(l10n.pitchLightSharpLabel, isNotEmpty));
    test('modeAuto is not empty', () => expect(l10n.modeAuto, isNotEmpty));
    test('modeReference is not empty', () => expect(l10n.modeReference, isNotEmpty));
    test('harpTypeLeverHarp is not empty', () => expect(l10n.harpTypeLeverHarp, isNotEmpty));
    test('reminderDismissBtn is not empty', () => expect(l10n.reminderDismissBtn, isNotEmpty));
  });

  group('AppLocalizations — Chinese Simplified (zh)', () {
    late AppLocalizations l10n;
    setUpAll(() async { l10n = await _l10n('zh'); });

    test('tunerTitle is not empty', () => expect(l10n.tunerTitle, isNotEmpty));
    test('settingsTitle is not empty', () => expect(l10n.settingsTitle, isNotEmpty));
    test('pitchLightFlatLabel is not empty', () => expect(l10n.pitchLightFlatLabel, isNotEmpty));
    test('pitchLightSharpLabel is not empty', () => expect(l10n.pitchLightSharpLabel, isNotEmpty));
    test('modeAuto is not empty', () => expect(l10n.modeAuto, isNotEmpty));
  });

  group('AppLocalizations — English (en) remaining strings', () {
    late AppLocalizations l10n;
    setUpAll(() async { l10n = await _l10n('en'); });

    test('harpTypePedalHarpSubtitle is not empty', () => expect(l10n.harpTypePedalHarpSubtitle, isNotEmpty));
    test('reminderPedalSnack is not empty', () => expect(l10n.reminderPedalSnack, isNotEmpty));
    test('reminderLeverSnack is not empty', () => expect(l10n.reminderLeverSnack, isNotEmpty));
    test('settingsShowReminderToggle is not empty', () => expect(l10n.settingsShowReminderToggle, isNotEmpty));
    test('settingsShowReminderToggleHint is not empty', () => expect(l10n.settingsShowReminderToggleHint, isNotEmpty));
    test('settingsInstrumentNone is not empty', () => expect(l10n.settingsInstrumentNone, isNotEmpty));
    test('settingsA4CalibLabel is not empty', () => expect(l10n.settingsA4CalibLabel, isNotEmpty));
    test('settingsShowOctaveToggle is not empty', () => expect(l10n.settingsShowOctaveToggle, isNotEmpty));
    test('settingsLanguageLabel is not empty', () => expect(l10n.settingsLanguageLabel, isNotEmpty));
  });
}
