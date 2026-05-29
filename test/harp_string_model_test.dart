import 'package:flutter_test/flutter_test.dart';
import 'package:harp_tuner/data/harp_presets.dart';
import 'package:harp_tuner/models/harp_string_model.dart';

HarpStringModel _str(NoteName note, int octave, {int semitoneAdjust = 0}) =>
    HarpStringModel(index: 1, note: note, octave: octave, semitoneAdjust: semitoneAdjust);

void main() {
  group('HarpStringModel.harpOctave', () {
    test('G7 and F7 are register 0 (top two pedal-harp strings)', () {
      expect(_str(NoteName.g, 7).harpOctave, 0);
      expect(_str(NoteName.f, 7).harpOctave, 0);
    });

    test('E7 through F6 are register 1', () {
      for (final note in [NoteName.e, NoteName.d, NoteName.c]) {
        expect(_str(note, 7).harpOctave, 1, reason: '$note octave 7');
      }
      for (final note in [NoteName.b, NoteName.a, NoteName.g, NoteName.f]) {
        expect(_str(note, 6).harpOctave, 1, reason: '$note octave 6');
      }
    });

    test('E6 through F5 are register 2', () {
      for (final note in [NoteName.e, NoteName.d, NoteName.c]) {
        expect(_str(note, 6).harpOctave, 2, reason: '$note octave 6');
      }
      for (final note in [NoteName.b, NoteName.a, NoteName.g, NoteName.f]) {
        expect(_str(note, 5).harpOctave, 2, reason: '$note octave 5');
      }
    });

    test('C1 (lowest pedal-harp note) is register 7', () {
      expect(_str(NoteName.c, 1).harpOctave, 7);
    });

    test('accidentals do not affect the register number', () {
      expect(_str(NoteName.g, 7, semitoneAdjust: -1).harpOctave, 0);
      expect(_str(NoteName.e, 7, semitoneAdjust: -1).harpOctave, 1);
    });
  });

  group('HarpStringModel.label', () {
    test('top pedal-harp strings use register-first format', () {
      expect(_str(NoteName.g, 7).label, '0G');
      expect(_str(NoteName.f, 7).label, '0F');
      expect(_str(NoteName.g, 7, semitoneAdjust: -1).label, '0G♭');
      expect(_str(NoteName.f, 7, semitoneAdjust: -1).label, '0F♭');
    });

    test('register 1 labels are correct', () {
      expect(_str(NoteName.e, 7, semitoneAdjust: -1).label, '1E♭');
      expect(_str(NoteName.c, 7, semitoneAdjust: -1).label, '1C♭');
      expect(_str(NoteName.b, 6, semitoneAdjust: -1).label, '1B♭');
      expect(_str(NoteName.f, 6, semitoneAdjust: -1).label, '1F♭');
    });

    test('natural note has no accidental suffix', () {
      expect(_str(NoteName.c, 4).label, '4C');
    });

    test('sharp note gets ♯ suffix', () {
      expect(_str(NoteName.c, 4, semitoneAdjust: 1).label, '4C♯');
    });
  });

  group('HarpStringModel.noteWithAccidental', () {
    test('natural note returns letter only', () {
      expect(_str(NoteName.c, 4).noteWithAccidental, 'C');
    });

    test('flat note returns letter + ♭', () {
      expect(_str(NoteName.e, 7, semitoneAdjust: -1).noteWithAccidental, 'E♭');
    });

    test('sharp note returns letter + ♯', () {
      expect(_str(NoteName.f, 4, semitoneAdjust: 1).noteWithAccidental, 'F♯');
    });
  });

  group('Pedal harp full-range register sanity', () {
    test('top string (G♭7) is register 0', () {
      final strings = HarpPresets.pedalHarp;
      final top = strings.last;
      expect(top.note, NoteName.g);
      expect(top.harpOctave, 0);
      expect(top.label, '0G♭');
    });

    test('bottom string (C♭1) is register 7', () {
      final strings = HarpPresets.pedalHarp;
      final bottom = strings.first;
      expect(bottom.note, NoteName.c);
      expect(bottom.harpOctave, 7);
      expect(bottom.label, '7C♭');
    });
  });

  group('Lever harp register sanity', () {
    test('top string (E♭7) is register 1', () {
      final strings = HarpPresets.leverHarpWithCount(40);
      final top = strings.last;
      expect(top.note, NoteName.e);
      expect(top.harpOctave, 1);
      expect(top.label, '1E♭');
    });
  });
}
