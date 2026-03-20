// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get tunerTitle => 'TUNER';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsInstrumentLabel => 'Instrument';

  @override
  String get settingsInstrumentNone => 'None';

  @override
  String get settingsNoteDisplayLabel => 'Note display';

  @override
  String get settingsAlwaysShowFlatsToggle => '♭  Always show flats';

  @override
  String get settingsAlwaysShowFlatsHint => 'e.g. B♭ instead of A♯';

  @override
  String get settingsOctaveNumberLabel => 'Octave number';

  @override
  String get settingsShowOctaveToggle => 'Show octave number';

  @override
  String get settingsShowOctaveHint => 'e.g. A4 instead of A';

  @override
  String get settingsA4CalibLabel => 'A4 Reference';

  @override
  String get settingsA4CalibStandard => 'Standard = 440 Hz';

  @override
  String get harpTypeLapHarp => 'Lap Harp';

  @override
  String get harpTypeLapHarpSubtitle => '15 strings · C4–C6';

  @override
  String get harpTypeLeverHarp => 'Lever Harp';

  @override
  String get harpTypeLeverHarpSubtitle => '34 strings · A1–F6';

  @override
  String get harpTypePedalHarp => 'Pedal Harp';

  @override
  String get harpTypePedalHarpSubtitle => '47 strings · C1–G7';

  @override
  String get settingsLanguageLabel => 'Language';

  @override
  String get tunerStartBtn => 'Start Tuning';

  @override
  String get tunerStopBtn => 'Stop';

  @override
  String get gaugeListeningMsg => 'Listening for a note…';

  @override
  String get gaugeTapToBeginMsg => 'Tap Start Tuning to begin';

  @override
  String get pitchLightFlatLabel => 'Flat';

  @override
  String get pitchLightInTuneLabel => 'In Tune';

  @override
  String get pitchLightSharpLabel => 'Sharp';

  @override
  String get errorMicDeniedTitle => 'Microphone access denied';

  @override
  String get errorMicDeniedMsg =>
      'Go to Settings → Tuner → Microphone and turn it on.';

  @override
  String get errorMicDeniedBtn => 'Open Settings';

  @override
  String get tapToDismiss => 'Tap to dismiss';

  @override
  String errorMicUnavailableMsg(String message) {
    return 'Microphone unavailable: $message';
  }
}
