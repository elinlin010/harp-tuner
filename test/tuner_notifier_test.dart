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
    // confirms B♭4. Since _confirmedNote is the A-string label (e.g. '3A♭' on lever
    // harp), the challenge branch fires when a new string is detected.
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

  // ── preferFlats / string alignment regression guards ─────────────────────
  //
  // Before the fix, auto mode used frequencyToNoteInfo (chromatic snapping),
  // which could produce note names like 'G♭4' that do not exist on the harp.
  // The string visualizer highlights the closest ACTUAL string (e.g. G4),
  // so the two would diverge.  The fix snaps both to the nearest harp string.

  group('preferFlats / string alignment regression guards', () {
    test('lever harp: A♭4 pitch resolves to A♭4 string label with ~0 cents', () async {
      SharedPreferences.setMockInitialValues({});
      final c = _container(overrideState: const TunerState(
        selectedHarp: HarpType.leverHarp, preferFlats: true, a4Hz: 440,
      ));
      await Future.delayed(Duration.zero);
      final n = c.read(tunerProvider.notifier);
      for (var i = 0; i < 8; i++) n.handlePitchResult(PitchResult(415.30));
      final s = c.read(tunerProvider);
      expect(s.closestNoteName, '3A♭');
      expect(s.cents!, closeTo(0.0, 5.0));
    });

    test('lever harp: G♭ pitch resolves to nearest harp string (G4), not off-harp G♭4', () async {
      // 380 Hz lies between F4 (349 Hz, ~144 ¢ away) and G4 (392 Hz, ~54 ¢ away),
      // so the closest lever harp string is G4.  Before the fix, frequencyToNoteInfo
      // returned 'G♭4' — a note that does not exist on the harp — causing
      // closestNoteName and the visualizer's highlighted string to disagree.
      SharedPreferences.setMockInitialValues({});
      final c = _container(overrideState: const TunerState(
        selectedHarp: HarpType.leverHarp, preferFlats: true, a4Hz: 440,
      ));
      await Future.delayed(Duration.zero);
      final n = c.read(tunerProvider.notifier);
      for (var i = 0; i < 8; i++) n.handlePitchResult(PitchResult(380.0));
      final name = c.read(tunerProvider).closestNoteName;
      expect(name, '3G', reason: 'should snap to nearest harp string, not off-harp G♭4');
      expect(name, isNot(contains('♯')));
    });

    test('lever harp: C♯ pitch resolves to nearest harp string (C4), not C♯4 or D♭4', () async {
      // 275 Hz is closer to C4 (261.63 Hz, ~87 ¢) than to D4 (293.66 Hz, ~113 ¢).
      SharedPreferences.setMockInitialValues({});
      final c = _container(overrideState: const TunerState(
        selectedHarp: HarpType.leverHarp, preferFlats: true, a4Hz: 440,
      ));
      await Future.delayed(Duration.zero);
      final n = c.read(tunerProvider.notifier);
      for (var i = 0; i < 8; i++) n.handlePitchResult(PitchResult(275.0));
      final s = c.read(tunerProvider);
      expect(s.closestNoteName, '4C');
      expect(s.closestNoteName, isNot(contains('♯')));
    });

    test('lever harp auto mode: closestNoteName never contains ♯ for common accidental pitches', () async {
      // Invariant: harp strings only carry ♭ or natural accidentals, so no ♯
      // note name can ever appear in auto mode when a harp is selected.
      SharedPreferences.setMockInitialValues({});
      const testPitches = <double>[
        277.18, // C♯4/D♭4 — no lever harp string here, closest is C4 or D4
        311.13, // D♯4/E♭4 — lever harp has E♭4 string
        380.0,  // between F4 and G4, closer to G4
        415.30, // G♯4/A♭4 — lever harp has A♭4 string
        466.16, // A♯4/B♭4 — lever harp has B♭4 string
      ];
      for (final hz in testPitches) {
        final c = _container(overrideState: const TunerState(
          selectedHarp: HarpType.leverHarp, preferFlats: true, a4Hz: 440,
        ));
        await Future.delayed(Duration.zero);
        final n = c.read(tunerProvider.notifier);
        for (var i = 0; i < 8; i++) n.handlePitchResult(PitchResult(hz));
        final name = c.read(tunerProvider).closestNoteName;
        if (name != null) {
          expect(name, isNot(contains('♯')),
              reason: 'sharp appeared for $hz Hz: got "$name"');
        }
      }
    });

    test('setA4Hz with lever harp: closestNoteName stays harp string label, not chromatic', () async {
      // Regression: before the fix, setA4Hz re-ran frequencyToNoteInfo which
      // could overwrite the correctly snapped harp-string label with an
      // off-harp chromatic name — e.g. 'G4' → 'G♭4' for detectedHz=380.
      SharedPreferences.setMockInitialValues({});
      final c = _container(overrideState: const TunerState(
        selectedHarp: HarpType.leverHarp, preferFlats: true,
        a4Hz: 440,
        detectedHz: 380.0,   // between F4 and G4 on the lever harp
        closestNoteName: '3G',
        cents: -52.0,
      ));
      await Future.delayed(Duration.zero);
      await c.read(tunerProvider.notifier).setA4Hz(445);
      final s = c.read(tunerProvider);
      expect(s.a4Hz, 445);
      expect(s.closestNoteName, '3G',
          reason: 'must not revert to off-harp chromatic name G♭4');
      expect(s.cents, isNotNull);
      expect(s.cents!, isNot(closeTo(-52.0, 1.0))); // cents change with a4Hz
    });

    test('togglePreferFlats resets hysteresis: adjacent note confirmed without challenge delay', () async {
      // Regression: without the hysteresis reset, _confirmedNote held the
      // confirmed string label ('D4') after togglePreferFlats; when the pitch
      // moved to the adjacent E♭4 string (100 ¢ away) the challenge counter
      // blocked acceptance for 3 frames — leaving 'D4' on screen.
      //
      // D4 → E♭4 is exactly 100 ¢ so it passes the outlier check (<150 ¢)
      // and cleanly replaces the history.  Frame 8 of E♭4 is the first
      // stability-gate pass after the history has been fully flushed.
      //   With fix (_confirmedNote=null): E♭4 confirmed on frame 8 ✓
      //   Without fix (_confirmedNote='D4'): only 1 challenge → still 'D4' ✗
      SharedPreferences.setMockInitialValues({});
      final c = _container(overrideState: const TunerState(
        selectedHarp: HarpType.leverHarp,
        preferFlats: false,
        a4Hz: 440,
      ));
      await Future.delayed(Duration.zero);
      final n = c.read(tunerProvider.notifier);
      // Confirm D4 (~293.66 Hz, natural D string on lever harp)
      for (var i = 0; i < 8; i++) n.handlePitchResult(PitchResult(293.66));
      expect(c.read(tunerProvider).closestNoteName, '4D');
      // Toggle preferFlats — must reset _confirmedNote to null
      await n.togglePreferFlats();
      // Switch to E♭4 (~311.13 Hz, one semitone above D4):
      // 8 frames flush the old D4 history; frame 8 triggers the stability gate.
      for (var i = 0; i < 8; i++) n.handlePitchResult(PitchResult(311.13));
      expect(c.read(tunerProvider).closestNoteName, '4E♭');
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
