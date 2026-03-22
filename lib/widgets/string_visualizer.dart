import 'package:flutter/material.dart';

import '../models/harp_string_model.dart';
import '../theme/app_theme.dart';

const _kItemWidth = 52.0;

// Traditional harp string palette — same colors used on physical instruments.
// In dark themes these are used as the fill with a white rim for legibility.
const _kDarkStringC       = Color(0xFFC0280A); // deep red
const _kDarkStringF       = Color(0xFFCDCDC8); // warm off-white — F is near-black on light, near-white on dark (inverted landmark)
const _kDarkStringNatural = Color(0xFF4E6A80); // slate blue

class StringVisualizer extends StatefulWidget {
  final List<HarpStringModel> strings;
  final HarpStringModel? activeString;
  final TunerThemeData theme;

  const StringVisualizer({
    super.key,
    required this.strings,
    required this.activeString,
    required this.theme,
  });

  @override
  State<StringVisualizer> createState() => _StringVisualizerState();
}

class _StringVisualizerState extends State<StringVisualizer> {
  final _scrollCtrl = ScrollController();

  @override
  void didUpdateWidget(StringVisualizer old) {
    super.didUpdateWidget(old);
    if (widget.activeString != old.activeString &&
        widget.activeString != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToActive());
    }
  }

  void _scrollToActive() {
    if (!_scrollCtrl.hasClients) return;
    final idx =
        widget.strings.indexWhere((s) => s == widget.activeString);
    if (idx < 0) return;
    final viewport = _scrollCtrl.position.viewportDimension;
    final target = idx * _kItemWidth - viewport / 2 + _kItemWidth / 2;
    _scrollCtrl.animateTo(
      target.clamp(0.0, _scrollCtrl.position.maxScrollExtent),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  Color _stringColor(NoteName note) {
    // Dark themes: use the traditional physical-harp palette. A white rim
    // (added in _StringCell) makes the dark colors legible on dark backgrounds.
    if (widget.theme.brightness == Brightness.dark) {
      return switch (note) {
        NoteName.c => _kDarkStringC,
        NoteName.f => _kDarkStringF,
        _ => _kDarkStringNatural,
      };
    }
    return switch (note) {
      NoteName.c => widget.theme.stringC,
      NoteName.f => widget.theme.stringF,
      _ => widget.theme.stringNatural,
    };
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 88,
      child: ListView.builder(
        controller: _scrollCtrl,
        clipBehavior: Clip.none,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: widget.strings.length,
        itemExtent: _kItemWidth,
        itemBuilder: (ctx, i) {
          final s = widget.strings[i];
          final isActive = s == widget.activeString;
          return _StringCell(
            string: s,
            isActive: isActive,
            stringColor: _stringColor(s.note),
            theme: widget.theme,
          );
        },
      ),
    );
  }
}

// ── Single string cell ─────────────────────────────────────────────────────────

class _StringCell extends StatelessWidget {
  final HarpStringModel string;
  final bool isActive;
  final Color stringColor;
  final TunerThemeData theme;

  const _StringCell({
    required this.string,
    required this.isActive,
    required this.stringColor,
    required this.theme,
  });

  bool get _isDark => theme.brightness == Brightness.dark;

  // Landmark strings (C, F) stay more opaque than naturals in both modes.
  double get _inactiveAlpha {
    return switch (string.note) {
      NoteName.c || NoteName.f => 0.92,
      _ => 0.65,
    };
  }

  @override
  Widget build(BuildContext context) {
    final animDuration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 200);

    // Dark mode: thin white/light rim makes traditional string colors legible
    // on dark backgrounds. Glow replaces the rim when active.
    final rimBorder = (_isDark && !isActive)
        ? Border.all(
            color: Colors.white.withValues(alpha: 0.45),
            width: 1.0,
          )
        : null;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // String + glow
        SizedBox(
          width: _kItemWidth,
          height: 56,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Glow halo
              AnimatedContainer(
                duration: animDuration,
                width: isActive ? 28 : 0,
                height: isActive ? 52 : 0,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: isActive
                      ? [
                          BoxShadow(
                            color: stringColor.withValues(alpha: 0.55),
                            blurRadius: 18,
                            spreadRadius: 6,
                          ),
                          BoxShadow(
                            color: stringColor.withValues(alpha: 0.25),
                            blurRadius: 32,
                            spreadRadius: 10,
                          ),
                        ]
                      : null,
                ),
              ),
              // String line
              AnimatedContainer(
                duration: animDuration,
                width: isActive ? 4.0 : 2.5,
                height: 48,
                decoration: BoxDecoration(
                  color: isActive
                      ? stringColor
                      : stringColor.withValues(alpha: _inactiveAlpha),
                  borderRadius: BorderRadius.circular(2),
                  border: rimBorder,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 2),
        // Label (note + octave, e.g. "C4")
        // Light mode: C and F labels show a tint of their string color when
        // inactive to reinforce the landmark identity. Dark mode uses
        // textSecondary for all inactive labels (string colors are too dark
        // to show on dark backgrounds).
        AnimatedDefaultTextStyle(
          duration: animDuration,
          style: theme.sans(
            isActive ? 13 : 12,
            weight: isActive ? FontWeight.w700 : FontWeight.w400,
            color: isActive
                ? stringColor
                : (!_isDark &&
                        (string.note == NoteName.c ||
                            string.note == NoteName.f))
                    ? stringColor.withValues(alpha: 0.70)
                    : theme.textSecondary,
          ),
          child: Text(string.label, textAlign: TextAlign.center),
        ),
      ],
    );
  }
}
