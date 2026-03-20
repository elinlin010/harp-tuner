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
import '../widgets/pitch_light_indicator.dart';
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

  HarpStringModel? _closestString(
      List<HarpStringModel> strings, double? hz, int a4Hz) {
    if (hz == null) return null;
    HarpStringModel? best;
    double bestCents = 50.0;
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

  void _showSettings(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const _SettingsSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tuner = ref.watch(tunerProvider);
    final theme = ref.watch(tunerThemeProvider);
    // Always show octave number (e.g. "A4" not "A")
    final noteName = tuner.closestNoteName;

    final harpStrings = tuner.selectedHarp != null
        ? HarpPresets.stringsFor(tuner.selectedHarp!)
        : <HarpStringModel>[];
    final activeString =
        _closestString(harpStrings, tuner.detectedHz, tuner.a4Hz);

    return Scaffold(
      backgroundColor: theme.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Top-right settings icon ────────────────────────────────────
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: Material(
                  color: theme.surfaceHi,
                  borderRadius: BorderRadius.circular(20),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () => _showSettings(context),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 14),
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
              ),

              // ── Gauge + readout ────────────────────────────────────────────
              Expanded(
                child: TunerGauge(
                  cents: tuner.cents,
                  noteName: noteName,
                  isListening: tuner.isListening,
                  theme: theme,
                ),
              ),

              // ── Pitch light indicator ──────────────────────────────────────
              const SizedBox(height: 20),
              PitchLightIndicator(
                cents: tuner.cents,
                isListening: tuner.isListening,
                theme: theme,
              ),
              const SizedBox(height: 16),

              // ── String visualizer ─────────────────────────────────────────
              if (tuner.selectedHarp != null) ...[
                const SizedBox(height: 4),
                StringVisualizer(
                  strings: harpStrings,
                  activeString: activeString,
                  theme: theme,
                ),
                const SizedBox(height: 4),
              ],

              // ── Listen button ──────────────────────────────────────────────
              _ListenButton(
                isListening: tuner.isListening,
                controller: _listenBtnCtrl,
                onTap: () =>
                    ref.read(tunerProvider.notifier).toggleListening(),
                theme: theme,
              ),

              // ── Permission denied banner ───────────────────────────────────
              if (tuner.permissionDenied) ...[
                const SizedBox(height: 12),
                _PermissionBanner(theme: theme),
              ],

              // ── Mic hardware/API error banner ──────────────────────────────
              if (tuner.micError != null) ...[
                const SizedBox(height: 12),
                _MicErrorBanner(
                  message: tuner.micError!,
                  onDismiss: () =>
                      ref.read(tunerProvider.notifier).clearMicError(),
                  theme: theme,
                ),
              ],

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Harp type localization helpers ────────────────────────────────────────────

String _harpName(HarpType type, AppLocalizations l10n) {
  switch (type) {
    case HarpType.lapHarp:   return l10n.harpTypeLapHarp;
    case HarpType.leverHarp: return l10n.harpTypeLeverHarp;
    case HarpType.pedalHarp: return l10n.harpTypePedalHarp;
  }
}

String _harpSubtitle(HarpType type, AppLocalizations l10n) {
  switch (type) {
    case HarpType.lapHarp:   return l10n.harpTypeLapHarpSubtitle;
    case HarpType.leverHarp: return l10n.harpTypeLeverHarpSubtitle;
    case HarpType.pedalHarp: return l10n.harpTypePedalHarpSubtitle;
  }
}

// ── Settings bottom sheet ─────────────────────────────────────────────────────

class _SettingsSheet extends ConsumerWidget {
  const _SettingsSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
      padding: EdgeInsets.fromLTRB(24, 12, 24, 24 + bottomPad),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.88,
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

          Text(l10n.settingsTitle, style: theme.sans(22, weight: FontWeight.w600)),
          const SizedBox(height: 24),

          // ── Instrument ────────────────────────────────────────────────────
          Text(l10n.settingsInstrumentLabel,
              style: theme.label(13, color: theme.textSecondary)),
          const SizedBox(height: 4),
          _InstrumentRow(
            label: l10n.settingsInstrumentNone,
            selected: tuner.selectedHarp == null,
            onTap: () =>
                ref.read(tunerProvider.notifier).setSelectedHarp(null),
            theme: theme,
          ),
          for (final type in HarpType.values)
            _InstrumentRow(
              label: _harpName(type, l10n),
              subtitle: _harpSubtitle(type, l10n),
              selected: tuner.selectedHarp == type,
              onTap: () =>
                  ref.read(tunerProvider.notifier).setSelectedHarp(type),
              theme: theme,
            ),

          const SizedBox(height: 20),
          Divider(color: theme.surfaceRim, height: 1),
          const SizedBox(height: 20),

          // ── Note display + A4 calibration ────────────────────────────────
          Text(l10n.settingsNoteDisplayLabel,
              style: theme.label(13, color: theme.textSecondary)),
          const SizedBox(height: 12),
          _SheetSwitchRow(
            label: l10n.settingsAlwaysShowFlatsToggle,
            subtitle: l10n.settingsAlwaysShowFlatsHint,
            value: tuner.preferFlats,
            onToggle: () => ref.read(tunerProvider.notifier).togglePreferFlats(),
            theme: theme,
            animDuration: animDuration,
          ),
          _A4StepperRow(
            a4Hz: tuner.a4Hz,
            onDecrement: () =>
                ref.read(tunerProvider.notifier).setA4Hz(tuner.a4Hz - 1),
            onIncrement: () =>
                ref.read(tunerProvider.notifier).setA4Hz(tuner.a4Hz + 1),
            theme: theme,
          ),

          const SizedBox(height: 20),
          Divider(color: theme.surfaceRim, height: 1),
          const SizedBox(height: 20),

          // ── Theme picker ──────────────────────────────────────────────────
          Text(l10n.settingsThemeLabel,
              style: theme.label(13, color: theme.textSecondary)),
          const SizedBox(height: 16),
          _ThemePickerRow(
            currentTheme: theme,
            onSelect: (t) =>
                ref.read(tunerThemeProvider.notifier).setTheme(t),
          ),

          const SizedBox(height: 20),
          Divider(color: theme.surfaceRim, height: 1),
          const SizedBox(height: 20),

          // ── Language ──────────────────────────────────────────────────────
          Text(l10n.settingsLanguageLabel,
              style: theme.label(13, color: theme.textSecondary)),
          const SizedBox(height: 4),
          for (final lang in _languages)
            _LanguageRow(
              nativeName: lang.value,
              locale: lang.key,
              selected: currentLocale.languageCode == lang.key.languageCode &&
                  (currentLocale.countryCode ?? '') ==
                      (lang.key.countryCode ?? ''),
              onTap: () =>
                  ref.read(localeProvider.notifier).setLocale(lang.key),
              theme: theme,
            ),
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

  const _SheetSwitchRow({
    required this.label,
    this.subtitle,
    required this.value,
    required this.onToggle,
    required this.theme,
    required this.animDuration,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      toggled: value,
      child: GestureDetector(
        onTap: onToggle,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 13),
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
                      Text(subtitle!,
                          style: theme.sans(16, color: theme.textSecondary)),
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
            padding: const EdgeInsets.symmetric(vertical: 20),
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
    return GestureDetector(
      onTap: onDismiss,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: BoxDecoration(
          color: Colors.amber.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: Colors.amber.withValues(alpha: 0.40), width: 1),
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
                      size: 20, color: Colors.amber.shade800),
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
    );
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
  final TunerThemeData theme;

  const _A4StepperRow({
    required this.a4Hz,
    required this.onDecrement,
    required this.onIncrement,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final atMin = a4Hz <= 430;
    final atMax = a4Hz >= 450;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.settingsA4CalibLabel,
                  style: theme.sans(16,
                      weight: FontWeight.w600, color: theme.textPrimary),
                ),
                const SizedBox(height: 2),
                Text(
                  l10n.settingsA4CalibStandard,
                  style: theme.sans(16, color: theme.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
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
                  style: theme.sans(16, weight: FontWeight.w600),
                ),
              ),
              _StepBtn(
                pointRight: true,
                onTap: atMax ? null : onIncrement,
                theme: theme,
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
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 48,
        height: 48,
        child: CustomPaint(
          painter: _TrianglePainter(
            pointRight: pointRight,
            color: enabled ? theme.textPrimary : theme.textDim,
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
          padding: const EdgeInsets.symmetric(vertical: 13),
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
                      Text(
                        subtitle!,
                        style: theme.sans(14, color: theme.textSecondary),
                      ),
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
    return Row(
      children: [
        for (final t in TunerThemes.all)
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: _ThemeSwatch(
              swatch: t,
              selected: t.id == currentTheme.id,
              accentColor: currentTheme.inTune,
              labelStyle: currentTheme.sans(11),
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

// ── Language row ──────────────────────────────────────────────────────────────

class _LanguageRow extends StatelessWidget {
  final String nativeName;
  final Locale locale;
  final bool selected;
  final VoidCallback onTap;
  final TunerThemeData theme;

  const _LanguageRow({
    required this.nativeName,
    required this.locale,
    required this.selected,
    required this.onTap,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            Text(
              nativeName,
              style: theme.sans(
                16,
                weight: selected ? FontWeight.w600 : FontWeight.w400,
                color: selected ? theme.textPrimary : theme.textSecondary,
              ),
            ),
            const Spacer(),
            if (selected)
              Icon(Icons.check_rounded, size: 20, color: theme.inTune),
          ],
        ),
      ),
    );
  }
}
