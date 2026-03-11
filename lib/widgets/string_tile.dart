import 'package:flutter/material.dart';
import '../models/harp_string_model.dart';
import '../theme/app_theme.dart';

class StringTile extends StatelessWidget {
  final HarpStringModel string;
  final bool isSelected;
  final bool isClosest;
  final VoidCallback onTap;
  final VoidCallback onPlayTone;

  const StringTile({
    super.key,
    required this.string,
    required this.isSelected,
    required this.isClosest,
    required this.onTap,
    required this.onPlayTone,
  });

  @override
  Widget build(BuildContext context) {
    final octColor = AppColors.octaveColor(string.octave);
    final active = isSelected || isClosest;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        decoration: BoxDecoration(
          color: active
              ? octColor.withValues(alpha: 0.12)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: active ? octColor.withValues(alpha: 0.55) : AppColors.surfaceRim,
            width: active ? 1.0 : 0.5,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: IntrinsicHeight(
            child: Row(
              children: [
                // ── Octave color bar ────────────────────────────────────────
                AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  width: 4,
                  color: active ? octColor : octColor.withValues(alpha: 0.28),
                ),
                // ── Content ─────────────────────────────────────────────────
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Note name + octave inline
                        Text(
                          string.note.label,
                          style: AppTextStyles.sans(26,
                              weight: FontWeight.w700,
                              color: active
                                  ? AppColors.textPrimary
                                  : AppColors.textSecondary),
                        ),
                        Text(
                          '${string.octave}',
                          style: AppTextStyles.sans(16,
                              weight: FontWeight.w500,
                              color: active
                                  ? AppColors.textSecondary
                                  : AppColors.textDim),
                        ),
                        const Spacer(),
                        // Hz — small, secondary
                        Text(
                          '${string.frequency.toStringAsFixed(1)} Hz',
                          style: AppTextStyles.sans(14,
                              color: active
                                  ? AppColors.textSecondary
                                  : AppColors.textDim),
                        ),
                        const SizedBox(width: 10),
                        // Play button — 44px touch target
                        GestureDetector(
                          onTap: onPlayTone,
                          behavior: HitTestBehavior.opaque,
                          child: SizedBox(
                            width: 44,
                            height: 44,
                            child: Center(
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 160),
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: active
                                      ? octColor.withValues(alpha: 0.22)
                                      : AppColors.surfaceHi,
                                  border: Border.all(
                                    color: active
                                        ? octColor.withValues(alpha: 0.65)
                                        : AppColors.surfaceRim,
                                    width: 1,
                                  ),
                                ),
                                child: Icon(
                                  Icons.play_arrow_rounded,
                                  size: 16,
                                  color: active ? octColor : AppColors.textDim,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
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
