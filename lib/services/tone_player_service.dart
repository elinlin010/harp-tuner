import 'dart:math';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Plays a harp-like reference tone for a given frequency.
///
/// Four layers that distinguish a real plucked string from a MIDI patch:
///
/// 1. **Inharmonicity** — each partial is stretched above its ideal harmonic:
///    freq_n = n·f₀·√(1 + B·n²), where B ≈ 0.00018 for concert harp strings.
///
/// 2. **Two-phase decay** — 60% of each partial's energy decays fast (the
///    bright initial ring-down), 40% decays slowly (the long sustain tail).
///    Real plucked strings lose energy in two stages; pure single-exponent
///    decay sounds synthetic.
///
/// 3. **Beating secondary modes** — each partial has a companion sinusoid at
///    freq + beatHz (0.55 Hz for fundamental, increasing per harmonic). This
///    models the two orthogonal polarization planes of a vibrating string.
///    Their slight frequency difference creates a natural amplitude shimmer.
///
/// 4. **Early reflections** — a short post-pass adds echoes at ~20 ms, ~35 ms,
///    and ~60 ms after each sample is computed, giving the impression of a
///    small acoustic space without the cost of full reverb.
class TonePlayerService {
  AudioPlayer? _player;

  /// Play a harp-like reference tone at [hz] for ~2 seconds.
  /// Stops any currently playing tone first.
  Future<void> play(double hz) async {
    _player ??= AudioPlayer();
    // Capture player locally so a concurrent dispose() can't null it between
    // the compute() await and the final play() call.
    final player = _player!;
    await player.stop();
    // Generate WAV bytes off the main thread to avoid any potential jank.
    final bytes = await compute(_generateTone, hz);
    if (_player == null) return; // disposed while computing
    await player.play(BytesSource(bytes));
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
    const attackLen  = 150;            // ~3.4 ms sharp pluck attack

    // String inharmonicity: freq_n = n·f₀·√(1 + B·n²).
    const B = 0.00018;

    // Sustained partials: (harmonic n, amplitude, fastDecay, slowDecay, beatHz)
    // Two-phase envelope: 0.60·exp(-t·fast) + 0.40·exp(-t·slow)
    //   fast  — bright ring-down in first 100–300 ms
    //   slow  — long sustain tail, like the string still ringing
    // beatHz — companion sinusoid offset, models the two polarization planes
    //   of a real plucked string vibrating in horizontal + vertical planes.
    //   Their slightly different frequencies create a natural amplitude shimmer.
    const partials = [
      (1, 1.00, 2.5,  0.70, 0.55),
      (2, 0.55, 3.8,  1.20, 0.80),
      (3, 0.36, 5.5,  2.00, 1.05),
      (4, 0.22, 7.5,  3.00, 1.30),
      (5, 0.14, 9.8,  4.20, 1.55),
      (6, 0.09, 12.5, 5.80, 1.80),
      (7, 0.05, 16.0, 7.80, 2.05),
      (8, 0.03, 20.0, 10.0, 2.30),
    ];

    // Pluck transient: high harmonics that vanish within ~10–25 ms, giving the
    // attack its bright "ping" without sounding electronic.
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

      for (final (n, amp, fast, slow, beatHz) in partials) {
        final freq = hz * n * sqrt(1.0 + B * n * n);
        final env  = 0.60 * exp(-t * fast) + 0.40 * exp(-t * slow);
        // Primary polarization plane
        sample += amp * env * sin(2 * pi * freq * t);
        // Secondary polarization plane — 10% amplitude, slightly offset pitch
        sample += amp * 0.10 * env * sin(2 * pi * (freq + beatHz) * t);
      }
      for (final (n, amp, decay) in transient) {
        final freq = hz * n * sqrt(1.0 + B * n * n);
        sample += amp * exp(-t * decay) * sin(2 * pi * freq * t);
      }

      pcm[i] = (sample * attack * 9000).clamp(-32768, 32767).toInt();
    }

    // Early reflections: three echo taps at ~20 ms, ~35 ms, ~60 ms.
    // Applied as a forward pass so each tap already has the correct dry signal.
    // Adds acoustic-space impression without full convolution reverb.
    const d1 = 882;   // 20 ms
    const d2 = 1543;  // 35 ms
    const d3 = 2646;  // 60 ms
    for (var i = d1; i < numSamples; i++) {
      double wet = pcm[i - d1] * 0.28;
      if (i >= d2) wet += pcm[i - d2] * 0.16;
      if (i >= d3) wet += pcm[i - d3] * 0.09;
      final mixed = pcm[i] + wet;
      pcm[i] = mixed.clamp(-32768.0, 32767.0).toInt();
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
