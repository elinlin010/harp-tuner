import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_de.dart';
import 'app_localizations_en.dart';
import 'app_localizations_fr.dart';
import 'app_localizations_it.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('de'),
    Locale('en'),
    Locale('fr'),
    Locale('it'),
    Locale('zh'),
    Locale('zh', 'TW'),
  ];

  /// No description provided for @tunerTitle.
  ///
  /// In en, this message translates to:
  /// **'TUNER'**
  String get tunerTitle;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingsInstrumentLabel.
  ///
  /// In en, this message translates to:
  /// **'Instrument'**
  String get settingsInstrumentLabel;

  /// No description provided for @settingsInstrumentNone.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get settingsInstrumentNone;

  /// No description provided for @settingsNoteDisplayLabel.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get settingsNoteDisplayLabel;

  /// No description provided for @settingsAlwaysShowFlatsToggle.
  ///
  /// In en, this message translates to:
  /// **'♭  Always show flats'**
  String get settingsAlwaysShowFlatsToggle;

  /// No description provided for @settingsAlwaysShowFlatsHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. B♭ instead of A♯'**
  String get settingsAlwaysShowFlatsHint;

  /// No description provided for @settingsOctaveNumberLabel.
  ///
  /// In en, this message translates to:
  /// **'Octave number'**
  String get settingsOctaveNumberLabel;

  /// No description provided for @settingsShowOctaveToggle.
  ///
  /// In en, this message translates to:
  /// **'Show octave number'**
  String get settingsShowOctaveToggle;

  /// No description provided for @settingsShowOctaveHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. A4 instead of A'**
  String get settingsShowOctaveHint;

  /// No description provided for @settingsA4CalibLabel.
  ///
  /// In en, this message translates to:
  /// **'A4 Reference'**
  String get settingsA4CalibLabel;

  /// No description provided for @settingsA4CalibStandard.
  ///
  /// In en, this message translates to:
  /// **'Reset to 440 Hz'**
  String get settingsA4CalibStandard;

  /// No description provided for @harpTypeLapHarp.
  ///
  /// In en, this message translates to:
  /// **'Lap Harp'**
  String get harpTypeLapHarp;

  /// No description provided for @harpTypeLapHarpSubtitle.
  ///
  /// In en, this message translates to:
  /// **'15 strings · C4–C6'**
  String get harpTypeLapHarpSubtitle;

  /// No description provided for @harpTypeLeverHarp.
  ///
  /// In en, this message translates to:
  /// **'Lever Harp'**
  String get harpTypeLeverHarp;

  /// No description provided for @harpTypeLeverHarpSubtitle.
  ///
  /// In en, this message translates to:
  /// **'34 strings · A♭1–F6 · E♭ maj'**
  String get harpTypeLeverHarpSubtitle;

  /// No description provided for @harpTypePedalHarp.
  ///
  /// In en, this message translates to:
  /// **'Pedal Harp'**
  String get harpTypePedalHarp;

  /// No description provided for @harpTypePedalHarpSubtitle.
  ///
  /// In en, this message translates to:
  /// **'47 strings · C♭1–G♭7 · flat pos.'**
  String get harpTypePedalHarpSubtitle;

  /// No description provided for @settingsDarkModeToggle.
  ///
  /// In en, this message translates to:
  /// **'Dark mode'**
  String get settingsDarkModeToggle;

  /// No description provided for @settingsThemeLabel.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get settingsThemeLabel;

  /// No description provided for @settingsLanguageLabel.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguageLabel;

  /// No description provided for @selectYourInstrument.
  ///
  /// In en, this message translates to:
  /// **'Select your instrument'**
  String get selectYourInstrument;

  /// No description provided for @tunerStartBtn.
  ///
  /// In en, this message translates to:
  /// **'Start Tuning'**
  String get tunerStartBtn;

  /// No description provided for @tunerStopBtn.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get tunerStopBtn;

  /// No description provided for @gaugeListeningMsg.
  ///
  /// In en, this message translates to:
  /// **'Listening for a note…'**
  String get gaugeListeningMsg;

  /// No description provided for @gaugeTapToBeginMsg.
  ///
  /// In en, this message translates to:
  /// **'Tap Start Tuning to begin'**
  String get gaugeTapToBeginMsg;

  /// No description provided for @gaugeStaleSemantics.
  ///
  /// In en, this message translates to:
  /// **'Tuner reading stale — play a note'**
  String get gaugeStaleSemantics;

  /// No description provided for @modeAuto.
  ///
  /// In en, this message translates to:
  /// **'Auto'**
  String get modeAuto;

  /// No description provided for @modeReference.
  ///
  /// In en, this message translates to:
  /// **'Reference'**
  String get modeReference;

  /// No description provided for @referenceTapHint.
  ///
  /// In en, this message translates to:
  /// **'Tap a string to hear it and tune to it'**
  String get referenceTapHint;

  /// No description provided for @pitchLightFlatLabel.
  ///
  /// In en, this message translates to:
  /// **'Flat'**
  String get pitchLightFlatLabel;

  /// No description provided for @pitchLightInTuneLabel.
  ///
  /// In en, this message translates to:
  /// **'In Tune'**
  String get pitchLightInTuneLabel;

  /// No description provided for @pitchLightSharpLabel.
  ///
  /// In en, this message translates to:
  /// **'Sharp'**
  String get pitchLightSharpLabel;

  /// No description provided for @errorMicDeniedTitle.
  ///
  /// In en, this message translates to:
  /// **'Microphone access denied'**
  String get errorMicDeniedTitle;

  /// No description provided for @errorMicDeniedMsg.
  ///
  /// In en, this message translates to:
  /// **'Go to Settings → Tuner → Microphone and turn it on.'**
  String get errorMicDeniedMsg;

  /// No description provided for @errorMicDeniedBtn.
  ///
  /// In en, this message translates to:
  /// **'Open Settings'**
  String get errorMicDeniedBtn;

  /// No description provided for @tapToDismiss.
  ///
  /// In en, this message translates to:
  /// **'Tap to dismiss'**
  String get tapToDismiss;

  /// No description provided for @errorMicUnavailableMsg.
  ///
  /// In en, this message translates to:
  /// **'Microphone unavailable: {message}'**
  String errorMicUnavailableMsg(String message);

  /// No description provided for @harpTypeLeverHarpSubtitleFmt.
  ///
  /// In en, this message translates to:
  /// **'{count} strings · {bottomNote}–{topNote} · E♭ maj'**
  String harpTypeLeverHarpSubtitleFmt(
    int count,
    String bottomNote,
    String topNote,
  );

  /// No description provided for @settingsLeverStringCountLabel.
  ///
  /// In en, this message translates to:
  /// **'String count'**
  String get settingsLeverStringCountLabel;

  /// No description provided for @settingsLeverStringCountValue.
  ///
  /// In en, this message translates to:
  /// **'{count} strings'**
  String settingsLeverStringCountValue(int count);

  /// No description provided for @settingsShowReminderToggle.
  ///
  /// In en, this message translates to:
  /// **'Show tuning reminder'**
  String get settingsShowReminderToggle;

  /// No description provided for @reminderPedalSnack.
  ///
  /// In en, this message translates to:
  /// **'Before tuning, set all pedals to the flat position (top notch).'**
  String get reminderPedalSnack;

  /// No description provided for @reminderLeverSnack.
  ///
  /// In en, this message translates to:
  /// **'Before tuning, disengage all levers (push down).'**
  String get reminderLeverSnack;

  /// No description provided for @reminderDismissBtn.
  ///
  /// In en, this message translates to:
  /// **'Got it'**
  String get reminderDismissBtn;

  /// No description provided for @settingsDisplayLabelInstrument.
  ///
  /// In en, this message translates to:
  /// **'HARP'**
  String get settingsDisplayLabelInstrument;

  /// No description provided for @settingsDisplayLabelA4.
  ///
  /// In en, this message translates to:
  /// **'A4'**
  String get settingsDisplayLabelA4;

  /// No description provided for @settingsDisplayLabelStrings.
  ///
  /// In en, this message translates to:
  /// **'STRINGS'**
  String get settingsDisplayLabelStrings;

  /// No description provided for @settingsDisplayHarpLever.
  ///
  /// In en, this message translates to:
  /// **'Lever'**
  String get settingsDisplayHarpLever;

  /// No description provided for @settingsDisplayHarpPedal.
  ///
  /// In en, this message translates to:
  /// **'Pedal'**
  String get settingsDisplayHarpPedal;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['de', 'en', 'fr', 'it', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when language+country codes are specified.
  switch (locale.languageCode) {
    case 'zh':
      {
        switch (locale.countryCode) {
          case 'TW':
            return AppLocalizationsZhTw();
        }
        break;
      }
  }

  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
    case 'fr':
      return AppLocalizationsFr();
    case 'it':
      return AppLocalizationsIt();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
