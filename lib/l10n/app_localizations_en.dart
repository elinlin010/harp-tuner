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
  String get settingsNoteDisplayLabel => 'Note';

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
  String get settingsA4CalibStandard => 'Reset to 440 Hz';

  @override
  String get harpTypeLapHarp => 'Lap Harp';

  @override
  String get harpTypeLapHarpSubtitle => '15 strings · C4–C6';

  @override
  String get harpTypeLeverHarp => 'Lever Harp';

  @override
  String get harpTypeLeverHarpSubtitle => '34 strings · A♭1–F6 · E♭ maj';

  @override
  String get harpTypePedalHarp => 'Pedal Harp';

  @override
  String get harpTypePedalHarpSubtitle => '47 strings · C♭1–G♭7 · flat pos.';

  @override
  String get settingsDarkModeToggle => 'Dark mode';

  @override
  String get settingsThemeLabel => 'Theme';

  @override
  String get settingsLanguageLabel => 'Language';

  @override
  String get selectYourInstrument => 'Select your instrument';

  @override
  String get tunerStartBtn => 'Start Tuning';

  @override
  String get tunerStopBtn => 'Stop';

  @override
  String get gaugeListeningMsg => 'Listening for a note…';

  @override
  String get gaugeTapToBeginMsg => 'Tap Start Tuning to begin';

  @override
  String get gaugeStaleSemantics => 'Tuner reading stale — play a note';

  @override
  String get modeAuto => 'Auto';

  @override
  String get modeReference => 'Reference';

  @override
  String get referenceTapHint => 'Tap a string to hear it and tune to it';

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

  @override
  String harpTypeLeverHarpSubtitleFmt(
    int count,
    String bottomNote,
    String topNote,
  ) {
    return '$count strings · $bottomNote–$topNote · E♭ maj';
  }

  @override
  String get settingsLeverStringCountLabel => 'String count';

  @override
  String settingsLeverStringCountValue(int count) {
    return '$count strings';
  }

  @override
  String get settingsShowReminderToggle => 'Show tuning reminder';

  @override
  String get reminderPedalSnack =>
      'Before tuning, set all pedals to the flat position (top notch).';

  @override
  String get reminderLeverSnack =>
      'Before tuning, disengage all levers (push down).';

  @override
  String get reminderDismissBtn => 'Got it';

  @override
  String get settingsDisplayLabelInstrument => 'HARP';

  @override
  String get settingsDisplayLabelA4 => 'A4';

  @override
  String get settingsDisplayLabelStrings => 'STRINGS';

  @override
  String get settingsDisplayHarpLever => 'Lever';

  @override
  String get settingsDisplayHarpPedal => 'Pedal';
}
