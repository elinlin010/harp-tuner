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
    test('null result: first silence when no confirmed note does NOT block subsequent detection', () async {
      // Regression: on slow devices, null frames arrive between valid detections.
      // A null during accumulation (no confirmed note) must not clear history,
      // otherwise a true/null/true/null pattern can never reach _stableNeeded.
      SharedPreferences.setMockInitialValues({});
      final c = _container();
      await Future.delayed(Duration.zero);
      final n = c.read(tunerProvider.notifier);
      // Alternating true/null must still confirm — the nulls must not reset the
      // accumulation. Feed enough pitched frames to fill the window and satisfy
      // the confirmation counter.
      for (var i = 0; i < 6; i++) {
        n.handlePitchResult(PitchResult(440.0));
        n.handlePitchResult(null);
      }
      expect(c.read(tunerProvider).closestNoteName, isNotNull);
    });

    test('isolated null after a confirmed note does not crash or clear', () async {
      // A single null is an intermittent YIN gap, not a note end. It must not
      // disturb the confirmed note — only sustained silence (_kStaleFrames)
      // resets detection state.
      SharedPreferences.setMockInitialValues({});
      final c = _container();
      await Future.delayed(Duration.zero);
      final n = c.read(tunerProvider.notifier);
      for (var i = 0; i < 5; i++) n.handlePitchResult(PitchResult(440.0));
      expect(c.read(tunerProvider).closestNoteName, isNotNull);
      n.handlePitchResult(null); // single gap — harmless
      expect(c.read(tunerProvider).closestNoteName, isNotNull);
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
      // Not yet stable (need 2 frames minimum), state unchanged after 1 frame
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

    test('genuine far jump confirms after short hysteresis', () async {
      // After confirming A4, a sustained jump to E5 (700 cents, non-harmonic)
      // switches once the new note survives the confirmation counter. The
      // history is cleared on the jump so E5 isn't dragged back to A4.
      SharedPreferences.setMockInitialValues({});
      final c = _container();
      await Future.delayed(Duration.zero);
      final n = c.read(tunerProvider.notifier);
      for (var i = 0; i < 4; i++) n.handlePitchResult(PitchResult(440.0));
      expect(c.read(tunerProvider).closestNoteName, contains('A'));
      // Sustained E5 switches after the counter is satisfied.
      for (var i = 0; i < 4; i++) n.handlePitchResult(PitchResult(659.25));
      expect(c.read(tunerProvider).closestNoteName, contains('E'),
          reason: 'sustained far jump should switch to the new note');
    });

    test('brief 1-2 frame transient does NOT flash the wrong note', () async {
      // Regression for the onset bounce: plucking a string can momentarily read
      // as a non-harmonic neighbour for a frame or two before settling. That
      // transient must not reach the display — the confirmation counter holds
      // the previously displayed note until the new one persists.
      SharedPreferences.setMockInitialValues({});
      final c = _container();
      await Future.delayed(Duration.zero);
      final n = c.read(tunerProvider.notifier);
      for (var i = 0; i < 4; i++) n.handlePitchResult(PitchResult(440.0));
      expect(c.read(tunerProvider).closestNoteName, contains('A'));
      // Two frames of a far note, then back to the real note: must stay A.
      n.handlePitchResult(PitchResult(659.25));
      n.handlePitchResult(PitchResult(659.25));
      expect(c.read(tunerProvider).closestNoteName, contains('A'),
          reason: 'a 2-frame transient must not switch the displayed note');
    });

    test('half-step move switches within a few frames (sliding stability window)', () async {
      // A half step (100¢) stays under the 150¢ clear threshold, so history is
      // not flushed. The sliding stability window must still let the new note
      // take over in a handful of frames rather than waiting for the full
      // _historyLen ring to drain (the half-step lag).
      SharedPreferences.setMockInitialValues({});
      final c = _container(); // chromatic (no harp)
      await Future.delayed(Duration.zero);
      final n = c.read(tunerProvider.notifier);
      for (var i = 0; i < 4; i++) n.handlePitchResult(PitchResult(440.0)); // A4
      expect(c.read(tunerProvider).closestNoteName, 'A4');
      // A♯4 is exactly 100¢ above A4. Four frames must be enough to switch —
      // with the old full-ring stability gate this took ~10 frames.
      for (var i = 0; i < 4; i++) n.handlePitchResult(PitchResult(466.16));
      expect(c.read(tunerProvider).closestNoteName, isNot('A4'),
          reason: 'half-step move should switch quickly, not hold the old note');
    });

    test('3rd-harmonic reading does not switch the confirmed note', () async {
      // Regression: playing D4 (293.66 Hz), YIN intermittently reports the 3rd
      // harmonic ≈ A5 (880.98 Hz). Without harmonic correction this was seeded
      // as a new note and confirmed, flipping the display to A and showing it
      // "in tune". With ÷3 correction it must stay D4.
      SharedPreferences.setMockInitialValues({});
      final c = _container(overrideState: const TunerState(
        selectedHarp: HarpType.leverHarp, preferFlats: true, a4Hz: 440,
      ));
      await Future.delayed(Duration.zero);
      final n = c.read(tunerProvider.notifier);
      // Establish D4
      for (var i = 0; i < 6; i++) n.handlePitchResult(PitchResult(293.66));
      final confirmed = c.read(tunerProvider).closestNoteName;
      expect(confirmed, contains('D'));
      // Inject several 3rd-harmonic readings (A5) — must NOT switch to A
      for (var i = 0; i < 4; i++) n.handlePitchResult(PitchResult(880.98));
      expect(c.read(tunerProvider).closestNoteName, confirmed,
          reason: '3rd harmonic must be corrected to fundamental, not shown as A');
    });

    test('sub-3rd-harmonic reading does not switch the confirmed note', () async {
      // C4 (261.63 Hz) sub-3rd harmonic ≈ F2 (87.21 Hz). Must stay C4.
      SharedPreferences.setMockInitialValues({});
      final c = _container(overrideState: const TunerState(
        selectedHarp: HarpType.leverHarp, preferFlats: true, a4Hz: 440,
      ));
      await Future.delayed(Duration.zero);
      final n = c.read(tunerProvider.notifier);
      for (var i = 0; i < 6; i++) n.handlePitchResult(PitchResult(261.63));
      final confirmed = c.read(tunerProvider).closestNoteName;
      expect(confirmed, contains('C'));
      for (var i = 0; i < 4; i++) n.handlePitchResult(PitchResult(87.21));
      expect(c.read(tunerProvider).closestNoteName, confirmed,
          reason: 'sub-3rd harmonic must be corrected to fundamental, not shown as F');
    });

    test('bass inter-harmonic jump (124↔184 Hz, 3:2) does not flip the note', () async {
      // A low string (~61 Hz fundamental) reads as its 2nd harmonic (~124 Hz)
      // and its 3rd (~184 Hz) intermittently — a 3:2 ratio between two
      // harmonics, not a simple multiple of the fundamental. Without bass
      // inter-harmonic correction the note flipped (e.g. C♭ ↔ G♭). It must hold.
      SharedPreferences.setMockInitialValues({});
      final c = _container(overrideState: const TunerState(
        selectedHarp: HarpType.pedalHarp, a4Hz: 440,
      ));
      await Future.delayed(Duration.zero);
      final n = c.read(tunerProvider.notifier);
      for (var i = 0; i < 6; i++) n.handlePitchResult(PitchResult(124.0));
      final confirmed = c.read(tunerProvider).closestNoteName;
      expect(confirmed, isNotNull);
      // Inject the 3:2 harmonic (~184 Hz) — must stay on the same note.
      for (var i = 0; i < 4; i++) n.handlePitchResult(PitchResult(184.0));
      expect(c.read(tunerProvider).closestNoteName, confirmed,
          reason: 'bass 3:2 harmonic jump must be corrected, not flip the note');
    });

    test('melodic fifth (A4→E5) is NOT collapsed by harmonic correction', () async {
      // The bass inter-harmonic correction must not apply above 250 Hz: A4→E5
      // is a real 3:2 jump between two strings and must switch, not snap back.
      SharedPreferences.setMockInitialValues({});
      final c = _container();
      await Future.delayed(Duration.zero);
      final n = c.read(tunerProvider.notifier);
      for (var i = 0; i < 4; i++) n.handlePitchResult(PitchResult(440.0));
      expect(c.read(tunerProvider).closestNoteName, contains('A'));
      for (var i = 0; i < 5; i++) n.handlePitchResult(PitchResult(659.25)); // E5
      expect(c.read(tunerProvider).closestNoteName, contains('E'),
          reason: 'a real fifth above 250 Hz must switch, not be harmonic-corrected');
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

  // ── octave-level detection (end-to-end) ──────────────────────────────────
  //
  // The reported bug included "the octave number is also wrong", so verify the
  // full detection pipeline — not just the naming helper — carries the correct
  // octave at every level, and that a clean octave overtone never bumps the
  // displayed octave up.
  group('TunerNotifier.handlePitchResult — octave-level detection', () {
    void confirm(TunerNotifier n, double hz, [int frames = 6]) {
      for (var i = 0; i < frames; i++) {
        n.handlePitchResult(PitchResult(hz));
      }
    }

    test('a steady A at every octave (A1–A7) confirms the correct octave', () async {
      const aByOctave = {
        1: 55.0, 2: 110.0, 3: 220.0, 4: 440.0,
        5: 880.0, 6: 1760.0, 7: 3520.0,
      };
      for (final entry in aByOctave.entries) {
        SharedPreferences.setMockInitialValues({});
        final c = _container(); // chromatic — label carries the octave digit
        await Future.delayed(Duration.zero);
        final n = c.read(tunerProvider.notifier);
        confirm(n, entry.value);
        final s = c.read(tunerProvider);
        expect(s.closestNoteName, 'A${entry.key}',
            reason: '${entry.value} Hz should detect as A${entry.key}');
        expect(s.detectedHz, closeTo(entry.value, entry.value * 0.02));
      }
    });

    test('octave boundary B3→C4 detects as two distinct octaves', () async {
      // B3 (246.94) confirmed, then C4 (261.63) — a semitone up that crosses the
      // octave-number rollover. The display must move B3 → C4, not stay on B or
      // mislabel the octave.
      SharedPreferences.setMockInitialValues({});
      final c = _container();
      await Future.delayed(Duration.zero);
      final n = c.read(tunerProvider.notifier);
      confirm(n, 246.94);
      expect(c.read(tunerProvider).closestNoteName, 'B3');
      confirm(n, 261.63);
      expect(c.read(tunerProvider).closestNoteName, 'C4',
          reason: 'crossing the octave rollover must relabel B3 → C4');
    });

    test('a clean octave overtone does not bump the displayed octave', () async {
      // Holding A3 (220) while YIN reports the octave overtone A4 (440): the
      // ÷2 correction must keep the display on A3, never flash A4.
      SharedPreferences.setMockInitialValues({});
      final c = _container();
      await Future.delayed(Duration.zero);
      final n = c.read(tunerProvider.notifier);
      confirm(n, 220.0); // A3
      expect(c.read(tunerProvider).closestNoteName, 'A3');
      confirm(n, 440.0, 4); // A4 overtone
      final s = c.read(tunerProvider);
      expect(s.closestNoteName, 'A3',
          reason: 'an octave overtone must not bump A3 up to A4');
      expect(s.detectedHz, lessThan(300.0));
    });
  });

  // ── instrument-independent detection ─────────────────────────────────────
  //
  // Harmonic correction runs on the raw detected Hz BEFORE any harp-string
  // snapping, so pitch detection must behave identically whichever instrument
  // is selected — the instrument only changes how the note is *labelled*, not
  // which pitch is detected. `detectedHz` carries the raw pitch, so it's the
  // instrument-independent signal to assert on. These tests run the same
  // scenarios across chromatic, lever harp and pedal harp.
  group('TunerNotifier.handlePitchResult — instrument-independent detection', () {
    void confirm(TunerNotifier n, double hz, [int frames = 6]) {
      for (var i = 0; i < frames; i++) {
        n.handlePitchResult(PitchResult(hz));
      }
    }

    // Pin the instrument deterministically: let the async _loadPrefs settle
    // (it defaults selectedHarp to leverHarp) BEFORE selecting, so the load
    // can't clobber our choice mid-test. null = chromatic (no harp).
    Future<ProviderContainer> withInstrument(HarpType? harp) async {
      SharedPreferences.setMockInitialValues({});
      final c = _container();
      await Future.delayed(const Duration(milliseconds: 20));
      await c.read(tunerProvider.notifier).setSelectedHarp(harp);
      return c;
    }

    const instruments = <String, HarpType?>{
      'chromatic': null,
      'lever harp': HarpType.leverHarp,
      'pedal harp': HarpType.pedalHarp,
    };

    instruments.forEach((name, harp) {
      test('$name: octave overtone is corrected (A3 held, A4 ignored)', () async {
        final c = await withInstrument(harp);
        final n = c.read(tunerProvider.notifier);
        confirm(n, 220.0); // A3
        final before = c.read(tunerProvider).closestNoteName;
        confirm(n, 440.0, 4); // A4 overtone
        final s = c.read(tunerProvider);
        expect(s.detectedHz, lessThan(300.0),
            reason: '$name: octave overtone must hold near 220 Hz');
        expect(s.closestNoteName, before,
            reason: '$name: octave overtone must not change the note');
      });

      test('$name: steady A4 (440 Hz) tracks the pitch', () async {
        final c = await withInstrument(harp);
        final n = c.read(tunerProvider.notifier);
        confirm(n, 440.0);
        expect(c.read(tunerProvider).detectedHz, closeTo(440.0, 6.0),
            reason: '$name: 440 Hz must read ~440 Hz on every instrument');
      });
    });

    test('switching instrument mid-session keeps detecting cleanly', () async {
      SharedPreferences.setMockInitialValues({});
      final c = _container();
      await Future.delayed(const Duration(milliseconds: 20));
      final n = c.read(tunerProvider.notifier);
      await n.setSelectedHarp(HarpType.leverHarp);
      confirm(n, 440.0);
      expect(c.read(tunerProvider).detectedHz, closeTo(440.0, 6.0));
      // Switch instruments right after a note was confirmed.
      await n.setSelectedHarp(HarpType.pedalHarp);
      confirm(n, 261.63); // C4
      final s = c.read(tunerProvider);
      expect(s.detectedHz, closeTo(261.63, 6.0),
          reason: 'detection must keep working after switching instruments');
      expect(s.closestNoteName, isNotNull);
    });
  });

  // ── platform-specific correctors (iOS vs Android) ────────────────────────
  //
  // iOS and Android run independently-tuned detection algorithms, frozen to
  // their respective store versions (App Store v1.1.10 / Play Store v1.1.11)
  // and selected by _detectionAlgo. Under `flutter test` the host is neither
  // platform, so the dispatcher defaults to Android; these tests pin each
  // algorithm explicitly via setDetectionAlgoForTest.
  group('TunerNotifier.handlePitchResult — platform correctors', () {
    void feed(TunerNotifier n, double hz, int frames) {
      for (var i = 0; i < frames; i++) {
        n.handlePitchResult(PitchResult(hz));
      }
    }

    test('dispatch differs: iOS confirms acquisition faster than Android', () async {
      // iOS confirms a freshly acquired note as soon as the stability window
      // fills (3 frames); Android additionally gates acquisition behind the
      // challenge counter. After exactly 3 identical frames iOS shows the note
      // and Android does not — proving the dispatcher picks different algorithms.
      SharedPreferences.setMockInitialValues({});
      final cIos = _container();
      final cAnd = _container();
      await Future.delayed(Duration.zero);
      final nIos = cIos.read(tunerProvider.notifier)
        ..setDetectionAlgoForTest(DetectionAlgo.ios);
      final nAnd = cAnd.read(tunerProvider.notifier)
        ..setDetectionAlgoForTest(DetectionAlgo.android);
      feed(nIos, 440.0, 3);
      feed(nAnd, 440.0, 3);
      expect(cIos.read(tunerProvider).closestNoteName, 'A4',
          reason: 'iOS confirms acquisition once the stability window fills');
      expect(cAnd.read(tunerProvider).closestNoteName, isNull,
          reason: 'Android still needs challenge frames after 3 stable frames');
    });

    test('iOS: octave overtone is corrected (A4 held against A5)', () async {
      SharedPreferences.setMockInitialValues({});
      final c = _container();
      await Future.delayed(Duration.zero);
      final n = c.read(tunerProvider.notifier)
        ..setDetectionAlgoForTest(DetectionAlgo.ios);
      feed(n, 440.0, 4);
      expect(c.read(tunerProvider).closestNoteName, 'A4');
      feed(n, 880.0, 3); // A5 octave overtone
      expect(c.read(tunerProvider).closestNoteName, 'A4',
          reason: 'iOS octave-corrects a ×2 overtone back to the fundamental');
    });

    test('iOS: a non-octave far reading is dropped, not switched mid-note', () async {
      // iOS corrects ONLY octaves; a far non-octave reading (e.g. a 3rd
      // harmonic) returns null and the frame is dropped, so a held note isn't
      // knocked off by a stray harmonic without a silence gap.
      SharedPreferences.setMockInitialValues({});
      final c = _container();
      await Future.delayed(Duration.zero);
      final n = c.read(tunerProvider.notifier)
        ..setDetectionAlgoForTest(DetectionAlgo.ios);
      feed(n, 261.63, 4); // C4
      expect(c.read(tunerProvider).closestNoteName, 'C4');
      feed(n, 784.0, 3); // C4's 3rd harmonic ≈ G5
      expect(c.read(tunerProvider).closestNoteName, 'C4',
          reason: 'iOS drops a non-octave harmonic frame, holding the note');
    });

    test('iOS: switches to a new note after a silence gap clears state', () async {
      // iOS resets detection state on the first silence frame, so a new note
      // plucked after the previous one decays acquires fresh.
      SharedPreferences.setMockInitialValues({});
      final c = _container();
      await Future.delayed(Duration.zero);
      final n = c.read(tunerProvider.notifier)
        ..setDetectionAlgoForTest(DetectionAlgo.ios);
      feed(n, 164.81, 4); // E3
      expect(c.read(tunerProvider).closestNoteName, 'E3');
      n.handlePitchResult(null); // silence → iOS clears state on the first null
      feed(n, 246.94, 4); // B3 — fresh acquisition
      expect(c.read(tunerProvider).closestNoteName, 'B3',
          reason: 'iOS acquires the new note fresh after a silence gap');
    });

    test('Android: 3rd-harmonic reading is corrected in-stream, holds the note',
        () async {
      // Android corrects ×3 without needing a silence gap, so a 3rd-harmonic
      // flash on a held note does not switch it.
      SharedPreferences.setMockInitialValues({});
      final c = _container();
      await Future.delayed(Duration.zero);
      final n = c.read(tunerProvider.notifier)
        ..setDetectionAlgoForTest(DetectionAlgo.android);
      feed(n, 261.63, 6); // C4
      expect(c.read(tunerProvider).closestNoteName, 'C4');
      feed(n, 784.0, 4); // 3rd harmonic ≈ G5
      expect(c.read(tunerProvider).closestNoteName, 'C4',
          reason: 'Android ×3-corrects the harmonic in-stream');
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

    test('togglePreferFlats resets hysteresis: adjacent note eventually confirms', () async {
      // Regression: without the hysteresis reset, _confirmedNote held 'D4' after
      // togglePreferFlats and the adjacent E♭4 string (100 ¢ away) could never
      // take over. After the reset, moving to E♭4 must end up displaying E♭4.
      //
      // D4 → E♭4 is 100 ¢ (<150 ¢), so it replaces history frame by frame; the
      // first stability-gate pass is at frame 8, then the confirmation counter
      // (_challengeNeeded) needs a couple more agreeing frames — the same
      // transient-filtering path every note acquisition uses now.
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
      // Sustained E♭4 (~311.13 Hz): flush old history, then satisfy the counter.
      for (var i = 0; i < 12; i++) n.handlePitchResult(PitchResult(311.13));
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
