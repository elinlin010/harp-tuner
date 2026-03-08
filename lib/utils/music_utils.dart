import 'dart:math';
import '../models/harp_string_model.dart';

class MusicUtils {
  MusicUtils._();

  static const _noteNames = [
    'C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'
  ];

  /// Converts a frequency in Hz to the nearest note name (e.g. "A4") and the
  /// deviation in cents from that note (-50..+50).
  static ({String noteName, int octave, double cents}) frequencyToNoteInfo(
      double hz) {
    final midi = 69.0 + 12.0 * log(hz / 440.0) / ln2;
    final roundedMidi = midi.round();
    final cents = (midi - roundedMidi) * 100.0;
    final noteIndex = ((roundedMidi % 12) + 12) % 12;
    final octave = (roundedMidi ~/ 12) - 1;
    return (
      noteName: '${_noteNames[noteIndex]}$octave',
      octave: octave,
      cents: cents.clamp(-50.0, 50.0),
    );
  }

  /// Finds the closest harp string to the given frequency (in octave distance).
  /// Returns null if [strings] is empty.
  static HarpStringModel? closestString(
      double hz, List<HarpStringModel> strings) {
    if (strings.isEmpty) return null;
    HarpStringModel? best;
    double bestDiff = double.infinity;
    for (final s in strings) {
      // Use log2 ratio so distance is symmetric in both directions
      final diff = (log(hz / s.frequency) / ln2).abs();
      if (diff < bestDiff) {
        bestDiff = diff;
        best = s;
      }
    }
    return best;
  }

  /// Cents deviation of [hz] from [targetHz].
  /// Positive = sharp, negative = flat.
  static double centsFromTarget(double hz, double targetHz) {
    return (1200.0 * log(hz / targetHz) / ln2).clamp(-50.0, 50.0);
  }
}
