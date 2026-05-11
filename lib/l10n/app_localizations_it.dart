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
  String get settingsNoteDisplayLabel => 'Nota';

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
  String get settingsA4CalibStandard => 'Ripristina a 440 Hz';

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
  String get selectYourInstrument => 'Seleziona lo strumento';

  @override
  String get tunerStartBtn => 'Inizia accordatura';

  @override
  String get tunerStopBtn => 'Ferma';

  @override
  String get gaugeListeningMsg => 'In ascolto di una nota…';

  @override
  String get gaugeTapToBeginMsg => 'Tocca per iniziare';

  @override
  String get gaugeStaleSemantics => 'Lettura scaduta — suona una nota';

  @override
  String get modeAuto => 'Auto';

  @override
  String get modeReference => 'Riferimento';

  @override
  String get referenceTapHint => 'Tocca una corda per ascoltarla e accordarla';

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

  @override
  String harpTypeLeverHarpSubtitleFmt(
    int count,
    String bottomNote,
    String topNote,
  ) {
    return '$count corde · $bottomNote–$topNote · Mi♭ mag';
  }

  @override
  String get settingsLeverStringCountLabel => 'Numero di corde';

  @override
  String settingsLeverStringCountValue(int count) {
    return '$count corde';
  }

  @override
  String get settingsShowReminderToggle => 'Promemoria accordatura';

  @override
  String get settingsShowReminderToggleHint =>
      'Promemoria per mettere tutti i pedali/leve in ♭';

  @override
  String get reminderPedalSnack => 'Pedali in ♭ prima di accordare';

  @override
  String get reminderLeverSnack => 'Disattiva le leve prima di accordare';

  @override
  String get reminderDismissBtn => 'OK';

  @override
  String get settingsDisplayLabelInstrument => 'ARPA';

  @override
  String get settingsDisplayLabelA4 => 'A4';

  @override
  String get settingsDisplayLabelStrings => 'CORDE';

  @override
  String get settingsDisplayHarpLever => 'Celtica';

  @override
  String get settingsDisplayHarpPedal => 'A pedali';
}
