import 'package:flutter_test/flutter_test.dart';
import 'package:harp_tuner/models/harp_string_model.dart';
import 'package:harp_tuner/models/harp_type.dart';
import 'package:harp_tuner/providers/tuner_provider.dart';

void main() {
  // ── Default values ────────────────────────────────────────────────────────────

  group('TunerState — default values', () {
    test('isListening defaults to false', () {
      expect(const TunerState().isListening, false);
    });
    test('permissionDenied defaults to false', () {
      expect(const TunerState().permissionDenied, false);
    });
    test('preferFlats defaults to false', () {
      expect(const TunerState().preferFlats, false);
    });
    test('showOctave defaults to false', () {
      expect(const TunerState().showOctave, false);
    });
    test('a4Hz defaults to 440', () {
      expect(const TunerState().a4Hz, 440);
    });
    test('leverStringCount defaults to 34', () {
      expect(const TunerState().leverStringCount, 34);
    });
    test('selectedHarp defaults to null', () {
      expect(const TunerState().selectedHarp, isNull);
    });
    test('tunerMode defaults to auto', () {
      expect(const TunerState().tunerMode, TunerMode.auto);
    });
    test('referenceString defaults to null', () {
      expect(const TunerState().referenceString, isNull);
    });
    test('isPlayingTone defaults to false', () {
      expect(const TunerState().isPlayingTone, false);
    });
    test('cents defaults to null', () {
      expect(const TunerState().cents, isNull);
    });
    test('detectedHz defaults to null', () {
      expect(const TunerState().detectedHz, isNull);
    });
    test('closestNoteName defaults to null', () {
      expect(const TunerState().closestNoteName, isNull);
    });
    test('micError defaults to null', () {
      expect(const TunerState().micError, isNull);
    });
    test('isStale defaults to false', () {
      expect(const TunerState().isStale, false);
    });
    test('showTuningReminder defaults to true', () {
      expect(const TunerState().showTuningReminder, true);
    });
  });

  // ── copyWith — simple field updates ───────────────────────────────────────────

  group('TunerState.copyWith — boolean fields', () {
    test('isListening toggles correctly', () {
      final s = const TunerState().copyWith(isListening: true);
      expect(s.isListening, true);
    });
    test('permissionDenied toggles correctly', () {
      final s = const TunerState().copyWith(permissionDenied: true);
      expect(s.permissionDenied, true);
    });
    test('preferFlats toggles correctly', () {
      final s = const TunerState().copyWith(preferFlats: true);
      expect(s.preferFlats, true);
    });
    test('showOctave toggles correctly', () {
      final s = const TunerState().copyWith(showOctave: true);
      expect(s.showOctave, true);
    });
    test('isPlayingTone toggles correctly', () {
      final s = const TunerState().copyWith(isPlayingTone: true);
      expect(s.isPlayingTone, true);
    });
    test('isStale toggles correctly', () {
      final s = const TunerState().copyWith(isStale: true);
      expect(s.isStale, true);
    });
    test('showTuningReminder updates to false', () {
      final s = const TunerState().copyWith(showTuningReminder: false);
      expect(s.showTuningReminder, false);
    });
  });

  group('TunerState.copyWith — numeric fields', () {
    test('a4Hz updates', () {
      final s = const TunerState().copyWith(a4Hz: 442);
      expect(s.a4Hz, 442);
    });
    test('leverStringCount updates', () {
      final s = const TunerState().copyWith(leverStringCount: 40);
      expect(s.leverStringCount, 40);
    });
    test('cents updates', () {
      final s = const TunerState().copyWith(cents: -12.5);
      expect(s.cents, -12.5);
    });
    test('detectedHz updates', () {
      final s = const TunerState().copyWith(detectedHz: 440.0);
      expect(s.detectedHz, 440.0);
    });
  });

  group('TunerState.copyWith — reference / nullable fields', () {
    test('selectedHarp updates', () {
      final s = const TunerState().copyWith(selectedHarp: HarpType.pedalHarp);
      expect(s.selectedHarp, HarpType.pedalHarp);
    });
    test('tunerMode updates to reference', () {
      final s = const TunerState().copyWith(tunerMode: TunerMode.reference);
      expect(s.tunerMode, TunerMode.reference);
    });
    test('closestNoteName updates', () {
      final s = const TunerState().copyWith(closestNoteName: 'A4');
      expect(s.closestNoteName, 'A4');
    });
    test('micError updates', () {
      final s = const TunerState().copyWith(micError: 'No mic');
      expect(s.micError, 'No mic');
    });
    test('referenceString updates', () {
      const string =
          HarpStringModel(index: 1, note: NoteName.a, octave: 4);
      final s = const TunerState().copyWith(referenceString: string);
      expect(s.referenceString, string);
    });
  });

  // ── copyWith — clear flags ─────────────────────────────────────────────────────

  group('TunerState.copyWith — clearSelectedHarp', () {
    test('clearSelectedHarp=true removes selectedHarp', () {
      const state = TunerState(selectedHarp: HarpType.leverHarp);
      final s = state.copyWith(clearSelectedHarp: true);
      expect(s.selectedHarp, isNull);
    });
    test('clearSelectedHarp=false preserves selectedHarp', () {
      const state = TunerState(selectedHarp: HarpType.leverHarp);
      final s = state.copyWith(clearSelectedHarp: false);
      expect(s.selectedHarp, HarpType.leverHarp);
    });
  });

  group('TunerState.copyWith — clearReferenceString', () {
    const string = HarpStringModel(index: 1, note: NoteName.a, octave: 4);
    test('clearReferenceString=true removes referenceString', () {
      final state = const TunerState().copyWith(referenceString: string);
      final s = state.copyWith(clearReferenceString: true);
      expect(s.referenceString, isNull);
    });
  });

  group('TunerState.copyWith — clearPitch', () {
    final baseState = const TunerState().copyWith(
      cents: 10.0,
      detectedHz: 440.0,
      closestNoteName: 'A4',
      micError: 'err',
      isStale: true,
    );

    test('clearPitch=true clears cents, detectedHz, closestNoteName, isStale',
        () {
      final s = baseState.copyWith(clearPitch: true);
      expect(s.cents, isNull);
      expect(s.detectedHz, isNull);
      expect(s.closestNoteName, isNull);
      expect(s.isStale, false);
    });

    test('clearPitch=true also clears micError', () {
      final s = baseState.copyWith(clearPitch: true);
      expect(s.micError, isNull);
    });
  });

  group('TunerState.copyWith — clearMicError', () {
    test('clearMicError=true clears micError only', () {
      final state = const TunerState().copyWith(
        micError: 'some error',
        cents: 5.0,
      );
      final s = state.copyWith(clearMicError: true);
      expect(s.micError, isNull);
      expect(s.cents, 5.0); // other fields preserved
    });
  });

  // ── Immutability ──────────────────────────────────────────────────────────────

  group('TunerState immutability', () {
    test('copyWith returns a new object', () {
      const state = TunerState();
      final updated = state.copyWith(showTuningReminder: false);
      expect(state.showTuningReminder, true);
      expect(updated.showTuningReminder, false);
    });

    test('original state is unchanged after multi-field copyWith', () {
      const state = TunerState(a4Hz: 440, preferFlats: false);
      state.copyWith(a4Hz: 442, preferFlats: true);
      expect(state.a4Hz, 440);
      expect(state.preferFlats, false);
    });
  });
}
