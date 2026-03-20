import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_theme.dart';

const _kThemeKey = 'theme_id';

final tunerThemeProvider = StateNotifierProvider<ThemeNotifier, TunerThemeData>(
  (ref) => ThemeNotifier(),
);

class ThemeNotifier extends StateNotifier<TunerThemeData> {
  SharedPreferences? _prefs;

  ThemeNotifier() : super(TunerThemes.linen) {
    _load();
  }

  Future<void> _load() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      final id = _prefs!.getString(_kThemeKey);
      if (id == null) return;
      final found = TunerThemes.all.where((t) => t.id == id).firstOrNull;
      if (found != null) state = found;
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

  /// Toggles between light and dark, keeping the same theme if possible.
  /// Falls back to linen (light) or blueprint (dark) if no match.
  Future<void> toggleDarkMode() async {
    final goingDark = state.brightness != Brightness.dark;
    final targetBrightness =
        goingDark ? Brightness.dark : Brightness.light;
    // Try to keep a same-brightness equivalent; otherwise pick the default.
    final next = TunerThemes.all.firstWhere(
      (t) => t.brightness == targetBrightness,
      orElse: () => goingDark ? TunerThemes.blueprint : TunerThemes.linen,
    );
    await setTheme(next);
  }
}
