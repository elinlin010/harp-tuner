// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get tunerTitle => '調音器';

  @override
  String get settingsTitle => '設定';

  @override
  String get settingsInstrumentLabel => '樂器';

  @override
  String get settingsInstrumentNone => '無';

  @override
  String get settingsNoteDisplayLabel => '音符顯示';

  @override
  String get settingsAlwaysShowFlatsToggle => '♭  一律顯示降號';

  @override
  String get settingsAlwaysShowFlatsHint => '例：B♭ 而非 A♯';

  @override
  String get settingsOctaveNumberLabel => '八度音';

  @override
  String get settingsShowOctaveToggle => '顯示八度音號碼';

  @override
  String get settingsShowOctaveHint => '例：A4 而非 A';

  @override
  String get settingsA4CalibLabel => 'A4 基準音';

  @override
  String get settingsA4CalibStandard => '標準 = 440 Hz';

  @override
  String get harpTypeLapHarp => '膝琴';

  @override
  String get harpTypeLapHarpSubtitle => '15 弦 · C4–C6';

  @override
  String get harpTypeLeverHarp => '槓桿豎琴';

  @override
  String get harpTypeLeverHarpSubtitle => '34 弦 · A1–F6';

  @override
  String get harpTypePedalHarp => '踏板豎琴';

  @override
  String get harpTypePedalHarpSubtitle => '47 弦 · C1–G7';

  @override
  String get settingsDarkModeToggle => '深色模式';

  @override
  String get settingsThemeLabel => '主題';

  @override
  String get settingsLanguageLabel => '語言';

  @override
  String get tunerStartBtn => '開始調音';

  @override
  String get tunerStopBtn => '停止';

  @override
  String get gaugeListeningMsg => '正在聆聽音符…';

  @override
  String get gaugeTapToBeginMsg => '點擊以開始調音';

  @override
  String get pitchLightFlatLabel => '偏低';

  @override
  String get pitchLightInTuneLabel => '準確';

  @override
  String get pitchLightSharpLabel => '偏高';

  @override
  String get errorMicDeniedTitle => '麥克風存取被拒';

  @override
  String get errorMicDeniedMsg => '請前往「設定」→「調音器」→「麥克風」並開啟權限。';

  @override
  String get errorMicDeniedBtn => '開啟設定';

  @override
  String get tapToDismiss => '點擊關閉';

  @override
  String errorMicUnavailableMsg(String message) {
    return '麥克風無法使用：$message';
  }
}

/// The translations for Chinese, as used in Taiwan (`zh_TW`).
class AppLocalizationsZhTw extends AppLocalizationsZh {
  AppLocalizationsZhTw() : super('zh_TW');

  @override
  String get tunerTitle => '調音器';

  @override
  String get settingsTitle => '設定';

  @override
  String get settingsInstrumentLabel => '樂器';

  @override
  String get settingsInstrumentNone => '無';

  @override
  String get settingsNoteDisplayLabel => '音符顯示';

  @override
  String get settingsAlwaysShowFlatsToggle => '♭  一律顯示降號';

  @override
  String get settingsAlwaysShowFlatsHint => '例：B♭ 而非 A♯';

  @override
  String get settingsOctaveNumberLabel => '八度音';

  @override
  String get settingsShowOctaveToggle => '顯示八度音號碼';

  @override
  String get settingsShowOctaveHint => '例：A4 而非 A';

  @override
  String get settingsA4CalibLabel => 'A4 基準音';

  @override
  String get settingsA4CalibStandard => '標準 = 440 Hz';

  @override
  String get harpTypeLapHarp => '膝琴';

  @override
  String get harpTypeLapHarpSubtitle => '15 弦 · C4–C6';

  @override
  String get harpTypeLeverHarp => '槓桿豎琴';

  @override
  String get harpTypeLeverHarpSubtitle => '34 弦 · A1–F6';

  @override
  String get harpTypePedalHarp => '踏板豎琴';

  @override
  String get harpTypePedalHarpSubtitle => '47 弦 · C1–G7';

  @override
  String get settingsDarkModeToggle => '深色模式';

  @override
  String get settingsThemeLabel => '主題';

  @override
  String get settingsLanguageLabel => '語言';

  @override
  String get tunerStartBtn => '開始調音';

  @override
  String get tunerStopBtn => '停止';

  @override
  String get gaugeListeningMsg => '正在聆聽音符…';

  @override
  String get gaugeTapToBeginMsg => '點擊以開始調音';

  @override
  String get pitchLightFlatLabel => '偏低';

  @override
  String get pitchLightInTuneLabel => '準確';

  @override
  String get pitchLightSharpLabel => '偏高';

  @override
  String get errorMicDeniedTitle => '麥克風存取被拒';

  @override
  String get errorMicDeniedMsg => '請前往「設定」→「調音器」→「麥克風」並開啟權限。';

  @override
  String get errorMicDeniedBtn => '開啟設定';

  @override
  String get tapToDismiss => '點擊關閉';

  @override
  String errorMicUnavailableMsg(String message) {
    return '麥克風無法使用：$message';
  }
}
