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
    Set<NoteName> flatNotes = const {},
  }) {
    final strings = <HarpStringModel>[];
    int idx = 1;
    for (int oct = startOctave; oct <= endOctave; oct++) {
      for (final note in _diatonic) {
        if (oct == startOctave && note.semitoneOffset < startNote.semitoneOffset) continue;
        if (oct == endOctave && note.semitoneOffset > endNote.semitoneOffset) continue;
        strings.add(HarpStringModel(
          index: idx++,
          note: note,
          octave: oct,
          semitoneAdjust: flatNotes.contains(note) ? -1 : 0,
        ));
      }
    }
    return strings;
  }

  /// Lever (Celtic) harp with configurable string count (19–40).
  /// The full pool of 40 strings runs A♭1–E♭7; the treble end (E♭7) is fixed
  /// and smaller counts shorten the bass range.
  static List<HarpStringModel> leverHarpWithCount(int count) {
    final pool = _buildRange(
      startOctave: 1, startNote: NoteName.a,
      endOctave: 7,   endNote: NoteName.e,
      flatNotes: {NoteName.e, NoteName.a, NoteName.b},
    );
    final clamped = count.clamp(19, 40);
    final taken = pool.sublist(pool.length - clamped);
    return List.generate(taken.length, (i) => HarpStringModel(
      index: i + 1,
      note: taken[i].note,
      octave: taken[i].octave,
      semitoneAdjust: taken[i].semitoneAdjust,
    ));
  }

  /// Pedal (concert) harp: 47 strings, C♭1 – G♭7
  /// All pedals in flat position (C♭ major) — standard resting/practice tuning
  static List<HarpStringModel> get pedalHarp => _buildRange(
    startOctave: 1, startNote: NoteName.c,
    endOctave: 7,   endNote: NoteName.g,
    flatNotes: {
      NoteName.c, NoteName.d, NoteName.e, NoteName.f,
      NoteName.g, NoteName.a, NoteName.b,
    },
  );

  static List<HarpStringModel> stringsFor(HarpType type, {int leverStringCount = 34}) {
    switch (type) {
      case HarpType.leverHarp: return leverHarpWithCount(leverStringCount);
      case HarpType.pedalHarp: return pedalHarp;
    }
  }
}
