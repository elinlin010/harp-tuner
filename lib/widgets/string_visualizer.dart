import 'package:flutter/material.dart';

import '../models/harp_string_model.dart';
import '../theme/app_theme.dart';
import 'wood_surface.dart';

const _kItemWidth = 52.0;

// Wood themes: neck rail and tuning-pin geometry within the 116px row.
const _kNeckTop = 12.0;
const _kNeckHeight = 14.0;
const _kPinTop = 9.0;
const _kPinSize = 9.0;
const _kWoodStringTop = _kPinTop + _kPinSize - 3; // starts 3px under the pin
const _kWoodStringHeight = 70.0;


class StringVisualizer extends StatefulWidget {
  final List<HarpStringModel> strings;
  final HarpStringModel? activeString;

  /// Callback fired when a string cell is tapped (reference mode only).
  /// Null in auto mode — taps are disabled.
  final void Function(HarpStringModel)? onTap;

  final TunerThemeData theme;

  const StringVisualizer({
    super.key,
    required this.strings,
    required this.activeString,
    this.onTap,
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
    // Each theme (light and dark) defines its own contrast-verified string
    // palette in TunerThemeData.stringC/F/Natural. Use them directly.
    return switch (note) {
      NoteName.c => widget.theme.stringC,
      NoteName.f => widget.theme.stringF,
      _ => widget.theme.stringNatural,
    };
  }

  @override
  Widget build(BuildContext context) {
    final wood = widget.theme.wood;
    final list = ListView.builder(
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
            onTap: widget.onTap != null ? () => widget.onTap!(s) : null,
          );
        },
      );
    if (wood == null) return SizedBox(height: 116, child: list);

    // Wood themes: the strings hang from a harp neck rail that stays put while
    // the strings scroll beneath it.
    return SizedBox(
      height: 116,
      child: Stack(
        children: [
          Positioned(
            left: 0,
            right: 0,
            top: _kNeckTop,
            height: _kNeckHeight,
            child: DecoratedBox(
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: wood.neckShadow,
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: WoodSurface(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: wood.neck,
                ),
                dark: wood.neckDarkGrain,
                child: DecoratedBox(
                  position: DecorationPosition.foreground,
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(color: wood.neckEdgeTop, width: 1),
                      bottom: BorderSide(color: wood.neckEdgeBottom, width: 1),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned.fill(child: list),
        ],
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
  final VoidCallback? onTap;

  const _StringCell({
    required this.string,
    required this.isActive,
    required this.stringColor,
    required this.theme,
    this.onTap,
  });

  bool get _isDark => theme.brightness == Brightness.dark;

  // Landmark strings (C, F) stay more opaque than naturals in both modes.
  double get _inactiveAlpha {
    return switch (string.note) {
      NoteName.c || NoteName.f => 0.92,
      _ => 0.65,
    };
  }

  List<BoxShadow>? get _glow => isActive
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
      : null;

  Widget _label(Duration animDuration) => AnimatedDefaultTextStyle(
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
      );

  // Wood themes: a gold tuning pin on the neck, the string hanging from it.
  Widget _woodCell(Duration animDuration) {
    return Column(
      children: [
        SizedBox(
          width: _kItemWidth,
          height: _kWoodStringTop + _kWoodStringHeight + 3,
          child: Stack(
            alignment: Alignment.topCenter,
            children: [
              // Glow halo
              Positioned(
                top: _kWoodStringTop + (_kWoodStringHeight - 76) / 2,
                child: AnimatedContainer(
                  duration: animDuration,
                  width: isActive ? 28 : 0,
                  height: isActive ? 76 : 0,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: _glow,
                  ),
                ),
              ),
              // String line
              Positioned(
                top: _kWoodStringTop,
                child: AnimatedContainer(
                  duration: animDuration,
                  width: isActive ? 4.0 : 3.0,
                  height: _kWoodStringHeight,
                  decoration: BoxDecoration(
                    color: isActive
                        ? stringColor
                        : stringColor.withValues(alpha: _inactiveAlpha),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              // Tuning pin
              Positioned(
                top: _kPinTop,
                child: Container(
                  width: _kPinSize,
                  height: _kPinSize,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: WoodMaterials.goldGradient,
                    boxShadow: [WoodMaterials.pinShadow],
                  ),
                ),
              ),
            ],
          ),
        ),
        _label(animDuration),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final animDuration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 200);

    if (theme.isWood) return _tappable(_woodCell(animDuration));

    // Dark mode: thin white/light rim makes traditional string colors legible
    // on dark backgrounds. Glow replaces the rim when active.
    final rimBorder = (_isDark && !isActive)
        ? Border.all(
            color: Colors.white.withValues(alpha: 0.45),
            width: 1.0,
          )
        : null;

    final cell = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // String + glow
        SizedBox(
          width: _kItemWidth,
          height: 80,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Glow halo
              AnimatedContainer(
                duration: animDuration,
                width: isActive ? 28 : 0,
                height: isActive ? 76 : 0,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: _glow,
                ),
              ),
              // String line
              AnimatedContainer(
                duration: animDuration,
                width: isActive ? 4.0 : 2.5,
                height: 68,
                decoration: BoxDecoration(
                  color: isActive
                      ? stringColor
                      : stringColor.withValues(alpha: _inactiveAlpha),
                  borderRadius: BorderRadius.circular(3),
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
        _label(animDuration),
      ],
    );

    return _tappable(cell);
  }

  // In reference mode, wrap with a tap affordance.
  Widget _tappable(Widget cell) {
    if (onTap == null) return cell;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: cell,
    );
  }
}
