import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../models/harp_type.dart';
import '../providers/tuner_provider.dart';
import '../theme/app_theme.dart';
import '../theme/theme_provider.dart';

enum SettingsSection { instrument, a4, stringCount }

class SettingsDisplay extends ConsumerWidget {
  final ValueChanged<SettingsSection> onTap;

  const SettingsDisplay({super.key, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final tuner = ref.watch(tunerProvider);
    final theme = ref.watch(tunerThemeProvider);

    final String instrumentValue;
    switch (tuner.selectedHarp) {
      case HarpType.leverHarp:
        instrumentValue = l10n.settingsDisplayHarpLever;
        break;
      case HarpType.pedalHarp:
        instrumentValue = l10n.settingsDisplayHarpPedal;
        break;
      case null:
        instrumentValue = l10n.settingsInstrumentNone;
        break;
    }

    final showStrings = tuner.selectedHarp == HarpType.leverHarp;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
      child: Row(
        children: [
          Expanded(
            child: _SettingsDisplayCard(
              label: l10n.settingsDisplayLabelInstrument,
              value: instrumentValue,
              onTap: () => onTap(SettingsSection.instrument),
              theme: theme,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _SettingsDisplayCard(
              label: l10n.settingsDisplayLabelA4,
              value: '${tuner.a4Hz} Hz',
              onTap: () => onTap(SettingsSection.a4),
              theme: theme,
            ),
          ),
          if (showStrings) ...[
            const SizedBox(width: 6),
            Expanded(
              child: _SettingsDisplayCard(
                label: l10n.settingsDisplayLabelStrings,
                value: tuner.leverStringCount.toString(),
                onTap: () => onTap(SettingsSection.stringCount),
                theme: theme,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SettingsDisplayCard extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onTap;
  final TunerThemeData theme;

  const _SettingsDisplayCard({
    required this.label,
    required this.value,
    required this.onTap,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$label, $value',
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          boxShadow: const [
            BoxShadow(
              color: Color(0x14000000),
              offset: Offset(0, 1),
              blurRadius: 2,
            ),
            BoxShadow(
              color: Color(0x1A000000),
              offset: Offset(0, 4),
              blurRadius: 10,
            ),
            BoxShadow(
              color: Color(0x0F000000),
              offset: Offset(0, 8),
              blurRadius: 20,
            ),
          ],
        ),
        child: Material(
          color: theme.surface,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    label,
                    style: theme
                        .sans(10, weight: FontWeight.w600, color: theme.textSecondary)
                        .copyWith(letterSpacing: 0.8),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: theme.sans(13, weight: FontWeight.w500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
