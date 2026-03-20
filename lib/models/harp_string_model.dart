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

  String get label {
    final acc = semitoneAdjust == -1 ? '♭' : semitoneAdjust == 1 ? '♯' : '';
    return '${note.label}$acc$octave';
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
