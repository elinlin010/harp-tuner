# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
# Run on a device/simulator
flutter run

# Static analysis
flutter analyze

# Run tests
flutter test

# Run single test file
flutter test test/widget_test.dart

# Build release APK / iOS archive
flutter build apk
flutter build ios
```

Flutter is bundled locally at `../flutter/` — use `../flutter/bin/flutter` if not on PATH.

## Architecture

**Tech stack:** Flutter + Riverpod (state) + Google Fonts (typography)

```
lib/
  main.dart                    # App entry, ProviderScope root
  theme/app_theme.dart         # AppColors, AppTextStyles, AppTheme.dark
  models/
    harp_type.dart             # HarpType enum + HarpTypeExt (displayName, subtitle, description)
    harp_string_model.dart     # HarpStringModel (note, octave → frequency via MIDI math)
  data/harp_presets.dart       # Static string layouts for all 3 harp types
  providers/tuner_provider.dart # Riverpod providers: selectedHarp, harpStrings, mode, tunerState
  screens/
    harp_select_screen.dart    # Harp type picker (entry screen)
    tuner_screen.dart          # Main tuner UI
  widgets/
    tuner_gauge.dart           # Animated arc gauge with needle (CustomPainter)
    string_tile.dart           # Individual string row in the list
    mode_toggle.dart           # AUTO / MANUAL segmented control
```

## Key Patterns

**State:** All state flows through Riverpod providers in `tuner_provider.dart`. The `TunerNotifier` holds mock pitch detection state — real mic integration goes here.

**Frequency math:** `HarpStringModel.frequency` uses `440 * 2^((midi - 69) / 12)`. MIDI for C4 = 60.

**Harp string layouts:**
- Lap harp: 15 strings, C4–C6 diatonic
- Lever harp: 34 strings, A1–F6 diatonic
- Pedal harp: 47 strings, C1–G7 diatonic (standard concert tuning)

**Design system:** Dark walnut palette defined in `AppColors`. Fonts: Cormorant Garamond (display) + Cutive Mono (numbers/readouts). All colors/text styles come from `app_theme.dart` — do not use hard-coded colors.

## Next Steps (not yet implemented)

- Real mic pitch detection: replace `TunerNotifier.mockReading` with `mic_stream` + `pitch_detector_dart`
- Reference tone playback: replace `TunerNotifier.playTone` stub with sine-wave generation + audioplayers
- Microphone permission: add `permission_handler` and request `Permission.microphone` before listening
