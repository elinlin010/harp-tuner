import 'package:flutter_test/flutter_test.dart';
import 'package:harp_tuner/providers/tuner_provider.dart';

void main() {
  group('TunerState.showTuningReminder', () {
    test('defaults to true', () {
      const state = TunerState();
      expect(state.showTuningReminder, true);
    });

    test('copyWith updates to false', () {
      const state = TunerState();
      final updated = state.copyWith(showTuningReminder: false);
      expect(updated.showTuningReminder, false);
    });

    test('copyWith updates to true', () {
      const state = TunerState(showTuningReminder: false);
      final updated = state.copyWith(showTuningReminder: true);
      expect(updated.showTuningReminder, true);
    });

    test('copyWith preserves value when null is passed', () {
      const state = TunerState(showTuningReminder: false);
      // Not passing showTuningReminder should preserve false
      final updated = state.copyWith(isStale: true);
      expect(updated.showTuningReminder, false);
    });

    test('other copyWith fields do not affect showTuningReminder', () {
      const state = TunerState(showTuningReminder: false);
      final updated = state.copyWith(
        preferFlats: true,
        showOctave: true,
        a4Hz: 442,
      );
      expect(updated.showTuningReminder, false);
    });
  });

  group('TunerState immutability', () {
    test('copyWith returns a new object', () {
      const state = TunerState();
      final updated = state.copyWith(showTuningReminder: false);
      // Original must be unchanged
      expect(state.showTuningReminder, true);
      expect(updated.showTuningReminder, false);
    });
  });
}
