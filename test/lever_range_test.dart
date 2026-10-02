import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harp_tuner/data/harp_presets.dart';
import 'package:harp_tuner/models/harp_string_model.dart';
import 'package:harp_tuner/providers/tuner_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_screen_wake.dart';

// ignore_for_file: invalid_use_of_visible_for_testing_member

class _FakeNotifier extends TunerNotifier {
  @override
  TunerState build() {
    final s = super.build();
    injectServicesForTest(screenWake: FakeScreenWake());
    return s;
  }
}

Future<ProviderContainer> _container() async {
  final c = ProviderContainer(
    overrides: [tunerProvider.overrideWith(() => _FakeNotifier())],
  );
  addTearDown(c.dispose);
  c.read(tunerProvider);
  // Let _loadPrefs finish.
  for (var i = 0; i < 5; i++) {
    await Future<void>.delayed(Duration.zero);
  }
  return c;
}

int _poolIndex(NoteName note, int octave) => HarpPresets.leverPool
    .indexWhere((s) => s.note == note && s.octave == octave);

List<String> _labels(List<HarpStringModel> s) => [s.first.label, s.last.label];

void main() {
  group('HarpPresets lever range', () {
    test('pool is 40 strings, A♭1–E♭7', () {
      expect(HarpPresets.leverPool.length, 40);
      expect(_labels(HarpPresets.leverPool), ['6A♭', '1E♭']);
    });

    test('23 strings default to 4G–1A♭ (G3–A♭6)', () {
      final strings = HarpPresets.leverHarpWithCount(23);
      expect(strings.length, 23);
      expect(_labels(strings), ['4G', '1A♭']);
      expect(strings.first.octave, 3);
      expect(strings.last.octave, 6);
    });

    test('other counts keep E♭7 as the top string', () {
      for (final count in [19, 22, 24, 34, 40]) {
        expect(HarpPresets.leverHarpWithCount(count).last.label, '1E♭',
            reason: '$count strings');
      }
    });

    test('custom top index shifts the window', () {
      final top = _poolIndex(NoteName.c, 7);
      final strings = HarpPresets.leverHarp(34, topIndex: top);
      expect(strings.length, 34);
      expect(strings.last.note, NoteName.c);
      expect(strings.last.octave, 7);
      expect(strings.first.index, 1);
    });

    test('top index is clamped so the window fits the pool', () {
      // 40 strings can only end at E♭7.
      expect(HarpPresets.leverRange(40, 10), (40, 39));
      expect(HarpPresets.leverRange(19, 99), (19, 39));
      expect(HarpPresets.leverRange(5, null), (19, 39));
    });
  });

  group('TunerNotifier lever range', () {
    test('setLeverRange sets count and top, and persists them', () async {
      SharedPreferences.setMockInitialValues({});
      final c = await _container();
      final bottom = _poolIndex(NoteName.c, 3);
      final top = _poolIndex(NoteName.g, 6);
      await c.read(tunerProvider.notifier).setLeverRange(bottom, top);

      final s = c.read(tunerProvider);
      expect(s.leverStringCount, top - bottom + 1);
      expect(s.leverTopIndex, top);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('tuner_lever_string_count'), top - bottom + 1);
      expect(prefs.getInt('tuner_lever_top_index'), top);
    });

    test('setLeverRange ignores spans outside 19–40 strings', () async {
      SharedPreferences.setMockInitialValues({});
      final c = await _container();
      final n = c.read(tunerProvider.notifier);
      await n.setLeverRange(20, 30); // 11 strings
      await n.setLeverRange(-1, 30);
      await n.setLeverRange(10, 40);
      final s = c.read(tunerProvider);
      expect(s.leverStringCount, 34);
      expect(s.leverTopIndex, isNull);
    });

    test('a picked range stays custom even when it matches a default',
        () async {
      SharedPreferences.setMockInitialValues({});
      final c = await _container();
      final top = _poolIndex(NoteName.a, 6);
      // 23 strings G3–A♭6 is exactly the 23-string default.
      await c.read(tunerProvider.notifier)
          .setLeverRange(_poolIndex(NoteName.g, 3), top);
      final s = c.read(tunerProvider);
      expect(s.leverStringCount, 23);
      expect(s.leverTopIndex, top);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('tuner_lever_top_index'), top);
    });

    test('a custom top survives the slider passing through 23', () async {
      SharedPreferences.setMockInitialValues({});
      final c = await _container();
      final n = c.read(tunerProvider.notifier);
      final a6 = _poolIndex(NoteName.a, 6);
      await n.setLeverRange(a6 - 29, a6); // 30 strings ending at A♭6
      for (final count in [23, 24, 23, 30]) {
        await n.setLeverStringCount(count);
        expect(c.read(tunerProvider).leverTopIndex, a6, reason: '$count');
      }

      final eb7 = HarpPresets.leverPool.length - 1;
      await n.setLeverRange(eb7 - 22, eb7); // 23 strings ending at E♭7
      await n.setLeverStringCount(24);
      await n.setLeverStringCount(23);
      expect(
          _labels(HarpPresets.leverHarp(23,
              topIndex: c.read(tunerProvider).leverTopIndex)),
          ['4D', '1E♭']);
    });

    test('setLeverStringCount keeps a custom top string', () async {
      SharedPreferences.setMockInitialValues({});
      final c = await _container();
      final n = c.read(tunerProvider.notifier);
      final top = _poolIndex(NoteName.c, 7);
      await n.setLeverRange(top - 29, top); // 30 strings ending at C7
      await n.setLeverStringCount(25);
      final s = c.read(tunerProvider);
      expect(s.leverStringCount, 25);
      expect(s.leverTopIndex, top);
    });

    test('setLeverStringCount on the default range uses the count default',
        () async {
      SharedPreferences.setMockInitialValues({});
      final c = await _container();
      await c.read(tunerProvider.notifier).setLeverStringCount(23);
      final s = c.read(tunerProvider);
      expect(s.leverTopIndex, isNull);
      expect(
          _labels(HarpPresets.leverHarp(s.leverStringCount,
              topIndex: s.leverTopIndex)),
          ['4G', '1A♭']);
    });

    test('saved range is restored on launch', () async {
      final top = _poolIndex(NoteName.d, 7);
      SharedPreferences.setMockInitialValues({
        'tuner_lever_string_count': 26,
        'tuner_lever_top_index': top,
      });
      final c = await _container();
      final s = c.read(tunerProvider);
      expect(s.leverStringCount, 26);
      expect(s.leverTopIndex, top);
    });
  });

  group('TunerNotifier lever range migration', () {
    test('a pre-range 23-string install keeps 4D–1E♭', () async {
      SharedPreferences.setMockInitialValues({'tuner_lever_string_count': 23});
      final c = await _container();
      final s = c.read(tunerProvider);
      expect(s.leverStringCount, 23);
      expect(
          _labels(HarpPresets.leverHarp(23, topIndex: s.leverTopIndex)),
          ['4D', '1E♭']);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('tuner_lever_top_index'), 39);
      expect(prefs.getBool('tuner_lever_range_migrated'), isTrue);
    });

    test('other pre-range counts keep following their default', () async {
      SharedPreferences.setMockInitialValues({'tuner_lever_string_count': 34});
      final c = await _container();
      expect(c.read(tunerProvider).leverTopIndex, isNull);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey('tuner_lever_top_index'), isFalse);
      expect(prefs.getBool('tuner_lever_range_migrated'), isTrue);
    });

    test('23 strings chosen after the migration get 4G–1A♭', () async {
      SharedPreferences.setMockInitialValues({
        'tuner_lever_string_count': 23,
        'tuner_lever_range_migrated': true,
      });
      final c = await _container();
      final s = c.read(tunerProvider);
      expect(s.leverTopIndex, isNull);
      expect(
          _labels(HarpPresets.leverHarp(23, topIndex: s.leverTopIndex)),
          ['4G', '1A♭']);
    });

    test('a fresh install that picks 23 strings gets 4G–1A♭', () async {
      SharedPreferences.setMockInitialValues({});
      final c = await _container();
      await c.read(tunerProvider.notifier).setLeverStringCount(23);
      expect(c.read(tunerProvider).leverTopIndex, isNull);

      // Next launch: the migration already ran, so nothing changes.
      final c2 = await _container();
      final s = c2.read(tunerProvider);
      expect(s.leverStringCount, 23);
      expect(s.leverTopIndex, isNull);
    });
  });
}
