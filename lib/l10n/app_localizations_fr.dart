// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get tunerTitle => 'ACCORDEUR';

  @override
  String get settingsTitle => 'Paramètres';

  @override
  String get settingsInstrumentLabel => 'Instrument';

  @override
  String get settingsInstrumentNone => 'Aucun';

  @override
  String get settingsNoteDisplayLabel => 'Note';

  @override
  String get settingsAlwaysShowFlatsToggle => '♭  Toujours en bémol';

  @override
  String get settingsAlwaysShowFlatsHint => 'ex. B♭ au lieu de A♯';

  @override
  String get settingsOctaveNumberLabel => 'Numéro d\'octave';

  @override
  String get settingsShowOctaveToggle => 'Afficher l\'octave';

  @override
  String get settingsShowOctaveHint => 'ex. A4 au lieu de A';

  @override
  String get settingsA4CalibLabel => 'Référence A4';

  @override
  String get settingsA4CalibStandard => 'Réinitialiser à 440 Hz';

  @override
  String get harpTypeLapHarp => 'Harpe de voyage';

  @override
  String get harpTypeLapHarpSubtitle => '15 cordes · C4–C6';

  @override
  String get harpTypeLeverHarp => 'Harpe celtique';

  @override
  String get harpTypeLeverHarpSubtitle => '34 cordes · A♭1–F6 · Mi♭ maj';

  @override
  String get harpTypePedalHarp => 'Harpe à pédales';

  @override
  String get harpTypePedalHarpSubtitle => '47 cordes · C♭1–G♭7 · pos. bémols';

  @override
  String get settingsDarkModeToggle => 'Mode sombre';

  @override
  String get settingsThemeLabel => 'Thème';

  @override
  String get settingsLanguageLabel => 'Langue';

  @override
  String get selectYourInstrument => 'Choisissez votre instrument';

  @override
  String get tunerStartBtn => 'Accorder';

  @override
  String get tunerStopBtn => 'Arrêter';

  @override
  String get gaugeListeningMsg => 'Écoute d\'une note…';

  @override
  String get gaugeTapToBeginMsg => 'Appuyez pour commencer';

  @override
  String get gaugeStaleSemantics => 'Lecture expirée — jouez une note';

  @override
  String get modeAuto => 'Auto';

  @override
  String get modeReference => 'Référence';

  @override
  String get referenceTapHint =>
      'Touchez une corde pour l\'entendre et l\'accorder';

  @override
  String get pitchLightFlatLabel => 'Trop bas';

  @override
  String get pitchLightInTuneLabel => 'Juste';

  @override
  String get pitchLightSharpLabel => 'Trop haut';

  @override
  String get errorMicDeniedTitle => 'Accès au microphone refusé';

  @override
  String get errorMicDeniedMsg =>
      'Allez dans Réglages → Accordeur → Microphone et activez-le.';

  @override
  String get errorMicDeniedBtn => 'Ouvrir les réglages';

  @override
  String get tapToDismiss => 'Appuyez pour fermer';

  @override
  String errorMicUnavailableMsg(String message) {
    return 'Microphone indisponible : $message';
  }

  @override
  String harpTypeLeverHarpSubtitleFmt(
    int count,
    String bottomNote,
    String topNote,
  ) {
    return '$count cordes · $bottomNote–$topNote · Mi♭ maj';
  }

  @override
  String get settingsLeverStringCountLabel => 'Nombre de cordes';

  @override
  String settingsLeverStringCountValue(int count) {
    return '$count cordes';
  }

  @override
  String get settingsShowReminderToggle => 'Afficher le rappel d\'accord';

  @override
  String get reminderPedalSnack =>
      'Avant d\'accorder, mettez toutes les pédales en position bémol (cran supérieur).';

  @override
  String get reminderLeverSnack =>
      'Avant d\'accorder, désengagez tous les leviers (vers le bas).';

  @override
  String get reminderDismissBtn => 'Compris';

  @override
  String get settingsDisplayLabelInstrument => 'HARPE';

  @override
  String get settingsDisplayLabelA4 => 'A4';

  @override
  String get settingsDisplayLabelStrings => 'CORDES';

  @override
  String get settingsDisplayHarpLever => 'Celtique';

  @override
  String get settingsDisplayHarpPedal => 'Pédales';
}
