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
flutter test test/harp_presets_test.dart

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

**Design system:** See `DESIGN.md` for the full design system. All colors/text styles come from `app_theme.dart` — do not use hard-coded colors. Use `TunerThemeData.sans()` and `TunerThemeData.label()` for all text; never hard-code `TextStyle` outside the theme. Theme is runtime-switchable via `tunerThemeProvider`.

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

## Design System

Always read `DESIGN.md` before making any visual or UI decisions.
All font choices, colors, spacing, and aesthetic direction are defined there.
Do not deviate without explicit user approval.
In QA mode, flag any code that doesn't match `DESIGN.md`.

## Development Principles

**i18n is non-negotiable.** Every user-visible string must live in the ARB files — never hardcode text in widgets. When adding any feature that shows text: write the ARB key first in all 6 locales (en, de, fr, it, zh, zh_TW), then use `l10n.yourKey` in the widget. Parametric keys (e.g. `{count} strings`) need typed placeholder metadata in the `@key` block.

**Test across locales before shipping.** German and Italian translations tend to be longer than English. A layout that fits "A4 Reference" may not fit "Riferimento A4". Design settings rows to handle long labels gracefully: `Expanded` on the label with `overflow: TextOverflow.ellipsis, maxLines: 1`, and group controls on the right with `mainAxisSize: MainAxisSize.min`.

**Prefer horizontal layouts in settings rows.** Users scan settings lists vertically. A stacked Column (label above, control below) doubles the visual height of a row and makes the sheet feel taller than it is. Keep label and control on one line whenever possible.

**Icon-only buttons for locale-variable actions.** If a button's label changes length across languages (e.g. "Reset to 440 Hz" vs "Réinitialiser à 440 Hz"), use an icon-only button with `Semantics(label: l10n.theLabel)` for screen readers. It's the only guaranteed overflow-safe solution.

**Visual gaps in CustomPaint come from the SizedBox, not the paint.** A triangle drawn centered in a 48×48 SizedBox has ~17px of dead space on each side. Reduce the SizedBox width (e.g. 36px) to tighten spacing — the touch target height can stay tall independently.

**Touch targets: 44pt minimum, always opaque.** Wrap small tap surfaces in `GestureDetector(behavior: HitTestBehavior.opaque)` so taps on transparent areas still register. Add `Semantics(button: true, label: ...)` on icon-only buttons.

**Accidentals (♭ ♯) in subtitles — use `_accText()`.** Flat and sharp symbols are tall glyphs that disrupt line rhythm when rendered at body size. Use the `_accText()` helper in `tuner_screen.dart` to render them at 68% size, bottom-aligned. Exception: primary labels and toggle row labels should keep them full size for legibility.

## Implemented Features

All core features are shipped:

- **Mic pitch detection**: `mic_stream` + `pitch_detector_dart` in `PitchDetectionService` (stability-gated, octave-corrected, hysteresis)
- **Reference tone playback**: 8-layer harp acoustic synthesis in `TonePlayerService`; tones are precomputed and cached when entering reference mode
- **Microphone permission**: `permission_handler` via a custom iOS method channel (`com.harptuner/mic_permission`) and Android manifest
- **Reference mode**: tap a string to hear it and tune to it; gauge shows cents relative to that string
- **Settings**: preferFlats, showOctave, A4 calibration (430–450 Hz), lever string count (19–40), theme, language

## Android Audio Notes

On Android, `AudioRecord` (mic) and `MediaPlayer` (tone) conflict for audio routing: if both are active simultaneously, output is silently routed to the earpiece. The fix in `TunerNotifier.playReferenceString` pauses the mic subscription while the tone plays and restarts it automatically after 2.3 s via `_micRestartTimer`.
