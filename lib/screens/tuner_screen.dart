import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../providers/tuner_provider.dart';
import '../theme/app_theme.dart';
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

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),

              // ── App title ─────────────────────────────────────────────────
              Center(
                child: Text(
                  'TUNER',
                  style: AppTextStyles.label(13, color: AppColors.gold),
                ),
              ),

              const SizedBox(height: 20),

              // ── Gauge card ────────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
                decoration: BoxDecoration(
                  color: AppColors.surfaceHi,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.surfaceRim, width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.45),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: TunerGauge(
                  cents: tuner.cents,
                  noteName: tuner.closestNoteName,
                  detectedHz: tuner.detectedHz,
                  isListening: tuner.isListening,
                ),
              ),

              const SizedBox(height: 28),

              // ── Flat/Sharp toggle ─────────────────────────────────────────
              Center(
                child: _FlatSharpToggle(
                  preferFlats: tuner.preferFlats,
                  onToggle: () =>
                      ref.read(tunerProvider.notifier).togglePreferFlats(),
                ),
              ),

              const SizedBox(height: 24),

              // ── Listen button ─────────────────────────────────────────────
              Center(
                child: _ListenButton(
                  isListening: tuner.isListening,
                  controller: _listenBtnCtrl,
                  onTap: () =>
                      ref.read(tunerProvider.notifier).toggleListening(),
                ),
              ),

              // ── Permission denied banner ───────────────────────────────────
              if (tuner.permissionDenied) ...[
                const SizedBox(height: 20),
                _PermissionBanner(),
              ],

              // ── Mic hardware/API error banner ──────────────────────────────
              if (tuner.micError != null) ...[
                const SizedBox(height: 20),
                _MicErrorBanner(
                  message: tuner.micError!,
                  onDismiss: () =>
                      ref.read(tunerProvider.notifier).clearMicError(),
                ),
              ],
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

  const _FlatSharpToggle({
    required this.preferFlats,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onToggle,
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.surfaceRim, width: 0.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ToggleTab(
              label: 'b  Flats',
              active: preferFlats,
              onTap: onToggle,
            ),
            _ToggleTab(
              label: '#  Sharps',
              active: !preferFlats,
              onTap: onToggle,
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

  const _ToggleTab({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        decoration: BoxDecoration(
          color: active
              ? AppColors.gold.withValues(alpha: 0.18)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(19),
          border: active
              ? Border.all(
                  color: AppColors.gold.withValues(alpha: 0.45), width: 0.5)
              : null,
        ),
        child: Text(
          label,
          style: AppTextStyles.label(
            12,
            color: active ? AppColors.goldBright : AppColors.textDim,
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

  const _ListenButton({
    required this.isListening,
    required this.controller,
    required this.onTap,
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
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 13),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(30),
              color: isListening
                  ? AppColors.gold.withValues(alpha: 0.15)
                  : AppColors.surface,
              border: Border.all(
                color: isListening
                    ? AppColors.gold.withValues(
                        alpha: 0.45 + controller.value * 0.25)
                    : AppColors.surfaceRim,
                width: 1,
              ),
              boxShadow: isListening
                  ? [
                      BoxShadow(
                        color: AppColors.gold.withValues(
                            alpha: 0.15 + controller.value * 0.15),
                        blurRadius: 14,
                        spreadRadius: 1,
                      )
                    ]
                  : [],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isListening ? Icons.stop_rounded : Icons.mic_rounded,
                  size: 16,
                  color: isListening
                      ? AppColors.goldBright
                      : AppColors.textSecondary,
                ),
                const SizedBox(width: 8),
                Text(
                  isListening ? 'Stop' : 'Start Tuning',
                  style: AppTextStyles.sans(
                    14,
                    weight: FontWeight.w600,
                    color: isListening
                        ? AppColors.goldBright
                        : AppColors.textSecondary,
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

  const _MicErrorBanner({required this.message, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onDismiss,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: Colors.amber.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: Colors.amber.withValues(alpha: 0.40), width: 1),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.warning_amber_rounded,
                size: 15, color: Colors.amber.shade400),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Microphone unavailable: $message',
                style: AppTextStyles.sans(12,
                    color: Colors.amber.shade300),
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.close_rounded,
                size: 14, color: Colors.amber.withValues(alpha: 0.60)),
          ],
        ),
      ),
    );
  }
}

// ── Permission denied banner ──────────────────────────────────────────────────

class _PermissionBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: AppColors.sharp.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: AppColors.sharp.withValues(alpha: 0.35), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.mic_off_rounded, size: 15, color: AppColors.sharp),
              const SizedBox(width: 8),
              Text(
                'Microphone access denied',
                style: AppTextStyles.sans(13,
                    weight: FontWeight.w600, color: AppColors.sharp),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Go to Settings → Tuner → Microphone and turn it on.',
            style: AppTextStyles.sans(12,
                color: AppColors.sharp.withValues(alpha: 0.85)),
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () => openAppSettings(),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 9),
              decoration: BoxDecoration(
                color: AppColors.sharp.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: AppColors.sharp.withValues(alpha: 0.45), width: 1),
              ),
              child: Text(
                'Open Settings',
                textAlign: TextAlign.center,
                style: AppTextStyles.sans(13,
                    weight: FontWeight.w600, color: AppColors.sharp),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
