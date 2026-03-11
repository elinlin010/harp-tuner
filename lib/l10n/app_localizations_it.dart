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
  String errorMicUnavailableMsg(String message) {
    return 'Microfono non disponibile: $message';
  }
}
