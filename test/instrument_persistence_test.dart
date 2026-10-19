import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harp_tuner/models/harp_type.dart';
import 'package:harp_tuner/providers/tuner_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_screen_wake.dart';

// ignore_for_file: invalid_use_of_visible_for_testing_member

class _FakeNotifier extends TunerNotifier {
  _FakeNotifier([this._initial]);
  final TunerState? _initial;

  @override
  TunerState build() {
    final s = super.build();
    injectServicesForTest(screenWake: FakeScreenWake());
    return _initial ?? s;
  }
}

Future<ProviderContainer> _container({TunerState? initial}) async {
  final c = ProviderContainer(
    overrides: [tunerProvider.overrideWith(() => _FakeNotifier(initial))],
  );
  addTearDown(c.dispose);
  c.read(tunerProvider);
  // Let _loadPrefs finish.
  for (var i = 0; i < 5; i++) {
    await Future<void>.delayed(Duration.zero);
  }
  return c;
}

void main() {
  group('Instrument persistence', () {
    test('first launch defaults to the lever harp', () async {
      SharedPreferences.setMockInitialValues({});
      final c = await _container();
      expect(c.read(tunerProvider).selectedHarp, HarpType.leverHarp);
    });

    test('"None" survives an app restart', () async {
      SharedPreferences.setMockInitialValues({'tuner_harp_type': 'leverHarp'});
      final first = await _container();
      await first.read(tunerProvider.notifier).setSelectedHarp(null);
      expect(first.read(tunerProvider).selectedHarp, isNull);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('tuner_harp_type'), 'none');

      // Reopen: a fresh notifier reads the same prefs.
      final reopened = await _container();
      expect(reopened.read(tunerProvider).selectedHarp, isNull);
    });

    test('a saved harp survives an app restart', () async {
      SharedPreferences.setMockInitialValues({});
      final first = await _container();
      await first.read(tunerProvider.notifier).setSelectedHarp(HarpType.pedalHarp);

      final reopened = await _container();
      expect(reopened.read(tunerProvider).selectedHarp, HarpType.pedalHarp);
    });

    test('picking a harp after "None" replaces the stored value', () async {
      SharedPreferences.setMockInitialValues({'tuner_harp_type': 'none'});
      final c = await _container();
      expect(c.read(tunerProvider).selectedHarp, isNull);
      await c.read(tunerProvider.notifier).setSelectedHarp(HarpType.leverHarp);

      final reopened = await _container();
      expect(reopened.read(tunerProvider).selectedHarp, HarpType.leverHarp);
    });

    test('"none" clears a harp already in state when prefs load', () async {
      SharedPreferences.setMockInitialValues({'tuner_harp_type': 'none'});
      final c = await _container(
          initial: const TunerState(selectedHarp: HarpType.leverHarp));
      expect(c.read(tunerProvider).selectedHarp, isNull);
    });
  });
}
