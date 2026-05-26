import 'package:flutter_test/flutter_test.dart';
import 'package:harp_tuner/models/harp_string_model.dart';
import 'package:harp_tuner/models/harp_type.dart';

void main() {
  // ── HarpType ─────────────────────────────────────────────────────────────────

  group('HarpType.displayName', () {
    test('leverHarp', () => expect(HarpType.leverHarp.displayName, 'Lever Harp'));
    test('pedalHarp', () => expect(HarpType.pedalHarp.displayName, 'Pedal Harp'));
  });

  group('HarpType.subtitle', () {
    test('leverHarp subtitle contains string count', () {
      expect(HarpType.leverHarp.subtitle, contains('34'));
    });
    test('pedalHarp subtitle contains 47', () {
      expect(HarpType.pedalHarp.subtitle, contains('47'));
    });
  });

  group('HarpType.description', () {
    test('leverHarp description is non-empty', () {
      expect(HarpType.leverHarp.description, isNotEmpty);
    });
    test('pedalHarp description is non-empty', () {
      expect(HarpType.pedalHarp.description, isNotEmpty);
    });
  });

  // ── NoteName ─────────────────────────────────────────────────────────────────

  group('NoteName.label', () {
    test('all 7 note names resolve correctly', () {
      expect(NoteName.c.label, 'C');
      expect(NoteName.d.label, 'D');
      expect(NoteName.e.label, 'E');
      expect(NoteName.f.label, 'F');
      expect(NoteName.g.label, 'G');
      expect(NoteName.a.label, 'A');
      expect(NoteName.b.label, 'B');
    });
  });

  group('NoteName.semitoneOffset', () {
    test('C is 0, D is 2 (whole step)', () {
      expect(NoteName.c.semitoneOffset, 0);
      expect(NoteName.d.semitoneOffset, 2);
    });
    test('E to F is a half step (4→5)', () {
      expect(NoteName.e.semitoneOffset, 4);
      expect(NoteName.f.semitoneOffset, 5);
    });
    test('B is 11', () => expect(NoteName.b.semitoneOffset, 11));
  });

  // ── HarpStringModel ───────────────────────────────────────────────────────────

  group('HarpStringModel.label', () {
    test('natural string: no accidental in label', () {
      const s = HarpStringModel(index: 1, note: NoteName.a, octave: 4);
      expect(s.label, 'A4');
    });

    test('flat string: ♭ in label', () {
      const s = HarpStringModel(
          index: 1, note: NoteName.b, octave: 4, semitoneAdjust: -1);
      expect(s.label, 'B♭4');
    });

    test('sharp string: ♯ in label', () {
      const s = HarpStringModel(
          index: 1, note: NoteName.c, octave: 5, semitoneAdjust: 1);
      expect(s.label, 'C♯5');
    });
  });

  group('HarpStringModel.midiNote', () {
    test('A4 = MIDI 69', () {
      const a4 = HarpStringModel(index: 1, note: NoteName.a, octave: 4);
      expect(a4.midiNote, 69);
    });

    test('C4 = MIDI 60', () {
      const c4 = HarpStringModel(index: 1, note: NoteName.c, octave: 4);
      expect(c4.midiNote, 60);
    });

    test('B♭4 = MIDI 70 (B=71, -1)', () {
      const bb4 = HarpStringModel(
          index: 1, note: NoteName.b, octave: 4, semitoneAdjust: -1);
      expect(bb4.midiNote, 70);
    });
  });

  group('HarpStringModel.frequency', () {
    test('A4 = 440 Hz', () {
      const a4 = HarpStringModel(index: 1, note: NoteName.a, octave: 4);
      expect(a4.frequency, closeTo(440.0, 0.01));
    });

    test('A5 = 880 Hz (one octave above A4)', () {
      const a5 = HarpStringModel(index: 1, note: NoteName.a, octave: 5);
      expect(a5.frequency, closeTo(880.0, 0.01));
    });

    test('C4 ≈ 261.63 Hz', () {
      const c4 = HarpStringModel(index: 1, note: NoteName.c, octave: 4);
      expect(c4.frequency, closeTo(261.63, 0.01));
    });
  });

  group('HarpStringModel.frequencyAt', () {
    test('A4 with 442 Hz reference = 442 Hz', () {
      const a4 = HarpStringModel(index: 1, note: NoteName.a, octave: 4);
      expect(a4.frequencyAt(442.0), closeTo(442.0, 0.01));
    });

    test('A5 with 442 Hz reference = 884 Hz', () {
      const a5 = HarpStringModel(index: 1, note: NoteName.a, octave: 5);
      expect(a5.frequencyAt(442.0), closeTo(884.0, 0.01));
    });
  });

  group('HarpStringModel equality', () {
    test('same note/octave/adjust are equal', () {
      const a = HarpStringModel(index: 1, note: NoteName.a, octave: 4);
      const b = HarpStringModel(index: 2, note: NoteName.a, octave: 4);
      expect(a, equals(b)); // index is ignored in equality
    });

    test('different octave → not equal', () {
      const a4 = HarpStringModel(index: 1, note: NoteName.a, octave: 4);
      const a5 = HarpStringModel(index: 1, note: NoteName.a, octave: 5);
      expect(a4, isNot(equals(a5)));
    });

    test('different semitoneAdjust → not equal', () {
      const natural =
          HarpStringModel(index: 1, note: NoteName.b, octave: 4);
      const flat = HarpStringModel(
          index: 1, note: NoteName.b, octave: 4, semitoneAdjust: -1);
      expect(natural, isNot(equals(flat)));
    });
  });
}
