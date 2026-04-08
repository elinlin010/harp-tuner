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
