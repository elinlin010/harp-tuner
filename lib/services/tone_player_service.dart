import 'dart:math';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Plays a harp-like reference tone for a given frequency.
///
/// Twelve acoustic layers model a real plucked concert harp string,
/// specifically targeting what distinguishes harp from piano:
///
///  1. Register-scaled inharmonicity (gut/nylon B curve)
///  2. Pitch-dependent two-phase decay
///  3. Dynamic partial count (harmonics below Nyquist only)
///  4. Soundboard body filter with narrow-Q resonance peaks
///  5. Soft finger-pad pluck noise (low-pass, raised-cosine envelope)
///  6. Gentle body resonance (not a percussive knock)
///  7. Partial frequency jitter (slow random walk)
///  8. Register-scaled polarisation beating
///  9. Pitch glide/scoop — finger stretch raises pitch ~15 cents at
///     attack, glides down over 50–200 ms. THE plucked-string signature
///     that hammer-struck piano lacks entirely.
/// 10. Pluck-position comb filter — finger at ~1/7 string length
///     suppresses 7th harmonic, shaping the warm harp spectrum.
/// 11. Sympathetic string resonance — low-amplitude octave and fifth
///     tones with delayed onset create the harp's "halo of sound".
/// 12. Early reflections for acoustic space.
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
    final rng = Random(hz.hashCode);   // deterministic per-pitch

    // ── 1. Register-scaled inharmonicity ────────────────────────────────────
    // Gut (bass) → nylon (treble) stiffness curve.
    final B = 0.00005 + 0.0000035 * hz;

    // ── 2. Pitch-dependent decay ────────────────────────────────────────────
    // At C2 (~65 Hz) ≈ 1.1×; at C7 (~2093 Hz) ≈ 5.2×.
    final decayScale = 1.0 + hz / 500.0;

    // ── 3. Dynamic partial count — gut/nylon cuts off around 5 kHz ──────────
    // Much lower than steel piano strings (8+ kHz). This is a key difference.
    final maxHarmonic = max(2, min(12, (5000 / hz).floor()));

    // ── 4. Soundboard body filter ───────────────────────────────────────────
    // Harp soundboard: narrow-Q peaks at body modes + steeper roll-off than
    // piano. Gut/nylon strings have almost no energy above 3 kHz.
    double bodyGain(double freq) {
      if (freq < 100) return freq / 100.0;
      // Resonant peak at ~180 Hz (body mode) and ~400 Hz (soundboard mode)
      final peak1 = 0.30 * exp(-pow((freq - 180) / 60, 2));
      final peak2 = 0.15 * exp(-pow((freq - 400) / 80, 2));
      double gain = 1.0 + peak1 + peak2;
      // Steep roll-off above 2 kHz (gut/nylon string damping)
      if (freq > 2000) gain *= pow(2000 / freq, 1.5); // ~9 dB/oct
      return gain;
    }

    // ── 10. Pluck-position comb filter ──────────────────────────────────────
    // Harpist plucks at ~1/7 of the string length from their end.
    // This suppresses the 7th harmonic and its multiples, giving harp its
    // characteristic warm, fundamental-heavy tone.
    const pluckPos = 1.0 / 7.0;
    double pluckGain(int n) {
      // sin(n * pi * pluckPos) = 0 when n is a multiple of 7
      return sin(n * pi * pluckPos).abs().clamp(0.15, 1.0);
    }

    // ── Attack: soft finger-pad release ─────────────────────────────────────
    // Harp pluck is softer than piano hammer. Raised-cosine ramp (not linear).
    // Bass: ~5 ms. Treble: ~2 ms. Both softer than the v1 linear ramp.
    final attackLen = max(88, (220 - hz * 0.06).round());

    // ── 8. Polarisation beating ─────────────────────────────────────────────
    final beatAmp = 0.10 * (1.0 - (hz - 200) / 2000).clamp(0.03, 1.0);

    // ── Partial amplitudes: strong fundamental dominance ────────────────────
    // Harp fundamental stands 6–12 dB above the 2nd harmonic (much more than
    // piano). This is the "golden, limpid" harp timbre.
    double partialAmp(int n) {
      if (n == 1) return 1.0;
      if (n == 2) return 0.35; // ~9 dB below fundamental (vs 0.55 before)
      return 0.35 * pow(2.0 / n, 1.5);
    }

    // Decay rates per harmonic — frequency-dependent damping from gut/nylon.
    // Higher harmonics die much faster in gut than in steel.
    double baseFast(int n) => 2.5 + (n - 1) * 2.0;
    double baseSlow(int n) => 0.70 + (n - 1) * 0.7;
    double beatHz(int n)   => 0.55 + (n - 1) * 0.25;

    // ── 9. Pitch glide (scoop) ──────────────────────────────────────────────
    // Finger deflects string sideways → tension rises → pitch goes sharp.
    // As amplitude decays, pitch settles to nominal. ~15 cents over 80–200 ms.
    // This is THE plucked-string signature that piano hammers never produce.
    final glideCents = 15.0; // cents sharp at onset
    final glideDecaySamples = (sampleRate * (0.08 + 0.12 * (1.0 - hz / 3000).clamp(0.0, 1.0))).round();
    // Pre-compute pitch multiplier table for the glide.
    final glideTable = Float64List(numSamples);
    for (var i = 0; i < numSamples; i++) {
      final cents = i < glideDecaySamples
          ? glideCents * pow(1.0 - i / glideDecaySamples, 2) // quadratic ease
          : 0.0;
      glideTable[i] = pow(2.0, cents / 1200.0).toDouble();
    }

    // ── 7. Partial frequency jitter ─────────────────────────────────────────
    final jitterTables = List.generate(maxHarmonic, (_) {
      final table = Float64List(numSamples);
      double phase = rng.nextDouble() * 2 * pi;
      final rate = 2.0 + rng.nextDouble() * 3.0;
      for (var i = 0; i < numSamples; i++) {
        table[i] = sin(phase) * 0.0003;
        phase += 2 * pi * rate / sampleRate;
      }
      return table;
    });

    // ── 5. Pluck noise: soft finger-pad (low-pass, raised-cosine) ───────────
    // Harp finger pad = soft, rounded noise. Piano hammer = hard, broadband.
    // Cutoff 1–2.5 kHz (vs piano's 5–10 kHz). Raised-cosine envelope shape.
    final noiseCutoffHz = (1000 + hz * 0.3).clamp(1000.0, 2500.0);
    final noiseDurationMs = (12.0 - hz * 0.003).clamp(5.0, 15.0); // ms
    final noiseDurationSamples = (noiseDurationMs * sampleRate / 1000).round();
    final noiseAmp = 0.045; // softer than before (was 0.07)
    final noiseLpCoeff = (2 * pi * noiseCutoffHz / sampleRate).clamp(0.0, 0.99);
    double noiseLpState = 0;

    // ── 6. Body resonance (gentle, not percussive) ──────────────────────────
    // Harp body is thin spruce — lighter, more resonant than piano's cast-iron
    // frame. Two soft modes that ring ~15 ms (was 8 ms "knock" — too piano).
    const body1Hz = 180.0;
    const body2Hz = 400.0;
    const bodyDecay = 280.0; // ~15 ms ring (softer than the old 550 "knock")

    // ── 11. Sympathetic string resonance ────────────────────────────────────
    // All harp strings are open (no dampers like piano). When one string is
    // plucked, harmonically related strings resonate sympathetically through
    // the soundboard. This creates the characteristic "halo of sound".
    // Model: low-amplitude tones at octave below, octave above, and fifth
    // above, with delayed onset (~60 ms) and very slow decay.
    final sympFreqs = [hz * 0.5, hz * 2.0, hz * 1.5]; // oct below, oct above, fifth
    final sympAmps  = [0.018, 0.012, 0.010];            // -35 to -40 dB below primary
    const sympOnsetSamples = 2646; // ~60 ms delay
    const sympDecay = 0.8;         // very slow decay

    final pcm = Int16List(numSamples);
    for (var i = 0; i < numSamples; i++) {
      final t = i / sampleRate;
      // Raised-cosine attack (softer than linear ramp)
      final attack = i < attackLen
          ? 0.5 * (1.0 - cos(pi * i / attackLen))
          : 1.0;
      final glide = glideTable[i];
      var sample = 0.0;

      // ── Sustained partials ────────────────────────────────────────────────
      for (var n = 1; n <= maxHarmonic; n++) {
        final jitter = jitterTables[n - 1][i];
        final freq = hz * n * sqrt(1.0 + B * n * n) * glide * (1.0 + jitter);
        final fast = baseFast(n) * decayScale;
        final slow = baseSlow(n) * decayScale;
        final env  = 0.60 * exp(-t * fast) + 0.40 * exp(-t * slow);
        final amp  = partialAmp(n) * bodyGain(freq) * pluckGain(n);

        sample += amp * env * sin(2 * pi * freq * t);
        sample += amp * beatAmp * env * sin(2 * pi * (freq + beatHz(n)) * t);
      }

      // ── Pluck transient partials ──────────────────────────────────────────
      for (var k = 0; k < 3; k++) {
        final n = maxHarmonic + 1 + k;
        final freq = hz * n * sqrt(1.0 + B * n * n) * glide;
        if (freq > 12000) break; // gut/nylon cutoff
        final tAmp = 0.08 / (1.0 + k * 0.7);
        final tDecay = 55.0 + k * 20.0;
        sample += tAmp * bodyGain(freq) * pluckGain(n)
            * exp(-t * tDecay) * sin(2 * pi * freq * t);
      }

      // ── Soft pluck noise (raised-cosine envelope, low-pass filtered) ──────
      if (i < noiseDurationSamples) {
        final rawNoise = rng.nextDouble() * 2.0 - 1.0;
        noiseLpState += noiseLpCoeff * (rawNoise - noiseLpState);
        // Raised-cosine envelope: gentle rise and fall, not abrupt
        final noiseEnv = 0.5 * (1.0 - cos(2 * pi * i / noiseDurationSamples));
        sample += noiseAmp * noiseLpState * noiseEnv;
      }

      // ── Body resonance (gentle ring, not hammer-like knock) ───────────────
      final bodyEnv = exp(-t * bodyDecay);
      // Raised-cosine onset for first 1 ms to soften the body excitation
      final bodyOnset = i < 44 ? 0.5 * (1.0 - cos(pi * i / 44)) : 1.0;
      sample += 0.035 * bodyEnv * bodyOnset * sin(2 * pi * body1Hz * t);
      sample += 0.020 * bodyEnv * bodyOnset * sin(2 * pi * body2Hz * t);

      // ── Sympathetic resonance ("halo of sound") ───────────────────────────
      if (i > sympOnsetSamples) {
        final st = (i - sympOnsetSamples) / sampleRate;
        // Gentle fade-in over ~40 ms
        final sympFade = min(1.0, st / 0.04);
        for (var s = 0; s < sympFreqs.length; s++) {
          if (sympFreqs[s] > 20 && sympFreqs[s] < 4000) {
            sample += sympAmps[s] * sympFade * exp(-st * sympDecay)
                * sin(2 * pi * sympFreqs[s] * st);
          }
        }
      }

      pcm[i] = (sample * attack * 9000).clamp(-32768, 32767).toInt();
    }

    // ── 12. Early reflections — acoustic space ──────────────────────────────
    final dry = Int16List.fromList(pcm);
    const d1 = 882;   // 20 ms
    const d2 = 1543;  // 35 ms
    const d3 = 2646;  // 60 ms
    for (var i = d1; i < numSamples; i++) {
      double wet = dry[i - d1] * 0.18;
      if (i >= d2) wet += dry[i - d2] * 0.11;
      if (i >= d3) wet += dry[i - d3] * 0.06;
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
