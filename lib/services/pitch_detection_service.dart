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

  // 8192 samples ≈ 186 ms — long enough to detect down to C1 (32.7 Hz)
  static const int _bufferSize = 8192;

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
    Stream<Uint8List>? rawStream;
    // Disable mic_stream's internal Permission.microphone.request() call —
    // it also uses AVCaptureDevice on iOS which crashes on iOS 26.
    MicStream.shouldRequestPermission(false);
    try {
      rawStream = await MicStream.microphone(
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

    if (rawStream == null) {
      _ctrl?.addError(const PitchServiceError(
        isPermissionError: false,
        message: 'Could not open microphone stream',
      ));
      return;
    }

    // Actual sample rate may differ from requested; re-create detector with it
    final actualRate = (await MicStream.sampleRate) ?? _targetSampleRate;
    _detector = PitchDetector(
      audioSampleRate: actualRate.toDouble(),
      bufferSize: _bufferSize,
    );

    _micSub = rawStream.listen(
      (bytes) => _onAudioChunk(bytes),
      onError: (e) => _ctrl?.addError(e is PitchServiceError
          ? e
          : PitchServiceError(isPermissionError: false, message: '$e')),
      cancelOnError: false,
    );
  }

  Future<void> _onAudioChunk(Uint8List bytes) async {
    // mic_stream delivers 16-bit signed PCM, little-endian
    final data = bytes.buffer.asByteData();
    for (int i = 0; i + 1 < bytes.length; i += 2) {
      final raw = data.getInt16(i, Endian.little);
      _accumulator.add(raw / 32768.0); // normalise to -1.0..1.0
    }

    // Process in _bufferSize chunks with 50% overlap for smooth updates
    while (_accumulator.length >= _bufferSize) {
      final chunk = _accumulator.sublist(0, _bufferSize);
      // Advance by half the buffer to maintain 50% overlap
      _accumulator.removeRange(0, _bufferSize ~/ 2);

      final result = await _detector!.getPitchFromFloatBuffer(chunk);

      if (result.pitched && result.pitch > 20.0 && result.pitch < 5000.0) {
        _ctrl?.add(PitchResult(result.pitch));
      } else {
        _ctrl?.add(null);
      }
    }
  }
}
