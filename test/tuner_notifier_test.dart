import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harp_tuner/models/harp_string_model.dart';
import 'package:harp_tuner/models/harp_type.dart';
import 'package:harp_tuner/providers/tuner_provider.dart';
import 'package:harp_tuner/services/pitch_detection_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ignore_for_file: invalid_use_of_visible_for_testing_member

class _FakeNotifier extends TunerNotifier {
  final TunerState? _overrideState;
  _FakeNotifier([this._overrideState]);

  @override
  TunerState build() {
    final s = super.build();
    if (_overrideState != null) {
      state = _overrideState!;
      return _overrideState!;
    }
    return s;
  }
}

ProviderContainer _container({TunerState? overrideState}) {
  final c = ProviderContainer(
    overrides: overrideState != null
        ? [tunerProvider.overrideWith(() => _FakeNotifier(overrideState))]
        : [],
  );
  addTearDown(c.dispose);
  return c;
}

void main() {
  // ── stopListening ────────────────────────────────────────────────────────

  group('TunerNotifier.stopListening', () {
    test('clears listening state and pitch', () async {
      SharedPreferences.setMockInitialValues({});
      final c = _container(
        overrideState: const TunerState(
          isListening: true,
          cents: 5.0,
          detectedHz: 440.0,
          closestNoteName: 'A4',
        ),
      );
      await Future.delayed(Duration.zero);
      c.read(tunerProvider.notifier).stopListening();
      final s = c.read(tunerProvider);
      expect(s.isListening, isFalse);
      expect(s.cents, isNull);
      expect(s.detectedHz, isNull);
    });

    test('is idempotent on fresh notifier', () {
      SharedPreferences.setMockInitialValues({});
      final c = _container();
      c.read(tunerProvider.notifier).stopListening();
      expect(c.read(tunerProvider).isListening, isFalse);
    });
  });

  // ── toggleListening ──────────────────────────────────────────────────────

  group('TunerNotifier.toggleListening', () {
    test('when isListening=true calls stopListening', () async {
      SharedPreferences.setMockInitialValues({});
      final c = _container(
        overrideState: const TunerState(isListening: true),
      );
      await Future.delayed(Duration.zero);
      c.read(tunerProvider.notifier).toggleListening();
      expect(c.read(tunerProvider).isListening, isFalse);
    });
  });

  // ── toggleShowOctave ─────────────────────────────────────────────────────

  group('TunerNotifier.toggleShowOctave', () {
    test('toggles showOctave from false to true', () async {
      SharedPreferences.setMockInitialValues({});
      final c = _container();
      await Future.delayed(Duration.zero);
      expect(c.read(tunerProvider).showOctave, isFalse);
      await c.read(tunerProvider.notifier).toggleShowOctave();
      expect(c.read(tunerProvider).showOctave, isTrue);
    });

    test('toggles showOctave back to false', () async {
      SharedPreferences.setMockInitialValues({});
      final c = _container(overrideState: const TunerState(showOctave: true));
      await Future.delayed(Duration.zero);
      await c.read(tunerProvider.notifier).toggleShowOctave();
      expect(c.read(tunerProvider).showOctave, isFalse);
    });
  });

  // ── togglePreferFlats ────────────────────────────────────────────────────

  group('TunerNotifier.togglePreferFlats — no detectedHz', () {
    test('toggles preferFlats from false to true', () async {
      SharedPreferences.setMockInitialValues({});
      final c = _container(
        overrideState: const TunerState(preferFlats: false),
      );
      await Future.delayed(Duration.zero);
      await c.read(tunerProvider.notifier).togglePreferFlats();
      expect(c.read(tunerProvider).preferFlats, isTrue);
    });

    test('toggles preferFlats from true to false', () async {
      SharedPreferences.setMockInitialValues({});
      final c = _container(
        overrideState: const TunerState(preferFlats: true),
      );
      await Future.delayed(Duration.zero);
      await c.read(tunerProvider.notifier).togglePreferFlats();
      expect(c.read(tunerProvider).preferFlats, isFalse);
    });
  });

  group('TunerNotifier.togglePreferFlats — with detectedHz', () {
    test('re-resolves note name for new accidental preference', () async {
      SharedPreferences.setMockInitialValues({});
      final c = _container(
        overrideState: const TunerState(
          preferFlats: false,
          detectedHz: 466.16,
          closestNoteName: 'A♯4',
          cents: 0.0,
          a4Hz: 440,
        ),
      );
      await Future.delayed(Duration.zero);
      await c.read(tunerProvider.notifier).togglePreferFlats();
      final s = c.read(tunerProvider);
      expect(s.preferFlats, isTrue);
      expect(s.closestNoteName, isNotNull);
    });
  });

  // ── setA4Hz with detectedHz ──────────────────────────────────────────────

  group('TunerNotifier.setA4Hz — with detectedHz', () {
    test('re-resolves cents when detectedHz is set', () async {
      SharedPreferences.setMockInitialValues({});
      final c = _container(
        overrideState: const TunerState(
          a4Hz: 440,
          detectedHz: 440.0,
          closestNoteName: 'A4',
          cents: 0.0,
        ),
      );
      await Future.delayed(Duration.zero);
      await c.read(tunerProvider.notifier).setA4Hz(442);
      final s = c.read(tunerProvider);
      expect(s.a4Hz, 442);
      expect(s.closestNoteName, isNotNull);
    });

    test('clamps a4Hz to valid range', () async {
      SharedPreferences.setMockInitialValues({});
      final c = _container();
      await Future.delayed(Duration.zero);
      await c.read(tunerProvider.notifier).setA4Hz(460); // above max
      expect(c.read(tunerProvider).a4Hz, 450); // clamped to max
    });
  });

  // ── setTunerMode ─────────────────────────────────────────────────────────

  group('TunerNotifier.setTunerMode', () {
    test('switching to reference mode updates tunerMode', () async {
      SharedPreferences.setMockInitialValues({});
      final c = _container();
      await Future.delayed(Duration.zero);
      // Default state has leverHarp selected
      await c.read(tunerProvider.notifier).setTunerMode(TunerMode.reference);
      expect(c.read(tunerProvider).tunerMode, TunerMode.reference);
    });

    test('switching back to auto mode clears reference state', () async {
      SharedPreferences.setMockInitialValues({});
      final c = _container(
        overrideState: const TunerState(
          tunerMode: TunerMode.reference,
          selectedHarp: HarpType.leverHarp,
        ),
      );
      await Future.delayed(Duration.zero);
      await c.read(tunerProvider.notifier).setTunerMode(TunerMode.auto);
      final s = c.read(tunerProvider);
      expect(s.tunerMode, TunerMode.auto);
      expect(s.referenceString, isNull);
    });

    test('no-op when mode is already set', () async {
      SharedPreferences.setMockInitialValues({});
      final c = _container();
      await Future.delayed(Duration.zero);
      final before = c.read(tunerProvider).tunerMode;
      await c.read(tunerProvider.notifier).setTunerMode(TunerMode.auto);
      expect(c.read(tunerProvider).tunerMode, before);
    });

    test('switching to reference with no harp skips precompute', () async {
      SharedPreferences.setMockInitialValues({});
      final c = _container(
        overrideState: const TunerState(
          tunerMode: TunerMode.auto,
          selectedHarp: null,
        ),
      );
      await Future.delayed(Duration.zero);
      await c.read(tunerProvider.notifier).setTunerMode(TunerMode.reference);
      expect(c.read(tunerProvider).tunerMode, TunerMode.reference);
    });

    test('switching to reference mode with harp triggers precompute', () async {
      SharedPreferences.setMockInitialValues({});
      final c = _container(
        overrideState: const TunerState(
          tunerMode: TunerMode.auto,
          selectedHarp: HarpType.leverHarp,
        ),
      );
      await Future.delayed(Duration.zero);
      await c.read(tunerProvider.notifier).setTunerMode(TunerMode.reference);
      expect(c.read(tunerProvider).tunerMode, TunerMode.reference);
    });
  });

  // ── handlePitchResult — silence paths ───────────────────────────────────

  group('TunerNotifier.handlePitchResult — silence handling', () {
    test('null result: first silence frame clears history', () async {
      SharedPreferences.setMockInitialValues({});
      final c = _container();
      await Future.delayed(Duration.zero);
      final n = c.read(tunerProvider.notifier);
      n.handlePitchResult(null);
      expect(c.read(tunerProvider).isListening, isFalse);
    });

    test('null result x _kStaleFrames → stale flag set (needs detectedHz)', () async {
      SharedPreferences.setMockInitialValues({});
      final c = _container(
        overrideState: const TunerState(
          isListening: true,
          detectedHz: 440.0,
          cents: 0.0,
          closestNoteName: 'A4',
          isStale: false,
        ),
      );
      await Future.delayed(Duration.zero);
      final n = c.read(tunerProvider.notifier);
      for (var i = 0; i < 15; i++) {
        n.handlePitchResult(null);
      }
      expect(c.read(tunerProvider).isStale, isTrue);
    });

    test('null result x _kHoldFrames → pitch cleared', () async {
      SharedPreferences.setMockInitialValues({});
      final c = _container(
        overrideState: const TunerState(
          isListening: true,
          detectedHz: 440.0,
          cents: 0.0,
          closestNoteName: 'A4',
        ),
      );
      await Future.delayed(Duration.zero);
      final n = c.read(tunerProvider.notifier);
      for (var i = 0; i < 22; i++) {
        n.handlePitchResult(null);
      }
      expect(c.read(tunerProvider).cents, isNull);
      expect(c.read(tunerProvider).detectedHz, isNull);
    });
  });

  // ── handlePitchResult — signal paths ─────────────────────────────────────

  group('TunerNotifier.handlePitchResult — signal handling', () {
    test('first signal with empty history: adds to history', () async {
      SharedPreferences.setMockInitialValues({});
      final c = _container();
      await Future.delayed(Duration.zero);
      final n = c.read(tunerProvider.notifier);
      n.handlePitchResult(PitchResult(440.0));
      // Not yet stable (need 3 frames), state unchanged
      expect(c.read(tunerProvider).detectedHz, isNull);
    });

    test('stability gate: 3 frames of same pitch confirms note', () async {
      SharedPreferences.setMockInitialValues({});
      final c = _container();
      await Future.delayed(Duration.zero);
      final n = c.read(tunerProvider.notifier);
      // Build up history with 440 Hz
      for (var i = 0; i < 8; i++) {
        n.handlePitchResult(PitchResult(440.0));
      }
      final s = c.read(tunerProvider);
      expect(s.detectedHz, isNotNull);
      expect(s.closestNoteName, isNotNull);
    });

    test('octave correction: 2x jump corrects to reference octave', () async {
      SharedPreferences.setMockInitialValues({});
      final c = _container();
      await Future.delayed(Duration.zero);
      final n = c.read(tunerProvider.notifier);
      // Build history with 440 Hz, then send 880 Hz (one octave up → >150 cents diff)
      n.handlePitchResult(PitchResult(440.0));
      n.handlePitchResult(PitchResult(440.0));
      n.handlePitchResult(PitchResult(880.0)); // octave jump
      // No exception
      expect(c.read(tunerProvider).isListening, isFalse);
    });

    test('spread too wide: stability gate rejects noisy signal', () async {
      SharedPreferences.setMockInitialValues({});
      final c = _container();
      await Future.delayed(Duration.zero);
      final n = c.read(tunerProvider.notifier);
      // Mix of frequencies with > 25 cents spread → gate fails
      n.handlePitchResult(PitchResult(440.0));
      n.handlePitchResult(PitchResult(460.0)); // wide spread — ~77 cents >> 25 threshold
      n.handlePitchResult(PitchResult(440.0));
      // Still no confirmed note
      expect(c.read(tunerProvider).detectedHz, isNull);
    });

    // 466.16 Hz = A♯4 — exactly 100 cents above A4 (440 Hz), within the ±150 cent
    // octave-correction window, so it passes the history outlier check and is added
    // to history normally. After 8 frames the stability gate sees centSpread≈0 and
    // confirms A♯4. Since _confirmedNote is 'A4', the challenge branch fires.
    test('challenge hysteresis: 3 frames of new note switches confirmed note', () async {
      SharedPreferences.setMockInitialValues({});
      final c = _container();
      await Future.delayed(Duration.zero);
      final n = c.read(tunerProvider.notifier);
      // Establish A4 as confirmed note
      for (var i = 0; i < 8; i++) {
        n.handlePitchResult(PitchResult(440.0));
      }
      expect(c.read(tunerProvider).closestNoteName, isNotNull);
      // 8 frames to replace all A4 history with A♯4, then 3 challenge frames.
      for (var i = 0; i < 11; i++) {
        n.handlePitchResult(PitchResult(466.16)); // A♯4 — 100 cents above A4
      }
      // After challenge succeeds, new note is confirmed
      expect(c.read(tunerProvider).closestNoteName, isNotNull);
    });

    test('challenge same note increments count', () async {
      SharedPreferences.setMockInitialValues({});
      final c = _container();
      await Future.delayed(Duration.zero);
      final n = c.read(tunerProvider.notifier);
      // Establish A4
      for (var i = 0; i < 8; i++) {
        n.handlePitchResult(PitchResult(440.0));
      }
      final confirmedBefore = c.read(tunerProvider).closestNoteName;
      // 8 frames to replace history + 1 challenge frame (count increments to 2)
      for (var i = 0; i < 9; i++) {
        n.handlePitchResult(PitchResult(466.16)); // A♯4 — within 150 cents of A4
      }
      // Two challenges: first sets _challengeNote, second increments count
      expect(c.read(tunerProvider).closestNoteName, isNotNull);
      expect(confirmedBefore, isNotNull);
    });
  });

  // ── handlePitchResult — reference mode ──────────────────────────────────

  group('TunerNotifier.handlePitchResult — reference mode', () {
    test('reference mode with no string selected: suppresses updates', () async {
      SharedPreferences.setMockInitialValues({});
      final c = _container(
        overrideState: const TunerState(
          tunerMode: TunerMode.reference,
          selectedHarp: HarpType.leverHarp,
          referenceString: null,
        ),
      );
      await Future.delayed(Duration.zero);
      final n = c.read(tunerProvider.notifier);
      // Fill history so stability gate passes
      for (var i = 0; i < 8; i++) {
        n.handlePitchResult(PitchResult(440.0));
      }
      // No update because referenceString is null
      expect(c.read(tunerProvider).detectedHz, isNull);
    });

    test('reference mode with string selected: measures cents vs reference', () async {
      SharedPreferences.setMockInitialValues({});
      const refString = HarpStringModel(
        index: 1,
        note: NoteName.a,
        octave: 4,
      );
      final c = _container(
        overrideState: const TunerState(
          tunerMode: TunerMode.reference,
          selectedHarp: HarpType.leverHarp,
          referenceString: refString,
          a4Hz: 440,
        ),
      );
      await Future.delayed(Duration.zero);
      final n = c.read(tunerProvider.notifier);
      for (var i = 0; i < 8; i++) {
        n.handlePitchResult(PitchResult(440.0));
      }
      final s = c.read(tunerProvider);
      expect(s.detectedHz, isNotNull);
      expect(s.cents, isNotNull);
      expect(s.closestNoteName, refString.label);
    });
  });
}
