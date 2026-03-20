// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get tunerTitle => 'STIMMGERÄT';

  @override
  String get settingsTitle => 'Einstellungen';

  @override
  String get settingsInstrumentLabel => 'Instrument';

  @override
  String get settingsInstrumentNone => 'Keines';

  @override
  String get settingsNoteDisplayLabel => 'Notenname';

  @override
  String get settingsAlwaysShowFlatsToggle => '♭  Immer b-Vorzeichen';

  @override
  String get settingsAlwaysShowFlatsHint => 'z.B. B♭ statt A♯';

  @override
  String get settingsOctaveNumberLabel => 'Oktavnummer';

  @override
  String get settingsShowOctaveToggle => 'Oktavnummer anzeigen';

  @override
  String get settingsShowOctaveHint => 'z.B. A4 statt A';

  @override
  String get settingsA4CalibLabel => 'A4-Referenz';

  @override
  String get settingsA4CalibStandard => 'Standard = 440 Hz';

  @override
  String get harpTypeLapHarp => 'Schoßharfe';

  @override
  String get harpTypeLapHarpSubtitle => '15 Saiten · C4–C6';

  @override
  String get harpTypeLeverHarp => 'Hakenharfe';

  @override
  String get harpTypeLeverHarpSubtitle => '34 Saiten · A1–F6';

  @override
  String get harpTypePedalHarp => 'Pedalharfe';

  @override
  String get harpTypePedalHarpSubtitle => '47 Saiten · C1–G7';

  @override
  String get settingsLanguageLabel => 'Sprache';

  @override
  String get tunerStartBtn => 'Stimmen starten';

  @override
  String get tunerStopBtn => 'Stopp';

  @override
  String get gaugeListeningMsg => 'Auf Ton hören…';

  @override
  String get gaugeTapToBeginMsg => 'Antippen zum Starten';

  @override
  String get pitchLightFlatLabel => 'Zu tief';

  @override
  String get pitchLightInTuneLabel => 'Gestimmt';

  @override
  String get pitchLightSharpLabel => 'Zu hoch';

  @override
  String get errorMicDeniedTitle => 'Mikrofonzugriff verweigert';

  @override
  String get errorMicDeniedMsg =>
      'Einstellungen → Stimmgerät → Mikrofon öffnen und aktivieren.';

  @override
  String get errorMicDeniedBtn => 'Einstellungen öffnen';

  @override
  String get tapToDismiss => 'Tippen zum Schließen';

  @override
  String errorMicUnavailableMsg(String message) {
    return 'Mikrofon nicht verfügbar: $message';
  }
}
