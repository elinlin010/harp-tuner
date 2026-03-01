import '../models/harp_string_model.dart';
import '../models/harp_type.dart';

class HarpPresets {
  static const _diatonic = [
    NoteName.c, NoteName.d, NoteName.e, NoteName.f,
    NoteName.g, NoteName.a, NoteName.b,
  ];

  static List<HarpStringModel> _buildRange({
    required int startOctave,
    required NoteName startNote,
    required int endOctave,
    required NoteName endNote,
  }) {
    final strings = <HarpStringModel>[];
    int idx = 1;
    for (int oct = startOctave; oct <= endOctave; oct++) {
      for (final note in _diatonic) {
        if (oct == startOctave && note.semitoneOffset < startNote.semitoneOffset) continue;
        if (oct == endOctave && note.semitoneOffset > endNote.semitoneOffset) continue;
        strings.add(HarpStringModel(index: idx++, note: note, octave: oct));
      }
    }
    return strings;
  }

  /// Lap harp: 15 strings, C4 – C6
  static List<HarpStringModel> get lapHarp => _buildRange(
    startOctave: 4, startNote: NoteName.c,
    endOctave: 6,   endNote: NoteName.c,
  );

  /// Lever (Celtic) harp: 34 strings, A1 – F6
  static List<HarpStringModel> get leverHarp => _buildRange(
    startOctave: 1, startNote: NoteName.a,
    endOctave: 6,   endNote: NoteName.f,
  );

  /// Pedal (concert) harp: 47 strings, C1 – G7
  static List<HarpStringModel> get pedalHarp => _buildRange(
    startOctave: 1, startNote: NoteName.c,
    endOctave: 7,   endNote: NoteName.g,
  );

  static List<HarpStringModel> stringsFor(HarpType type) {
    switch (type) {
      case HarpType.lapHarp:   return lapHarp;
      case HarpType.leverHarp: return leverHarp;
      case HarpType.pedalHarp: return pedalHarp;
    }
  }
}
