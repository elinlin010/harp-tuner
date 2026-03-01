import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/harp_type.dart';
import '../models/harp_string_model.dart';
import '../data/harp_presets.dart';

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

// ── Mock tuner state ─────────────────────────────────────────────────────────

class TunerState {
  final bool isListening;
  final bool isPlayingTone;
  final double? cents;      // -50..+50, null = no signal
  final double? detectedHz;
  final HarpStringModel? closestString;

  const TunerState({
    this.isListening = false,
    this.isPlayingTone = false,
    this.cents,
    this.detectedHz,
    this.closestString,
  });

  TunerState copyWith({
    bool? isListening,
    bool? isPlayingTone,
    double? cents,
    double? detectedHz,
    HarpStringModel? closestString,
    bool clearCents = false,
  }) {
    return TunerState(
      isListening: isListening ?? this.isListening,
      isPlayingTone: isPlayingTone ?? this.isPlayingTone,
      cents: clearCents ? null : (cents ?? this.cents),
      detectedHz: clearCents ? null : (detectedHz ?? this.detectedHz),
      closestString: clearCents ? null : (closestString ?? this.closestString),
    );
  }
}

class TunerNotifier extends StateNotifier<TunerState> {
  TunerNotifier() : super(const TunerState());

  void startListening() {
    state = state.copyWith(isListening: true);
    // TODO: connect real pitch detection
  }

  void stopListening() {
    state = state.copyWith(isListening: false, clearCents: true);
  }

  void toggleListening() {
    if (state.isListening) {
      stopListening();
    } else {
      startListening();
    }
  }

  /// Simulate a tuner reading (for UI demo)
  void mockReading({required double cents, required double hz, required HarpStringModel string}) {
    state = state.copyWith(cents: cents, detectedHz: hz, closestString: string);
  }

  void playTone(HarpStringModel string) {
    // TODO: generate and play sine wave
    state = state.copyWith(isPlayingTone: true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) state = state.copyWith(isPlayingTone: false);
    });
  }

  void stopTone() {
    state = state.copyWith(isPlayingTone: false);
  }
}

final tunerProvider = StateNotifierProvider<TunerNotifier, TunerState>(
  (ref) => TunerNotifier(),
);
