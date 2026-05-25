import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harp_tuner/providers/locale_provider.dart';
import 'package:harp_tuner/theme/app_theme.dart';
import 'package:harp_tuner/theme/theme_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

ProviderContainer _container() {
  final c = ProviderContainer();
  addTearDown(c.dispose);
  return c;
}

void main() {
  // ── AppColors ────────────────────────────────────────────────────────────────

  group('AppColors.octaveColor', () {
    test('octave 1 returns first color', () {
      expect(AppColors.octaveColor(1), AppColors.octaveColors[0]);
    });

    test('octave below 1 is clamped to index 0', () {
      expect(AppColors.octaveColor(0), AppColors.octaveColors[0]);
    });

    test('octave above max is clamped to last color', () {
      final last = AppColors.octaveColors.length;
      expect(AppColors.octaveColor(100), AppColors.octaveColors[last - 1]);
    });
  });

  // ── ThemeNotifier ─────────────────────────────────────────────────────────────

  group('ThemeNotifier — initial state', () {
    test('defaults to linen theme', () {
      SharedPreferences.setMockInitialValues({});
      final c = _container();
      expect(c.read(tunerThemeProvider), equals(TunerThemes.linen));
    });
  });

  group('ThemeNotifier.setTheme', () {
    test('updates state to blueprint', () async {
      SharedPreferences.setMockInitialValues({});
      final c = _container();
      await c.read(tunerThemeProvider.notifier).setTheme(TunerThemes.blueprint);
      expect(c.read(tunerThemeProvider), equals(TunerThemes.blueprint));
    });

    test('updates state to void_ (dark)', () async {
      SharedPreferences.setMockInitialValues({});
      final c = _container();
      await c.read(tunerThemeProvider.notifier).setTheme(TunerThemes.void_);
      expect(c.read(tunerThemeProvider), equals(TunerThemes.void_));
    });
  });

  group('ThemeNotifier.toggleDarkMode', () {
    test('toggles from light to dark', () async {
      SharedPreferences.setMockInitialValues({});
      final c = _container();
      expect(c.read(tunerThemeProvider).brightness, Brightness.light);
      await c.read(tunerThemeProvider.notifier).toggleDarkMode();
      expect(c.read(tunerThemeProvider).brightness, Brightness.dark);
    });

    test('toggles from dark back to light', () async {
      SharedPreferences.setMockInitialValues({'theme_id': 'blueprint'});
      final c = _container();
      await c.read(tunerThemeProvider.notifier).setTheme(TunerThemes.blueprint);
      await c.read(tunerThemeProvider.notifier).toggleDarkMode();
      expect(c.read(tunerThemeProvider).brightness, Brightness.light);
    });
  });

  // ── LocaleNotifier ────────────────────────────────────────────────────────────

  group('LocaleNotifier — initial state', () {
    test('defaults to English locale', () {
      SharedPreferences.setMockInitialValues({});
      final c = _container();
      expect(c.read(localeProvider), equals(const Locale('en')));
    });
  });

  group('LocaleNotifier.setLocale', () {
    test('updates state to French', () async {
      SharedPreferences.setMockInitialValues({});
      final c = _container();
      await c.read(localeProvider.notifier).setLocale(const Locale('fr'));
      expect(c.read(localeProvider), equals(const Locale('fr')));
    });

    test('updates state to zh_TW locale with country code', () async {
      SharedPreferences.setMockInitialValues({});
      final c = _container();
      await c.read(localeProvider.notifier).setLocale(const Locale('zh', 'TW'));
      expect(c.read(localeProvider), equals(const Locale('zh', 'TW')));
    });
  });
}
