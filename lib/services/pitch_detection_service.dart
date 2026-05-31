import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show compute, visibleForTesting;
import 'package:flutter/services.dart';
import 'package:mic_stream/mic_stream.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:pitch_detector_dart/pitch_detector.dart';
import 'package:pitch_detector_dart/pitch_detector_result.dart';

// ── Persistent YIN isolate ────────────────────────────────────────────────────
// compute() spawns a new Dart isolate on EVERY call — on Android this costs
// 50–200 ms of OS thread creation before YIN even starts, making detection feel
// sluggish or unreliable. A persistent isolate pays the spawn cost once and then
// processes each buffer via a fast port message (~1 ms round-trip overhead).
//
// Fallback: while the isolate is still spawning (first few buffers), we use
// compute() — NOT synchronous YIN on the main thread. Running YIN synchronously
// would block the event loop for ~30–100 ms per buffer on Android, causing
// mic chunks to pile up and subsequent detections to fail.

class _YinRequest {
  final SendPort replyPort;
  final double sampleRate;
  final int bufferSize;
  final List<double> buffer;
  const _YinRequest(this.replyPort, this.sampleRate, this.bufferSize, this.buffer);
}

// Used by compute() fallback — top-level required by compute().
class _YinInput {
  final double sampleRate;
  final int bufferSize;
  final List<double> buffer;
  const _YinInput(this.sampleRate, this.bufferSize, this.buffer);
}

Future<PitchDetectorResult> _runYin(_YinInput input) {
  final detector = PitchDetector(
    audioSampleRate: input.sampleRate,
    bufferSize: input.bufferSize,
  );
  return detector.getPitchFromFloatBuffer(input.buffer);
}

// Top-level function — required by Isolate.spawn().
// Caches the PitchDetector so it is not reallocated on every buffer.
void _yinIsolateEntry(SendPort mainPort) {
  final port = ReceivePort();
  mainPort.send(port.sendPort); // hand back our receive port

  PitchDetector? detector;
  double? cachedRate;
  int? cachedSize;

  port.listen((message) {
    if (message == null) { // graceful shutdown signal
      port.close();
      return;
    }
    final req = message as _YinRequest;
    if (detector == null || cachedRate != req.sampleRate || cachedSize != req.bufferSize) {
      detector = PitchDetector(audioSampleRate: req.sampleRate, bufferSize: req.bufferSize);
      cachedRate = req.sampleRate;
      cachedSize = req.bufferSize;
    }
    // Always send a reply — if we throw, replyPort.first in the main isolate
    // hangs indefinitely, leaving _processing=true and killing detection.
    try {
      detector!.getPitchFromFloatBuffer(req.buffer)
          .then((r) => req.replyPort.send(r))
          .catchError((_) => req.replyPort.send(PitchDetectorResult(pitched: false, pitch: -1, probability: 0)));
    } catch (_) {
      req.replyPort.send(PitchDetectorResult(pitched: false, pitch: -1, probability: 0));
    }
  });
}

// ─────────────────────────────────────────────────────────────────────────────

class PitchResult {
  final double frequency; // Hz
  PitchResult(this.frequency);
}

class PitchServiceError implements Exception {
  final bool isPermissionError;
  final String message;
  const PitchServiceError({
    required this.isPermissionError,
    required this.message,
  });
}

/// Streams detected fundamental frequencies from the device microphone.
///
/// Usage:
///   final service = PitchDetectionService();
///   final granted = await service.requestPermission();
///   if (granted) {
///     service.start().listen((result) { ... });
///   }
///   service.stop();
class PitchDetectionService {
  static const int _targetSampleRate = 44100;

  // iOS: use AVAudioSession channel (AVCaptureDevice.requestAccessForMediaType
  // is broken on iOS 26 simulator and silently kills the app).
  static const _iosPermChannel =
      MethodChannel('com.harptuner/mic_permission');

  // 4096 samples ≈ 93 ms — covers down to ~21 Hz (below all harp strings).
  static const int _bufferSize = 4096;

  StreamSubscription<Uint8List>? _micSub;
  StreamController<PitchResult?>? _ctrl;
  double _actualSampleRate = _targetSampleRate.toDouble();

  // Running accumulator of normalised float samples
  final List<double> _accumulator = [];

  // Guard: skip incoming chunk if previous detection is still running.
  bool _processing = false;

  // Monotonically-increasing session counter. Incremented on stop() so the
  // finally{} block of an in-flight YIN call from session N doesn't reset
  // _processing for session N+1 after a rapid stop()+start().
  int _sessionId = 0;

  // Persistent YIN isolate — spawned once on start(), killed on stop().
  SendPort? _yinSendPort;
  Isolate? _yinIsolate;

  /// Override the mic stream source for testing.
  /// When set, [_startMic] calls this factory instead of [MicStream.microphone].
  @visibleForTesting
  Stream<Uint8List> Function()? micStreamOverride;

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Expose the audio-chunk processing pipeline for unit testing.
  /// In production this is driven by [_micSub]; in tests, callers can feed
  /// synthetic PCM directly without needing a real microphone.
  @visibleForTesting
  Future<void> processChunkForTest(Uint8List bytes) => _onAudioChunk(bytes);

  Future<bool> requestPermission() async {
    if (Platform.isIOS) {
      // Use AVAudioSession.requestRecordPermission — works correctly on iOS 26.
      // permission_handler_apple uses AVCaptureDevice which is broken there.
      return await _iosPermChannel.invokeMethod<bool>('requestPermission') ??
          false;
    }
    var status = await Permission.microphone.status;
    if (status.isGranted) return true;
    if (status.isPermanentlyDenied) return false;
    status = await Permission.microphone.request();
    return status.isGranted;
  }

  /// Read-only permission check — no dialog shown.
  Future<bool> checkPermission() async {
    if (Platform.isIOS) {
      return await _iosPermChannel.invokeMethod<bool>('checkPermission') ??
          false;
    }
    final status = await Permission.microphone.status;
    return status.isGranted;
  }

  /// Spawn the YIN isolate ahead of [start] so it is already warm before the
  /// user taps the mic button. Safe to call repeatedly — a no-op once the
  /// isolate exists. Call this when the tuner screen mounts to remove the
  /// ~260 ms isolate-spawn latency from the first detection (cold start).
  void prewarm() => _ensureYinIsolate();

  /// Returns a broadcast stream of [PitchResult] (or null when no pitch found).
  /// Caller must call [stop] when done.
  Stream<PitchResult?> start() {
    _ctrl?.close();
    _ctrl = StreamController<PitchResult?>.broadcast();
    _accumulator.clear();
    // Spawn the YIN isolate if it isn't already warm from prewarm() or a
    // previous session. Kept alive across stop()/start() so warm restarts skip
    // the spawn entirely; torn down only in dispose().
    _ensureYinIsolate();
    _startMic();
    return _ctrl!.stream;
  }

  void stop() {
    _sessionId++; // invalidate any in-flight _onAudioChunk finally{} blocks
    _micSub?.cancel();
    _micSub = null;
    _ctrl?.close();
    _ctrl = null;
    _accumulator.clear();
    _processing = false;
    _actualSampleRate = _targetSampleRate.toDouble();
    // The YIN isolate is intentionally kept alive here so the next start() is a
    // warm restart (no ~260 ms respawn). It is killed in dispose().
  }

  /// Permanently tears down the service, including the persistent YIN isolate.
  /// After this, a later [start] re-spawns from cold. Call from the owner's
  /// dispose — NOT between sessions (use [stop] for that).
  void dispose() {
    stop();
    _disposeYinIsolate();
  }

  // ── Persistent isolate lifecycle ───────────────────────────────────────────

  void _ensureYinIsolate() {
    if (_yinSendPort != null) return;
    final setupPort = ReceivePort();
    Isolate.spawn(_yinIsolateEntry, setupPort.sendPort).then((iso) {
      _yinIsolate = iso;
      setupPort.first.then((port) {
        _yinSendPort = port as SendPort;
        setupPort.close();
      });
    }).catchError((_) {
      setupPort.close();
      // Isolate spawn failed — _yinSendPort stays null; _detectPitch will
      // fall back to compute() via _runYinFallback.
    });
  }

  void _disposeYinIsolate() {
    _yinSendPort?.send(null); // graceful shutdown
    _yinSendPort = null;
    _yinIsolate?.kill(priority: Isolate.immediate);
    _yinIsolate = null;
  }

  // Runs YIN via the persistent isolate. Falls back to compute() if the
  // isolate is not yet ready (first call latency) or spawn failed.
  Future<PitchDetectorResult> _detectPitch(
      double sampleRate, int bufferSize, List<double> buffer) async {
    final port = _yinSendPort;
    if (port != null) {
      final replyPort = ReceivePort();
      port.send(_YinRequest(replyPort.sendPort, sampleRate, bufferSize, buffer));
      try {
        // 500 ms safety timeout: if the isolate hangs (e.g. killed mid-reply),
        // replyPort.first would block forever, leaving _processing=true permanently.
        final result = await replyPort.first
            .timeout(const Duration(milliseconds: 500)) as PitchDetectorResult;
        return result;
      } on TimeoutException {
        return PitchDetectorResult(pitched: false, pitch: -1, probability: 0);
      } finally {
        replyPort.close();
      }
    }
    // Fallback: isolate not ready yet. Use compute() — NOT synchronous YIN.
    // Running YIN inline blocks the main Dart isolate for ~30–100 ms on Android,
    // preventing mic chunk delivery and cascading into missed detections.
    return compute(_runYin, _YinInput(sampleRate, bufferSize, buffer));
  }

  // ── Internal ───────────────────────────────────────────────────────────────

  void _startMic() async {
    // Yield one event loop turn so the caller can subscribe to _ctrl.stream
    // before we emit any errors (broadcast streams drop events with no listeners).
    final thisCtrl = _ctrl;
    await Future.delayed(Duration.zero);
    // Guard against stop() or a rapid second start() that replaced _ctrl.
    if (_ctrl == null || !identical(_ctrl, thisCtrl)) return;
    if (Platform.isIOS) {
      // Disable mic_stream's internal permission request on iOS —
      // it uses AVCaptureDevice which crashes on iOS 26.
      MicStream.shouldRequestPermission(false);
    }
    Stream<Uint8List> rawStream;
    try {
      if (micStreamOverride != null) {
        rawStream = micStreamOverride!();
      } else if (Platform.isAndroid) {
        // Prefer UNPROCESSED (bypasses AGC/noise-suppression). Some non-Pixel
        // Android devices don't support it — fall back to MIC on failure.
        try {
          rawStream = MicStream.microphone(
            sampleRate: _targetSampleRate,
            audioFormat: AudioFormat.ENCODING_PCM_16BIT,
            audioSource: AudioSource.UNPROCESSED,
          );
        } catch (_) {
          rawStream = MicStream.microphone(
            sampleRate: _targetSampleRate,
            audioFormat: AudioFormat.ENCODING_PCM_16BIT,
            audioSource: AudioSource.MIC,
          );
        }
      } else {
        rawStream = MicStream.microphone(
          sampleRate: _targetSampleRate,
          audioFormat: AudioFormat.ENCODING_PCM_16BIT,
          audioSource: AudioSource.DEFAULT,
        );
      }
    } catch (e) {
      _ctrl?.addError(PitchServiceError(
        isPermissionError: false,
        message: 'Microphone error: $e',
      ));
      return;
    }

    _micSub = rawStream.listen(
      (bytes) => _onAudioChunk(bytes),
      onError: (e) => _ctrl?.addError(e is PitchServiceError
          ? e
          : PitchServiceError(isPermissionError: false, message: '$e')),
      cancelOnError: false,
    );

    // sampleRate completes once the stream has started; update if the device
    // rate differs from our target so the YIN isolate uses the right value.
    // Skip when using a test override (MicStream may not be initialized).
    if (micStreamOverride == null) {
      MicStream.sampleRate.then((actualRate) {
        _actualSampleRate = actualRate.toDouble();
      }).catchError((_) {}); // default of 44100 Hz remains on error
    }
  }

  Future<void> _onAudioChunk(Uint8List bytes) async {
    // Capture _ctrl and _sessionId into locals to guard against TOCTOU across
    // the await. stop()+start() can replace _ctrl and increment _sessionId
    // while YIN is running. The identical() check on _ctrl prevents emitting
    // stale results into a new session; the sessionId check in finally{} prevents
    // the old session from resetting the new session's _processing flag.
    final ctrl = _ctrl;
    if (ctrl == null) return; // service stopped — discard late-arriving bytes
    final capturedSession = _sessionId;

    // Always decode and accumulate PCM — never drop incoming audio, even while
    // YIN is running. Previously the guard was at the top, which silently
    // discarded the attack transient of any note plucked during the compute window.
    //
    // mic_stream delivers 16-bit signed PCM, little-endian.
    // Pass offsetInBytes so we read the correct slice of the underlying buffer
    // (bytes may be a sub-view with a non-zero offset into its ByteBuffer).
    // Note: mic_stream on Android can deliver odd-byte chunks. The loop
    // condition (i + 1 < bytes.length) silently drops the trailing byte,
    // which is correct — a single byte is not a valid int16 sample.
    final data = bytes.buffer.asByteData(bytes.offsetInBytes, bytes.lengthInBytes);
    for (int i = 0; i + 1 < bytes.length; i += 2) {
      final raw = data.getInt16(i, Endian.little);
      _accumulator.add(raw / 32768.0); // normalise to -1.0..1.0
    }

    // Only gate the YIN computation — audio bytes are always accumulated above.
    if (_processing) return;

    // Discard stale audio to stay real-time: if the accumulator has grown
    // beyond two buffers (YIN lagging), skip ahead to the newest audio.
    bool trimmedThisCycle = false;
    if (_accumulator.length > _bufferSize * 2) {
      _accumulator.removeRange(0, _accumulator.length - _bufferSize);
      trimmedThisCycle = true;
    }

    if (_accumulator.length < _bufferSize) return;

    _processing = true;
    try {
      final chunk = _accumulator.sublist(0, _bufferSize);
      // 50% overlap when keeping up — consecutive windows share the second half,
      // preserving the decaying tail of harp notes across detection cycles.
      // When the accumulator needed a trim this call (device fell > 2× behind),
      // drop the overlap so the next window starts on fresh audio instead of
      // re-processing the same stale samples.
      _accumulator.removeRange(0, trimmedThisCycle ? _bufferSize : _bufferSize ~/ 2);

      final result = await _detectPitch(_actualSampleRate, _bufferSize, chunk);

      // Post-await guard: bail if the service was stopped or restarted while
      // YIN was running — don't emit stale results into a new session.
      if (!identical(_ctrl, ctrl)) return;

      if (result.pitched && result.pitch > 27.0 && result.pitch < 4200.0) {
        ctrl.add(PitchResult(result.pitch));
      } else {
        ctrl.add(null);
      }
    } finally {
      // Only reset _processing for the session we captured. If stop()+start()
      // fired during the await, _sessionId has been incremented and we must not
      // clear the new session's flag.
      if (_sessionId == capturedSession) _processing = false;
    }
  }
}
