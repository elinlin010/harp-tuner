import 'dart:math';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Fills its area with a base colour or gradient plus a near-vertical wood
/// grain, clipped to [borderRadius] (or a circle when [circle] is true).
class WoodGrainPainter extends CustomPainter {
  final Color? color;
  final Gradient? gradient;
  final bool dark;
  final BorderRadius borderRadius;
  final bool circle;

  const WoodGrainPainter({
    this.color,
    this.gradient,
    required this.dark,
    this.borderRadius = BorderRadius.zero,
    this.circle = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.save();
    if (circle) {
      canvas.clipPath(Path()..addOval(rect));
    } else if (borderRadius != BorderRadius.zero) {
      canvas.clipRRect(borderRadius.toRRect(rect));
    } else {
      canvas.clipRect(rect);
    }

    final base = Paint();
    if (gradient != null) {
      base.shader = gradient!.createShader(rect);
    } else {
      base.color = color ?? Colors.transparent;
    }
    canvas.drawRect(rect, base);

    // Each layer: stripes of `width` every `period` px, tilted `angle`° off
    // vertical. Rotating about the centre and over-drawing by the diagonal
    // keeps the tilted stripes covering every corner.
    final diag = sqrt(size.width * size.width + size.height * size.height);
    final layers = dark ? WoodMaterials.grainDark : WoodMaterials.grainLight;
    for (final (stripe, width, period, angle) in layers) {
      final paint = Paint()..color = stripe;
      canvas.save();
      canvas.translate(size.width / 2, size.height / 2);
      canvas.rotate(angle * pi / 180);
      for (double x = -diag / 2; x < diag / 2; x += period) {
        canvas.drawRect(Rect.fromLTWH(x, -diag / 2, width, diag), paint);
      }
      canvas.restore();
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(WoodGrainPainter old) =>
      old.color != color ||
      old.gradient != gradient ||
      old.dark != dark ||
      old.borderRadius != borderRadius ||
      old.circle != circle;
}

/// A wood-grain panel behind [child]. The grain sits on its own repaint
/// boundary so an animating child (the gauge needle) never re-records it.
class WoodSurface extends StatelessWidget {
  final Color? color;
  final Gradient? gradient;
  final bool dark;
  final BorderRadius borderRadius;
  final Widget? child;

  const WoodSurface({
    super.key,
    this.color,
    this.gradient,
    required this.dark,
    this.borderRadius = BorderRadius.zero,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.passthrough,
      children: [
        Positioned.fill(
          child: RepaintBoundary(
            child: CustomPaint(
              painter: WoodGrainPainter(
                color: color,
                gradient: gradient,
                dark: dark,
                borderRadius: borderRadius,
              ),
            ),
          ),
        ),
        ?child,
      ],
    );
  }
}

/// Page background for a theme: wood grain on wood themes, flat `bg` otherwise.
class ThemedPageBackground extends StatelessWidget {
  final TunerThemeData theme;
  final Widget child;

  const ThemedPageBackground({
    super.key,
    required this.theme,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final wood = theme.wood;
    if (wood == null) return child;
    return WoodSurface(
      gradient: woodPageGradient(wood),
      dark: wood.darkGrain,
      child: child,
    );
  }
}

/// The page material of a wood theme — shared by the page and its swatch.
Gradient woodPageGradient(WoodFinish wood) => LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: wood.page,
);

/// The gauge card fill of a wood theme.
Gradient woodGaugeGradient(WoodFinish wood) => wood.radialGauge
    ? RadialGradient(
        center: const Alignment(0, -0.4), // 50% / 30%
        radius: 1.2,
        colors: wood.gauge,
      )
    : LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: wood.gauge,
      );
