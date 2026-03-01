import 'package:flutter/material.dart';
import '../providers/tuner_provider.dart';
import '../theme/app_theme.dart';

class ModeToggle extends StatelessWidget {
  final TunerMode mode;
  final ValueChanged<TunerMode> onChanged;

  const ModeToggle({super.key, required this.mode, required this.onChanged});

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
          _Tab(label: 'AUTO', active: mode == TunerMode.auto,
               onTap: () => onChanged(TunerMode.auto)),
          _Tab(label: 'MANUAL', active: mode == TunerMode.manual,
               onTap: () => onChanged(TunerMode.manual)),
        ],
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _Tab({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
        decoration: BoxDecoration(
          color: active ? AppColors.gold.withValues(alpha: 0.18) : Colors.transparent,
          borderRadius: BorderRadius.circular(17),
          border: active
              ? Border.all(color: AppColors.gold.withValues(alpha: 0.5), width: 0.5)
              : null,
        ),
        child: Text(
          label,
          style: AppTextStyles.label(12,
              color: active ? AppColors.goldBright : AppColors.textDim),
        ),
      ),
    );
  }
}
