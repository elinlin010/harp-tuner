import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/harp_presets.dart';
import '../models/harp_string_model.dart';
import '../models/harp_type.dart';
import '../services/pitch_detection_service.dart';
import '../services/tone_player_service.dart';
import '../utils/music_utils.dart';

// ── Enums ─────────────────────────────────────────────────────────────────────

enum TunerMode { auto, reference }

// ── Tuner state ───────────────────────────────────────────────────────────────

class TunerState {
  final bool isListening;
  final bool permissionDenied;
  final bool preferFlats;
  final bool showOctave;
  final int a4Hz;
  final int leverStringCount;
  final HarpType? selectedHarp;
  final TunerMode tunerMode;
  final HarpStringModel? referenceString;
  final bool isPlayingTone;
  final double? cents;
  final double? detectedHz;
  final String? closestNoteName;
  final String? micError;
  final bool isStale;
  final bool showTuningReminder;

  const TunerState({
    this.isListening = false,
    this.permissionDenied = false,
    this.preferFlats = false,
    this.showOctave = false,
    this.a4Hz = 440,
    this.leverStringCount = 34,
    this.selectedHarp,
    this.tunerMode = TunerMode.auto,
    this.referenceString,
    this.isPlayingTone = false,
    this.cents,
    this.detectedHz,
    this.closestNoteName,
    this.micError,
    this.isStale = false,
    this.showTuningReminder = true,
  });

  TunerState copyWith({
    bool? isListening,
    bool? permissionDenied,
    bool? preferFlats,
    bool? showOctave,
    int? a4Hz,
    int? leverStringCount,
    HarpType? selectedHarp,
    bool clearSelectedHarp = false,
    TunerMode? tunerMode,
    HarpStringModel? referenceString,
    bool clearReferenceString = false,
    bool? isPlayingTone,
    bool? showTuningReminder,
    double? cents,
    double? detectedHz,
    String? closestNoteName,
    String? micError,
    bool? isStale,
    bool clearPitch = false,
    bool clearMicError = false,
  }) {
    return TunerState(
      isListening: isListening ?? this.isListening,
      permissionDenied: permissionDenied ?? this.permissionDenied,
      preferFlats: preferFlats ?? this.preferFlats,
      showOctave: showOctave ?? this.showOctave,
      a4Hz: a4Hz ?? this.a4Hz,
      leverStringCount: leverStringCount ?? this.leverStringCount,
      selectedHarp: clearSelectedHarp ? null : (selectedHarp ?? this.selectedHarp),
      tunerMode: tunerMode ?? this.tunerMode,
      referenceString: clearReferenceString ? null : (referenceString ?? this.referenceString),
      isPlayingTone: isPlayingTone ?? this.isPlayingTone,
      showTuningReminder: showTuningReminder ?? this.showTuningReminder,
      cents: clearPitch ? null : (cents ?? this.cents),
      detectedHz: clearPitch ? null : (detectedHz ?? this.detectedHz),
      closestNoteName:
          clearPitch ? null : (closestNoteName ?? this.closestNoteName),
      micError:
          (clearPitch || clearMicError) ? null : (micError ?? this.micError),
      isStale: clearPitch ? false : (isStale ?? this.isStale),
    );
  }
}

// ── Tuner notifier ────────────────────────────────────────────────────────────

class TunerNotifier extends StateNotifier<TunerState> {
  final PitchDetectionService _service    = PitchDetectionService();
  final TonePlayerService     _tonePlayer = TonePlayerService();
  StreamSubscription<PitchResult?>? _pitchSub;
  SharedPreferences? _prefs;

  static const _historyLen      = 8;
  static const _stableNeeded    = 3;   // 3 stable frames (~280ms) to confirm a note
  static const _stableCents     = 25.0;
  static const _challengeNeeded = 3;   // 3 challenge frames before switching note
  static const _kStaleFrames    = 15;  // ~1.4s silence → dim display
  static const _kHoldFrames     = 22;  // ~2.0s silence → clear display

  static const _kA4HzKey              = 'tuner_a4_hz';
  static const _kPreferFlatsKey       = 'tuner_prefer_flats';
  static const _kShowOctaveKey        = 'tuner_show_octave';
  static const _kHarpTypeKey          = 'tuner_harp_type';
  static const _kLeverStringCountKey  = 'tuner_lever_string_count';
  static const _kShowTuningReminderKey = 'tuner_show_tuning_reminder';
  static const _kA4HzMin = 430;
  static const _kA4HzMax = 450;
  static const _kLeverStringMin = 19;
  static const _kLeverStringMax = 40;

  final _freqHistory = <double>[];
  int _silenceCount = 0;
  String? _confirmedNote;
  String? _challengeNote;
  int _challengeCount = 0;

  // On Android, AudioRecord and AudioTrack/MediaPlayer conflict for audio
  // routing: while the mic is active, speaker output is routed to the earpiece.
  // We pause the mic during reference tone playback and restart it after.
  Timer? _micRestartTimer;

  // Mic suppression: ignore pitch results briefly after restarting the mic so
  // the speaker bleed doesn't confuse the pitch detector.
  DateTime? _suppressUntil;

  TunerNotifier() : super(const TunerState()) {
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      final savedA4             = _prefs!.getInt(_kA4HzKey);
      final savedFlats          = _prefs!.getBool(_kPreferFlatsKey);
      final savedOctave         = _prefs!.getBool(_kShowOctaveKey);
      final savedHarpType       = _prefs!.getString(_kHarpTypeKey);
      final savedLeverCount     = _prefs!.getInt(_kLeverStringCountKey);
      final savedShowReminder   = _prefs!.getBool(_kShowTuningReminderKey);

      HarpType? harpType;
      if (savedHarpType != null) {
        try {
          harpType = HarpType.values.firstWhere((e) => e.name == savedHarpType);
        } catch (_) {}
      }

      state = state.copyWith(
        a4Hz: savedA4 != null ? savedA4.clamp(_kA4HzMin, _kA4HzMax) : state.a4Hz,
        preferFlats: savedFlats ?? state.preferFlats,
        showOctave: savedOctave ?? state.showOctave,
        selectedHarp: harpType,
        showTuningReminder: savedShowReminder ?? state.showTuningReminder,
        leverStringCount: savedLeverCount != null
            ? savedLeverCount.clamp(_kLeverStringMin, _kLeverStringMax)
            : state.leverStringCount,
      );
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

    _attachMicSubscription();
  }

  void _attachMicSubscription() {
    if (_pitchSub != null) return; // already subscribed — don't create a second one
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
    _micRestartTimer?.cancel();
    _micRestartTimer = null;
    _pitchSub?.cancel();
    _pitchSub = null;
    _service.stop();
    _freqHistory.clear();
    _silenceCount = 0;
    _confirmedNote = null;
    _challengeNote = null;
    _challengeCount = 0;
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

  // ── Tone precomputation ────────────────────────────────────────────────────

  void _precomputeHarpTones(HarpType harp) {
    final strings = HarpPresets.stringsFor(harp);
    final freqs = strings.map((s) => s.frequencyAt(state.a4Hz.toDouble())).toList();
    _tonePlayer.precompute(freqs);
  }

  // ── Mode switching ─────────────────────────────────────────────────────────

  Future<void> setTunerMode(TunerMode mode) async {
    if (mode == state.tunerMode) return;
    if (mode == TunerMode.auto) {
      // Leaving reference mode: stop any playing tone and wipe reference state.
      try {
        await _tonePlayer.stop();
      } catch (e) {
        debugPrint('TunerNotifier: failed to stop tone on mode switch: $e');
      }
      state = state.copyWith(
        tunerMode: TunerMode.auto,
        clearReferenceString: true,
        isPlayingTone: false,
        clearPitch: true,
      );
    } else {
      state = state.copyWith(
        tunerMode: TunerMode.reference,
        clearPitch: true,
      );
      // Kick off background synthesis for all strings so taps are instant.
      if (state.selectedHarp != null) _precomputeHarpTones(state.selectedHarp!);
    }
  }

  // ── Reference tone playback ────────────────────────────────────────────────

  /// Tap a string in reference mode: play its tone and pin it as the tuning
  /// target.
  ///
  /// On Android, AudioRecord and MediaPlayer conflict for audio routing while
  /// both are active simultaneously — output ends up on the earpiece instead
  /// of the speaker. To work around this we pause the mic for the duration of
  /// the tone (2 s) and restart it automatically afterward.
  Future<void> playReferenceString(HarpStringModel string) async {
    // Cancel any pending mic-restart from a previous tap.
    _micRestartTimer?.cancel();
    _micRestartTimer = null;

    state = state.copyWith(
      referenceString: string,
      isPlayingTone: true,
      clearPitch: true,
    );

    // Reset detection history so the next note gets a clean reading.
    _freqHistory.clear();
    _silenceCount = 0;
    _confirmedNote = null;
    _challengeNote = null;
    _challengeCount = 0;

    // Pause the mic while the tone plays so Android routes audio to speaker.
    final wasMicActive = _pitchSub != null;
    if (wasMicActive) {
      _pitchSub!.cancel();
      _pitchSub = null;
      _service.stop();
    }

    final hz = string.frequencyAt(state.a4Hz.toDouble());
    try {
      await _tonePlayer.play(hz);
    } catch (e) {
      debugPrint('TunerNotifier: failed to play reference tone: $e');
    } finally {
      if (mounted) state = state.copyWith(isPlayingTone: false);
    }

    // Restart mic 2.3 s after playback begins (tone is 2 s; small buffer for
    // the tail). If the user taps stop tuning before the timer fires,
    // stopListening() cancels it and isListening → false so the callback
    // becomes a no-op.
    // Use state.isListening (intent) not wasMicActive (actual) — on rapid double-tap
    // the second call sees _pitchSub == null (already stopped by first tap), so
    // wasMicActive would be false and no restart would ever be scheduled.
    if (state.isListening && mounted) {
      _micRestartTimer = Timer(const Duration(milliseconds: 2300), () {
        _micRestartTimer = null;
        if (!mounted || !state.isListening || _pitchSub != null) return;
        // Brief suppression so speaker bleed at end of tone doesn't register.
        _suppressUntil = DateTime.now().add(const Duration(milliseconds: 300));
        _attachMicSubscription();
      });
    }
  }

  // ── Settings ────────────────────────────────────────────────────────────────

  Future<void> toggleShowOctave() async {
    final newVal = !state.showOctave;
    state = state.copyWith(showOctave: newVal);
    try {
      _prefs ??= await SharedPreferences.getInstance();
      await _prefs!.setBool(_kShowOctaveKey, newVal);
    } catch (e) {
      debugPrint('TunerNotifier: failed to save showOctave: $e');
    }
  }

  Future<void> togglePreferFlats() async {
    final newPreferFlats = !state.preferFlats;
    if (state.detectedHz != null) {
      final info = MusicUtils.frequencyToNoteInfo(
        state.detectedHz!,
        preferFlats: newPreferFlats,
        pedalHarp: state.selectedHarp == HarpType.pedalHarp,
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
    try {
      _prefs ??= await SharedPreferences.getInstance();
      await _prefs!.setBool(_kPreferFlatsKey, newPreferFlats);
    } catch (e) {
      debugPrint('TunerNotifier: failed to save preferFlats: $e');
    }
  }

  Future<void> setA4Hz(int hz) async {
    final clamped = hz.clamp(_kA4HzMin, _kA4HzMax);
    if (state.detectedHz != null) {
      final info = MusicUtils.frequencyToNoteInfo(
        state.detectedHz!,
        preferFlats: state.preferFlats,
        pedalHarp: state.selectedHarp == HarpType.pedalHarp,
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

  Future<void> setLeverStringCount(int count) async {
    final clamped = count.clamp(_kLeverStringMin, _kLeverStringMax);
    state = state.copyWith(leverStringCount: clamped);
    try {
      _prefs ??= await SharedPreferences.getInstance();
      await _prefs!.setInt(_kLeverStringCountKey, clamped);
    } catch (e) {
      debugPrint('TunerNotifier: failed to save leverStringCount: $e');
    }
  }

  Future<void> toggleShowTuningReminder() async {
    final newVal = !state.showTuningReminder;
    state = state.copyWith(showTuningReminder: newVal);
    try {
      _prefs ??= await SharedPreferences.getInstance();
      await _prefs!.setBool(_kShowTuningReminderKey, newVal);
    } catch (e) {
      debugPrint('TunerNotifier: failed to save showTuningReminder: $e');
    }
  }

  Future<void> setSelectedHarp(HarpType? harp) async {
    if (harp == null) {
      // Deselecting instrument: also exit reference mode
      await _tonePlayer.stop();
      state = state.copyWith(
        clearSelectedHarp: true,
        tunerMode: TunerMode.auto,
        clearReferenceString: true,
        isPlayingTone: false,
      );
    } else {
      // Harp selected — always enable preferFlats (B♭ convention)
      state = state.copyWith(selectedHarp: harp, preferFlats: true);
      // If already in reference mode, precompute tones for the new harp.
      if (state.tunerMode == TunerMode.reference) _precomputeHarpTones(harp);
    }
    try {
      _prefs ??= await SharedPreferences.getInstance();
      if (harp == null) {
        await _prefs!.remove(_kHarpTypeKey);
      } else {
        await _prefs!.setString(_kHarpTypeKey, harp.name);
        await _prefs!.setBool(_kPreferFlatsKey, true);
      }
    } catch (e) {
      debugPrint('TunerNotifier: failed to save harpType: $e');
    }
  }

  // ── Pitch processing ───────────────────────────────────────────────────────

  void _onPitchResult(PitchResult? result) {
    if (result == null) {
      _silenceCount++;
      if (_silenceCount == 1) {
        // First silence frame: reset detection state immediately so the next
        // note has a clean history and no hysteresis blocking. Display stays
        // fully bright until _kStaleFrames to avoid flicker between notes.
        _freqHistory.clear();
        _confirmedNote = null;
        _challengeNote = null;
        _challengeCount = 0;
      } else if (_silenceCount == _kStaleFrames && !state.isStale) {
        // Sustained silence: dim the display to signal stale reading
        if (state.cents != null) state = state.copyWith(isStale: true);
      } else if (_silenceCount >= _kHoldFrames) {
        // Long silence: wipe the display too
        _silenceCount = 0;
        state = state.copyWith(clearPitch: true); // also resets isStale
      }
      return;
    }

    // Suppress pitch updates briefly after playing a reference tone so the
    // speaker output doesn't confuse the pitch detector.
    if (_suppressUntil != null && DateTime.now().isBefore(_suppressUntil!)) {
      return;
    }

    // Signal returned — reset silence tracking
    _silenceCount = 0;

    final hz = result.frequency;

    // Octave correction + outlier rejection
    if (_freqHistory.isNotEmpty) {
      final med = _median(_freqHistory);
      final centsDiff = 1200 * log(hz / med) / ln2;
      if (centsDiff.abs() > 150) {
        final corrected = _octaveCorrect(hz, med);
        if (corrected == null) return;
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

    // ── Reference mode: measure cents relative to the pinned string ──────────
    // If no string has been tapped yet, suppress all updates — the gauge should
    // stay blank rather than silently behaving like auto mode.
    if (state.tunerMode == TunerMode.reference && state.referenceString == null) {
      return;
    }
    if (state.tunerMode == TunerMode.reference && state.referenceString != null) {
      final refHz    = state.referenceString!.frequencyAt(state.a4Hz.toDouble());
      final refCents = (1200 * log(stableHz / refHz) / ln2).clamp(-100.0, 100.0);
      state = state.copyWith(
        isStale: false,
        detectedHz: stableHz,
        closestNoteName: state.referenceString!.label,
        cents: refCents,
      );
      return;
    }

    // ── Auto mode: find the closest note ────────────────────────────────────
    final info = MusicUtils.frequencyToNoteInfo(
      stableHz,
      preferFlats: state.preferFlats,
      pedalHarp: state.selectedHarp == HarpType.pedalHarp,
      a4Hz: state.a4Hz.toDouble(),
    );

    // Hysteresis: prevent rapid note switching
    if (_confirmedNote == null || _confirmedNote == info.noteName) {
      _confirmedNote = info.noteName;
      _challengeNote = null;
      _challengeCount = 0;
      state = state.copyWith(
        isStale: false,
        detectedHz: stableHz,
        closestNoteName: info.noteName,
        cents: info.cents,
      );
    } else {
      if (_challengeNote == info.noteName) {
        _challengeCount++;
      } else {
        _challengeNote = info.noteName;
        _challengeCount = 1;
      }
      if (_challengeCount >= _challengeNeeded) {
        _confirmedNote = info.noteName;
        _challengeNote = null;
        _challengeCount = 0;
        state = state.copyWith(
          isStale: false,
          detectedHz: stableHz,
          closestNoteName: info.noteName,
          cents: info.cents,
        );
      }
    }
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
    _micRestartTimer?.cancel();
    _pitchSub?.cancel();
    _service.stop();
    _tonePlayer.dispose();
    super.dispose();
  }
}

final tunerProvider = StateNotifierProvider<TunerNotifier, TunerState>(
  (ref) => TunerNotifier(),
);
