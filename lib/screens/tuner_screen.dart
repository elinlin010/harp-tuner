import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../providers/tuner_provider.dart';
import '../theme/app_theme.dart';
import '../theme/theme_provider.dart';
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
  void dispose() {
    _listenBtnCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tuner = ref.watch(tunerProvider);
    final theme = ref.watch(tunerThemeProvider);

    return Scaffold(
      backgroundColor: theme.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),

              // ── App title ─────────────────────────────────────────────────
              Center(
                child: Text(
                  'TUNER',
                  style: theme.label(14, color: theme.textDim),
                ),
              ),

              // ── Gauge + readout — fills remaining space ────────────────────
              Expanded(
                child: TunerGauge(
                  cents: tuner.cents,
                  noteName: tuner.closestNoteName,
                  detectedHz: tuner.detectedHz,
                  isListening: tuner.isListening,
                  theme: theme,
                ),
              ),

              // ── Flat/Sharp toggle ─────────────────────────────────────────
              Center(
                child: _FlatSharpToggle(
                  preferFlats: tuner.preferFlats,
                  onToggle: () =>
                      ref.read(tunerProvider.notifier).togglePreferFlats(),
                  theme: theme,
                ),
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

              const SizedBox(height: 36),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Flat/Sharp toggle ─────────────────────────────────────────────────────────

class _FlatSharpToggle extends StatelessWidget {
  final bool preferFlats;
  final VoidCallback onToggle;
  final TunerThemeData theme;

  const _FlatSharpToggle({
    required this.preferFlats,
    required this.onToggle,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onToggle,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: theme.surfaceHi,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: theme.surfaceRim, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ToggleTab(
              label: '♭  Flats',
              active: preferFlats,
              onTap: onToggle,
              theme: theme,
            ),
            _ToggleTab(
              label: '♯  Sharps',
              active: !preferFlats,
              onTap: onToggle,
              theme: theme,
            ),
          ],
        ),
      ),
    );
  }
}

class _ToggleTab extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  final TunerThemeData theme;

  const _ToggleTab({
    required this.label,
    required this.active,
    required this.onTap,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 11),
        decoration: BoxDecoration(
          color: active ? theme.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
          border: active
              ? Border.all(color: theme.surfaceRim, width: 1.0)
              : null,
          boxShadow: active
              ? [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 4)]
              : null,
        ),
        child: Text(
          label,
          style: theme.sans(
            16,
            weight: active ? FontWeight.w600 : FontWeight.w400,
            color: active ? theme.textPrimary : theme.textDim,
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
                style: theme.sans(15, color: Colors.amber.shade300),
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
            style: theme.sans(15, color: theme.sharp.withValues(alpha: 0.85)),
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
