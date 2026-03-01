import 'dart:math';

enum NoteName { c, d, e, f, g, a, b }

extension NoteNameExt on NoteName {
  String get label {
    switch (this) {
      case NoteName.c: return 'C';
      case NoteName.d: return 'D';
      case NoteName.e: return 'E';
      case NoteName.f: return 'F';
      case NoteName.g: return 'G';
      case NoteName.a: return 'A';
      case NoteName.b: return 'B';
    }
  }

  int get semitoneOffset {
    switch (this) {
      case NoteName.c: return 0;
      case NoteName.d: return 2;
      case NoteName.e: return 4;
      case NoteName.f: return 5;
      case NoteName.g: return 7;
      case NoteName.a: return 9;
      case NoteName.b: return 11;
    }
  }
}

class HarpStringModel {
  final int index; // 1-based, 1 = lowest
  final NoteName note;
  final int octave;

  const HarpStringModel({
    required this.index,
    required this.note,
    required this.octave,
  });

  String get label => '${note.label}$octave';

  /// MIDI note number (C4 = 60)
  int get midiNote => 12 * (octave + 1) + note.semitoneOffset;

  /// Frequency in Hz (A4 = 440 Hz)
  double get frequency => 440.0 * pow(2.0, (midiNote - 69) / 12.0);
}
