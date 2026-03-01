import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class TunerGauge extends StatefulWidget {
  final double? cents;
  final String? noteName;
  final double? detectedHz;
  final bool isListening;

  const TunerGauge({
    super.key,
    this.cents,
    this.noteName,
    this.detectedHz,
    required this.isListening,
  });

  @override
  State<TunerGauge> createState() => _TunerGaugeState();
}

class _TunerGaugeState extends State<TunerGauge>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  Color get _stateColor {
    final c = widget.cents;
    if (c == null) return AppColors.textDim;
    if (c.abs() <= 5) return AppColors.inTune;
    if (c > 0) return AppColors.sharp;
    return AppColors.flat;
  }

  String get _tuneWord {
    final c = widget.cents;
    if (c == null) return '';
    if (c.abs() <= 5) return 'IN TUNE';
    if (c > 0) return 'SHARP';
    return 'FLAT';
  }

  @override
  Widget build(BuildContext context) {
    final hasSignal = widget.cents != null;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Arc with scale labels ───────────────────────────────────────────
        SizedBox(
          height: 148,
          child: Stack(
            children: [
              // Canvas
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: _pulseCtrl,
                  builder: (ctx, child) => CustomPaint(
                    painter: _ArcPainter(
                      cents: widget.cents,
                      stateColor: _stateColor,
                      isListening: widget.isListening,
                      pulse: _pulseCtrl.value,
                    ),
                  ),
                ),
              ),
              // Scale labels
              Positioned(
                bottom: 0,
                left: 14,
                child: _ScaleLabel('−50'),
              ),
              Positioned(
                top: 4,
                left: 0,
                right: 0,
                child: Center(child: _ScaleLabel('0')),
              ),
              Positioned(
                bottom: 0,
                right: 14,
                child: _ScaleLabel('+50'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // ── Readout ─────────────────────────────────────────────────────────
        if (!hasSignal)
          _IdleReadout(isListening: widget.isListening, pulse: _pulseCtrl)
        else
          _SignalReadout(
            cents: widget.cents!,
            noteName: widget.noteName ?? '—',
            detectedHz: widget.detectedHz,
            stateColor: _stateColor,
            tuneWord: _tuneWord,
          ),
      ],
    );
  }
}

// ── Scale label ───────────────────────────────────────────────────────────────

class _ScaleLabel extends StatelessWidget {
  final String text;
  const _ScaleLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: AppTextStyles.sans(10,
          weight: FontWeight.w500, color: AppColors.textDim),
    );
  }
}

// ── Arc painter ───────────────────────────────────────────────────────────────

class _ArcPainter extends CustomPainter {
  final double? cents;
  final Color stateColor;
  final bool isListening;
  final double pulse;

  _ArcPainter({
    required this.cents,
    required this.stateColor,
    required this.isListening,
    required this.pulse,
  });

  static const _startAngle = pi;
  static const _sweep = pi;

  double _centsToAngle(double c) =>
      _startAngle + _sweep * ((c + 50) / 100);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height;
    final r = size.height - 16;
    final arcRect = Rect.fromCircle(center: Offset(cx, cy), radius: r);

    // ── Track ─────────────────────────────────────────────────────────────
    canvas.drawArc(
      arcRect,
      _startAngle,
      _sweep,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..color = AppColors.surfaceRim,
    );

    // ── In-tune zone ───────────────────────────────────────────────────────
    final zoneStart = _centsToAngle(-5);
    final zoneSweep = _sweep * (10 / 100);
    canvas.drawArc(
      arcRect,
      zoneStart,
      zoneSweep,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7
        ..strokeCap = StrokeCap.round
        ..color = AppColors.inTune.withValues(alpha: 0.35),
    );

    // ── Ticks ──────────────────────────────────────────────────────────────
    for (int c = -50; c <= 50; c += 5) {
      final isMajor = c % 10 == 0;
      final angle = _centsToAngle(c.toDouble());
      final outer = r - 2;
      final inner = r - (isMajor ? 18 : 10);
      canvas.drawLine(
        Offset(cx + inner * cos(angle), cy + inner * sin(angle)),
        Offset(cx + outer * cos(angle), cy + outer * sin(angle)),
        Paint()
          ..color = isMajor
              ? AppColors.textDim
              : AppColors.surfaceRim.withValues(alpha: 0.8)
          ..strokeWidth = isMajor ? 1.5 : 1.0
          ..style = PaintingStyle.stroke,
      );
    }

    // ── Needle ─────────────────────────────────────────────────────────────
    final hasSignal = cents != null;
    final angle = hasSignal ? _centsToAngle(cents!) : _centsToAngle(0);
    final needleLen = r - 14;
    final tipX = cx + needleLen * cos(angle);
    final tipY = cy + needleLen * sin(angle);

    if (hasSignal) {
      // Glow
      canvas.drawLine(
        Offset(cx, cy), Offset(tipX, tipY),
        Paint()
          ..color = stateColor.withValues(alpha: 0.18 + pulse * 0.14)
          ..strokeWidth = 18
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke,
      );
      // Core
      canvas.drawLine(
        Offset(cx, cy), Offset(tipX, tipY),
        Paint()
          ..color = stateColor
          ..strokeWidth = 3.5
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke,
      );
    }

    // Pivot dot
    canvas.drawCircle(
      Offset(cx, cy),
      hasSignal ? 6 : 4,
      Paint()
        ..color = hasSignal ? stateColor : AppColors.textDim.withValues(alpha: 0.4)
        ..style = PaintingStyle.fill,
    );

    // Idle pulse
    if (isListening && !hasSignal) {
      canvas.drawCircle(
        Offset(cx, cy),
        12 + pulse * 8,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = AppColors.gold.withValues(alpha: 0.10 + pulse * 0.20),
      );
    }
  }

  @override
  bool shouldRepaint(_ArcPainter old) =>
      old.cents != cents ||
      old.stateColor != stateColor ||
      old.isListening != isListening ||
      old.pulse != pulse;
}

// ── Idle readout ──────────────────────────────────────────────────────────────

class _IdleReadout extends StatelessWidget {
  final bool isListening;
  final Animation<double> pulse;

  const _IdleReadout({required this.isListening, required this.pulse});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulse,
      builder: (ctx, child) => Opacity(
        opacity: isListening ? (0.6 + pulse.value * 0.4) : 1.0,
        child: child,
      ),
      child: Text(
        isListening ? 'Listening for a string…' : 'Play a string to tune',
        style: AppTextStyles.sans(15,
            weight: FontWeight.w500, color: AppColors.textSecondary),
        textAlign: TextAlign.center,
      ),
    );
  }
}

// ── Signal readout ────────────────────────────────────────────────────────────

class _SignalReadout extends StatelessWidget {
  final double cents;
  final String noteName;
  final double? detectedHz;
  final Color stateColor;
  final String tuneWord;

  const _SignalReadout({
    required this.cents,
    required this.noteName,
    required this.detectedHz,
    required this.stateColor,
    required this.tuneWord,
  });

  @override
  Widget build(BuildContext context) {
    final centsStr =
        cents >= 0 ? '+${cents.toStringAsFixed(1)}' : cents.toStringAsFixed(1);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        // Note name
        Text(
          noteName,
          style: AppTextStyles.sans(52, weight: FontWeight.w800)
              .copyWith(color: AppColors.textPrimary, height: 1),
        ),
        const SizedBox(width: 14),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Cents — large, colored
            Text(
              '$centsStr¢',
              style: AppTextStyles.mono(24, weight: FontWeight.w700,
                  color: stateColor),
            ),
            // Hz + badge
            Row(
              children: [
                if (detectedHz != null)
                  Text(
                    '${detectedHz!.toStringAsFixed(1)} Hz',
                    style: AppTextStyles.sans(12,
                        color: AppColors.textSecondary),
                  ),
                if (tuneWord.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: stateColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Text(
                      tuneWord,
                      style: AppTextStyles.label(9, color: stateColor),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ],
    );
  }
}
