import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show compute, visibleForTesting;
import 'package:flutter/services.dart';
import 'package:mic_stream/mic_stream.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:pitch_detector_dart/pitch_detector.dart';
import 'package:pitch_detector_dart/pitch_detector_result.dart';

// Passed to a compute isolate — YIN is O(n²) and blocks the main thread if run inline.
class _YinInput {
  final double sampleRate;
  final int bufferSize;
  final List<double> buffer;
  const _YinInput(this.sampleRate, this.bufferSize, this.buffer);
}

// Top-level function required by compute().
Future<PitchDetectorResult> _runYin(_YinInput input) {
  final detector = PitchDetector(
    audioSampleRate: input.sampleRate,
    bufferSize: input.bufferSize,
  );
  return detector.getPitchFromFloatBuffer(input.buffer);
}

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
  // Halved from 8192: YIN is O(n²), so 2048²=4M ops vs 4096²=16M ops per frame.
  static const int _bufferSize = 4096;

  StreamSubscription<Uint8List>? _micSub;
  StreamController<PitchResult?>? _ctrl;
  double _actualSampleRate = _targetSampleRate.toDouble();

  // Running accumulator of normalised float samples
  final List<double> _accumulator = [];

  // Guard: skip incoming chunk if previous detection is still running
  bool _processing = false;

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

  /// Returns a broadcast stream of [PitchResult] (or null when no pitch found).
  /// Caller must call [stop] when done.
  Stream<PitchResult?> start() {
    _ctrl?.close();
    _ctrl = StreamController<PitchResult?>.broadcast();
    _accumulator.clear();
    _startMic();
    return _ctrl!.stream;
  }

  void stop() {
    _micSub?.cancel();
    _micSub = null;
    _ctrl?.close();
    _ctrl = null;
    _accumulator.clear();
    _processing = false;
    _actualSampleRate = _targetSampleRate.toDouble();
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
      // mic_stream 0.7+: microphone() returns Stream<Uint8List> directly (not a Future)
      // Android: UNPROCESSED bypasses AGC/noise-suppression (Pixel's audio HAL
      // enables these on DEFAULT/MIC, subtly distorting the YIN autocorrelation
      // and causing a small systematic pitch offset vs iOS's .measurement mode).
      // Requires API 24+; virtually all modern Android devices qualify.
      rawStream = micStreamOverride != null
          ? micStreamOverride!()
          : MicStream.microphone(
              sampleRate: _targetSampleRate,
              audioFormat: AudioFormat.ENCODING_PCM_16BIT,
              audioSource: Platform.isAndroid
                  ? AudioSource.UNPROCESSED
                  : AudioSource.DEFAULT,
            );
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
    // rate differs from our target so the compute isolate uses the right value.
    // Skip when using a test override (MicStream may not be initialized).
    if (micStreamOverride == null) {
      MicStream.sampleRate.then((actualRate) {
        _actualSampleRate = actualRate.toDouble();
      }).catchError((_) {}); // default of 44100 Hz remains on error
    }
  }

  Future<void> _onAudioChunk(Uint8List bytes) async {
    // Capture _ctrl into a local to guard against TOCTOU across the await:
    // stop()+start() can replace _ctrl while compute() is suspended, and we
    // must not emit the result of session N into session N+1's stream.
    // Using an identical() check after await detects the replacement.
    final ctrl = _ctrl;
    if (ctrl == null) return; // service stopped — discard late-arriving bytes

    // Always decode and accumulate PCM — never drop incoming audio, even while
    // YIN is running. Previously the guard was at the top, which silently
    // discarded the attack transient of any note plucked during the ~100ms
    // compute() window, causing missed detections when playing quickly.
    //
    // mic_stream delivers 16-bit signed PCM, little-endian.
    // Pass offsetInBytes so we read the correct slice of the underlying buffer
    // (bytes may be a sub-view with a non-zero offset into its ByteBuffer).
    final data = bytes.buffer.asByteData(bytes.offsetInBytes, bytes.lengthInBytes);
    for (int i = 0; i + 1 < bytes.length; i += 2) {
      final raw = data.getInt16(i, Endian.little);
      _accumulator.add(raw / 32768.0); // normalise to -1.0..1.0
    }

    // Only gate the YIN computation — audio bytes are always accumulated above.
    if (_processing) return;

    // Discard stale audio to stay real-time: if the accumulator has grown
    // beyond two buffers (YIN lagging in debug mode), skip ahead.
    if (_accumulator.length > _bufferSize * 2) {
      _accumulator.removeRange(0, _accumulator.length - _bufferSize);
    }

    if (_accumulator.length < _bufferSize) return;

    _processing = true;
    try {
      final chunk = _accumulator.sublist(0, _bufferSize);
      _accumulator.removeRange(0, _bufferSize ~/ 2); // 50% overlap

      final result = await compute(
        _runYin,
        _YinInput(_actualSampleRate, _bufferSize, chunk),
      );

      // Post-await guard: bail if the service was stopped or restarted while
      // compute() was running — don't emit stale results into a new session.
      if (!identical(_ctrl, ctrl)) return;

      if (result.pitched && result.pitch > 27.0 && result.pitch < 4200.0) {
        ctrl.add(PitchResult(result.pitch));
      } else {
        ctrl.add(null);
      }
    } finally {
      _processing = false;
    }
  }
}
