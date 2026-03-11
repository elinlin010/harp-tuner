import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:mic_stream/mic_stream.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:pitch_detector_dart/pitch_detector.dart';

class PitchResult {
  final double frequency; // Hz
  PitchResult(this.frequency);
}

class PitchServiceError {
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
  PitchDetector? _detector;

  // Running accumulator of normalised float samples
  final List<double> _accumulator = [];

  // ── Public API ─────────────────────────────────────────────────────────────

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
  }

  // ── Internal ───────────────────────────────────────────────────────────────

  void _startMic() async {
    if (Platform.isIOS) {
      // Disable mic_stream's internal permission request on iOS —
      // it uses AVCaptureDevice which crashes on iOS 26.
      MicStream.shouldRequestPermission(false);
    }
    Stream<Uint8List> rawStream;
    try {
      // mic_stream 0.7+: microphone() returns Stream<Uint8List> directly (not a Future)
      rawStream = MicStream.microphone(
        sampleRate: _targetSampleRate,
        audioFormat: AudioFormat.ENCODING_PCM_16BIT,
      );
    } catch (e) {
      _ctrl?.addError(PitchServiceError(
        isPermissionError: false,
        message: 'Microphone error: $e',
      ));
      return;
    }

    // In 0.7+, the stream only starts when listened to, so subscribe first.
    // Initialize detector with target rate; update it once the stream is running
    // and the actual sample rate is known.
    _detector = PitchDetector(
      audioSampleRate: _targetSampleRate.toDouble(),
      bufferSize: _bufferSize,
    );

    _micSub = rawStream.listen(
      (bytes) => _onAudioChunk(bytes),
      onError: (e) => _ctrl?.addError(e is PitchServiceError
          ? e
          : PitchServiceError(isPermissionError: false, message: '$e')),
      cancelOnError: false,
    );

    // sampleRate completes once the stream has started; recreate detector if needed.
    MicStream.sampleRate.then((actualRate) {
      if (actualRate != _targetSampleRate) {
        _detector = PitchDetector(
          audioSampleRate: actualRate.toDouble(),
          bufferSize: _bufferSize,
        );
      }
    });
  }

  Future<void> _onAudioChunk(Uint8List bytes) async {
    // mic_stream delivers 16-bit signed PCM, little-endian.
    // Pass offsetInBytes so we read the correct slice of the underlying buffer
    // (bytes may be a sub-view with a non-zero offset into its ByteBuffer).
    final data = bytes.buffer.asByteData(bytes.offsetInBytes, bytes.lengthInBytes);
    for (int i = 0; i + 1 < bytes.length; i += 2) {
      final raw = data.getInt16(i, Endian.little);
      _accumulator.add(raw / 32768.0); // normalise to -1.0..1.0
    }

    // Discard stale audio to stay real-time: if the accumulator has grown
    // beyond two buffers (YIN lagging in debug mode), skip ahead.
    if (_accumulator.length > _bufferSize * 2) {
      _accumulator.removeRange(0, _accumulator.length - _bufferSize);
    }

    if (_accumulator.length < _bufferSize) return;

    final chunk = _accumulator.sublist(0, _bufferSize);
    _accumulator.removeRange(0, _bufferSize ~/ 2); // 50% overlap

    final result = await _detector!.getPitchFromFloatBuffer(chunk);

    if (result.pitched && result.pitch > 27.0 && result.pitch < 4200.0) {
      _ctrl?.add(PitchResult(result.pitch));
    } else {
      _ctrl?.add(null);
    }
  }
}
