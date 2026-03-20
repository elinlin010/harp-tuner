// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Italian (`it`).
class AppLocalizationsIt extends AppLocalizations {
  AppLocalizationsIt([String locale = 'it']) : super(locale);

  @override
  String get tunerTitle => 'ACCORDATORE';

  @override
  String get settingsTitle => 'Impostazioni';

  @override
  String get settingsInstrumentLabel => 'Strumento';

  @override
  String get settingsInstrumentNone => 'Nessuno';

  @override
  String get settingsNoteDisplayLabel => 'Visualizzazione note';

  @override
  String get settingsAlwaysShowFlatsToggle => '♭  Mostra sempre i bemolle';

  @override
  String get settingsAlwaysShowFlatsHint => 'es. B♭ invece di A♯';

  @override
  String get settingsOctaveNumberLabel => 'Numero di ottava';

  @override
  String get settingsShowOctaveToggle => 'Mostra numero di ottava';

  @override
  String get settingsShowOctaveHint => 'es. A4 invece di A';

  @override
  String get settingsA4CalibLabel => 'Riferimento A4';

  @override
  String get settingsA4CalibStandard => 'Standard = 440 Hz';

  @override
  String get harpTypeLapHarp => 'Arpa da grembo';

  @override
  String get harpTypeLapHarpSubtitle => '15 corde · C4–C6';

  @override
  String get harpTypeLeverHarp => 'Arpa celtica';

  @override
  String get harpTypeLeverHarpSubtitle => '34 corde · A♭1–F6 · Mi♭ mag';

  @override
  String get harpTypePedalHarp => 'Arpa a pedali';

  @override
  String get harpTypePedalHarpSubtitle => '47 corde · C♭1–G♭7 · pos. bemolli';

  @override
  String get settingsDarkModeToggle => 'Modalità scura';

  @override
  String get settingsThemeLabel => 'Tema';

  @override
  String get settingsLanguageLabel => 'Lingua';

  @override
  String get tunerStartBtn => 'Inizia accordatura';

  @override
  String get tunerStopBtn => 'Ferma';

  @override
  String get gaugeListeningMsg => 'In ascolto di una nota…';

  @override
  String get gaugeTapToBeginMsg => 'Tocca per iniziare';

  @override
  String get pitchLightFlatLabel => 'Basso';

  @override
  String get pitchLightInTuneLabel => 'Intonato';

  @override
  String get pitchLightSharpLabel => 'Alto';

  @override
  String get errorMicDeniedTitle => 'Accesso al microfono negato';

  @override
  String get errorMicDeniedMsg =>
      'Vai in Impostazioni → Accordatore → Microfono e attivalo.';

  @override
  String get errorMicDeniedBtn => 'Apri impostazioni';

  @override
  String get tapToDismiss => 'Tocca per chiudere';

  @override
  String errorMicUnavailableMsg(String message) {
    return 'Microfono non disponibile: $message';
  }
}
