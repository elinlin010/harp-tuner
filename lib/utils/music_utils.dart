import 'dart:math';
import '../models/harp_string_model.dart';

class MusicUtils {
  MusicUtils._();

  static const _noteNamesSharps = [
    'C', 'C♯', 'D', 'D♯', 'E', 'F', 'F♯', 'G', 'G♯', 'A', 'A♯', 'B'
  ];
  static const _noteNamesFlats = [
    'C', 'D♭', 'D', 'E♭', 'E', 'F', 'G♭', 'G', 'A♭', 'A', 'B♭', 'B'
  ];
  // Pedal harp (all-flat / C♭ major): E♮→F♭, B♮→C♭; all others same as flats.
  static const _noteNamesPedalHarp = [
    'C', 'D♭', 'D', 'E♭', 'F♭', 'F', 'G♭', 'G', 'A♭', 'A', 'B♭', 'C♭'
  ];

  /// Converts a frequency in Hz to the nearest note name (e.g. "A4") and the
  /// deviation in cents from that note (-50..+50).
  ///
  /// [a4Hz] is the reference pitch for A4 (default 440 Hz). Changing this
  /// shifts all note targets proportionally — the standard tuner calibration.
  /// [pedalHarp] uses C♭-major enharmonics (E♮→F♭, B♮→C♭).
  static ({String noteName, int octave, double cents}) frequencyToNoteInfo(
      double hz, {bool preferFlats = false, bool pedalHarp = false, double a4Hz = 440.0}) {
    final midi = 69.0 + 12.0 * log(hz / a4Hz) / ln2;
    final roundedMidi = midi.round();
    final cents = (midi - roundedMidi) * 100.0;
    final noteIndex = ((roundedMidi % 12) + 12) % 12;
    final octave = (roundedMidi ~/ 12) - 1;
    final names = pedalHarp ? _noteNamesPedalHarp
        : (preferFlats ? _noteNamesFlats : _noteNamesSharps);
    return (
      noteName: '${names[noteIndex]}$octave',
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
