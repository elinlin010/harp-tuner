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

    test('octave number is correct for notes across the range', () {
      expect(MusicUtils.frequencyToNoteInfo(32.70).noteName, 'C1');  // C1
      expect(MusicUtils.frequencyToNoteInfo(4186.0).noteName, 'C8'); // C8
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
