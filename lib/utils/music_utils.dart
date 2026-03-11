import 'dart:math';

class MusicUtils {
  MusicUtils._();

  static const _sharps = [
    'C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'
  ];
  static const _flats = [
    'C', 'Db', 'D', 'Eb', 'E', 'F', 'Gb', 'G', 'Ab', 'A', 'Bb', 'B'
  ];

  /// Converts a frequency in Hz to the nearest note name (e.g. "A4") and the
  /// deviation in cents from that note (-50..+50).
  static ({String noteName, int octave, double cents}) frequencyToNoteInfo(
      double hz, {bool preferFlats = false}) {
    final midi = 69.0 + 12.0 * log(hz / 440.0) / ln2;
    final roundedMidi = midi.round();
    final cents = (midi - roundedMidi) * 100.0;
    final noteIndex = ((roundedMidi % 12) + 12) % 12;
    final octave = (roundedMidi ~/ 12) - 1;
    final names = preferFlats ? _flats : _sharps;
    return (
      noteName: '${names[noteIndex]}$octave',
      octave: octave,
      cents: cents.clamp(-50.0, 50.0),
    );
  }

  /// Cents deviation of [hz] from [targetHz].
  /// Positive = sharp, negative = flat.
  static double centsFromTarget(double hz, double targetHz) {
    return (1200.0 * log(hz / targetHz) / ln2).clamp(-50.0, 50.0);
  }
}
