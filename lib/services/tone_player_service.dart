import 'dart:math';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Plays a harp-like reference tone for a given frequency.
///
/// Eight acoustic layers model a real plucked concert harp string:
///
/// 1. **Register-scaled inharmonicity** — B rises from ~0.00008 (bass) to
///    ~0.004 (top treble), matching gut/nylon string stiffness variation.
///
/// 2. **Pitch-dependent decay** — high strings die in ~0.5 s, bass strings
///    sustain 5+ s. Two-phase envelope (fast ring-down + slow sustain tail).
///
/// 3. **Dynamic partial count** — only harmonics below 18 kHz are rendered.
///    High notes get 2–5 partials; bass gets up to 12.
///
/// 4. **Soundboard body filter** — gentle low-pass roll-off above 2.5 kHz
///    applied per-partial, plus a resonant peak at 180–400 Hz.
///
/// 5. **Pluck noise burst** — bandpass-filtered noise at the attack instant.
///    Breaks the pure-sinusoid sterility that makes digital tones robotic.
///
/// 6. **Body knock impulse** — two fixed-frequency resonances (~180 Hz,
///    ~350 Hz) that decay in ~8 ms, giving a "wooden instrument" thump.
///
/// 7. **Partial frequency jitter** — slow random walk (~3 Hz modulation)
///    breaks perfect periodicity. Amplitude ~0.03 %.
///
/// 8. **Register-scaled polarisation beating** + **early reflections** —
///    secondary vibration plane fades bass→treble; three echo taps at
///    20/35/60 ms give acoustic-space impression without full reverb.
class TonePlayerService {
  AudioPlayer? _player;

  // Cache of precomputed WAV bytes keyed by frequency.
  // Avoids re-running the expensive synthesis isolate on every tap.
  final Map<double, Uint8List> _cache = {};

  // Track in-flight compute futures so duplicate requests don't double-compute.
  final Map<double, Future<Uint8List>> _pending = {};

  // Limit concurrent isolate launches during precompute. Each synthesis call
  // allocates ~9 MB peak (jitter tables + PCM buffers). Launching all 47 pedal-
  // harp strings simultaneously would spike to ~420 MB — enough to OOM on
  // constrained Android devices. Process at most 4 strings in parallel.
  static const _maxConcurrent = 4;
  int _runningComputes = 0;
  final _precomputeQueue = <double>[];

  /// Kick off background computation for a set of frequencies so they are
  /// cached before the user taps them.  Safe to call multiple times.
  void precompute(List<double> frequencies) {
    for (final hz in frequencies) {
      if (!_cache.containsKey(hz) && !_pending.containsKey(hz)) {
        _precomputeQueue.add(hz);
      }
    }
    _drainPrecomputeQueue();
  }

  void _drainPrecomputeQueue() {
    while (_runningComputes < _maxConcurrent && _precomputeQueue.isNotEmpty) {
      final hz = _precomputeQueue.removeAt(0);
      if (_cache.containsKey(hz) || _pending.containsKey(hz)) {
        continue; // already handled — pick next
      }
      _runningComputes++;
      _getBytes(hz).whenComplete(() {
        _runningComputes--;
        _drainPrecomputeQueue();
      }).ignore();
    }
  }

  Future<Uint8List> _getBytes(double hz) {
    if (_cache.containsKey(hz)) return Future.value(_cache[hz]!);
    // Join an in-flight compute if one exists, otherwise start a new one.
    return _pending[hz] ??= compute(_generateTone, hz).then((bytes) {
      _cache[hz] = bytes;
      _pending.remove(hz);
      return bytes;
    }).catchError((e) {
      _pending.remove(hz);
      throw e;
    });
  }

  /// Play a harp-like reference tone at [hz] for ~2 seconds.
  /// Stops any currently playing tone first.
  Future<void> play(double hz) async {
    _player ??= AudioPlayer();
    // Capture player locally so a concurrent dispose() can't null it between
    // the await and the final play() call.
    final player = _player!;
    await player.stop();
    final bytes = await _getBytes(hz);
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
    // B rises from ~0.00008 (bass gut) to ~0.004 (top treble nylon).
    final B = 0.00005 + 0.0000035 * hz;

    // ── 2. Pitch-dependent decay multiplier ─────────────────────────────────
    // High strings decay much faster. At C2 (~65 Hz) factor ≈ 1.1;
    // at C7 (~2093 Hz) factor ≈ 5.2. This scales the base decay rates.
    final decayScale = 1.0 + hz / 500.0;

    // ── 3. Dynamic partial count — only harmonics below 18 kHz ──────────────
    final maxHarmonic = max(2, min(12, (18000 / hz).floor()));

    // ── 4. Soundboard body filter — per-partial amplitude shaping ───────────
    double bodyGain(double freq) {
      double g;
      if (freq < 120) {
        g = freq / 120.0;
      } else if (freq < 400) {
        g = 1.0 + 0.25 * (1.0 - (freq - 180).abs() / 220);
      } else if (freq < 2500) {
        g = 1.0;
      } else {
        g = 2500.0 / freq; // gentle 6 dB/oct roll-off
      }
      return g.clamp(0.0, 1.0); // never boost above unity — prevents clipping on resonant peak
    }

    // ── 7. Register-scaled attack ───────────────────────────────────────────
    // Bass: ~4.5 ms ramp. Treble: ~1 ms percussive snap.
    final attackLen = max(44, (200 - hz * 0.08).round());

    // ── 8. Polarisation beating scales down in treble ───────────────────────
    final beatAmp = 0.10 * (1.0 - (hz - 200) / 2000).clamp(0.03, 1.0);

    // Base partial amplitudes — 1/n roll-off with a sharper slope for higher
    // harmonics, matching measured harp spectra.
    double partialAmp(int n) {
      if (n == 1) return 1.0;
      if (n == 2) return 0.55;
      return 0.55 * pow(2.0 / n, 1.35);
    }

    // Base decay rates per harmonic — higher harmonics decay faster.
    double baseFast(int n) => 2.5 + (n - 1) * 1.6;
    double baseSlow(int n) => 0.70 + (n - 1) * 0.55;
    double beatHz(int n)   => 0.55 + (n - 1) * 0.25;

    // ── 5. Partial frequency jitter — slow random walk per partial ──────────
    // Pre-generate jitter tables (one per partial) for O(1) lookup.
    final jitterTables = List.generate(maxHarmonic, (_) {
      final table = Float64List(numSamples);
      double phase = rng.nextDouble() * 2 * pi;
      final rate = 2.0 + rng.nextDouble() * 3.0; // 2–5 Hz modulation
      for (var i = 0; i < numSamples; i++) {
        table[i] = sin(phase) * 0.0003; // ±0.03% pitch wobble
        phase += 2 * pi * rate / sampleRate;
      }
      return table;
    });

    // ── 6. Pluck noise burst — bandpass-filtered noise, ~5–15 ms ────────────
    // Center frequency scales slightly with pitch.
    final noiseCenterHz = (1500 + hz * 0.5).clamp(1500.0, 5000.0);
    final noiseDecayRate = 120.0 + hz * 0.04; // faster fade at higher pitches
    final noiseAmp = 0.07; // ~7 % of peak

    // Simple one-pole bandpass state for noise colouring.
    final noiseBandCoeff = (2 * pi * noiseCenterHz / sampleRate).clamp(0.0, 0.99);
    double noiseLp = 0;

    // ── Body resonance (soft soundboard ring, not percussive knock) ────────
    const body1Hz = 180.0;
    const body2Hz = 350.0;
    const bodyDecay = 320.0; // ~13 ms ring (softer than old 550 = 8 ms)

    final pcm = Int16List(numSamples);
    for (var i = 0; i < numSamples; i++) {
      final t = i / sampleRate;
      // Raised-cosine attack (softer finger-pad onset vs linear ramp)
      final attack = i < attackLen
          ? 0.5 * (1.0 - cos(pi * i / attackLen))
          : 1.0;
      var sample = 0.0;

      // ── Sustained partials with all register-dependent shaping ────────────
      // Beating & jitter fade out faster than the main tone so the tail is clean.
      final modFade = exp(-t * 4.0);
      for (var n = 1; n <= maxHarmonic; n++) {
        final jitter = jitterTables[n - 1][i] * modFade;
        // No pitch glide — reference tones must be pitch-accurate from the first sample.
        final freq = hz * n * sqrt(1.0 + B * n * n) * (1.0 + jitter);
        final fast = baseFast(n) * decayScale;
        final slow = baseSlow(n) * decayScale;
        final env  = 0.60 * exp(-t * fast) + 0.40 * exp(-t * slow);
        final amp  = partialAmp(n) * bodyGain(freq);

        // Primary polarisation plane
        sample += amp * env * sin(2 * pi * freq * t);
        // Secondary plane — fades out so the tail rings clean
        sample += amp * beatAmp * modFade * env * sin(2 * pi * (freq + beatHz(n)) * t);
      }

      // ── Pluck transient partials (harmonics maxHarmonic+1 .. +4) ──────────
      for (var k = 0; k < 4; k++) {
        final n = maxHarmonic + 1 + k;
        final freq = hz * n * sqrt(1.0 + B * n * n);
        if (freq > 20000) break; // skip inaudible
        final tAmp = 0.11 / (1.0 + k * 0.6);
        final tDecay = 55.0 + k * 20.0;
        sample += tAmp * bodyGain(freq) * exp(-t * tDecay) * sin(2 * pi * freq * t);
      }

      // ── Pluck noise burst ─────────────────────────────────────────────────
      final rawNoise = rng.nextDouble() * 2.0 - 1.0;
      noiseLp += noiseBandCoeff * (rawNoise - noiseLp); // crude bandpass
      sample += noiseAmp * noiseLp * exp(-t * noiseDecayRate);

      // ── Body resonance (gentle soundboard ring) ──────────────────────────
      final bodyEnv = exp(-t * bodyDecay);
      sample += 0.04 * bodyEnv * sin(2 * pi * body1Hz * t);
      sample += 0.025 * bodyEnv * sin(2 * pi * body2Hz * t);

      pcm[i] = (sample * attack * 9000).clamp(-32768, 32767).toInt();
    }

    // ── 9. Early reflections — three echo taps for acoustic space ────────────
    // Copy into double buffer to avoid compounding feedback.
    final dry = Int16List.fromList(pcm);
    const d1 = 882;   // 20 ms
    const d2 = 1543;  // 35 ms
    const d3 = 2646;  // 60 ms
    for (var i = d1; i < numSamples; i++) {
      double wet = dry[i - d1] * 0.22;
      if (i >= d2) wet += dry[i - d2] * 0.13;
      if (i >= d3) wet += dry[i - d3] * 0.07;
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

    void str(String s) { for (final c in s.codeUnits) { header.setUint8(p++, c); } }
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
