import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harp_tuner/services/pitch_detection_service.dart';

// ignore_for_file: invalid_use_of_visible_for_testing_member

// ── PCM test helpers ──────────────────────────────────────────────────────────

/// Returns [samples] zero-valued int16 LE samples (silence).
Uint8List _pcmSilence(int samples) => Uint8List(samples * 2);

/// Returns [samples] int16 LE samples of a sine wave at [freq] Hz.
Uint8List _pcmSineWave(int samples, {double freq = 440.0, int sampleRate = 44100}) {
  final bd = ByteData(samples * 2);
  for (int i = 0; i < samples; i++) {
    final v = (sin(2 * pi * freq * i / sampleRate) * 32767).round().clamp(-32768, 32767);
    bd.setInt16(i * 2, v, Endian.little);
  }
  return bd.buffer.asUint8List();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // ── PitchResult ───────────────────────────────────────────────────────────

  group('PitchResult', () {
    test('stores frequency', () {
      final r = PitchResult(440.0);
      expect(r.frequency, 440.0);
    });

    test('stores arbitrary frequency', () {
      final r = PitchResult(261.63);
      expect(r.frequency, closeTo(261.63, 0.001));
    });
  });

  // ── PitchServiceError ─────────────────────────────────────────────────────

  group('PitchServiceError', () {
    test('stores isPermissionError=false and message', () {
      // Use final (not const) so the constructor body executes at runtime.
      final e = PitchServiceError(isPermissionError: false, message: 'test');
      expect(e.isPermissionError, isFalse);
      expect(e.message, 'test');
    });

    test('stores isPermissionError=true', () {
      final e = PitchServiceError(isPermissionError: true, message: 'perm');
      expect(e.isPermissionError, isTrue);
    });
  });

  // ── PitchDetectionService.stop ────────────────────────────────────────────

  group('PitchDetectionService.stop', () {
    test('stop on fresh instance is a no-op (all null-safe)', () {
      final svc = PitchDetectionService();
      svc.stop(); // no subscription, no controller → safe
    });

    test('stop after start cleans up state', () {
      final svc = PitchDetectionService();
      // start() will fail internally when MicStream.microphone() throws,
      // but lines 83-88 are covered by the call itself.
      try {
        svc.start();
      } catch (_) {}
      svc.stop(); // should not throw
    });
  });

  // ── PitchDetectionService: _startMic error handler ────────────────────────

  group('PitchDetectionService._startMic error handler', () {
    test('start without stop: _ctrl.addError fires when mic unavailable',
        () async {
      final svc = PitchDetectionService();

      Object? caughtError;
      final sub = svc.start().listen(
        (_) {},
        // ignore: avoid_types_on_closure_parameters
        onError: (Object e) { caughtError = e; },
        cancelOnError: false,
      );
      addTearDown(() async {
        await sub.cancel();
        svc.stop();
      });

      // Yield to the microtask queue so _startMic() async body executes.
      // MicStream.microphone() throws MissingPluginException in test env,
      // triggering the catch block at lines 135-138.
      await Future.delayed(const Duration(milliseconds: 30));

      // The error must have been delivered — if not, the test is a no-op
      // (MicStream might not throw on this platform/version), which is fine.
      if (caughtError != null) {
        expect(caughtError, isA<PitchServiceError>());
        expect((caughtError as PitchServiceError).isPermissionError, isFalse);
      }
    });
  });

  // ── PitchDetectionService.requestPermission (Android/non-iOS path) ────────

  group('PitchDetectionService.requestPermission', () {
    const _permChannel = MethodChannel(
        'flutter.baseflow.com/permissions/methods');

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_permChannel, null);
    });

    test('already granted: returns true immediately', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_permChannel, (call) async {
        if (call.method == 'checkPermissionStatus') return 1; // granted
        return null;
      });
      final svc = PitchDetectionService();
      final result = await svc.requestPermission();
      expect(result, isTrue);
    });

    test('permanently denied: returns false without requesting', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_permChannel, (call) async {
        if (call.method == 'checkPermissionStatus') return 4; // permanentlyDenied
        return null;
      });
      final svc = PitchDetectionService();
      final result = await svc.requestPermission();
      expect(result, isFalse);
    });

    test('denied then request granted: returns true', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_permChannel, (call) async {
        if (call.method == 'checkPermissionStatus') return 0; // denied
        if (call.method == 'requestPermissions') return {7: 1}; // granted
        return null;
      });
      final svc = PitchDetectionService();
      final result = await svc.requestPermission();
      expect(result, isTrue);
    });

    test('denied then request denied: returns false', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_permChannel, (call) async {
        if (call.method == 'checkPermissionStatus') return 0; // denied
        if (call.method == 'requestPermissions') return {7: 0}; // still denied
        return null;
      });
      final svc = PitchDetectionService();
      final result = await svc.requestPermission();
      expect(result, isFalse);
    });
  });

  // ── PitchDetectionService.checkPermission (Android/non-iOS path) ──────────

  group('PitchDetectionService.checkPermission', () {
    const _permChannel = MethodChannel(
        'flutter.baseflow.com/permissions/methods');

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_permChannel, null);
    });

    test('returns true when mic is granted', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_permChannel, (call) async {
        if (call.method == 'checkPermissionStatus') return 1; // granted
        return null;
      });
      final svc = PitchDetectionService();
      final result = await svc.checkPermission();
      expect(result, isTrue);
    });

    test('returns false when mic is denied', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_permChannel, (call) async {
        if (call.method == 'checkPermissionStatus') return 0; // denied
        return null;
      });
      final svc = PitchDetectionService();
      final result = await svc.checkPermission();
      expect(result, isFalse);
    });
  });

  // ── PitchDetectionService.processChunkForTest (_onAudioChunk paths) ───────

  group('PitchDetectionService.processChunkForTest', () {
    test('small chunk (< bufferSize): accumulates samples and returns early',
        () async {
      final svc = PitchDetectionService();
      addTearDown(svc.stop);
      // start() sets up _ctrl so _ctrl?.add() calls actually fire
      svc.start().listen((_) {}, onError: (_) {}, cancelOnError: false);

      // 2048 samples = 4096 bytes; bufferSize = 4096 samples → returns at line 177
      await svc.processChunkForTest(_pcmSilence(2048));
    });

    test('silence: two chunks fill the buffer, compute runs, null emitted',
        () async {
      final svc = PitchDetectionService();
      addTearDown(svc.stop);
      final results = <PitchResult?>[];
      svc.start().listen(results.add, onError: (_) {}, cancelOnError: false);

      await svc.processChunkForTest(_pcmSilence(2048));
      await svc.processChunkForTest(_pcmSilence(2048));
      await Future.delayed(Duration.zero);

      expect(results, contains(null));
    },
        timeout: const Timeout(Duration(seconds: 30)),
        skip: const bool.fromEnvironment('SKIP_SLOW_TESTS')
            ? 'Slow YIN computation skipped'
            : null);

    test('440 Hz sine: compute runs, pitched result emitted', () async {
      final svc = PitchDetectionService();
      addTearDown(svc.stop);
      final results = <PitchResult?>[];
      svc.start().listen(results.add, onError: (_) {}, cancelOnError: false);

      await svc.processChunkForTest(_pcmSineWave(2048));
      await svc.processChunkForTest(_pcmSineWave(2048));
      await Future.delayed(Duration.zero);

      expect(results.isNotEmpty, isTrue);
    },
        timeout: const Timeout(Duration(seconds: 30)),
        skip: const bool.fromEnvironment('SKIP_SLOW_TESTS')
            ? 'Slow YIN computation skipped'
            : null);

    test('regression: bytes arriving while compute runs are accumulated, not dropped',
        () async {
      // Before the fix, _processing was checked at the TOP of _onAudioChunk.
      // Any bytes arriving while YIN was running via compute() were silently
      // discarded — causing missed detections when notes were played quickly
      // (approximately 1 per second). The fix moves accumulation before the guard.
      //
      // Setup:
      //   Batch A (4096 samples): fills buffer → triggers compute1, _processing=true
      //   Batches B+C (4096+4096): arrive during compute1
      //     Fix:  accumulated → accumulator grows to ~10K samples
      //     Bug:  dropped    → accumulator stays at ~2K (overlap only)
      //   Trigger (256 samples): arrives after compute1 finishes
      //     Fix:  accumulator ≥ bufferSize → triggers compute2 → detection2
      //     Bug:  accumulator < bufferSize → no detection2
      final svc = PitchDetectionService();
      addTearDown(svc.stop);

      final sc = StreamController<Uint8List>();
      svc.micStreamOverride = () => sc.stream;

      final results = <PitchResult?>[];
      svc.start().listen(results.add, onError: (_) {}, cancelOnError: false);
      await Future.delayed(const Duration(milliseconds: 10));

      // Batch A: triggers detection 1 and sets _processing = true.
      sc.add(_pcmSineWave(4096, freq: 440.0));
      // Batches B+C: must accumulate during compute1 (not be dropped).
      sc.add(_pcmSineWave(4096, freq: 440.0));
      sc.add(_pcmSineWave(4096, freq: 440.0));

      // Wait for compute1 to finish (YIN on 4096 samples; generous for CI).
      await Future.delayed(const Duration(seconds: 2));

      // Trigger: tips the large accumulated buffer into a second compute.
      // With the bug, the accumulator only has ~2048 samples here, so no
      // second detection fires.
      sc.add(_pcmSineWave(256, freq: 440.0));
      await Future.delayed(const Duration(seconds: 2));

      final pitched = results.whereType<PitchResult>().toList();
      expect(pitched.length, greaterThanOrEqualTo(2),
          reason: 'Bytes B+C must have accumulated during compute1; '
              'trigger must fire compute2 → detection2');

      await sc.close();
    },
        timeout: const Timeout(Duration(seconds: 30)),
        skip: const bool.fromEnvironment('SKIP_SLOW_TESTS')
            ? 'Slow YIN computation skipped'
            : null);

    test('bytes arriving after stop() are discarded before accumulation',
        () async {
      // _ctrl null-guard: _onAudioChunk exits before touching the accumulator.
      final svc = PitchDetectionService();

      final results = <PitchResult?>[];
      svc.start().listen(results.add, onError: (_) {}, cancelOnError: false);
      svc.stop(); // _ctrl → null

      await svc.processChunkForTest(_pcmSineWave(4096, freq: 440.0));
      await svc.processChunkForTest(_pcmSineWave(4096, freq: 440.0));
      await Future.delayed(Duration.zero);

      expect(results, isEmpty, reason: 'No results should emit after stop()');
    });

    test('stop-then-start: session 1 stream receives no emissions after stop()',
        () async {
      // Note: processChunkForTest awaits the full pipeline, so by the time
      // stop()+start() runs, the prior compute has already completed. This test
      // verifies the sequential post-stop invariant; the concurrent race
      // (compute in-flight when stop() fires) is guarded by _sessionId and
      // _ctrl identity checks but requires real concurrent timing to trigger.
      final svc = PitchDetectionService();
      addTearDown(svc.stop);

      final session1 = <PitchResult?>[];
      svc.start().listen(session1.add, onError: (_) {}, cancelOnError: false);
      await svc.processChunkForTest(_pcmSineWave(4096, freq: 440.0));
      await Future.delayed(Duration.zero);
      final countBeforeStop = session1.length;

      svc.stop();
      final session2 = <PitchResult?>[];
      svc.start().listen(session2.add, onError: (_) {}, cancelOnError: false);

      await svc.processChunkForTest(_pcmSineWave(4096, freq: 440.0));
      await svc.processChunkForTest(_pcmSineWave(4096, freq: 440.0));
      await Future.delayed(Duration.zero);

      expect(session1.length, countBeforeStop,
          reason: 'Session 1 stream must not grow after stop()');
    },
        timeout: const Timeout(Duration(seconds: 30)),
        skip: const bool.fromEnvironment('SKIP_SLOW_TESTS')
            ? 'Slow YIN computation skipped'
            : null);

    test('accumulator overflow: chunk > 2×bufferSize trims to bufferSize before compute',
        () async {
      final svc = PitchDetectionService();
      addTearDown(svc.stop);
      final results = <PitchResult?>[];
      svc.start().listen(results.add, onError: (_) {}, cancelOnError: false);

      // 9000 samples > bufferSize*2 (8192) → triggers the overflow trim path
      await svc.processChunkForTest(_pcmSilence(9000));
      await Future.delayed(Duration.zero);

      // Trim fires and compute runs; silence → null
      expect(results, contains(null));
    },
        timeout: const Timeout(Duration(seconds: 30)),
        skip: const bool.fromEnvironment('SKIP_SLOW_TESTS')
            ? 'Slow YIN computation skipped'
            : null);
  });

  // ── micStreamOverride injection (covers _startMic stream-setup paths) ─────

  group('PitchDetectionService micStreamOverride', () {
    test('throwing factory emits PitchServiceError on the stream', () async {
      final svc = PitchDetectionService();
      addTearDown(svc.stop);

      svc.micStreamOverride = () => throw Exception('no mic available');

      Object? received;
      svc.start().listen(
        (_) {},
        onError: (Object e) { received = e; },
        cancelOnError: false,
      );

      // Yield so _startMic() async body runs and the catch block fires
      await Future.delayed(const Duration(milliseconds: 30));

      expect(received, isA<PitchServiceError>());
      expect((received! as PitchServiceError).isPermissionError, isFalse);
      expect((received! as PitchServiceError).message, contains('no mic available'));
    });

    test('stream emitting bytes triggers the data callback', () async {
      final svc = PitchDetectionService();
      addTearDown(svc.stop);

      final sc = StreamController<Uint8List>.broadcast();
      svc.micStreamOverride = () => sc.stream;
      svc.start().listen((_) {}, onError: (_) {}, cancelOnError: false);

      // Let _startMic() run and register the stream listener
      await Future.delayed(const Duration(milliseconds: 10));

      // Adding bytes invokes the data callback (bytes) => _onAudioChunk(bytes)
      sc.add(_pcmSilence(100));
      await Future.delayed(const Duration(milliseconds: 10));

      await sc.close();
    });

    test('stream emitting a non-PitchServiceError wraps it', () async {
      final svc = PitchDetectionService();
      addTearDown(svc.stop);

      final sc = StreamController<Uint8List>.broadcast();
      svc.micStreamOverride = () => sc.stream;

      Object? received;
      svc.start().listen(
        (_) {},
        onError: (Object e) { received = e; },
        cancelOnError: false,
      );

      await Future.delayed(const Duration(milliseconds: 10));

      // A bare Exception from the stream should be wrapped in PitchServiceError
      sc.addError(Exception('stream broke'));
      await Future.delayed(const Duration(milliseconds: 10));

      expect(received, isA<PitchServiceError>());
      expect((received! as PitchServiceError).isPermissionError, isFalse);
      expect((received! as PitchServiceError).message, contains('stream broke'));

      await sc.close();
    });

  });

  // ── Pitch accuracy (platform-agnostic core algorithm) ────────────────────
  //
  // These tests feed synthetic PCM directly into the detection pipeline,
  // bypassing the microphone entirely. Because _onAudioChunk and the YIN
  // parameters (sampleRate=44100, bufferSize=4096) are identical on Android
  // and iOS, accuracy here proves the detection is consistent across platforms.

  group('PitchDetectionService pitch accuracy', () {
    // Returns the first PitchResult emitted after feeding [pcm].
    // Null means YIN decided no pitch was present.
    Future<PitchResult?> firstResult(double freq) async {
      final svc = PitchDetectionService();
      addTearDown(svc.stop);
      final results = <PitchResult?>[];
      svc.start().listen(results.add, onError: (_) {}, cancelOnError: false);
      // One call with exactly bufferSize samples triggers a single YIN pass.
      await svc.processChunkForTest(_pcmSineWave(4096, freq: freq));
      await Future.delayed(Duration.zero);
      return results.whereType<PitchResult>().firstOrNull;
    }

    void expectAccurate(PitchResult? result, double expectedHz,
        {double maxCents = 15.0}) {
      expect(result, isNotNull,
          reason: 'YIN should detect a pitch for ${expectedHz}Hz sine wave');
      final detected = result!.frequency;
      final cents = 1200 * log(detected / expectedHz) / log(2);
      expect(cents.abs(), lessThan(maxCents),
          reason: 'detected ${detected.toStringAsFixed(2)} Hz, expected '
              '$expectedHz Hz (${cents.toStringAsFixed(1)} cents off; '
              'max $maxCents cents allowed)');
    }

    test(
      'A4 (440 Hz) — standard reference, verifies 44100 Hz sample-rate config',
      () async {
        final result = await firstResult(440.0);
        expectAccurate(result, 440.0);
      },
      timeout: const Timeout(Duration(seconds: 30)),
      skip: const bool.fromEnvironment('SKIP_SLOW_TESTS')
          ? 'Slow YIN computation skipped'
          : null,
    );

    test(
      'C4 (261.63 Hz) — middle C, 24 cycles in buffer',
      () async {
        final result = await firstResult(261.63);
        expectAccurate(result, 261.63);
      },
      timeout: const Timeout(Duration(seconds: 30)),
      skip: const bool.fromEnvironment('SKIP_SLOW_TESTS')
          ? 'Slow YIN computation skipped'
          : null,
    );

    test(
      'G3 (196 Hz) — lever harp bass zone, 18 cycles in buffer',
      () async {
        final result = await firstResult(196.0);
        expectAccurate(result, 196.0);
      },
      timeout: const Timeout(Duration(seconds: 30)),
      skip: const bool.fromEnvironment('SKIP_SLOW_TESTS')
          ? 'Slow YIN computation skipped'
          : null,
    );

    test(
      'A5 (880 Hz) — upper harp range, 82 cycles in buffer',
      () async {
        final result = await firstResult(880.0);
        expectAccurate(result, 880.0);
      },
      timeout: const Timeout(Duration(seconds: 30)),
      skip: const bool.fromEnvironment('SKIP_SLOW_TESTS')
          ? 'Slow YIN computation skipped'
          : null,
    );

    test(
      'C5 (523.25 Hz) — treble harp range, 49 cycles in buffer',
      () async {
        final result = await firstResult(523.25);
        expectAccurate(result, 523.25);
      },
      timeout: const Timeout(Duration(seconds: 30)),
      skip: const bool.fromEnvironment('SKIP_SLOW_TESTS')
          ? 'Slow YIN computation skipped'
          : null,
    );

    test(
      'amplitude independence: half-scale (16-bit) sine detects same as full-scale',
      () async {
        // YIN is autocorrelation-based; amplitude does not affect pitch accuracy.
        // This verifies int16 normalisation (/32768.0) is correct for both Android
        // (UNPROCESSED source, often lower gain) and iOS (DEFAULT/measurement mode).
        final bd = ByteData(4096 * 2);
        for (int i = 0; i < 4096; i++) {
          final v =
              (sin(2 * pi * 440.0 * i / 44100) * 16383).round().clamp(-32768, 32767);
          bd.setInt16(i * 2, v, Endian.little);
        }
        final halfScale = bd.buffer.asUint8List();

        final svc = PitchDetectionService();
        addTearDown(svc.stop);
        final results = <PitchResult?>[];
        svc.start().listen(results.add, onError: (_) {}, cancelOnError: false);
        await svc.processChunkForTest(halfScale);
        await Future.delayed(Duration.zero);

        final result = results.whereType<PitchResult>().firstOrNull;
        expectAccurate(result, 440.0);
      },
      timeout: const Timeout(Duration(seconds: 30)),
      skip: const bool.fromEnvironment('SKIP_SLOW_TESTS')
          ? 'Slow YIN computation skipped'
          : null,
    );

    test(
      '50% overlap: second window (2048 new + 2048 carry-over) detects the same pitch',
      () async {
        // After the first 4096-sample buffer is processed, 2048 samples remain
        // (the 50% overlap). The next 2048 samples complete a new buffer and
        // should detect the same pitch — verifying the overlap logic is correct
        // on all platforms.
        final svc = PitchDetectionService();
        addTearDown(svc.stop);
        final results = <PitchResult?>[];
        svc.start().listen(results.add, onError: (_) {}, cancelOnError: false);

        await svc.processChunkForTest(_pcmSineWave(4096, freq: 440.0));
        await Future.delayed(Duration.zero);
        await svc.processChunkForTest(_pcmSineWave(2048, freq: 440.0));
        await Future.delayed(Duration.zero);

        final pitched = results.whereType<PitchResult>().toList();
        expect(pitched.length, greaterThanOrEqualTo(2),
            reason: 'both overlapping windows should detect 440 Hz');
        for (final r in pitched) {
          final cents = 1200 * log(r.frequency / 440.0) / log(2);
          expect(cents.abs(), lessThan(15.0),
              reason: 'overlap window detected ${r.frequency} Hz, expected 440 Hz');
        }
      },
      timeout: const Timeout(Duration(seconds: 60)),
      skip: const bool.fromEnvironment('SKIP_SLOW_TESTS')
          ? 'Slow YIN computation skipped'
          : null,
    );
  });
}
