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
- **Settings**: preferFlats, showOctave, A4 calibration (430–450 Hz), lever string count (19–40), theme, language, showTuningReminder
- **Tuning reminder**: on mic start, a floating snackbar prompts pedal harp users to set pedals to flat and lever harp users to disengage levers. Dismissed via "Got it" or mic stop. Toggle in settings (`showTuningReminder`, persisted via SharedPreferences key `tuner_show_tuning_reminder`).

## Versioning

VERSION file uses Flutter format `MAJOR.MINOR.PATCH+BUILD` (e.g. `1.0.6+6`), matching `pubspec.yaml`. The gstack `/ship` skill may write a 4-digit format — always verify and correct after a ship run. Both `VERSION` and `pubspec.yaml` must be kept in sync.

## Lever Harp String Layout

`HarpPresets.leverHarpWithCount` is treble-anchored: E♭7 is always the top string regardless of count. The bass note varies: 40 strings = A♭1, 34 strings (default) = G2, 19 strings = A♭4. The implementation uses `pool.sublist(pool.length - clamped)` — do not change to `pool.take(count)`, which would bass-anchor instead.

## ARB Placeholder Changes

When adding a new `{placeholder}` to an existing ARB key: update all 6 locale files (app_en.arb, app_de.arb, app_fr.arb, app_it.arb, app_zh.arb, app_zh_TW.arb) before running `flutter gen-l10n`. Missing even one locale causes inconsistent generated Dart method signatures.

## ref.listen Side Effects

When a `ref.listen<TunerState>` callback drives side effects (e.g. showing a snackbar), enumerate all state transitions that should trigger the effect — not just initial activation. Re-enabling a toggle while the relevant feature is already active is a valid state transition that won't fire unless handled explicitly (e.g. a `reminderTurnedOn` case alongside the `listeningStarted` case).

## Android Audio Notes

On Android, `AudioRecord` (mic) and `MediaPlayer` (tone) conflict for audio routing: if both are active simultaneously, output is silently routed to the earpiece. The fix in `TunerNotifier.playReferenceString` pauses the mic subscription while the tone plays and restarts it automatically after 2.3 s via `_micRestartTimer`.

## Android Resource Rules

`android:drawable` on `<item>` in a `<layer-list>` does NOT accept raw hex colors — AAPT will reject it at build time. Always use a `@color/` reference. Define the color in `android/app/src/main/res/values/colors.xml` first. The splash screen (`launch_background`) and adaptive icon background (`ic_launcher_background`) are separate color entries even if they share the same value.

## Android Package Rename

Changing `namespace` / `applicationId` in `build.gradle.kts` requires three matching updates: (1) the Kotlin source directory path (`kotlin/com/career010/harpie/`), (2) the `package` declaration in `MainActivity.kt`, and (3) all `PRODUCT_BUNDLE_IDENTIFIER` entries in `ios/Runner.xcodeproj/project.pbxproj`. Missing any one causes a runtime `ClassNotFoundException` or a mismatched iOS bundle ID. Package ID changes also wipe SharedPreferences on existing installs (different sandbox) — always default-initialize critical state so the app is usable on first launch.

## Android Adaptive Icon

The adaptive icon requires per-density foreground PNGs in each `drawable-<density>/` folder (not a single file). `mipmap-anydpi-v26/ic_launcher.xml` references `@drawable/ic_launcher_foreground` (resolves by density) and `@color/ic_launcher_background`. If the foreground PNG already has safe-zone padding baked in, do NOT add an `<inset>` in the XML — double-padding shrinks the icon visually. Use designer-provided pre-sized files rather than programmatic background removal, which produces washed-out results.

## iOS PrivacyInfo.xcprivacy

The file at `ios/Runner/PrivacyInfo.xcprivacy` must be added to the Xcode project (drag into Xcode navigator with "Add to target: Runner" checked). Placing the file on disk alone is insufficient — Xcode will not include it in the build without a project reference. This step must be done manually in Xcode.

## Skill routing

When the user's request matches an available skill, ALWAYS invoke it using the Skill
tool as your FIRST action. Do NOT answer directly, do NOT use other tools first.
The skill has specialized workflows that produce better results than ad-hoc answers.

Key routing rules:
- Product ideas, "is this worth building", brainstorming → invoke office-hours
- Bugs, errors, "why is this broken", 500 errors → invoke investigate
- Ship, deploy, push, create PR → invoke ship
- QA, test the site, find bugs → invoke qa
- Code review, check my diff → invoke review
- Update docs after shipping → invoke document-release
- Weekly retro → invoke retro
- Design system, brand → invoke design-consultation
- Visual audit, design polish → invoke design-review
- Architecture review → invoke plan-eng-review
- Save progress, checkpoint, resume → invoke context-save
- Code quality, health check → invoke health
