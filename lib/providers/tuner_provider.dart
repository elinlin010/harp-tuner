import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/harp_presets.dart';
import '../models/harp_string_model.dart';
import '../models/harp_type.dart';
import '../services/pitch_detection_service.dart';
import '../utils/music_utils.dart';

// ── Harp selection ──────────────────────────────────────────────────────────

final selectedHarpProvider = StateProvider<HarpType?>((ref) => null);

final harpStringsProvider = Provider<List<HarpStringModel>>((ref) {
  final type = ref.watch(selectedHarpProvider);
  if (type == null) return [];
  return HarpPresets.stringsFor(type);
});

// ── Tuner mode ──────────────────────────────────────────────────────────────

enum TunerMode { auto, manual }

final tunerModeProvider = StateProvider<TunerMode>((ref) => TunerMode.auto);

// ── Selected string (manual mode) ───────────────────────────────────────────

final selectedStringIndexProvider = StateProvider<int?>((ref) => null);

final selectedStringProvider = Provider<HarpStringModel?>((ref) {
  final strings = ref.watch(harpStringsProvider);
  final idx = ref.watch(selectedStringIndexProvider);
  if (idx == null || idx >= strings.length) return null;
  return strings[idx];
});

// ── Tuner state ──────────────────────────────────────────────────────────────

class TunerState {
  final bool isListening;
  final bool isPlayingTone;
  final bool permissionDenied;
  final double? cents;
  final double? detectedHz;
  final HarpStringModel? closestString;

  const TunerState({
    this.isListening = false,
    this.isPlayingTone = false,
    this.permissionDenied = false,
    this.cents,
    this.detectedHz,
    this.closestString,
  });

  TunerState copyWith({
    bool? isListening,
    bool? isPlayingTone,
    bool? permissionDenied,
    double? cents,
    double? detectedHz,
    HarpStringModel? closestString,
    bool clearPitch = false,
  }) {
    return TunerState(
      isListening: isListening ?? this.isListening,
      isPlayingTone: isPlayingTone ?? this.isPlayingTone,
      permissionDenied: permissionDenied ?? this.permissionDenied,
      cents: clearPitch ? null : (cents ?? this.cents),
      detectedHz: clearPitch ? null : (detectedHz ?? this.detectedHz),
      closestString: clearPitch ? null : (closestString ?? this.closestString),
    );
  }
}

// ── Tuner notifier ────────────────────────────────────────────────────────────

class TunerNotifier extends StateNotifier<TunerState> {
  final Ref _ref;
  final PitchDetectionService _service = PitchDetectionService();
  StreamSubscription<PitchResult?>? _pitchSub;

  TunerNotifier(this._ref) : super(const TunerState());

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
      onError: (_) => stopListening(),
      cancelOnError: false,
    );
  }

  void stopListening() {
    _pitchSub?.cancel();
    _pitchSub = null;
    _service.stop();
    state = state.copyWith(isListening: false, clearPitch: true);
  }

  void toggleListening() {
    if (state.isListening) {
      stopListening();
    } else {
      startListening();
    }
  }

  void _onPitchResult(PitchResult? result) {
    if (result == null) {
      // No clear pitch detected — keep last reading briefly, then clear
      // (avoids flickering; handled by UI idle timeout if desired)
      return;
    }

    final strings = _ref.read(harpStringsProvider);
    final closest = MusicUtils.closestString(result.frequency, strings);

    if (closest == null) return;

    final cents = MusicUtils.centsFromTarget(result.frequency, closest.frequency);

    state = state.copyWith(
      cents: cents,
      detectedHz: result.frequency,
      closestString: closest,
    );
  }

  // ── Reference tone ─────────────────────────────────────────────────────────

  void playTone(HarpStringModel string) {
    // TODO: generate sine wave and play via audioplayers
    state = state.copyWith(isPlayingTone: true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) state = state.copyWith(isPlayingTone: false);
    });
  }

  void stopTone() {
    state = state.copyWith(isPlayingTone: false);
  }

  // ── Demo / testing ─────────────────────────────────────────────────────────

  void mockReading({
    required double cents,
    required double hz,
    required HarpStringModel string,
  }) {
    state = state.copyWith(cents: cents, detectedHz: hz, closestString: string);
  }

  @override
  void dispose() {
    _pitchSub?.cancel();
    _service.stop();
    super.dispose();
  }
}

final tunerProvider = StateNotifierProvider<TunerNotifier, TunerState>(
  (ref) => TunerNotifier(ref),
);
