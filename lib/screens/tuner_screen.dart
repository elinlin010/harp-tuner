import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/harp_string_model.dart';
import '../models/harp_type.dart';
import '../providers/tuner_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/string_tile.dart';
import '../widgets/tuner_gauge.dart';

class TunerScreen extends ConsumerStatefulWidget {
  const TunerScreen({super.key});

  @override
  ConsumerState<TunerScreen> createState() => _TunerScreenState();
}

class _TunerScreenState extends ConsumerState<TunerScreen>
    with SingleTickerProviderStateMixin {
  late ScrollController _scrollCtrl;
  late AnimationController _listenBtnCtrl;

  @override
  void initState() {
    super.initState();
    _scrollCtrl = ScrollController();
    _listenBtnCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    _listenBtnCtrl.dispose();
    super.dispose();
  }

  void _mockDetect(List<HarpStringModel> strings) {
    if (strings.isEmpty) return;
    final rng = math.Random();
    final s = strings[rng.nextInt(strings.length)];
    final cents = rng.nextDouble() * 60 - 30;
    ref.read(tunerProvider.notifier).mockReading(
      cents: cents,
      hz: s.frequency * math.pow(2, cents / 1200).toDouble(),
      string: s,
    );
  }

  @override
  Widget build(BuildContext context) {
    final harpType = ref.watch(selectedHarpProvider);
    final strings = ref.watch(harpStringsProvider);
    final mode = ref.watch(tunerModeProvider);
    final tuner = ref.watch(tunerProvider);
    final selectedIdx = ref.watch(selectedStringIndexProvider);
    final selectedStr = ref.watch(selectedStringProvider);

    final gaugeString =
        mode == TunerMode.auto ? tuner.closestString : selectedStr;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Column(
        children: [
          // ── Top bar (includes mode toggle) ────────────────────────────────
          _TopBar(
            harpType: harpType?.displayName ?? '',
            mode: mode,
            onModeChanged: (m) {
              ref.read(tunerModeProvider.notifier).state = m;
              ref.read(selectedStringIndexProvider.notifier).state = null;
            },
          ),

          // ── Gauge card ────────────────────────────────────────────────────
          _GaugeCard(
            mode: mode,
            tuner: tuner,
            gaugeString: gaugeString,
            listenBtnCtrl: _listenBtnCtrl,
            onToggleListen: () {
              ref.read(tunerProvider.notifier).toggleListening();
              if (!tuner.isListening) _mockDetect(strings);
            },
            onMockDetect: () => _mockDetect(strings),
          ),

          // ── Strings header ────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
            child: Row(
              children: [
                Text('STRINGS',
                    style: AppTextStyles.label(11,
                        color: AppColors.textSecondary)),
                const Spacer(),
                Text('${strings.length} strings',
                    style: AppTextStyles.sans(12, color: AppColors.textDim)),
              ],
            ),
          ),

          // ── String list ───────────────────────────────────────────────────
          Expanded(
            child: ListView.builder(
              controller: _scrollCtrl,
              padding: const EdgeInsets.only(bottom: 32),
              itemCount: strings.length,
              itemBuilder: (context, i) {
                final dispIdx = strings.length - 1 - i;
                final s = strings[dispIdx];
                final isSelected =
                    mode == TunerMode.manual && selectedIdx == dispIdx;
                final isClosest = mode == TunerMode.auto &&
                    tuner.closestString?.label == s.label;
                return StringTile(
                  key: ValueKey(s.label),
                  string: s,
                  isSelected: isSelected,
                  isClosest: isClosest,
                  onTap: () {
                    ref.read(selectedStringIndexProvider.notifier).state =
                        (selectedIdx == dispIdx) ? null : dispIdx;
                  },
                  onPlayTone: () =>
                      ref.read(tunerProvider.notifier).playTone(s),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── Top bar ───────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  final String harpType;
  final TunerMode mode;
  final ValueChanged<TunerMode> onModeChanged;

  const _TopBar({
    required this.harpType,
    required this.mode,
    required this.onModeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: Row(
          children: [
            // Back button — 44px touch target
            GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              behavior: HitTestBehavior.opaque,
              child: SizedBox(
                width: 44,
                height: 44,
                child: Center(
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.surfaceRim),
                      color: AppColors.surface,
                    ),
                    child: const Icon(Icons.chevron_left_rounded,
                        color: AppColors.textSecondary, size: 22),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Title
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(harpType,
                      style: AppTextStyles.sans(16, weight: FontWeight.w700)),
                  Text('TUNER',
                      style: AppTextStyles.label(9, color: AppColors.gold)),
                ],
              ),
            ),
            // Mode toggle — inline in top bar
            _ModeToggle(mode: mode, onChanged: onModeChanged),
          ],
        ),
      ),
    );
  }
}

class _ModeToggle extends StatelessWidget {
  final TunerMode mode;
  final ValueChanged<TunerMode> onChanged;

  const _ModeToggle({required this.mode, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.surfaceRim, width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ModeTab(
              label: 'AUTO',
              active: mode == TunerMode.auto,
              onTap: () => onChanged(TunerMode.auto)),
          _ModeTab(
              label: 'MANUAL',
              active: mode == TunerMode.manual,
              onTap: () => onChanged(TunerMode.manual)),
        ],
      ),
    );
  }
}

class _ModeTab extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _ModeTab(
      {required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: active
              ? AppColors.gold.withValues(alpha: 0.18)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(17),
          border: active
              ? Border.all(
                  color: AppColors.gold.withValues(alpha: 0.45), width: 0.5)
              : null,
        ),
        child: Text(
          label,
          style: AppTextStyles.label(11,
              color: active ? AppColors.goldBright : AppColors.textDim),
        ),
      ),
    );
  }
}

// ── Gauge card ────────────────────────────────────────────────────────────────

class _GaugeCard extends StatelessWidget {
  final TunerMode mode;
  final TunerState tuner;
  final HarpStringModel? gaugeString;
  final AnimationController listenBtnCtrl;
  final VoidCallback onToggleListen;
  final VoidCallback onMockDetect;

  const _GaugeCard({
    required this.mode,
    required this.tuner,
    required this.gaugeString,
    required this.listenBtnCtrl,
    required this.onToggleListen,
    required this.onMockDetect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TunerGauge(
            cents: tuner.cents,
            noteName: gaugeString?.label,
            detectedHz: tuner.detectedHz,
            isListening: tuner.isListening,
          ),
          const SizedBox(height: 14),
          // Action row
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (mode == TunerMode.auto)
                _ListenButton(
                  isListening: tuner.isListening,
                  controller: listenBtnCtrl,
                  onTap: onToggleListen,
                )
              else
                Text(
                  'Tap a string below to tune it',
                  style: AppTextStyles.sans(13,
                      color: AppColors.textSecondary),
                ),
            ],
          ),
          // Debug simulate button — tiny, unobtrusive
          const SizedBox(height: 8),
          GestureDetector(
            onTap: onMockDetect,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                'simulate',
                style: AppTextStyles.sans(11, color: AppColors.textDim),
              ),
            ),
          ),
        ],
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
            padding:
                const EdgeInsets.symmetric(horizontal: 24, vertical: 11),
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
                  style: AppTextStyles.sans(14,
                      weight: FontWeight.w600,
                      color: isListening
                          ? AppColors.goldBright
                          : AppColors.textSecondary),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
