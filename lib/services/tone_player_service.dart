import 'dart:math';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Plays a harp-like reference tone for a given frequency.
///
/// Uses additive synthesis with inharmonicity: fundamental + 7 sustained
/// harmonics plus 4 fast-decaying pluck-transient partials. Inharmonicity
/// stretches each partial slightly (as in real string stiffness), and the
/// transient partials fade within ~10–25 ms to reproduce the bright "ping"
/// of a plucked harp string without sounding electronic.
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
    const sampleRate = 44100;
    const numSamples = sampleRate * 2; // 2 seconds
    const attackLen  = 150;            // ~3.4 ms sharp attack for pluck character

    // Inharmonicity: real harp strings are slightly stiff, so each partial
    // is stretched above its harmonic: freq_n = n·f₀·√(1 + B·n²).
    // B ≈ 0.00018 is typical for mid-range concert harp strings.
    const B = 0.00018;

    // Sustained partials: fundamental + 7 harmonics with natural decay.
    // Low partials are strongest and sustain longest.
    const partials = [
      (1, 1.00, 1.0),
      (2, 0.58, 1.9),
      (3, 0.38, 3.1),
      (4, 0.24, 4.6),
      (5, 0.16, 6.2),
      (6, 0.10, 8.0),
      (7, 0.06, 10.5),
      (8, 0.04, 13.0),
    ];

    // Pluck transient: very high harmonics that vanish within ~10–25 ms,
    // giving the attack its characteristic bright "ping" without sounding
    // electronic.
    const transient = [
      (9,  0.11, 55.0),
      (10, 0.08, 72.0),
      (11, 0.06, 90.0),
      (12, 0.04, 112.0),
    ];

    final pcm = Int16List(numSamples);
    for (var i = 0; i < numSamples; i++) {
      final t      = i / sampleRate;
      final attack = i < attackLen ? i / attackLen : 1.0;
      var sample   = 0.0;
      for (final (n, amp, decay) in partials) {
        final freq = hz * n * sqrt(1.0 + B * n * n);
        sample += amp * exp(-t * decay) * sin(2 * pi * freq * t);
      }
      for (final (n, amp, decay) in transient) {
        final freq = hz * n * sqrt(1.0 + B * n * n);
        sample += amp * exp(-t * decay) * sin(2 * pi * freq * t);
      }
      pcm[i] = (sample * attack * 12000).clamp(-32768, 32767).toInt();
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
