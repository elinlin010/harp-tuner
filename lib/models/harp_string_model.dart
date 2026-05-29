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
  /// -1 = flat (e.g. B♭), 0 = natural, +1 = sharp
  final int semitoneAdjust;

  const HarpStringModel({
    required this.index,
    required this.note,
    required this.octave,
    this.semitoneAdjust = 0,
  });

  /// Diatonic step from C within the octave (C=0 … B=6).
  int get _diatonicPos {
    switch (note) {
      case NoteName.c: return 0;
      case NoteName.d: return 1;
      case NoteName.e: return 2;
      case NoteName.f: return 3;
      case NoteName.g: return 4;
      case NoteName.a: return 5;
      case NoteName.b: return 6;
    }
  }

  /// Harp-convention register number.
  /// G7 and F7 (top two pedal-harp strings) are register 0.
  /// Each subsequent group of 7 diatonic notes (E…F descending) increments
  /// the register: 1 = E7…F6, 2 = E6…F5, 3 = E5…F4, etc.
  int get harpOctave {
    const g7Diatonic = 7 * 7 + 4; // octave 7, G = 7*7+4 = 53
    final rank = g7Diatonic - (octave * 7 + _diatonicPos);
    if (rank <= 1) return 0;
    return (rank - 2) ~/ 7 + 1;
  }

  /// Note letter + accidental without the register number, e.g. "E♭".
  String get noteWithAccidental {
    final acc = semitoneAdjust == -1 ? '♭' : semitoneAdjust == 1 ? '♯' : '';
    return '${note.label}$acc';
  }

  /// Display label in harp-convention format: register first, e.g. "0G", "1E♭".
  String get label {
    final acc = semitoneAdjust == -1 ? '♭' : semitoneAdjust == 1 ? '♯' : '';
    return '$harpOctave${note.label}$acc';
  }

  /// MIDI note number (C4 = 60), adjusted for accidental.
  int get midiNote => 12 * (octave + 1) + note.semitoneOffset + semitoneAdjust;

  /// Frequency in Hz using standard A4 = 440 Hz.
  double get frequency => 440.0 * pow(2.0, (midiNote - 69) / 12.0);

  /// Frequency in Hz using a custom A4 reference (for calibrated tuning).
  double frequencyAt(double a4Hz) => a4Hz * pow(2.0, (midiNote - 69) / 12.0);

  @override
  bool operator ==(Object other) =>
      other is HarpStringModel &&
      other.note == note &&
      other.octave == octave &&
      other.semitoneAdjust == semitoneAdjust;

  @override
  int get hashCode => Object.hash(note, octave, semitoneAdjust);
}
