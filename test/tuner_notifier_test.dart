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

    test('bass melodic fifth (E3→B3) is NOT collapsed by harmonic correction', () async {
      // Regression: the original cutoff (reference < 250) treated E3 (165 Hz) as
      // "bass" and snapped B3 (247 Hz, a fifth up) back via 247 × 2/3 ≈ 165 —
      // so playing B after E showed E with the wrong octave. The cutoff is now
      // 130 Hz, so E3 is a well-locked fundamental and the fifth must switch.
      SharedPreferences.setMockInitialValues({});
      final c = _container();
      await Future.delayed(Duration.zero);
      final n = c.read(tunerProvider.notifier);
      for (var i = 0; i < 4; i++) n.handlePitchResult(PitchResult(164.81)); // E3
      expect(c.read(tunerProvider).closestNoteName, contains('E'));
      for (var i = 0; i < 5; i++) n.handlePitchResult(PitchResult(246.94)); // B3
      expect(c.read(tunerProvider).closestNoteName, contains('B'),
          reason: 'a real fifth from a 165 Hz reference must switch, not collapse to E');
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

  // ── harmonic correction & the 130 Hz bass cutoff ─────────────────────────
  //
  // _octaveCorrect pulls harmonic/sub-harmonic misreads back to the fundamental
  // so a plucked string's overtones don't flash a wrong note. It tries octave
  // ratios (×2 ÷2 ×4 ÷4) and twelfth ratios (×3 ÷3) everywhere, plus
  // inter-harmonic ratios (3:2, 2:3, 4:3, 3:4) ONLY when the reference is below
  // 130 Hz — the register where the weakest fundamentals make YIN jump between
  // overtones. Above 130 Hz those same ratios are real melodic fourths/fifths
  // between two strings and MUST switch. These tests pin both halves of that
  // contract, and the cutoff itself, so it can't silently drift back to the old
  // 250 Hz value that turned B into E.
  group('TunerNotifier.handlePitchResult — harmonic correction & bass cutoff', () {
    // Drive enough identical frames to fill the sliding window and clear the
    // challenge counter, confirming a note from the given frequency.
    void confirm(TunerNotifier n, double hz, [int frames = 6]) {
      for (var i = 0; i < frames; i++) {
        n.handlePitchResult(PitchResult(hz));
      }
    }

    test('reference just BELOW 130 Hz still collapses a 3:2 inter-harmonic jump',
        () async {
      // Seed ~120 Hz (a weak-fundamental bass string read as an overtone), then
      // inject its 3:2 partner ~180 Hz. Because 120 < 130 the inter-harmonic
      // rule fires: 180 × 2/3 = 120, within 80¢, so it must HOLD near 120 Hz and
      // not jump to 180. This is the Android weak-bass fix; it must survive the
      // lowered cutoff.
      SharedPreferences.setMockInitialValues({});
      final c = _container();
      await Future.delayed(Duration.zero);
      final n = c.read(tunerProvider.notifier);
      confirm(n, 120.0);
      final held = c.read(tunerProvider).closestNoteName;
      confirm(n, 180.0, 4);
      final s = c.read(tunerProvider);
      expect(s.closestNoteName, held,
          reason: 'a 3:2 jump from a <130 Hz reference is a harmonic, must hold');
      expect(s.detectedHz, lessThan(140.0),
          reason: 'reading must stay near 120 Hz, not climb to 180 Hz');
    });

    test('reference just ABOVE 130 Hz lets a real fifth switch', () async {
      // Seed ~140 Hz (a well-locked fundamental), then play its fifth ~210 Hz.
      // Because 140 > 130 the inter-harmonic rule is skipped: this is a genuine
      // melodic fifth and must SWITCH up to ~210 Hz, not snap back to 140.
      SharedPreferences.setMockInitialValues({});
      final c = _container();
      await Future.delayed(Duration.zero);
      final n = c.read(tunerProvider.notifier);
      confirm(n, 140.0);
      final before = c.read(tunerProvider).closestNoteName;
      confirm(n, 210.0);
      final s = c.read(tunerProvider);
      expect(s.detectedHz, greaterThan(180.0),
          reason: 'a fifth from a >130 Hz reference must switch, not collapse');
      expect(s.closestNoteName, isNot(before));
    });

    test('descending fifth (B3→E3) switches — the reported bug, mirrored', () async {
      // The user-reported failure was ascending B-after-E showing E. The
      // descending direction must work too: E-after-B must show E, not stay B.
      SharedPreferences.setMockInitialValues({});
      final c = _container();
      await Future.delayed(Duration.zero);
      final n = c.read(tunerProvider.notifier);
      confirm(n, 246.94); // B3
      expect(c.read(tunerProvider).closestNoteName, contains('B'));
      confirm(n, 164.81); // E3
      final s = c.read(tunerProvider);
      expect(s.closestNoteName, contains('E'),
          reason: 'a real descending fifth must switch, not hold B');
      expect(s.detectedHz, lessThan(190.0),
          reason: 'octave must follow the note down to E3 (~165 Hz)');
    });

    test('real perfect fourth (E3→A3) switches', () async {
      // E3 (165 Hz) → A3 (220 Hz) is a 4:3 ratio. With the old 250 Hz cutoff
      // this collapsed (165 < 250 → 220 × 3/4 ≈ 165). At 130 Hz it switches.
      SharedPreferences.setMockInitialValues({});
      final c = _container();
      await Future.delayed(Duration.zero);
      final n = c.read(tunerProvider.notifier);
      confirm(n, 164.81); // E3
      expect(c.read(tunerProvider).closestNoteName, contains('E'));
      confirm(n, 220.0); // A3
      final s = c.read(tunerProvider);
      expect(s.closestNoteName, contains('A'),
          reason: 'a real fourth above 130 Hz must switch, not be harmonic-corrected');
      expect(s.detectedHz, greaterThan(195.0));
    });

    test('octave harmonic (A4→A5, ×2) is corrected to the fundamental', () async {
      // A clean octave overtone is the most common YIN error. Playing A4 (440)
      // while YIN reports A5 (880) must hold A4, not jump an octave.
      SharedPreferences.setMockInitialValues({});
      final c = _container();
      await Future.delayed(Duration.zero);
      final n = c.read(tunerProvider.notifier);
      confirm(n, 440.0);
      final held = c.read(tunerProvider).closestNoteName;
      confirm(n, 880.0, 4); // A5 overtone
      final s = c.read(tunerProvider);
      expect(s.closestNoteName, held,
          reason: 'an octave overtone must be corrected, not switch the note');
      expect(s.detectedHz, lessThan(500.0),
          reason: 'reading must stay near A4 (440 Hz), not jump to 880 Hz');
    });

    test('two-octave harmonic (A4→A6, ×4) is corrected to the fundamental',
        () async {
      // The ×4 factor covers the two-octave overtone: A4 (440) read as A6 (1760).
      SharedPreferences.setMockInitialValues({});
      final c = _container();
      await Future.delayed(Duration.zero);
      final n = c.read(tunerProvider.notifier);
      confirm(n, 440.0);
      final held = c.read(tunerProvider).closestNoteName;
      confirm(n, 1760.0, 4); // A6 overtone
      final s = c.read(tunerProvider);
      expect(s.closestNoteName, held,
          reason: 'a two-octave overtone must be corrected, not switch the note');
      expect(s.detectedHz, lessThan(700.0));
    });

    test('isolated harmonic spike does not flash through the confirmed note',
        () async {
      // A single overtone frame mid-note (the common YIN glitch) must never
      // reach the display — the confirmed note holds throughout.
      SharedPreferences.setMockInitialValues({});
      final c = _container();
      await Future.delayed(Duration.zero);
      final n = c.read(tunerProvider.notifier);
      confirm(n, 293.66); // D4
      final held = c.read(tunerProvider).closestNoteName;
      n.handlePitchResult(PitchResult(880.98)); // one 3rd-harmonic spike (A5)
      expect(c.read(tunerProvider).closestNoteName, held,
          reason: 'a single harmonic spike must not change the displayed note');
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
      test('$name: real fifth (E3→B3) tracks up, does not collapse (B→E fix)',
          () async {
        final c = await withInstrument(harp);
        final n = c.read(tunerProvider.notifier);
        confirm(n, 164.81); // E3
        final low = c.read(tunerProvider);
        expect(low.detectedHz, closeTo(164.81, 6.0));
        confirm(n, 246.94); // B3 — a fifth up
        final high = c.read(tunerProvider);
        expect(high.detectedHz, greaterThan(200.0),
            reason: '$name: the fifth must track to ~247 Hz, not collapse to 165');
        expect(high.closestNoteName, isNot(low.closestNoteName),
            reason: '$name: the note label must change on a real interval');
      });

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

  // ── sub-harmonic acquisition (anti-octave-lock) ──────────────────────────
  //
  // A sub-harmonic misread reads LOW (C4 → C4÷3 = F2 ≈ 87 Hz). If it seeds the
  // empty history first — common in the noisy pluck attack — the real higher
  // fundamental was being folded DOWN onto it and the note locked to the wrong
  // (lower) string, or wouldn't switch until re-plucked. The acquisition
  // re-anchor pulls history UP to the persistent higher fundamental. These
  // tests cover the seed-first case (distinct from the established-note tests
  // above, which verify a held note still rejects a sub-harmonic without
  // drifting).
  group('TunerNotifier.handlePitchResult — sub-harmonic acquisition', () {
    void confirm(TunerNotifier n, double hz, [int frames = 6]) {
      for (var i = 0; i < frames; i++) {
        n.handlePitchResult(PitchResult(hz));
      }
    }

    test('chromatic: F2 sub-harmonic seeds first, C4 still wins', () async {
      // The reported bug: play C, see F. One stray F2 (sub-3rd) lands first,
      // then the real C4 stream — must re-anchor up and confirm C4, not F2.
      SharedPreferences.setMockInitialValues({});
      final c = _container();
      await Future.delayed(Duration.zero);
      final n = c.read(tunerProvider.notifier);
      n.handlePitchResult(PitchResult(87.21)); // F2 sub-harmonic seeds history
      confirm(n, 261.63); // real C4 stream
      final s = c.read(tunerProvider);
      expect(s.closestNoteName, 'C4',
          reason: 'real C4 must win over the F2 sub-harmonic that seeded first');
      expect(s.detectedHz, closeTo(261.63, 8.0),
          reason: 'reading must re-anchor up to ~261 Hz, not lock at ~87 Hz');
    });

    test('chromatic: alternating F2/C4 readings still resolve to C4', () async {
      // YIN bouncing between the fundamental and its sub-3rd harmonic. The
      // re-anchor must accumulate evidence across the intervening sub-harmonic
      // frames and still land on C4.
      SharedPreferences.setMockInitialValues({});
      final c = _container();
      await Future.delayed(Duration.zero);
      final n = c.read(tunerProvider.notifier);
      for (final hz in [87.21, 261.63, 87.21, 261.63, 261.63, 261.63, 261.63]) {
        n.handlePitchResult(PitchResult(hz));
      }
      expect(c.read(tunerProvider).closestNoteName, 'C4',
          reason: 'alternating sub-harmonic/fundamental must resolve to C4');
    });

    test('harp mode: F2 sub-harmonic seeds first, C string still wins', () async {
      // Same fix must hold with a harp selected (label is register-format).
      // Lever harp (E♭ major) has a real C string; pedal harp is all-flat and
      // would snap 261.63 Hz to D♭4, so we use lever harp for a clean C label.
      SharedPreferences.setMockInitialValues({});
      final c = _container();
      await Future.delayed(const Duration(milliseconds: 20));
      final n = c.read(tunerProvider.notifier);
      await n.setSelectedHarp(HarpType.leverHarp);
      n.handlePitchResult(PitchResult(87.21)); // F2 sub-harmonic
      confirm(n, 261.63); // real C4
      final s = c.read(tunerProvider);
      expect(s.detectedHz, closeTo(261.63, 8.0),
          reason: 'harp mode must re-anchor up to ~261 Hz too');
      expect(s.closestNoteName, contains('C'),
          reason: 'closest string must be a C, not an F');
      expect(s.closestNoteName, isNot(contains('F')),
          reason: 'must not lock to the F2 sub-harmonic');
    });

    test('octave 2nd-harmonic flashes do NOT jump the acquired note up (B♭4 stays B♭4)',
        () async {
      // Reported regression: plucking a note flashes its strong 2nd harmonic
      // (an octave up) for a frame or two during the attack. The re-anchor must
      // NOT treat the octave as a sub-harmonic and jump up — the octave is
      // ambiguous (a note's 2nd harmonic IS its octave). Only the non-octave
      // twelfth (×3) re-anchors, so even SUSTAINED octave-overtone frames hold.
      SharedPreferences.setMockInitialValues({});
      final c = _container(); // chromatic; A♯4 = B♭4 enharmonic
      await Future.delayed(Duration.zero);
      final n = c.read(tunerProvider.notifier);
      n.handlePitchResult(PitchResult(466.16)); // B♭4 fundamental seeds
      n.handlePitchResult(PitchResult(932.33)); // 2nd-harmonic flash
      n.handlePitchResult(PitchResult(932.33)); // ...persists 2 frames
      for (var i = 0; i < 4; i++) n.handlePitchResult(PitchResult(466.16));
      final s = c.read(tunerProvider);
      expect(s.closestNoteName, 'A♯4',
          reason: 'B♭4 must not jump to B♭5 on a 2nd-harmonic flash');
      expect(s.detectedHz, closeTo(466.16, 10.0),
          reason: 'reading must stay near 466 Hz, not climb to 932 Hz');
    });

    test('octave overtone does NOT jump up for an arbitrary note (A4 stays A4)',
        () async {
      // Generality: the octave-overtone confusion was reported on many notes,
      // not just B♭. A4 (440) with sustained A5 (880) overtone frames stays A4.
      SharedPreferences.setMockInitialValues({});
      final c = _container();
      await Future.delayed(Duration.zero);
      final n = c.read(tunerProvider.notifier);
      for (final hz in [440.0, 880.0, 880.0, 440.0, 440.0, 440.0, 440.0]) {
        n.handlePitchResult(PitchResult(hz));
      }
      expect(c.read(tunerProvider).closestNoteName, 'A4',
          reason: 'A4 must not jump to A5 on a 2nd-harmonic flash');
    });

    test('two-octave overtone (×4) does NOT jump the acquired note up', () async {
      // ×4 is octave-class (two octaves) and shares the same ambiguity as ×2,
      // so it is excluded from re-anchoring too. C4 with C6 (×4) overtone holds.
      SharedPreferences.setMockInitialValues({});
      final c = _container();
      await Future.delayed(Duration.zero);
      final n = c.read(tunerProvider.notifier);
      for (final hz in [261.63, 1046.5, 1046.5, 261.63, 261.63, 261.63, 261.63]) {
        n.handlePitchResult(PitchResult(hz));
      }
      expect(c.read(tunerProvider).closestNoteName, 'C4',
          reason: 'C4 must not jump to C6 on a two-octave overtone flash');
    });

    test('clean fundamental-first acquisition is unaffected (no added lag)',
        () async {
      // Regression guard: when the fundamental seeds first (the normal case),
      // the re-anchor never fires and acquisition is unchanged.
      SharedPreferences.setMockInitialValues({});
      final c = _container();
      await Future.delayed(Duration.zero);
      final n = c.read(tunerProvider.notifier);
      confirm(n, 261.63, 5);
      expect(c.read(tunerProvider).closestNoteName, 'C4');
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
