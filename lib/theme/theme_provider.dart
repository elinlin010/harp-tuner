import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_theme.dart';

const _kThemeKey = 'theme_id';

// Keys earlier releases write on user action. Any one present proves this
// install ran a pre-wood release. Their absence proves nothing: a user who
// never opened settings has none, which is why resolveStartupTheme also asks
// the platform whether the app was updated rather than freshly installed.
const _kLegacyPrefKeys = [
  'app_locale',
  'tuner_a4_hz',
  'tuner_prefer_flats',
  'tuner_show_octave',
  'tuner_harp_type',
  'tuner_lever_string_count',
  'tuner_show_tuning_reminder',
];

/// Theme resolved in `main()` before the first frame, so the app never flashes
/// the placeholder theme. Null outside the app (tests, previews), in which case
/// [ThemeNotifier] resolves asynchronously instead.
final startupThemeProvider = Provider<TunerThemeData?>((_) => null);

final tunerThemeProvider = NotifierProvider<ThemeNotifier, TunerThemeData>(
  ThemeNotifier.new,
);

/// Reports whether this install is an update of an earlier release (true), a
/// fresh install (false), or unknown (null).
typedef UpgradeProbe = Future<bool?> Function();

/// Picks the theme for this launch.
///
/// A saved `theme_id` always wins. Otherwise this is the first launch since the
/// wood themes shipped, and the default depends on who is launching:
///  - a fresh install gets [TunerThemes.maple], the new default;
///  - an existing install, or one we cannot classify, keeps [TunerThemes.linen],
///    the theme it has been seeing all along.
/// The choice is saved so the answer never changes on later launches (a new
/// user's next app update must not flip them back to Linen).
Future<TunerThemeData> resolveStartupTheme({UpgradeProbe? isUpgrade}) async {
  final prefs = await SharedPreferences.getInstance();
  final savedId = prefs.getString(_kThemeKey);
  if (savedId != null) {
    final saved = TunerThemes.all.where((t) => t.id == savedId).firstOrNull;
    if (saved != null) return saved;
  }

  final bool existingUser;
  if (savedId != null || _kLegacyPrefKeys.any(prefs.containsKey)) {
    existingUser = true;
  } else {
    existingUser = await (isUpgrade ?? _installWasUpdated)() ?? true;
  }

  final theme = existingUser ? TunerThemes.linen : TunerThemes.maple;
  await prefs.setString(_kThemeKey, theme.id);
  return theme;
}

// Android: firstInstallTime == lastUpdateTime until the first update.
// iOS: Documents-folder creation (install) vs app-bundle mtime (last update).
// A fresh install lands both within seconds; the margin absorbs that.
Future<bool?> _installWasUpdated() async {
  try {
    final info = await PackageInfo.fromPlatform();
    final installed = info.installTime;
    final updated = info.updateTime;
    if (installed == null || updated == null) return null;
    return updated.difference(installed) > const Duration(minutes: 10);
  } catch (e) {
    debugPrint('ThemeNotifier: install-time probe failed: $e');
    return null;
  }
}

class ThemeNotifier extends Notifier<TunerThemeData> {
  SharedPreferences? _prefs;

  @override
  TunerThemeData build() {
    final startup = ref.read(startupThemeProvider);
    if (startup != null) return startup;
    _load();
    return TunerThemes.linen;
  }

  Future<void> _load() async {
    try {
      final theme = await resolveStartupTheme();
      if (ref.mounted) state = theme;
    } catch (e) {
      debugPrint('ThemeNotifier: failed to load saved theme: $e');
    }
  }

  Future<void> setTheme(TunerThemeData theme) async {
    state = theme;
    try {
      _prefs ??= await SharedPreferences.getInstance();
      await _prefs!.setString(_kThemeKey, theme.id);
    } catch (e) {
      debugPrint('ThemeNotifier: failed to save theme: $e');
    }
  }

  /// Switches to the paired theme of the other brightness
  /// (Maple ↔ Mahogany, Spruce ↔ Walnut, Linen ↔ Blueprint, Milk ↔ Void).
  Future<void> toggleDarkMode() async {
    final goingDark = state.brightness != Brightness.dark;
    final next =
        TunerThemes.darkModePairs[state.id] ??
        (goingDark ? TunerThemes.blueprint : TunerThemes.linen);
    await setTheme(next);
  }
}
