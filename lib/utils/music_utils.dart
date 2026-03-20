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
  /// [pedalHarp] snaps to the nearest C♭-major scale degree so only flat note
  /// names (D♭, E♭, F♭, G♭, A♭, B♭, C♭) ever appear — natural notes are
  /// never shown in pedal harp mode.
  static ({String noteName, int octave, double cents}) frequencyToNoteInfo(
      double hz, {bool preferFlats = false, bool pedalHarp = false, double a4Hz = 440.0}) {
    final midi = 69.0 + 12.0 * log(hz / a4Hz) / ln2;
    // Pedal harp: snap to the nearest C♭-major note (diatonic snap) so that
    // only flat note names appear. For all other modes, snap chromatically.
    final roundedMidi = pedalHarp ? _snapToCbMajor(midi) : midi.round();
    final cents = (midi - roundedMidi) * 100.0;
    final noteIndex = ((roundedMidi % 12) + 12) % 12;
    final octave = (roundedMidi ~/ 12) - 1;
    final names = pedalHarp ? _noteNamesPedalHarp
        : (preferFlats ? _noteNamesFlats : _noteNamesSharps);
    // C♭ (index 11) is enharmonic to B♮ but belongs to the octave above in
    // harp notation — the C string in octave N flat sounds like B(N-1), so
    // the displayed octave must be incremented by 1 to match string labels.
    final displayOctave = (pedalHarp && noteIndex == 11) ? octave + 1 : octave;
    return (
      noteName: '${names[noteIndex]}$displayOctave',
      octave: displayOctave,
      cents: cents.clamp(-50.0, 50.0),
    );
  }

  /// Snaps [midi] to the nearest note in the C♭ major scale
  /// (D♭, E♭, F♭, G♭, A♭, B♭, C♭ — semitone offsets 1,3,4,6,8,10,11).
  /// On a tie (pitch exactly between two scale notes), the lower note wins so
  /// the display reads "sharp of the lower string" rather than "flat of the
  /// upper string".
  static int _snapToCbMajor(double midi) {
    const scaleDegrees = [1, 3, 4, 6, 8, 10, 11];
    final approxOct = midi ~/ 12;
    double bestDist = double.infinity;
    double bestNote = midi;
    for (final deg in scaleDegrees) {
      for (final oct in [approxOct - 1, approxOct, approxOct + 1]) {
        final candidate = oct * 12.0 + deg;
        final dist = (midi - candidate).abs();
        if (dist < bestDist || (dist == bestDist && candidate < bestNote)) {
          bestDist = dist;
          bestNote = candidate;
        }
      }
    }
    return bestNote.round();
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
