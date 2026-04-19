import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:mic_stream/mic_stream.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:pitch_detector_dart/pitch_detector.dart';

// Ring buffer backed by Float64List. Avoids O(n) List<double> ops per chunk.
class _RingBuffer {
  final Float64List _data;
  int _head = 0; // next write index
  int _len = 0;

  _RingBuffer(int capacity) : _data = Float64List(capacity);

  int get length => _len;
  int get capacity => _data.length;

  void add(double v) {
    _data[_head] = v;
    _head = (_head + 1) % _data.length;
    if (_len < _data.length) _len++;
  }

  /// Read the most recent [n] samples into [out] in chronological order.
  /// Requires [_len] >= n.
  void readLast(int n, Float64List out) {
    assert(n <= _len && out.length >= n);
    final start = (_head - n + _data.length) % _data.length;
    if (start + n <= _data.length) {
      out.setRange(0, n, _data, start);
    } else {
      final first = _data.length - start;
      out.setRange(0, first, _data, start);
      out.setRange(first, n, _data, 0);
    }
  }

  /// Drop the oldest [n] samples (advances the virtual read pointer).
  void advance(int n) {
    if (n >= _len) {
      _len = 0;
    } else {
      _len -= n;
    }
  }

  void clear() {
    _head = 0;
    _len = 0;
  }
}

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

  // 8192 samples ≈ 186 ms @ 44.1 kHz — ≈ 5.7 periods of C♭1 (30.87 Hz).
  // YIN needs ≥4 periods to reliably lock the lowest pedal-harp string;
  // 4096 was borderline and failed on ~31 Hz. O(n²) CPU cost is manageable
  // on modern phones (~25 ms/frame mid-tier Android); we compensate for the
  // larger window with 75 % overlap so detections still arrive every ~46 ms.
  static const int _bufferSize = 8192;
  static const int _hopSize = _bufferSize ~/ 4; // 75% overlap

  StreamSubscription<Uint8List>? _micSub;
  StreamController<PitchResult?>? _ctrl;
  PitchDetector? _detector;

  // Ring buffer of normalised float samples. Capacity = 2 buffers so a brief
  // processing stall can drain without allocating.
  final _RingBuffer _accumulator = _RingBuffer(_bufferSize * 2);

  // Reusable working buffer handed to YIN — avoids per-frame allocation.
  final Float64List _workBuf = Float64List(_bufferSize);

  // Guard: skip incoming chunk if previous detection is still running
  bool _processing = false;

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
    _processing = false;
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
    // Ingest samples into the ring buffer on every chunk (cheap).
    // mic_stream delivers 16-bit signed PCM, little-endian.
    // Pass offsetInBytes so we read the correct slice of the underlying buffer
    // (bytes may be a sub-view with a non-zero offset into its ByteBuffer).
    final data =
        bytes.buffer.asByteData(bytes.offsetInBytes, bytes.lengthInBytes);
    final end = bytes.length & ~1;
    for (int i = 0; i < end; i += 2) {
      final raw = data.getInt16(i, Endian.little);
      _accumulator.add(raw / 32768.0); // normalise to -1.0..1.0
    }

    if (_processing) return; // detector busy — next chunk will re-enter
    if (_accumulator.length < _bufferSize) return;

    _processing = true;
    try {
      // Read the most recent buffer window. The ring already discards older
      // samples once capacity is hit, so we always analyse the freshest audio.
      _accumulator.readLast(_bufferSize, _workBuf);
      _accumulator.advance(_hopSize); // 75% overlap → detect every ~46 ms

      final result = await _detector!.getPitchFromFloatBuffer(_workBuf);

      // Allow down to 27 Hz — below lowest harp string (C♭1 ≈ 30.87 Hz).
      if (result.pitched && result.pitch > 27.0 && result.pitch < 4200.0) {
        _ctrl?.add(PitchResult(result.pitch));
      } else {
        _ctrl?.add(null);
      }
    } finally {
      _processing = false;
    }
  }
}
