import 'package:flutter_test/flutter_test.dart';
import 'package:harp_tuner/data/harp_presets.dart';
import 'package:harp_tuner/models/harp_string_model.dart';
import 'package:harp_tuner/models/harp_type.dart';

void main() {
  group('HarpPresets.leverHarpWithCount', () {
    test('default count (34) returns 34 strings', () {
      final strings = HarpPresets.leverHarpWithCount(34);
      expect(strings.length, 34);
    });

    test('minimum count (19) returns 19 strings', () {
      final strings = HarpPresets.leverHarpWithCount(19);
      expect(strings.length, 19);
    });

    test('maximum count (40) returns 40 strings', () {
      final strings = HarpPresets.leverHarpWithCount(40);
      expect(strings.length, 40);
    });

    test('count below minimum (0) is clamped to 19', () {
      final strings = HarpPresets.leverHarpWithCount(0);
      expect(strings.length, 19);
    });

    test('count above maximum (99) is clamped to 40', () {
      final strings = HarpPresets.leverHarpWithCount(99);
      expect(strings.length, 40);
    });

    test('strings are indexed sequentially from 1', () {
      final strings = HarpPresets.leverHarpWithCount(25);
      for (int i = 0; i < strings.length; i++) {
        expect(strings[i].index, i + 1);
      }
    });

    test('all lever harp strings have flat semitone adjustments on E, A, B', () {
      final strings = HarpPresets.leverHarpWithCount(34);
      for (final s in strings) {
        if (s.note == NoteName.e || s.note == NoteName.a || s.note == NoteName.b) {
          expect(s.semitoneAdjust, -1,
              reason: '${s.note} should be flat (semitoneAdjust = -1)');
        } else {
          expect(s.semitoneAdjust, 0,
              reason: '${s.note} should be natural (semitoneAdjust = 0)');
        }
      }
    });

    test('treble end is always E♭7 regardless of count', () {
      for (final count in [19, 25, 34, 40]) {
        final strings = HarpPresets.leverHarpWithCount(count);
        final top = strings.last;
        expect(top.note, NoteName.e, reason: 'top note should be E (♭)');
        expect(top.octave, 7, reason: 'top octave should be 7');
        expect(top.semitoneAdjust, -1, reason: 'top note should be flat');
      }
    });

    test('full range (40) starts at A♭1', () {
      final strings = HarpPresets.leverHarpWithCount(40);
      final bottom = strings.first;
      expect(bottom.note, NoteName.a);
      expect(bottom.octave, 1);
      expect(bottom.semitoneAdjust, -1);
    });

    test('default range (34) starts at G2', () {
      final strings = HarpPresets.leverHarpWithCount(34);
      final bottom = strings.first;
      expect(bottom.note, NoteName.g);
      expect(bottom.octave, 2);
      expect(bottom.semitoneAdjust, 0);
    });

    test('minimum range (19) starts at A♭4', () {
      final strings = HarpPresets.leverHarpWithCount(19);
      final bottom = strings.first;
      expect(bottom.note, NoteName.a);
      expect(bottom.octave, 4);
      expect(bottom.semitoneAdjust, -1);
    });
  });

  group('HarpPresets.stringsFor', () {
    test('leverHarp with default count returns 34 strings', () {
      final strings = HarpPresets.stringsFor(HarpType.leverHarp);
      expect(strings.length, 34);
    });

    test('leverHarp with custom count 22 returns 22 strings', () {
      final strings = HarpPresets.stringsFor(HarpType.leverHarp, leverStringCount: 22);
      expect(strings.length, 22);
    });

    test('pedalHarp returns 47 strings', () {
      final strings = HarpPresets.stringsFor(HarpType.pedalHarp);
      expect(strings.length, 47);
    });
  });
}
