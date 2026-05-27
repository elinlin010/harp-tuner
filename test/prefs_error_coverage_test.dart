import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harp_tuner/models/harp_type.dart';
import 'package:harp_tuner/providers/locale_provider.dart';
import 'package:harp_tuner/providers/tuner_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

// A SharedPreferencesStorePlatform that throws on every operation.
// Setting isMock=true bypasses PlatformInterface.verify().
class _ThrowingPrefsStore extends SharedPreferencesStorePlatform {
  @override
  bool get isMock => true;

  @override
  Future<bool> clear() async => throw Exception('test-prefs-throw');

  @override
  Future<Map<String, Object>> getAll() async =>
      throw Exception('test-prefs-throw');

  @override
  Future<bool> remove(String key) async => throw Exception('test-prefs-throw');

  @override
  Future<bool> setValue(String valueType, String key, Object value) async =>
      throw Exception('test-prefs-throw');
}

// Reset singleton (_completer=null) then install a throwing store so that the
// very next getInstance() call throws, causing every notifier's _load* to hit
// its catch block.
void _installThrowingStore() {
  SharedPreferences.setMockInitialValues({});
  SharedPreferencesStorePlatform.instance = _ThrowingPrefsStore();
}

void main() {
  // ── LocaleNotifier catch blocks ─────────────────────────────────────────────

  group('SharedPreferences error — LocaleNotifier catch blocks', () {
    tearDown(() => SharedPreferences.setMockInitialValues({}));

    test('_load catch (line 28): logs on getInstance failure', () async {
      _installThrowingStore();
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(localeProvider);
      await Future.delayed(Duration.zero);
    });

    test('setLocale catch (line 41): logs on save failure', () async {
      _installThrowingStore();
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(localeProvider);
      await Future.delayed(Duration.zero);
      // _prefs is null → ??= getInstance() throws → catch fires
      await container.read(localeProvider.notifier).setLocale(const Locale('fr'));
    });
  });

  // ── TunerNotifier settings catch blocks ────────────────────────────────────

  group('SharedPreferences error — TunerNotifier settings catch blocks', () {
    late ProviderContainer container;

    setUp(() async {
      _installThrowingStore();
      container = ProviderContainer();
      container.read(tunerProvider); // triggers build() → _loadPrefs() throws
      await Future.delayed(Duration.zero); // let _loadPrefs() async throw
    });

    tearDown(() {
      container.dispose();
      SharedPreferences.setMockInitialValues({});
    });

    test('toggleShowOctave catch (line 364)', () async {
      await container.read(tunerProvider.notifier).toggleShowOctave();
    });

    test('togglePreferFlats catch (line 389)', () async {
      await container.read(tunerProvider.notifier).togglePreferFlats();
    });

    test('setA4Hz catch (line 414)', () async {
      await container.read(tunerProvider.notifier).setA4Hz(442);
    });

    test('setLeverStringCount catch (line 425)', () async {
      await container.read(tunerProvider.notifier).setLeverStringCount(36);
    });

    test('toggleShowTuningReminder catch (line 436)', () async {
      await container.read(tunerProvider.notifier).toggleShowTuningReminder();
    });

    test('setSelectedHarp catch (line 465)', () async {
      await container
          .read(tunerProvider.notifier)
          .setSelectedHarp(HarpType.leverHarp);
    });
  });
}
