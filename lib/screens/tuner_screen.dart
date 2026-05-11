import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../data/harp_presets.dart';
import '../l10n/app_localizations.dart';
import '../models/harp_string_model.dart';
import '../models/harp_type.dart';
import '../providers/locale_provider.dart';
import '../providers/tuner_provider.dart';
import '../theme/app_theme.dart';
import '../theme/theme_provider.dart';
import '../widgets/mode_toggle.dart';
import '../widgets/pitch_light_indicator.dart';
import '../widgets/settings_display.dart';
import '../widgets/string_visualizer.dart';
import '../widgets/tuner_gauge.dart';

class TunerScreen extends ConsumerStatefulWidget {
  const TunerScreen({super.key});

  @override
  ConsumerState<TunerScreen> createState() => _TunerScreenState();
}

class _TunerScreenState extends ConsumerState<TunerScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _listenBtnCtrl;

  @override
  void initState() {
    super.initState();
    _listenBtnCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final disable = MediaQuery.disableAnimationsOf(context);
    if (disable) {
      _listenBtnCtrl.stop();
      _listenBtnCtrl.value = 0.5;
    } else if (!_listenBtnCtrl.isAnimating) {
      _listenBtnCtrl.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _listenBtnCtrl.dispose();
    super.dispose();
  }

  void _showTuningReminderSnackBar(HarpType harp, TunerThemeData theme) {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    final text = harp == HarpType.pedalHarp
        ? l10n.reminderPedalSnack
        : l10n.reminderLeverSnack;

    // Light themes (Linen, Milk): inverted snackbar — textPrimary bg.
    // Dark themes (Blueprint, Void): dark surfaceHi bg, inTune border ring.
    // OK button: bold + larger; light mode uses muted white (softer against dark bg).
    final Color bgColor;
    final Color contentColor;
    final Color okColor;
    Color? accentBorder;

    if (theme.brightness == Brightness.light) {
      bgColor = theme.textPrimary;
      contentColor = theme.bg;
      okColor = theme.bg.withValues(alpha: 0.75);
    } else {
      bgColor = theme.surfaceHi;
      contentColor = theme.textPrimary;
      okColor = theme.inTune;
      accentBorder = theme.inTune;
    }

    messenger.showSnackBar(
      SnackBar(
        backgroundColor: bgColor,
        behavior: SnackBarBehavior.floating,
        dismissDirection: DismissDirection.none,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.all(Radius.circular(10)),
          side: accentBorder != null
              ? BorderSide(color: accentBorder, width: 1.5)
              : BorderSide.none,
        ),
        content: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: messenger.hideCurrentSnackBar,
          child: Row(
            children: [
              Expanded(
                child: Text(text, style: theme.sans(16, color: contentColor)),
              ),
              const SizedBox(width: 16),
              Semantics(
                button: true,
                label: l10n.reminderDismissBtn,
                child: Text(
                  l10n.reminderDismissBtn,
                  style: theme.sans(18,
                      weight: FontWeight.w700, color: okColor),
                ),
              ),
            ],
          ),
        ),
        duration: const Duration(days: 365),
      ),
    );
  }

  HarpStringModel? _closestString(
      List<HarpStringModel> strings, double? hz, int a4Hz) {
    if (hz == null || strings.isEmpty) return null;
    HarpStringModel? best;
    double bestCents = double.infinity;
    for (final s in strings) {
      final diff =
          (1200 * log(hz / s.frequencyAt(a4Hz.toDouble())) / ln2).abs();
      if (diff < bestCents) {
        bestCents = diff;
        best = s;
      }
    }
    return best;
  }

  void _showSettings(BuildContext context, {SettingsSection? focus}) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _SettingsSheet(focus: focus),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tuner = ref.watch(tunerProvider);
    final theme = ref.watch(tunerThemeProvider);

    ref.listen<TunerState>(tunerProvider, (prev, next) {
      final startedListening = !(prev?.isListening ?? false) && next.isListening;
      final stoppedListening = (prev?.isListening ?? false) && !next.isListening;
      final harpChangedWhileListening = next.isListening &&
          prev?.selectedHarp != next.selectedHarp &&
          next.selectedHarp != null;
      final reminderTurnedOff =
          (prev?.showTuningReminder ?? true) && !next.showTuningReminder;
      final reminderTurnedOn =
          !(prev?.showTuningReminder ?? true) && next.showTuningReminder;
      if ((startedListening || harpChangedWhileListening || reminderTurnedOn) &&
          next.showTuningReminder &&
          next.selectedHarp != null) {
        _showTuningReminderSnackBar(next.selectedHarp!, theme);
      } else if (stoppedListening || (reminderTurnedOff && next.isListening)) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
      }
    });

    ref.listen<TunerThemeData>(tunerThemeProvider, (_, nextTheme) {
      final tuner = ref.read(tunerProvider);
      if (tuner.isListening &&
          tuner.showTuningReminder &&
          tuner.selectedHarp != null) {
        _showTuningReminderSnackBar(tuner.selectedHarp!, nextTheme);
      }
    });

    final harpStrings = tuner.selectedHarp != null
        ? HarpPresets.stringsFor(tuner.selectedHarp!, leverStringCount: tuner.leverStringCount)
        : <HarpStringModel>[];

    // In reference mode the active string is the pinned reference string;
    // in auto mode it is the closest detected string.
    final isReference = tuner.tunerMode == TunerMode.reference;
    final activeString = isReference
        ? tuner.referenceString
        : _closestString(harpStrings, tuner.detectedHz, tuner.a4Hz);

    // The note name shown on the gauge always matches the active string.
    final noteName = tuner.closestNoteName;

    return Scaffold(
      backgroundColor: theme.bg,
      body: SafeArea(
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Current-settings mini cards (tap → jump into settings) ────
              SettingsDisplay(
                onTap: (section) =>
                    _showSettings(context, focus: section),
              ),

              // ── Nav bar: mode toggle (left) + settings (right) ────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Row(
                  children: [
                    // Mode toggle — only shown when a harp is selected
                    if (tuner.selectedHarp != null)
                      ModeToggle(
                        mode: tuner.tunerMode,
                        onChanged: (m) =>
                            ref.read(tunerProvider.notifier).setTunerMode(m),
                        theme: theme,
                      ),
                    const Spacer(),
                    // Settings pill
                    Material(
                      color: theme.surfaceHi,
                      borderRadius: BorderRadius.circular(20),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () => _showSettings(context),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.tune_rounded,
                                  size: 18, color: theme.textSecondary),
                              const SizedBox(width: 6),
                              Text(
                                AppLocalizations.of(context)!.settingsTitle,
                                style: theme.sans(14,
                                    weight: FontWeight.w600,
                                    color: theme.textSecondary),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Gauge + readout (full width, no horizontal padding) ────────
              Expanded(
                child: TunerGauge(
                  cents: tuner.cents,
                  noteName: noteName,
                  isListening: tuner.isListening,
                  isStale: tuner.isStale,
                  theme: theme,
                ),
              ),

              // ── String visualizer ──────────────────────────────────────────
              if (tuner.selectedHarp != null) ...[
                const SizedBox(height: 10),
                StringVisualizer(
                  strings: harpStrings,
                  activeString: activeString,
                  onTap: isReference
                      ? (s) => ref
                          .read(tunerProvider.notifier)
                          .playReferenceString(s)
                      : null,
                  theme: theme,
                ),
              ],

              // ── Pitch light indicator ──────────────────────────────────────
              const SizedBox(height: 14),
              PitchLightIndicator(
                cents: tuner.cents,
                isListening: tuner.isListening,
                isStale: tuner.isStale,
                theme: theme,
              ),
              const SizedBox(height: 14),

              // ── Listen button ──────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: _ListenButton(
                  isListening: tuner.isListening,
                  controller: _listenBtnCtrl,
                  onTap: () =>
                      ref.read(tunerProvider.notifier).toggleListening(),
                  theme: theme,
                ),
              ),

              // ── Permission denied banner ───────────────────────────────────
              if (tuner.permissionDenied) ...[
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: _PermissionBanner(theme: theme),
                ),
              ],

              // ── Mic hardware/API error banner ──────────────────────────────
              if (tuner.micError != null) ...[
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: _MicErrorBanner(
                    message: tuner.micError!,
                    onDismiss: () =>
                        ref.read(tunerProvider.notifier).clearMicError(),
                    theme: theme,
                  ),
                ),
              ],

              const SizedBox(height: 16),
            ],
        ),
      ),
    );
  }
}

// ── Harp type localization helpers ────────────────────────────────────────────

String _harpName(HarpType type, AppLocalizations l10n) {
  switch (type) {
    case HarpType.leverHarp: return l10n.harpTypeLeverHarp;
    case HarpType.pedalHarp: return l10n.harpTypePedalHarp;
  }
}

String _harpSubtitle(HarpType type, AppLocalizations l10n, {int leverStringCount = 34}) {
  switch (type) {
    case HarpType.leverHarp:
      return l10n.harpTypeLeverHarpSubtitleFmt(leverStringCount, _leverBottomNote(leverStringCount), _kLeverTopNote);
    case HarpType.pedalHarp: return l10n.harpTypePedalHarpSubtitle;
  }
}

// Pool: A♭1(0), B♭1(1), C2(2)…B♭2(8), C3(9)…B♭3(15), C4(16)…B♭4(22),
//       C5(23)…B♭5(29), C6(30)…B♭6(36), C7(37), D7(38), E♭7(39).
// Treble end is fixed at E♭7 (index 39); the bottom note index is 40 - count.

// Bottom note for each count (index = 40 - count, so count=40→index 0=A♭1,
// count=34→index 6=G2, count=19→index 21=A♭4).
const _kLeverBottomNotes = [
  'A♭1', // 40 — full range
  'B♭1', // 39
  'C2',  // 38
  'D2',  // 37
  'E♭2', // 36
  'F2',  // 35
  'G2',  // 34 — default
  'A♭2', // 33
  'B♭2', // 32
  'C3',  // 31
  'D3',  // 30
  'E♭3', // 29
  'F3',  // 28
  'G3',  // 27
  'A♭3', // 26
  'B♭3', // 25
  'C4',  // 24
  'D4',  // 23
  'E♭4', // 22
  'F4',  // 21
  'G4',  // 20
  'A♭4', // 19 — minimum
];

String _leverBottomNote(int count) {
  final idx = (40 - count.clamp(19, 40)).clamp(0, _kLeverBottomNotes.length - 1);
  return _kLeverBottomNotes[idx];
}

// Top note is always E♭7 (the treble end is fixed).
const _kLeverTopNote = 'E♭7';

// ── Settings bottom sheet ─────────────────────────────────────────────────────

class _SettingsSheet extends ConsumerStatefulWidget {
  final SettingsSection? focus;
  const _SettingsSheet({this.focus});

  @override
  ConsumerState<_SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends ConsumerState<_SettingsSheet> {
  final _instrumentKey = GlobalKey();
  final _a4Key = GlobalKey();
  final _stringCountKey = GlobalKey();
  SettingsSection? _pulseSection;

  @override
  void initState() {
    super.initState();
    if (widget.focus != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _scrollToAndPulse(widget.focus!);
      });
    }
  }

  GlobalKey _keyFor(SettingsSection section) {
    switch (section) {
      case SettingsSection.instrument:
        return _instrumentKey;
      case SettingsSection.a4:
        return _a4Key;
      case SettingsSection.stringCount:
        return _stringCountKey;
    }
  }

  Future<void> _scrollToAndPulse(SettingsSection section) async {
    final ctx = _keyFor(section).currentContext;
    if (ctx != null) {
      await Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
        alignment: 0.15,
      );
    }
    if (!mounted) return;
    setState(() => _pulseSection = section);
  }

  // Sheet content padding is applied per-child so pulse backgrounds can
  // still span the full sheet width.
  Widget _hPad(Widget child) =>
      Padding(padding: const EdgeInsets.symmetric(horizontal: 24), child: child);

  Widget _pulseWrap(SettingsSection section, TunerThemeData theme, Widget child) {
    if (_pulseSection != section) return child;
    // Dark rims are low-chroma gray on near-black — fades to invisible fast.
    // Use a white surface-tint with linear decay so the peak actually holds.
    final isDark = theme.brightness == Brightness.dark;
    final peak = isDark
        ? Colors.white.withValues(alpha: 0.14)
        : theme.surfaceRim.withValues(alpha: 0.55);
    return TweenAnimationBuilder<double>(
      key: ValueKey('pulse-$section'),
      tween: Tween(begin: 1.0, end: 0.0),
      duration: Duration(milliseconds: isDark ? 2400 : 1400),
      curve: isDark ? Curves.linear : Curves.easeOutCubic,
      builder: (context, t, c) => ColoredBox(
        color: Color.lerp(Colors.transparent, peak, t)!,
        child: c,
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final tuner = ref.watch(tunerProvider);
    final theme = ref.watch(tunerThemeProvider);
    final currentLocale = ref.watch(localeProvider);
    final animDuration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 200);
    final mq = MediaQuery.of(context);
    final bottomPad = mq.viewInsets.bottom + mq.padding.bottom;

    return Container(
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: theme.surfaceRim, width: 1)),
      ),
      padding: EdgeInsets.fromLTRB(0, 12, 0, 24 + bottomPad),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.72,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          // drag handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: theme.surfaceRim,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          _hPad(Text(l10n.settingsTitle, style: theme.sans(22, weight: FontWeight.w600))),
          const SizedBox(height: 24),

          // ── Instrument ────────────────────────────────────────────────────
          _pulseWrap(
            SettingsSection.instrument,
            theme,
            _hPad(Column(
              key: _instrumentKey,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SectionHeader(label: l10n.settingsInstrumentLabel, icon: Icons.piano_rounded, theme: theme),
                const SizedBox(height: 4),
                _InstrumentRow(
                  label: l10n.settingsInstrumentNone,
                  selected: tuner.selectedHarp == null,
                  onTap: () =>
                      ref.read(tunerProvider.notifier).setSelectedHarp(null),
                  theme: theme,
                ),
                for (final type in HarpType.values) ...[
                  _InstrumentRow(
                    label: _harpName(type, l10n),
                    subtitle: _harpSubtitle(type, l10n,
                        leverStringCount: tuner.leverStringCount),
                    selected: tuner.selectedHarp == type,
                    onTap: () =>
                        ref.read(tunerProvider.notifier).setSelectedHarp(type),
                    theme: theme,
                  ),
                  if (type == HarpType.leverHarp &&
                      tuner.selectedHarp == HarpType.leverHarp)
                    _pulseWrap(
                      SettingsSection.stringCount,
                      theme,
                      _LeverStringCountRow(
                        key: _stringCountKey,
                        count: tuner.leverStringCount,
                        onChanged: (v) => ref
                            .read(tunerProvider.notifier)
                            .setLeverStringCount(v),
                        theme: theme,
                      ),
                    ),
                ],
              ],
            )),
          ),

          if (tuner.selectedHarp != null) ...[
            _hPad(_SheetSwitchRow(
              label: l10n.settingsShowReminderToggle,
              subtitle: l10n.settingsShowReminderToggleHint,
              value: tuner.showTuningReminder,
              onToggle: () => ref
                  .read(tunerProvider.notifier)
                  .toggleShowTuningReminder(),
              theme: theme,
              animDuration: animDuration,
            )),
          ],

          const SizedBox(height: 20),
          Divider(color: theme.surfaceRim, height: 1),
          const SizedBox(height: 20),

          // ── Note display + A4 calibration ────────────────────────────────
          _hPad(_SectionHeader(label: l10n.settingsNoteDisplayLabel, icon: Icons.music_note_rounded, theme: theme)),
          const SizedBox(height: 12),
          _hPad(_SheetSwitchRow(
            label: l10n.settingsAlwaysShowFlatsToggle,
            subtitle: l10n.settingsAlwaysShowFlatsHint,
            // Harps are conventionally notated in flats — when a harp is
            // selected, the displayed note must match the string visualizer
            // (which uses flats), so the user can't toggle this off.
            value: tuner.selectedHarp != null ? true : tuner.preferFlats,
            disabled: tuner.selectedHarp != null,
            onToggle: () => ref.read(tunerProvider.notifier).togglePreferFlats(),
            theme: theme,
            animDuration: animDuration,
          )),
          _pulseWrap(
            SettingsSection.a4,
            theme,
            _hPad(_A4StepperRow(
              key: _a4Key,
              a4Hz: tuner.a4Hz,
              onDecrement: () =>
                  ref.read(tunerProvider.notifier).setA4Hz(tuner.a4Hz - 1),
              onIncrement: () =>
                  ref.read(tunerProvider.notifier).setA4Hz(tuner.a4Hz + 1),
              onReset: tuner.a4Hz != 440
                  ? () => ref.read(tunerProvider.notifier).setA4Hz(440)
                  : null,
              theme: theme,
            )),
          ),

          const SizedBox(height: 20),
          Divider(color: theme.surfaceRim, height: 1),
          const SizedBox(height: 20),

          // ── Appearance ────────────────────────────────────────────────────
          _hPad(_SectionHeader(label: l10n.settingsThemeLabel, icon: Icons.palette_outlined, theme: theme)),
          const SizedBox(height: 4),
          _hPad(_SheetSwitchRow(
            label: l10n.settingsDarkModeToggle,
            value: theme.brightness == Brightness.dark,
            onToggle: () =>
                ref.read(tunerThemeProvider.notifier).toggleDarkMode(),
            theme: theme,
            animDuration: animDuration,
          )),
          const SizedBox(height: 8),
          _hPad(_ThemePickerRow(
            currentTheme: theme,
            onSelect: (t) =>
                ref.read(tunerThemeProvider.notifier).setTheme(t),
          )),

          const SizedBox(height: 20),
          Divider(color: theme.surfaceRim, height: 1),
          const SizedBox(height: 20),

          // ── Language ──────────────────────────────────────────────────────
          _hPad(_SectionHeader(label: l10n.settingsLanguageLabel, icon: Icons.language_rounded, theme: theme)),
          const SizedBox(height: 4),
          _hPad(_LanguageDropdownRow(
            languages: _languages,
            currentLocale: currentLocale,
            onSelect: (locale) =>
                ref.read(localeProvider.notifier).setLocale(locale),
            theme: theme,
          )),
          ],
        ),
      ),
      ),
    );
  }
}

// A row with a label + custom toggle switch on the right
class _SheetSwitchRow extends StatelessWidget {
  final String label;
  final String? subtitle;
  final bool value;
  final VoidCallback onToggle;
  final TunerThemeData theme;
  final Duration animDuration;
  final bool disabled;

  const _SheetSwitchRow({
    required this.label,
    this.subtitle,
    required this.value,
    required this.onToggle,
    required this.theme,
    required this.animDuration,
    this.disabled = false,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      toggled: value,
      enabled: !disabled,
      child: GestureDetector(
        onTap: disabled ? null : onToggle,
        behavior: HitTestBehavior.opaque,
        child: Opacity(
          opacity: disabled ? 0.4 : 1.0,
          child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: theme.sans(16,
                            weight: FontWeight.w600,
                            color: theme.textPrimary)),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      _accText(subtitle!,
                          theme.sans(16, color: theme.textSecondary)),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 16),
              AnimatedContainer(
                duration: animDuration,
                width: 50,
                height: 28,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: value
                      ? theme.inTune.withValues(alpha: 0.25)
                      : theme.surfaceHi,
                  border: Border.all(
                    color: value
                        ? theme.inTune.withValues(alpha: 0.55)
                        : theme.surfaceRim,
                    width: 1,
                  ),
                ),
                child: AnimatedAlign(
                  duration: animDuration,
                  alignment:
                      value ? Alignment.centerRight : Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: AnimatedContainer(
                      duration: animDuration,
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: value ? theme.inTune : theme.textSecondary,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        ),
      ),
    );
  }
}

// ── Listen button ─────────────────────────────────────────────────────────────

class _ListenButton extends StatelessWidget {
  final bool isListening;
  final AnimationController controller;
  final VoidCallback onTap;
  final TunerThemeData theme;

  const _ListenButton({
    required this.isListening,
    required this.controller,
    required this.onTap,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedBuilder(
        animation: controller,
        builder: (ctx, child) {
          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              color: isListening
                  ? theme.inTune.withValues(alpha: 0.14)
                  : theme.surface,
              border: Border.all(
                color: isListening
                    ? theme.inTune.withValues(
                        alpha: 0.40 + controller.value * 0.20)
                    : theme.surfaceRim,
                width: 1.5,
              ),
              boxShadow: isListening
                  ? [
                      BoxShadow(
                        color: theme.inTune.withValues(
                            alpha: 0.12 + controller.value * 0.14),
                        blurRadius: 20,
                        spreadRadius: 2,
                      )
                    ]
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      )
                    ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isListening ? Icons.stop_rounded : Icons.mic_rounded,
                  size: 28,
                  color: isListening ? theme.inTune : theme.textSecondary,
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                    isListening ? l10n.tunerStopBtn : l10n.tunerStartBtn,
                    style: theme.sans(
                      20,
                      weight: FontWeight.w700,
                      color: isListening ? theme.inTune : theme.textSecondary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}



// ── Mic hardware/API error banner ─────────────────────────────────────────────

class _MicErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback onDismiss;
  final TunerThemeData theme;

  const _MicErrorBanner({
    required this.message,
    required this.onDismiss,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Semantics(
      label: l10n.errorMicDeniedTitle,
      button: true,
      hint: l10n.tapToDismiss,
      child: GestureDetector(
      onTap: onDismiss,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: BoxDecoration(
          color: theme.sharp.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: theme.sharp.withValues(alpha: 0.35), width: 1),
        ),
        child: Builder(builder: (ctx) {
          final l10n = AppLocalizations.of(ctx)!;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.warning_amber_rounded,
                      size: 20, color: theme.sharp),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      l10n.errorMicUnavailableMsg(message),
                      style: theme.sans(16, color: theme.textPrimary),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                l10n.tapToDismiss,
                style: theme.sans(16,
                    weight: FontWeight.w600,
                    color: theme.textSecondary),
              ),
            ],
          );
        }),
      ),
      ),    // GestureDetector
    );      // Semantics
  }
}

// ── Permission denied banner ──────────────────────────────────────────────────

class _PermissionBanner extends StatelessWidget {
  final TunerThemeData theme;

  const _PermissionBanner({required this.theme});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: theme.sharp.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border:
            Border.all(color: theme.sharp.withValues(alpha: 0.35), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.mic_off_rounded, size: 20, color: theme.sharp),
              const SizedBox(width: 10),
              Text(
                l10n.errorMicDeniedTitle,
                style: theme.sans(16, weight: FontWeight.w700, color: theme.sharp),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            l10n.errorMicDeniedMsg,
            style: theme.sans(16, color: theme.sharp.withValues(alpha: 0.85)),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () => openAppSettings(),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: theme.sharp.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: theme.sharp.withValues(alpha: 0.45), width: 1),
              ),
              child: Text(
                l10n.errorMicDeniedBtn,
                textAlign: TextAlign.center,
                style: theme.sans(16, weight: FontWeight.w700, color: theme.sharp),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── A4 calibration stepper ────────────────────────────────────────────────────

class _A4StepperRow extends StatelessWidget {
  final int a4Hz;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;
  final VoidCallback? onReset;
  final TunerThemeData theme;

  const _A4StepperRow({
    super.key,
    required this.a4Hz,
    required this.onDecrement,
    required this.onIncrement,
    required this.onReset,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final atMin = a4Hz <= 430;
    final atMax = a4Hz >= 450;
    final canReset = onReset != null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              l10n.settingsA4CalibLabel,
              style: theme.sans(16,
                  weight: FontWeight.w600, color: theme.textPrimary),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _StepBtn(
                pointRight: false,
                onTap: atMin ? null : onDecrement,
                theme: theme,
              ),
              SizedBox(
                width: 72,
                child: Text(
                  '$a4Hz Hz',
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  style: theme.sans(16, weight: FontWeight.w600),
                ),
              ),
              _StepBtn(
                pointRight: true,
                onTap: atMax ? null : onIncrement,
                theme: theme,
              ),
              Semantics(
                button: true,
                label: l10n.settingsA4CalibStandard,
                child: GestureDetector(
                  onTap: onReset,
                  behavior: HitTestBehavior.opaque,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.refresh_rounded,
                      key: ValueKey(canReset),
                      size: 20,
                      color: canReset ? theme.inTune : theme.textDim,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StepBtn extends StatelessWidget {
  final bool pointRight;
  final VoidCallback? onTap;
  final TunerThemeData theme;

  const _StepBtn({required this.pointRight, required this.onTap, required this.theme});

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Semantics(
      button: true,
      enabled: enabled,
      child: GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 36,
        height: 48,
        child: CustomPaint(
          painter: _TrianglePainter(
            pointRight: pointRight,
            color: enabled ? theme.textPrimary : theme.textDim,
          ),
        ),
      ),
      ),
    );
  }
}

class _TrianglePainter extends CustomPainter {
  final bool pointRight;
  final Color color;

  _TrianglePainter({required this.pointRight, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    const h = 14.0; // triangle height
    const w = 12.0; // triangle half-width

    final path = Path();
    if (pointRight) {
      path.moveTo(cx + h / 2, cy);
      path.lineTo(cx - h / 2, cy - w);
      path.lineTo(cx - h / 2, cy + w);
    } else {
      path.moveTo(cx - h / 2, cy);
      path.lineTo(cx + h / 2, cy - w);
      path.lineTo(cx + h / 2, cy + w);
    }
    path.close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_TrianglePainter old) =>
      old.pointRight != pointRight || old.color != color;
}


// ── Accidental text helper ────────────────────────────────────────────────────

/// Renders [text] with ♭ and ♯ shown as small subscript-style symbols (~68% size,
/// bottom-aligned to the surrounding text's descent line).
Widget _accText(String text, TextStyle style, {TextAlign textAlign = TextAlign.start}) {
  final accSize = (style.fontSize ?? 16) * 0.68;
  final regex = RegExp('[♭♯]');
  final matches = regex.allMatches(text).toList();
  if (matches.isEmpty) return Text(text, style: style, textAlign: textAlign);

  final spans = <InlineSpan>[];
  int start = 0;
  for (final match in matches) {
    if (match.start > start) {
      spans.add(TextSpan(text: text.substring(start, match.start), style: style));
    }
    spans.add(WidgetSpan(
      alignment: PlaceholderAlignment.bottom,
      child: Text(
        match.group(0)!,
        style: style.copyWith(fontSize: accSize, height: 1.0),
      ),
    ));
    start = match.end;
  }
  if (start < text.length) {
    spans.add(TextSpan(text: text.substring(start), style: style));
  }
  return Text.rich(TextSpan(children: spans), textAlign: textAlign);
}

// ── Lever string count slider ─────────────────────────────────────────────────

class _LeverStringCountRow extends StatelessWidget {
  final int count;
  final ValueChanged<int> onChanged;
  final TunerThemeData theme;

  const _LeverStringCountRow({
    super.key,
    required this.count,
    required this.onChanged,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.settingsLeverStringCountLabel,
                  style: theme.sans(16, weight: FontWeight.w600,
                      color: theme.textPrimary),
                ),
              ),
              Text(
                l10n.settingsLeverStringCountValue(count),
                style: theme.sans(16, weight: FontWeight.w600,
                    color: theme.inTune),
              ),
            ],
          ),
          const SizedBox(height: 4),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: theme.inTune,
              inactiveTrackColor: theme.surfaceRim,
              thumbColor: theme.inTune,
              overlayColor: theme.inTune.withValues(alpha: 0.12),
              trackHeight: 2,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 18),
            ),
            child: Slider(
              value: count.toDouble(),
              min: 19,
              max: 40,
              divisions: 21,
              onChanged: (v) => onChanged(v.round()),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('19', style: theme.sans(11, color: theme.textSecondary)),
              Text('40', style: theme.sans(11, color: theme.textSecondary)),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Instrument row ────────────────────────────────────────────────────────────

class _InstrumentRow extends StatelessWidget {
  final String label;
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;
  final TunerThemeData theme;

  const _InstrumentRow({
    required this.label,
    this.subtitle,
    required this.selected,
    required this.onTap,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      selected: selected,
      button: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected
                      ? theme.inTune.withValues(alpha: 0.20)
                      : Colors.transparent,
                  border: Border.all(
                    color: selected ? theme.inTune : theme.surfaceRim,
                    width: 2,
                  ),
                ),
                child: selected
                    ? Center(
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: theme.inTune,
                          ),
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: theme.sans(
                        16,
                        weight: selected ? FontWeight.w600 : FontWeight.w400,
                        color: selected ? theme.textPrimary : theme.textSecondary,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      _accText(subtitle!,
                          theme.sans(14, color: theme.textSecondary)),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Theme picker ──────────────────────────────────────────────────────────────

class _ThemePickerRow extends StatelessWidget {
  final TunerThemeData currentTheme;
  final void Function(TunerThemeData) onSelect;

  const _ThemePickerRow({required this.currentTheme, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final filtered = TunerThemes.all
        .where((t) => t.brightness == currentTheme.brightness)
        .toList();
    return Row(
      children: [
        for (final t in filtered)
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: _ThemeSwatch(
              swatch: t,
              selected: t.id == currentTheme.id,
              accentColor: currentTheme.inTune,
              labelStyle: currentTheme.sans(13),
              onTap: () => onSelect(t),
            ),
          ),
      ],
    );
  }
}

class _ThemeSwatch extends StatelessWidget {
  final TunerThemeData swatch;
  final bool selected;
  final Color accentColor;
  final TextStyle labelStyle;
  final VoidCallback onTap;

  const _ThemeSwatch({
    required this.swatch,
    required this.selected,
    required this.accentColor,
    required this.labelStyle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final animDuration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 200);

    return Semantics(
      label: swatch.displayName,
      selected: selected,
      button: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          children: [
            AnimatedContainer(
              duration: animDuration,
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: swatch.bg,
                border: Border.all(
                  color: selected
                      ? accentColor
                      : swatch.surfaceRim.withValues(alpha: 0.6),
                  width: selected ? 2.5 : 1.5,
                ),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: accentColor.withValues(alpha: 0.35),
                          blurRadius: 10,
                          spreadRadius: 1,
                        )
                      ]
                    : null,
              ),
              child: selected
                  ? Center(
                      child: Icon(Icons.check_rounded,
                          size: 22, color: accentColor),
                    )
                  : Center(
                      child: Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: swatch.inTune,
                        ),
                      ),
                    ),
            ),
            const SizedBox(height: 6),
            Text(
              swatch.displayName,
              style: labelStyle.copyWith(
                color: selected
                    ? accentColor
                    : labelStyle.color?.withValues(alpha: 0.6),
                fontWeight:
                    selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Language data ─────────────────────────────────────────────────────────────

const _languages = [
  MapEntry(Locale('en'), 'English'),
  MapEntry(Locale('zh', 'TW'), '繁體中文'),
  MapEntry(Locale('de'), 'Deutsch'),
  MapEntry(Locale('fr'), 'Français'),
  MapEntry(Locale('it'), 'Italiano'),
];

// ── Section header ────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String label;
  final IconData icon;
  final TunerThemeData theme;

  const _SectionHeader({
    required this.label,
    required this.icon,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: theme.textSecondary),
        const SizedBox(width: 5),
        Text(label,
            style: theme.sans(14,
                weight: FontWeight.w600, color: theme.textSecondary)),
      ],
    );
  }
}

// ── Language dropdown ─────────────────────────────────────────────────────────

class _LanguageDropdownRow extends StatelessWidget {
  final List<MapEntry<Locale, String>> languages;
  final Locale currentLocale;
  final ValueChanged<Locale> onSelect;
  final TunerThemeData theme;

  const _LanguageDropdownRow({
    required this.languages,
    required this.currentLocale,
    required this.onSelect,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final current = languages.firstWhere(
      (e) =>
          e.key.languageCode == currentLocale.languageCode &&
          (e.key.countryCode ?? '') == (currentLocale.countryCode ?? ''),
      orElse: () => languages.first,
    );

    return Theme(
      data: Theme.of(context).copyWith(
        popupMenuTheme: PopupMenuThemeData(
          color: theme.surfaceHi,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
          textStyle: theme.sans(15, color: theme.textPrimary),
          elevation: 4,
        ),
      ),
      child: PopupMenuButton<Locale>(
        onSelected: onSelect,
        offset: const Offset(0, 8),
        itemBuilder: (_) => [
          for (final lang in languages)
            PopupMenuItem<Locale>(
              value: lang.key,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
              child: Row(
                children: [
                  Text(
                    lang.value,
                    style: theme.sans(
                      15,
                      weight: lang.key.languageCode == currentLocale.languageCode
                          ? FontWeight.w600
                          : FontWeight.w400,
                      color: lang.key.languageCode == currentLocale.languageCode
                          ? theme.inTune
                          : theme.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  if (lang.key.languageCode == currentLocale.languageCode &&
                      (lang.key.countryCode ?? '') ==
                          (currentLocale.countryCode ?? ''))
                    Icon(Icons.check_rounded, size: 16, color: theme.inTune),
                ],
              ),
            ),
        ],
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              Text(current.value,
                  style: theme.sans(16, weight: FontWeight.w600)),
              const SizedBox(width: 4),
              Icon(Icons.expand_more_rounded,
                  size: 18, color: theme.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}
