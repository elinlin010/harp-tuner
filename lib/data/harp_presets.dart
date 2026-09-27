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

  static const leverStringMin = 19;
  static const leverStringMax = 40;

  /// Every string a lever harp layout can use: 40 strings, A♭1–E♭7, tuned to
  /// E♭ major (levers disengaged). A layout is a contiguous window of it.
  static final List<HarpStringModel> leverPool = _buildRange(
    startOctave: 1, startNote: NoteName.a,
    endOctave: 7,   endNote: NoteName.e,
    flatNotes: {NoteName.e, NoteName.a, NoteName.b},
  );

  static const _leverPoolTop = 39; // E♭7
  static const _leverA6 = 35;      // A♭6 ("1A♭")

  /// Pool index of the top string for a string count when the user has not
  /// picked their own range. The treble end is E♭7 except for 23 strings,
  /// which runs G3–A♭6 ("4G"–"1A♭"), the common small lever harp compass.
  static int leverDefaultTopIndex(int count) =>
      count == 23 ? _leverA6 : _leverPoolTop;

  /// Clamps [count] to 19–40 and [topIndex] (a [leverPool] index, `null` =
  /// the default for the count) so the window fits the pool. Returns the
  /// effective (count, topIndex).
  static (int, int) leverRange(int count, int? topIndex) {
    final c = count.clamp(leverStringMin, leverStringMax);
    final top = (topIndex ?? leverDefaultTopIndex(c)).clamp(c - 1, _leverPoolTop);
    return (c, top);
  }

  /// Lever (Celtic) harp: [count] strings (19–40) ending at [leverPool]
  /// index [topIndex], or at [leverDefaultTopIndex] when it is `null`.
  static List<HarpStringModel> leverHarp(int count, {int? topIndex}) {
    final (c, top) = leverRange(count, topIndex);
    final taken = leverPool.sublist(top - c + 1, top + 1);
    return List.generate(taken.length, (i) => HarpStringModel(
      index: i + 1,
      note: taken[i].note,
      octave: taken[i].octave,
      semitoneAdjust: taken[i].semitoneAdjust,
    ));
  }

  /// Lever harp with [count] strings in its default range.
  static List<HarpStringModel> leverHarpWithCount(int count) => leverHarp(count);

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

  static List<HarpStringModel> stringsFor(HarpType type,
      {int leverStringCount = 34, int? leverTopIndex}) {
    switch (type) {
      case HarpType.leverHarp:
        return leverHarp(leverStringCount, topIndex: leverTopIndex);
      case HarpType.pedalHarp: return pedalHarp;
    }
  }
}
