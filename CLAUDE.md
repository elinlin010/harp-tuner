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
    harp_type.dart             # HarpType enum (leverHarp, pedalHarp) + HarpTypeExt
    harp_string_model.dart     # HarpStringModel (note, octave → frequency via MIDI math)
  data/harp_presets.dart       # String layouts — leverHarpWithCount(int) + pedalHarp
  providers/
    tuner_provider.dart        # TunerState + TunerNotifier (Riverpod StateNotifier)
    locale_provider.dart       # Locale switching
  services/
    pitch_detection_service.dart  # Mic input + pitch detection (real implementation)
    tone_player_service.dart      # Reference tone playback (real implementation)
  screens/
    harp_select_screen.dart    # Harp type picker (entry screen)
    tuner_screen.dart          # Main tuner UI + settings bottom sheet
  widgets/
    tuner_gauge.dart           # Animated arc gauge with needle (CustomPainter)
    string_visualizer.dart     # Horizontal string list (tap-to-reference in reference mode)
    mode_toggle.dart           # AUTO / REFERENCE segmented pill
    pitch_light_indicator.dart # ♭ / ✓ / ♯ traffic-light bulbs
  l10n/                        # ARB files + generated app_localizations*.dart (6 locales)
  utils/music_utils.dart       # frequencyToNoteInfo(), cents math
```

## Key Patterns

**State:** All state flows through `TunerState` / `TunerNotifier` in `tuner_provider.dart`. Key fields: `selectedHarp`, `leverStringCount` (19–40, default 34), `a4Hz` (430–450, default 440), `preferFlats`, `showOctave`, `tunerMode`, `referenceString`, `cents`, `isStale`. All user-facing settings are persisted via `SharedPreferences`.

**Frequency math:** `HarpStringModel.frequency` uses `440 * 2^((midi - 69) / 12)`. MIDI for C4 = 60. Pass `a4Hz` override via `frequencyAt(double a4Hz)`.

**Harp string layouts:**
- Lever harp: 19–40 strings (user-configurable), A♭1 up — `HarpPresets.leverHarpWithCount(count)`. Default 34 strings (A♭1–F6, E♭ major).
- Pedal harp: 47 strings, C♭1–G♭7, all pedals flat — `HarpPresets.pedalHarp`.
- Lap harp was removed. `HarpType` has only `leverHarp` and `pedalHarp`.

**Localisation:** 6 locales (en, de, fr, it, zh, zh_TW). ARB template is `app_en.arb`. Regenerate with `flutter gen-l10n` (configured in `l10n.yaml`). Parametric keys use `{placeholder}` syntax with typed placeholders in the `@key` metadata block.

**Settings sheet patterns:**
- Row layout for label + control: use `Expanded` on the label (left-aligned) and wrap controls in a `Row(mainAxisSize: MainAxisSize.min)` (right-aligned).
- Accidentals in subtitles: use `_accText()` helper in `tuner_screen.dart` — renders ♭/♯ at 68% size, bottom-aligned, using `WidgetSpan` + `PlaceholderAlignment.bottom`. Do NOT apply to primary labels (toggle row labels, section headers).
- Touch targets: wrap icons in `GestureDetector(behavior: HitTestBehavior.opaque)` for reliable hit testing on small targets. Add `Semantics(button: true, label: ...)` for accessibility.

**Design system:** Dark walnut palette defined in `AppColors`. Fonts: Cormorant Garamond (display) + Cutive Mono (numbers/readouts). All colors/text styles come from `app_theme.dart` — do not use hard-coded colors. Theme is runtime-switchable via `tunerThemeProvider`.

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

- Real mic pitch detection via `PitchDetectionService` (stability-gated, octave-corrected, hysteresis)
- Reference tone playback via `TonePlayerService` (sine wave, mic suppression window after playback)
- Microphone permission via `permission_handler`
- Reference mode: tap a string to hear it and tune to it; gauge shows cents relative to that string
- Settings: preferFlats, showOctave, A4 calibration (430–450 Hz), lever string count (19–40), theme, language
