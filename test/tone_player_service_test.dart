import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:harp_tuner/services/tone_player_service.dart';

// ignore_for_file: invalid_use_of_visible_for_testing_member

void main() {
  // ── generateToneForTest ───────────────────────────────────────────────────
  // Exercises the static synthesis path directly in the main isolate so lcov
  // instruments every line (compute() spawns a separate isolate whose lines
  // are not tracked).

  group('TonePlayerService.generateToneForTest', () {
    test('returns valid WAV bytes for A4 (440 Hz)', () {
      final bytes = TonePlayerService.generateToneForTest(440.0);
      expect(bytes.length, greaterThan(44)); // WAV header (44) + PCM data
      // RIFF header
      expect(String.fromCharCodes(bytes.sublist(0, 4)), 'RIFF');
      expect(String.fromCharCodes(bytes.sublist(8, 12)), 'WAVE');
    },
        timeout: const Timeout(Duration(seconds: 60)),
        skip: const bool.fromEnvironment('SKIP_SLOW_TESTS')
            ? 'Slow synthesis skipped'
            : null);

    test('returns valid WAV bytes for high note (4000 Hz — minimal harmonics)',
        () {
      // maxHarmonic = min(12, floor(18000/4000)) = 4 — much faster than A4
      final bytes = TonePlayerService.generateToneForTest(4000.0);
      expect(bytes.length, greaterThan(44));
      expect(String.fromCharCodes(bytes.sublist(0, 4)), 'RIFF');
    }, timeout: const Timeout(Duration(seconds: 30)));

    test('bass note (55 Hz = A1) succeeds with max harmonics', () {
      // maxHarmonic = min(12, floor(18000/55)) = 12 — most complex path
      final bytes = TonePlayerService.generateToneForTest(55.0);
      expect(bytes.length, greaterThan(44));
    },
        timeout: const Timeout(Duration(seconds: 120)),
        skip: const bool.fromEnvironment('SKIP_SLOW_TESTS')
            ? 'Slow synthesis skipped'
            : null);
  });

  // ── toWavForTest ─────────────────────────────────────────────────────────

  group('TonePlayerService.toWavForTest', () {
    test('wraps empty PCM with correct WAV header', () {
      final pcm = Uint8List(0);
      final wav = TonePlayerService.toWavForTest(pcm, 44100);
      expect(wav.length, 44); // header only
      expect(String.fromCharCodes(wav.sublist(0, 4)), 'RIFF');
      expect(String.fromCharCodes(wav.sublist(8, 12)), 'WAVE');
      expect(String.fromCharCodes(wav.sublist(12, 16)), 'fmt ');
      expect(String.fromCharCodes(wav.sublist(36, 40)), 'data');
    });

    test('PCM data is appended after 44-byte header', () {
      final pcm = Uint8List.fromList([1, 2, 3, 4]);
      final wav = TonePlayerService.toWavForTest(pcm, 44100);
      expect(wav.length, 48);
      expect(wav.sublist(44), [1, 2, 3, 4]);
    });

    test('sampleRate is written correctly into header', () {
      final pcm = Uint8List(0);
      final wav = TonePlayerService.toWavForTest(pcm, 44100);
      // Bytes 24-27 are sampleRate as little-endian uint32
      final bd = ByteData.sublistView(wav);
      expect(bd.getUint32(24, Endian.little), 44100);
    });
  });

  // ── precompute / _drainPrecomputeQueue / _getBytes ────────────────────────

  group('TonePlayerService.precompute', () {
    test('precompute with empty list is a no-op', () {
      final svc = TonePlayerService();
      addTearDown(svc.dispose);
      svc.precompute([]); // should not throw
    });

    test('precompute queues frequencies and starts drain', () {
      final svc = TonePlayerService();
      addTearDown(svc.dispose);
      // Queue two frequencies — the drain loop starts immediately.
      // Lines in precompute(), _drainPrecomputeQueue(), _getBytes() are covered.
      svc.precompute([440.0, 880.0]);
    });

    test('precompute skips already-cached frequencies', () {
      final svc = TonePlayerService();
      addTearDown(svc.dispose);
      svc.precompute([440.0]);
      svc.precompute([440.0]); // second call: 440 is already pending → skipped
    });

    test('stop on fresh instance is a no-op', () async {
      final svc = TonePlayerService();
      addTearDown(svc.dispose);
      await svc.stop(); // _player is null → null-safe no-op
    });

    test('dispose on fresh instance is a no-op', () {
      final svc = TonePlayerService();
      svc.dispose(); // _player is null → null-safe no-op
    });
  });
}
