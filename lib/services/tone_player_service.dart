import 'dart:math';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Plays a harp-like reference tone for a given frequency.
///
/// Uses additive synthesis: fundamental + 4 harmonics, each with an
/// independent exponential decay. Higher harmonics decay faster, producing
/// the characteristic bright-attack → warm-sustain → decay envelope of a
/// plucked harp string.
class TonePlayerService {
  AudioPlayer? _player;

  /// Play a harp-like reference tone at [hz] for ~2 seconds.
  /// Stops any currently playing tone first.
  Future<void> play(double hz) async {
    _player ??= AudioPlayer();
    await _player!.stop();
    // Generate WAV bytes off the main thread to avoid any potential jank.
    final bytes = await compute(_generateTone, hz);
    await _player!.play(BytesSource(bytes));
  }

  Future<void> stop() async {
    await _player?.stop();
  }

  void dispose() {
    _player?.dispose();
    _player = null;
  }

  // ── Synthesis ───────────────────────────────────────────────────────────────

  static Uint8List _generateTone(double hz) {
    const sampleRate  = 44100;
    const numSamples  = sampleRate * 2; // 2 seconds
    const attackLen   = 220;           // ~5 ms linear attack to avoid click

    // Additive partials: (harmonic n, amplitude, decay rate s⁻¹)
    // Amplitudes and decay rates tuned to approximate harp string timbre:
    //   low partials are strong and sustain longer,
    //   high partials add initial brightness then fade quickly.
    const partials = [
      (1, 1.00, 1.4),
      (2, 0.55, 2.5),
      (3, 0.35, 4.0),
      (4, 0.20, 5.5),
      (5, 0.12, 7.0),
    ];

    final pcm = Int16List(numSamples);
    for (var i = 0; i < numSamples; i++) {
      final t      = i / sampleRate;
      final attack = i < attackLen ? i / attackLen : 1.0;
      var sample   = 0.0;
      for (final (n, amp, decay) in partials) {
        sample += amp * exp(-t * decay) * sin(2 * pi * hz * n * t);
      }
      pcm[i] = (sample * attack * 22000).clamp(-32768, 32767).toInt();
    }

    return _toWav(pcm.buffer.asUint8List(), sampleRate);
  }

  /// Wraps raw 16-bit mono PCM bytes in a standard WAV/RIFF header.
  static Uint8List _toWav(Uint8List pcm, int sampleRate) {
    final dataLen = pcm.length;
    final header  = ByteData(44);
    int p = 0;

    void str(String s) { for (final c in s.codeUnits) header.setUint8(p++, c); }
    void u32(int v)    { header.setUint32(p, v, Endian.little); p += 4; }
    void u16(int v)    { header.setUint16(p, v, Endian.little); p += 2; }

    str('RIFF'); u32(36 + dataLen);
    str('WAVE');
    str('fmt '); u32(16); u16(1); u16(1);          // PCM, mono
    u32(sampleRate); u32(sampleRate * 2); u16(2); u16(16);
    str('data'); u32(dataLen);

    final out = Uint8List(44 + dataLen);
    out.setAll(0, header.buffer.asUint8List());
    out.setAll(44, pcm);
    return out;
  }
}
