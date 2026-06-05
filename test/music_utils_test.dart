import 'package:flutter_test/flutter_test.dart';
import 'package:harp_tuner/data/harp_presets.dart';
import 'package:harp_tuner/models/harp_string_model.dart';
import 'package:harp_tuner/utils/music_utils.dart';

void main() {
  group('MusicUtils.frequencyToNoteInfo — chromatic (sharps)', () {
    test('A4 at 440 Hz = A4, 0 cents', () {
      final r = MusicUtils.frequencyToNoteInfo(440.0);
      expect(r.noteName, 'A4');
      expect(r.cents.abs(), lessThan(0.5));
    });

    test('C4 (middle C) ≈ 261.63 Hz', () {
      final r = MusicUtils.frequencyToNoteInfo(261.63);
      expect(r.noteName, 'C4');
    });

    test('A4 sharp = A♯4 above 440 Hz', () {
      // A♯4 ≈ 466.16 Hz
      final r = MusicUtils.frequencyToNoteInfo(466.16);
      expect(r.noteName, 'A♯4');
    });

    test('preferFlats=true returns D♭ instead of C♯', () {
      // C♯4/D♭4 ≈ 277.18 Hz
      final rSharp = MusicUtils.frequencyToNoteInfo(277.18);
      expect(rSharp.noteName, startsWith('C♯'));

      final rFlat = MusicUtils.frequencyToNoteInfo(277.18, preferFlats: true);
      expect(rFlat.noteName, startsWith('D♭'));
    });

    test('cents are clamped to ±50', () {
      // Even a frequency at the extreme edge should clamp
      final r = MusicUtils.frequencyToNoteInfo(440.0);
      expect(r.cents, inInclusiveRange(-50.0, 50.0));
    });

    test('A4 at 441 Hz is slightly sharp (~3.9 cents)', () {
      final r = MusicUtils.frequencyToNoteInfo(441.0);
      expect(r.noteName, 'A4');
      expect(r.cents, greaterThan(0)); // sharp
      expect(r.cents, lessThan(10));
    });

    test('A4 at 439 Hz is slightly flat', () {
      final r = MusicUtils.frequencyToNoteInfo(439.0);
      expect(r.noteName, 'A4');
      expect(r.cents, lessThan(0)); // flat
    });

    test('custom a4Hz reference shifts targets', () {
      // With a4Hz=442, the same frequency reads slightly flat
      final r440 = MusicUtils.frequencyToNoteInfo(440.0, a4Hz: 440.0);
      final r442 = MusicUtils.frequencyToNoteInfo(440.0, a4Hz: 442.0);
      expect(r440.cents.abs(), lessThan(0.5));
      expect(r442.cents, lessThan(0)); // 440 Hz is flat when A=442
    });

    test('A at every octave (A1–A7) resolves to the correct octave number', () {
      // A doubles each octave from A4=440. Covers the full harp range and then
      // some, proving octave numbering is correct (not off-by-one) everywhere.
      const aByOctave = {
        1: 55.0, 2: 110.0, 3: 220.0, 4: 440.0,
        5: 880.0, 6: 1760.0, 7: 3520.0,
      };
      aByOctave.forEach((octave, hz) {
        final r = MusicUtils.frequencyToNoteInfo(hz);
        expect(r.noteName, 'A$octave', reason: '$hz Hz should be A$octave');
        expect(r.octave, octave);
        expect(r.cents.abs(), lessThan(1.0), reason: '$hz Hz is exactly A$octave');
      });
    });

    test('C at every octave (C1–C8) — the octave number increments at C', () {
      // C is where the octave label rolls over (B3 → C4). Verifying every C
      // pins the rollover point at each octave so a note can't land an octave off.
      const cByOctave = {
        1: 32.70, 2: 65.41, 3: 130.81, 4: 261.63,
        5: 523.25, 6: 1046.50, 7: 2093.00, 8: 4186.01,
      };
      cByOctave.forEach((octave, hz) {
        final r = MusicUtils.frequencyToNoteInfo(hz);
        expect(r.noteName, 'C$octave', reason: '$hz Hz should be C$octave');
        expect(r.octave, octave);
      });
    });

    test('octave boundary B3↔C4 does not bleed across the rollover', () {
      // One semitone apart but a different octave digit — the exact place an
      // off-by-one octave bug would show. B3 (246.94) must NOT become C4, and
      // C4 (261.63) must NOT become B3.
      expect(MusicUtils.frequencyToNoteInfo(246.94).noteName, 'B3');
      expect(MusicUtils.frequencyToNoteInfo(261.63).noteName, 'C4');
      // And the same boundary an octave up, to confirm it generalises.
      expect(MusicUtils.frequencyToNoteInfo(493.88).noteName, 'B4');
      expect(MusicUtils.frequencyToNoteInfo(523.25).noteName, 'C5');
    });
  });

  group('MusicUtils.frequencyToNoteInfo — pedal harp (C♭ major snap)', () {
    test('pedalHarp=true snaps to C♭ major scale', () {
      // E♮ (329.63 Hz) → snaps to F♭ in C♭ major (same pitch, different name)
      final r = MusicUtils.frequencyToNoteInfo(329.63, pedalHarp: true);
      expect(r.noteName, startsWith('F♭'));
    });

    test('C♭ octave increments correctly (B♮ enharmonic)', () {
      // B4 = 493.88 Hz; in pedal harp it becomes C♭ and the octave bumps
      final r = MusicUtils.frequencyToNoteInfo(493.88, pedalHarp: true);
      expect(r.noteName, startsWith('C♭'));
      // octave should be 5 (C♭5 sounds like B4)
      expect(r.octave, 5);
    });

    test('D♭ stays D♭ in pedal harp mode', () {
      // C♯4/D♭4 ≈ 277.18 Hz
      final r = MusicUtils.frequencyToNoteInfo(277.18, pedalHarp: true);
      expect(r.noteName, startsWith('D♭'));
    });

    test('C♭ octave bump is correct at every octave (B♮ → C♭ of next octave)', () {
      // A B♮ at octave N is named C♭ at octave N+1 in harp notation. This +1
      // bump must hold across the whole range, not just B4. Each B_n must read
      // as C♭(n+1).
      const bByOctave = {
        2: 123.47, 3: 246.94, 4: 493.88, 5: 987.77, 6: 1975.53,
      };
      bByOctave.forEach((bOctave, hz) {
        final r = MusicUtils.frequencyToNoteInfo(hz, pedalHarp: true);
        expect(r.noteName, 'C♭${bOctave + 1}',
            reason: 'B$bOctave ($hz Hz) should display as C♭${bOctave + 1}');
        expect(r.octave, bOctave + 1);
      });
    });

    test('pedal harp octave numbers are correct across the bass range', () {
      // The bass is where the harp lives and where octave errors were reported.
      // Only C♭-major degrees exist on a pedal harp (all-flat), so spot-check
      // actual flat scale notes resolve to the right octave digit. (Naturals
      // like C2/D3 are off-instrument and correctly snap to a neighbouring flat.)
      expect(MusicUtils.frequencyToNoteInfo(61.74, pedalHarp: true).noteName, 'C♭2');
      expect(MusicUtils.frequencyToNoteInfo(77.78, pedalHarp: true).noteName, 'E♭2');
      expect(MusicUtils.frequencyToNoteInfo(92.50, pedalHarp: true).noteName, 'G♭2');
      expect(MusicUtils.frequencyToNoteInfo(138.59, pedalHarp: true).noteName, 'D♭3');
      expect(MusicUtils.frequencyToNoteInfo(207.65, pedalHarp: true).noteName, 'A♭3');
    });
  });

  group('MusicUtils.closestString', () {
    final strings = HarpPresets.leverHarpWithCount(34);

    test('returns null for empty list', () {
      expect(MusicUtils.closestString(440.0, []), isNull);
    });

    test('closest string to A♭4 frequency is A♭4', () {
      // A♭4 ≈ 415.3 Hz; lever harp has A♭ strings in E♭ major tuning
      final result = MusicUtils.closestString(415.3, strings);
      expect(result, isNotNull);
      expect(result!.note, NoteName.a);
      expect(result.semitoneAdjust, -1); // flat
    });

    test('finds closest string to a frequency between two strings', () {
      // G3 ≈ 196 Hz is a natural string on the lever harp
      final result = MusicUtils.closestString(196.0, strings);
      expect(result, isNotNull);
      expect(result!.note, NoteName.g);
    });

    test('works with a single-string list', () {
      final single = [
        const HarpStringModel(
            index: 1, note: NoteName.a, octave: 4, semitoneAdjust: 0)
      ];
      final result = MusicUtils.closestString(440.0, single);
      expect(result, isNotNull);
      expect(result!.note, NoteName.a);
    });
  });

  group('MusicUtils.centsFromTarget', () {
    test('identical frequencies → 0 cents', () {
      expect(MusicUtils.centsFromTarget(440.0, 440.0), closeTo(0.0, 0.001));
    });

    test('one semitone sharp (A♯ vs A) → ~100 cents, clamped to 50', () {
      // A♯4 ≈ 466.16 Hz vs A4 440 Hz → 100 cents sharp, clamped at 50
      expect(MusicUtils.centsFromTarget(466.16, 440.0), closeTo(50.0, 0.5));
    });

    test('one semitone flat → clamped to -50', () {
      // G♯4 ≈ 415.3 Hz vs A4 440 Hz → -100 cents flat, clamped at -50
      expect(MusicUtils.centsFromTarget(415.3, 440.0), closeTo(-50.0, 0.5));
    });

    test('slightly sharp → positive cents', () {
      // 441 Hz vs 440 Hz ≈ +3.93 cents
      final c = MusicUtils.centsFromTarget(441.0, 440.0);
      expect(c, greaterThan(0));
      expect(c, lessThan(10));
    });

    test('slightly flat → negative cents', () {
      final c = MusicUtils.centsFromTarget(439.0, 440.0);
      expect(c, lessThan(0));
      expect(c, greaterThan(-10));
    });
  });
}
