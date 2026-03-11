import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/harp_type.dart';
import '../services/pitch_detection_service.dart';
import '../utils/music_utils.dart';

// ── Enums / simple providers ───────────────────────────────────────────────────

enum TunerMode { auto, manual }

final selectedHarpProvider = StateProvider<HarpType>((ref) => HarpType.lapHarp);

// ── Tuner state ───────────────────────────────────────────────────────────────

class TunerState {
  final bool isListening;
  final bool permissionDenied;
  final bool preferFlats;
  final bool showOctave;
  final int a4Hz;
  final double? cents;
  final double? detectedHz;
  final String? closestNoteName;
  final String? micError;

  const TunerState({
    this.isListening = false,
    this.permissionDenied = false,
    this.preferFlats = false,
    this.showOctave = false,
    this.a4Hz = 440,
    this.cents,
    this.detectedHz,
    this.closestNoteName,
    this.micError,
  });

  TunerState copyWith({
    bool? isListening,
    bool? permissionDenied,
    bool? preferFlats,
    bool? showOctave,
    int? a4Hz,
    double? cents,
    double? detectedHz,
    String? closestNoteName,
    String? micError,
    bool clearPitch = false,
    bool clearMicError = false,
  }) {
    return TunerState(
      isListening: isListening ?? this.isListening,
      permissionDenied: permissionDenied ?? this.permissionDenied,
      preferFlats: preferFlats ?? this.preferFlats,
      showOctave: showOctave ?? this.showOctave,
      a4Hz: a4Hz ?? this.a4Hz,
      cents: clearPitch ? null : (cents ?? this.cents),
      detectedHz: clearPitch ? null : (detectedHz ?? this.detectedHz),
      closestNoteName:
          clearPitch ? null : (closestNoteName ?? this.closestNoteName),
      micError: (clearPitch || clearMicError) ? null : (micError ?? this.micError),
    );
  }
}

// ── Tuner notifier ────────────────────────────────────────────────────────────

class TunerNotifier extends StateNotifier<TunerState> {
  final PitchDetectionService _service = PitchDetectionService();
  StreamSubscription<PitchResult?>? _pitchSub;
  SharedPreferences? _prefs;

  static const _historyLen   = 5;     // ring buffer size
  static const _stableNeeded = 3;     // readings before showing display
  static const _stableCents  = 80.0;  // max spread (cents) to count as stable
  static const _holdFrames   = 4;     // consecutive nulls before clearing (~370 ms)

  static const _kA4HzKey  = 'tuner_a4_hz';
  static const _kA4HzMin  = 430;
  static const _kA4HzMax  = 450;

  final _freqHistory = <double>[];
  int _silenceCount  = 0;

  TunerNotifier() : super(const TunerState()) {
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      final savedA4 = _prefs!.getInt(_kA4HzKey);
      if (savedA4 != null) state = state.copyWith(a4Hz: savedA4.clamp(_kA4HzMin, _kA4HzMax));
    } catch (e) {
      debugPrint('TunerNotifier: failed to load prefs: $e');
    }
  }

  // ── Listening ──────────────────────────────────────────────────────────────

  Future<void> startListening() async {
    if (state.isListening) return;

    final granted = await _service.requestPermission();
    if (!granted) {
      state = state.copyWith(permissionDenied: true);
      return;
    }

    state = state.copyWith(
      isListening: true,
      permissionDenied: false,
      clearPitch: true,
    );

    _pitchSub = _service.start().listen(
      _onPitchResult,
      onError: (e) async {
        stopListening();
        if (e is PitchServiceError && e.isPermissionError) {
          state = state.copyWith(permissionDenied: true);
        } else if (e is PitchServiceError) {
          state = state.copyWith(micError: e.message);
        } else {
          final granted = await _service.checkPermission();
          if (!granted) {
            state = state.copyWith(permissionDenied: true);
          }
        }
      },
      cancelOnError: false,
    );
  }

  void stopListening() {
    _pitchSub?.cancel();
    _pitchSub = null;
    _service.stop();
    _freqHistory.clear();
    _silenceCount = 0;
    state = state.copyWith(isListening: false, clearPitch: true);
  }

  void toggleListening() {
    if (state.isListening) {
      stopListening();
    } else {
      startListening();
    }
  }

  void clearMicError() {
    state = state.copyWith(clearMicError: true);
  }

  void toggleShowOctave() {
    state = state.copyWith(showOctave: !state.showOctave);
  }

  void togglePreferFlats() {
    // When flats preference changes, re-render the current note name if present
    final newPreferFlats = !state.preferFlats;
    if (state.detectedHz != null) {
      final info = MusicUtils.frequencyToNoteInfo(
        state.detectedHz!,
        preferFlats: newPreferFlats,
        a4Hz: state.a4Hz.toDouble(),
      );
      state = state.copyWith(
        preferFlats: newPreferFlats,
        closestNoteName: info.noteName,
        cents: info.cents,
      );
    } else {
      state = state.copyWith(preferFlats: newPreferFlats);
    }
  }

  Future<void> setA4Hz(int hz) async {
    final clamped = hz.clamp(_kA4HzMin, _kA4HzMax);
    // Re-compute displayed note/cents with new reference immediately
    if (state.detectedHz != null) {
      final info = MusicUtils.frequencyToNoteInfo(
        state.detectedHz!,
        preferFlats: state.preferFlats,
        a4Hz: clamped.toDouble(),
      );
      state = state.copyWith(
        a4Hz: clamped,
        closestNoteName: info.noteName,
        cents: info.cents,
      );
    } else {
      state = state.copyWith(a4Hz: clamped);
    }
    try {
      _prefs ??= await SharedPreferences.getInstance();
      await _prefs!.setInt(_kA4HzKey, clamped);
    } catch (e) {
      debugPrint('TunerNotifier: failed to save a4Hz: $e');
    }
  }

  void _onPitchResult(PitchResult? result) {
    if (result == null) {
      _silenceCount++;
      if (_silenceCount >= _holdFrames) {
        _freqHistory.clear();
        state = state.copyWith(clearPitch: true);
      }
      return;
    }
    _silenceCount = 0;
    final hz = result.frequency;

    // Octave correction + outlier rejection
    if (_freqHistory.isNotEmpty) {
      final med = _median(_freqHistory);
      final centsDiff = 1200 * log(hz / med) / ln2;
      if (centsDiff.abs() > 150) {
        final corrected = _octaveCorrect(hz, med);
        if (corrected == null) return; // genuine outlier — discard
        _addToHistory(corrected);
      } else {
        _addToHistory(hz);
      }
    } else {
      _addToHistory(hz);
    }

    // Stability gate
    if (_freqHistory.length < _stableNeeded) return;
    if (_centSpread(_freqHistory) > _stableCents) return;

    final stableHz = _median(_freqHistory);
    final info = MusicUtils.frequencyToNoteInfo(
      stableHz,
      preferFlats: state.preferFlats,
      a4Hz: state.a4Hz.toDouble(),
    );
    state = state.copyWith(
      detectedHz: stableHz,
      closestNoteName: info.noteName,
      cents: info.cents,
    );
  }

  void _addToHistory(double hz) {
    _freqHistory.add(hz);
    if (_freqHistory.length > _historyLen) _freqHistory.removeAt(0);
  }

  double _median(List<double> list) {
    final s = List<double>.from(list)..sort();
    final m = s.length ~/ 2;
    return s.length.isOdd ? s[m] : (s[m - 1] + s[m]) / 2;
  }

  double _centSpread(List<double> list) {
    final s = List<double>.from(list)..sort();
    return 1200 * log(s.last / s.first) / ln2;
  }

  // Returns hz folded to same octave as reference if they differ by ~1 octave, else null.
  double? _octaveCorrect(double hz, double reference) {
    for (final factor in [2.0, 0.5]) {
      final candidate = hz * factor;
      final cents = 1200 * log(candidate / reference) / ln2;
      if (cents.abs() < 80) return candidate;
    }
    return null;
  }

  @override
  void dispose() {
    _pitchSub?.cancel();
    _service.stop();
    super.dispose();
  }
}

final tunerProvider = StateNotifierProvider<TunerNotifier, TunerState>(
  (ref) => TunerNotifier(),
);
