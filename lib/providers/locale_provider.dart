import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kLocaleKey = 'app_locale';

final localeProvider = StateNotifierProvider<LocaleNotifier, Locale>(
  (ref) => LocaleNotifier(),
);

class LocaleNotifier extends StateNotifier<Locale> {
  SharedPreferences? _prefs;

  LocaleNotifier() : super(const Locale('en')) {
    _load();
  }

  Future<void> _load() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      final stored = _prefs!.getString(_kLocaleKey);
      if (stored == null) return;
      final parts = stored.split('_');
      state = parts.length == 2 ? Locale(parts[0], parts[1]) : Locale(parts[0]);
    } catch (e) {
      debugPrint('LocaleNotifier: failed to load saved locale: $e');
    }
  }

  Future<void> setLocale(Locale locale) async {
    state = locale;
    try {
      _prefs ??= await SharedPreferences.getInstance();
      final key = (locale.countryCode?.isNotEmpty ?? false)
          ? '${locale.languageCode}_${locale.countryCode}'
          : locale.languageCode;
      await _prefs!.setString(_kLocaleKey, key);
    } catch (e) {
      debugPrint('LocaleNotifier: failed to save locale: $e');
    }
  }
}
