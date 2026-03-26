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

## gstack Skills

Use the `/browse` skill from gstack for all web browsing. Never use `mcp__claude-in-chrome__*` tools.

Available skills:
- `/office-hours` — Brainstorm and reframe a product idea before writing code
- `/plan-ceo-review` — Strategic review of a feature plan
- `/plan-eng-review` — Architecture review of a technical plan
- `/plan-design-review` — Design review of a plan
- `/design-consultation` — Create or audit a design system
- `/review` — Pre-landing code review (bugs, security, structure)
- `/ship` — Full ship workflow: tests → review → bump version → PR
- `/land-and-deploy` — Land PR and deploy to production
- `/canary` — Canary deploy workflow
- `/benchmark` — Performance benchmarking
- `/browse` — Headless browser for QA and dogfooding
- `/qa` — Full QA pass on the app
- `/qa-only` — QA without code changes
- `/design-review` — Visual design audit
- `/setup-browser-cookies` — Set up browser session cookies
- `/setup-deploy` — Set up deploy pipeline
- `/retro` — Weekly retrospective and dev stats
- `/investigate` — Debug errors and investigate issues
- `/document-release` — Post-ship documentation updates
- `/codex` — Adversarial second-opinion code review
- `/careful` — Safety mode for production/live systems
- `/freeze` — Scope edits to one module/directory
- `/guard` — Maximum safety mode (destructive warnings + edit restrictions)
- `/unfreeze` — Remove edit restrictions
- `/gstack-upgrade` — Upgrade gstack to latest version

If gstack skills aren't working, run `cd ~/.claude/skills/gstack && ./setup` to rebuild.

## Implemented Features

All core features are shipped:

- **Mic pitch detection**: `mic_stream` + `pitch_detector_dart` in `PitchDetectionService`
- **Reference tone playback**: 8-layer harp acoustic synthesis in `TonePlayerService`; tones are precomputed and cached when entering reference mode
- **Microphone permission**: `permission_handler` via a custom iOS method channel (`com.harptuner/mic_permission`) and Android manifest

## Android Audio Notes

On Android, `AudioRecord` (mic) and `MediaPlayer` (tone) conflict for audio routing: if both are active simultaneously, output is silently routed to the earpiece. The fix in `TunerNotifier.playReferenceString` pauses the mic subscription while the tone plays and restarts it automatically after 2.3 s via `_micRestartTimer`.
