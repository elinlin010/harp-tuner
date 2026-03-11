import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../providers/tuner_provider.dart';
import '../theme/app_theme.dart';
import '../theme/theme_provider.dart';
import '../widgets/tuner_gauge.dart';
import '../widgets/pitch_light_indicator.dart';

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
  void dispose() {
    _listenBtnCtrl.dispose();
    super.dispose();
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
    final noteName = tuner.showOctave
        ? tuner.closestNoteName
        : tuner.closestNoteName?.replaceAll(RegExp(r'\d+$'), '');

    return Scaffold(
      backgroundColor: theme.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),

              // ── Title bar ─────────────────────────────────────────────────
              Row(
                children: [
                  const SizedBox(width: 40), // balance the icon button
                  Expanded(
                    child: Center(
                      child: Text(
                        'TUNER',
                        style: theme.label(16, color: theme.textSecondary),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 48,
                    height: 48,
                    child: Material(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(24),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(24),
                        onTap: () => _showSettings(context),
                        child: Icon(
                          Icons.tune_rounded,
                          size: 28,
                          color: theme.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              // ── Gauge + readout, vertically centered ──────────────────────
              Expanded(
                flex: 2,
                child: Center(
                  child: TunerGauge(
                    cents: tuner.cents,
                    noteName: noteName,
                    detectedHz: tuner.detectedHz,
                    isListening: tuner.isListening,
                    theme: theme,
                  ),
                ),
              ),

              // ── Pitch light indicator ────────────────────────────────────
              const SizedBox(height: 12),
              PitchLightIndicator(
                cents: tuner.cents,
                isListening: tuner.isListening,
                theme: theme,
              ),
              const SizedBox(height: 20),

              // ── Listen button — full width, big ───────────────────────────
              _ListenButton(
                isListening: tuner.isListening,
                controller: _listenBtnCtrl,
                onTap: () =>
                    ref.read(tunerProvider.notifier).toggleListening(),
                theme: theme,
              ),

              // ── Permission denied banner ───────────────────────────────────
              if (tuner.permissionDenied) ...[
                const SizedBox(height: 16),
                _PermissionBanner(theme: theme),
              ],

              // ── Mic hardware/API error banner ──────────────────────────────
              if (tuner.micError != null) ...[
                const SizedBox(height: 16),
                _MicErrorBanner(
                  message: tuner.micError!,
                  onDismiss: () =>
                      ref.read(tunerProvider.notifier).clearMicError(),
                  theme: theme,
                ),
              ],

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Settings bottom sheet ─────────────────────────────────────────────────────

class _SettingsSheet extends ConsumerWidget {
  const _SettingsSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tuner = ref.watch(tunerProvider);
    final theme = ref.watch(tunerThemeProvider);
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

          Text('Settings', style: theme.sans(22, weight: FontWeight.w600)),
          const SizedBox(height: 24),

          // ── Note display ──────────────────────────────────────────────────
          Text('Note display',
              style: theme.label(11, color: theme.textDim)),
          const SizedBox(height: 12),
          _SheetSwitchRow(
            label: '♭  Always show flats',
            subtitle: 'e.g. B♭ instead of A♯',
            value: tuner.preferFlats,
            onToggle: () => ref.read(tunerProvider.notifier).togglePreferFlats(),
            theme: theme,
            animDuration: animDuration,
          ),

          const SizedBox(height: 20),
          Divider(color: theme.surfaceRim, height: 1),
          const SizedBox(height: 20),

          // ── Octave number ─────────────────────────────────────────────────
          Text('Octave number',
              style: theme.label(11, color: theme.textDim)),
          const SizedBox(height: 12),
          _SheetSwitchRow(
            label: 'Show octave number',
            subtitle: 'e.g. A4 instead of A',
            value: tuner.showOctave,
            onToggle: () => ref.read(tunerProvider.notifier).toggleShowOctave(),
            theme: theme,
            animDuration: animDuration,
          ),
        ],
      ),
    );
  }
}

// A row with a label + custom toggle switch on the right
class _SheetSwitchRow extends StatelessWidget {
  final String label;
  final String subtitle;
  final bool value;
  final VoidCallback onToggle;
  final TunerThemeData theme;
  final Duration animDuration;

  const _SheetSwitchRow({
    required this.label,
    required this.subtitle,
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
          padding: const EdgeInsets.symmetric(vertical: 6),
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
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: theme.sans(13, color: theme.textSecondary)),
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
                Text(
                  isListening ? 'Stop' : 'Start Tuning',
                  style: theme.sans(
                    20,
                    weight: FontWeight.w700,
                    color: isListening ? theme.inTune : theme.textSecondary,
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
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.warning_amber_rounded,
                size: 20, color: Colors.amber.shade400),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Microphone unavailable: $message',
                style: theme.sans(16, color: Colors.amber.shade300),
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.close_rounded,
                size: 18, color: Colors.amber.withValues(alpha: 0.60)),
          ],
        ),
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
                'Microphone access denied',
                style: theme.sans(16, weight: FontWeight.w700, color: theme.sharp),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Go to Settings → Tuner → Microphone and turn it on.',
            style: theme.sans(16, color: theme.sharp.withValues(alpha: 0.85)),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () => openAppSettings(),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: theme.sharp.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: theme.sharp.withValues(alpha: 0.45), width: 1),
              ),
              child: Text(
                'Open Settings',
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
