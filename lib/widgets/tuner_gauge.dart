import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';

class TunerGauge extends StatefulWidget {
  final double? cents;
  final String? noteName;
  final bool isListening;
  final bool isStale;
  final TunerThemeData theme;

  const TunerGauge({
    super.key,
    this.cents,
    this.noteName,
    required this.isListening,
    this.isStale = false,
    required this.theme,
  });

  @override
  State<TunerGauge> createState() => _TunerGaugeState();
}

class _TunerGaugeState extends State<TunerGauge>
    with TickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  late AnimationController _needleCtrl;

  static const _spring = SpringDescription(
    mass: 1.0,
    stiffness: 180.0,
    damping: 20.0,  // ratio ≈ 0.74 — near-critically damped, minimal overshoot
  );

  // EMA smoothing for the spring target — reduces micro-wobble from noisy pitch
  static const _kSmoothAlpha = 0.3; // 0 = frozen, 1 = no smoothing
  double? _smoothedTarget;

  // Velocity tracking for smooth spring hand-offs (no abrupt momentum reset)
  double _needleVelocity = 0.0;
  double _prevNeedleValue = 0.0;
  double _prevListenTime  = 0.0;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);

    // Wide bounds to allow spring overshoot beyond ±50 cents
    _needleCtrl = AnimationController(
      vsync: this,
      lowerBound: -100.0,
      upperBound: 100.0,
      value: 0.0,
    );
    _needleCtrl.addListener(() {
      final now = DateTime.now().microsecondsSinceEpoch / 1e6;
      final dt  = now - _prevListenTime;
      if (dt > 0.001 && dt < 0.2) {
        _needleVelocity = (_needleCtrl.value - _prevNeedleValue) / dt;
      }
      _prevNeedleValue = _needleCtrl.value;
      _prevListenTime  = now;
      setState(() {});
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final disable = MediaQuery.disableAnimationsOf(context);
    if (disable) {
      _pulseCtrl.stop();
      _pulseCtrl.value = 1.0; // full opacity when reduced motion
      _needleCtrl.stop();
      if (widget.cents != null) {
        _needleCtrl.value = widget.cents!.clamp(-50.0, 50.0);
      }
    } else if (!_pulseCtrl.isAnimating) {
      _pulseCtrl.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(TunerGauge old) {
    super.didUpdateWidget(old);
    if (MediaQuery.disableAnimationsOf(context)) {
      if (widget.cents != null) {
        _needleCtrl.value = widget.cents!.clamp(-50.0, 50.0);
      } else {
        _needleCtrl.value = 0.0;
      }
      return;
    }

    if (widget.cents != old.cents) {
      if (widget.cents != null) {
        final raw = widget.cents!.clamp(-50.0, 50.0);
        // EMA smoothing: dampens micro-wobble from noisy pitch input
        _smoothedTarget = (_smoothedTarget == null)
            ? raw
            : _kSmoothAlpha * raw + (1 - _kSmoothAlpha) * _smoothedTarget!;
        _needleCtrl.animateWith(
          SpringSimulation(_spring, _needleCtrl.value, _smoothedTarget!, _needleVelocity),
        );
      } else {
        // clearPitch fired (stop button) — spring needle back to center
        _smoothedTarget = null;
        _needleCtrl.animateWith(
          SpringSimulation(_spring, _needleCtrl.value, 0.0, _needleVelocity),
        );
      }
    }
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _needleCtrl.dispose();
    super.dispose();
  }

  Color get _stateColor {
    if (widget.cents == null) return widget.theme.textDim;
    final c = _needleCtrl.value;
    if (c.abs() <= 5) return widget.theme.inTune;
    if (c > 0) return widget.theme.sharp;
    return widget.theme.flat;
  }

  @override
  Widget build(BuildContext context) {
    final hasSignal = widget.cents != null;
    final needlePos = _needleCtrl.value;
    // Show needle whenever signal present OR it's still animating back
    final showNeedle = hasSignal || needlePos.abs() > 1.0;

    final animDur = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 300);

    return AnimatedOpacity(
      opacity: widget.isStale ? 0.40 : 1.0,
      duration: animDur,
      child: LayoutBuilder(
      builder: (ctx, constraints) {
        final maxH = constraints.maxHeight;
        final maxW = constraints.maxWidth;
        final arcH = min(maxW / 2 + 16, maxH * 0.50);

        return Column(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // ── Readout ─────────────────────────────────────────────────
              Expanded(
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: AnimatedOpacity(
                        opacity: hasSignal ? 0.0 : 1.0,
                        duration: const Duration(milliseconds: 200),
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: _IdleReadout(
                            isListening: widget.isListening,
                            pulse: _pulseCtrl,
                            theme: widget.theme,
                          ),
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: AnimatedOpacity(
                        opacity: hasSignal ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 200),
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: _SignalReadout(
                              cents: needlePos,
                              noteName: widget.noteName ?? '—',
                              stateColor: _stateColor,
                              theme: widget.theme,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // ── Arc ─────────────────────────────────────────────────────
              SizedBox(
                height: arcH,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: AnimatedBuilder(
                        animation: Listenable.merge([_pulseCtrl, _needleCtrl]),
                        builder: (ctx, child) => CustomPaint(
                          painter: _ArcPainter(
                            needlePos: needlePos,
                            showNeedle: showNeedle,
                            stateColor: _stateColor,
                            isListening: widget.isListening,
                            hasSignal: hasSignal,
                            pulse: _pulseCtrl.value,
                            theme: widget.theme,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      left: 14,
                      child: _ScaleLabel('−50', theme: widget.theme),
                    ),
                    Positioned(
                      top: 6,
                      left: 0,
                      right: 0,
                      child:
                          Center(child: _ScaleLabel('0', theme: widget.theme)),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 14,
                      child: _ScaleLabel('+50', theme: widget.theme),
                    ),
                  ],
                ),
              ),
            ],
        );
      },
    ),  // LayoutBuilder
    );  // AnimatedOpacity
  }
}

// ── Scale label ───────────────────────────────────────────────────────────────

class _ScaleLabel extends StatelessWidget {
  final String text;
  final TunerThemeData theme;

  const _ScaleLabel(this.text, {required this.theme});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: theme.sans(14, color: theme.textSecondary),
    );
  }
}

// ── Arc painter ───────────────────────────────────────────────────────────────

class _ArcPainter extends CustomPainter {
  final double needlePos;
  final bool showNeedle;
  final Color stateColor;
  final bool isListening;
  final bool hasSignal;
  final double pulse;
  final TunerThemeData theme;

  _ArcPainter({
    required this.needlePos,
    required this.showNeedle,
    required this.stateColor,
    required this.isListening,
    required this.hasSignal,
    required this.pulse,
    required this.theme,
  });

  static const _startAngle = pi;
  static const _sweep = pi;

  double _centsToAngle(double c) =>
      _startAngle + _sweep * ((c + 50) / 100);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height - 10;
    final r = size.height - 26;
    final arcRect = Rect.fromCircle(center: Offset(cx, cy), radius: r);

    // ── Track ─────────────────────────────────────────────────────────────
    canvas.drawArc(
      arcRect,
      _startAngle,
      _sweep,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..color = theme.surfaceRim,
    );

    // ── In-tune zone ──────────────────────────────────────────────────────
    final zoneStart = _centsToAngle(-5);
    final zoneSweep = _sweep * (10 / 100);
    canvas.drawArc(
      arcRect,
      zoneStart,
      zoneSweep,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round
        ..color = theme.inTune.withValues(alpha: 0.35),
    );

    // ── Ticks ─────────────────────────────────────────────────────────────
    for (int c = -50; c <= 50; c += 5) {
      final isMajor = c % 10 == 0;
      final angle = _centsToAngle(c.toDouble());
      final outer = r - 2;
      final inner = r - (isMajor ? 20.0 : 10.0);
      canvas.drawLine(
        Offset(cx + inner * cos(angle), cy + inner * sin(angle)),
        Offset(cx + outer * cos(angle), cy + outer * sin(angle)),
        Paint()
          ..color = isMajor ? theme.textSecondary : theme.textDim
          ..strokeWidth = isMajor ? 2.0 : 1.2
          ..style = PaintingStyle.stroke,
      );
    }

    // ── Needle ────────────────────────────────────────────────────────────
    final angle = _centsToAngle(needlePos.clamp(-50.0, 50.0));
    final needleLen = r - 18;
    final tipX = cx + needleLen * cos(angle);
    final tipY = cy + needleLen * sin(angle);

    if (showNeedle) {
      // Soft halo
      canvas.drawLine(
        Offset(cx, cy),
        Offset(tipX, tipY),
        Paint()
          ..color = stateColor.withValues(alpha: 0.15 + pulse * 0.10)
          ..strokeWidth = 18
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke,
      );
      // Core
      canvas.drawLine(
        Offset(cx, cy),
        Offset(tipX, tipY),
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
      showNeedle ? 6.0 : 4.0,
      Paint()
        ..color =
            showNeedle ? stateColor : theme.textDim.withValues(alpha: 0.5)
        ..style = PaintingStyle.fill,
    );

    // Idle pulse ring
    if (isListening && !hasSignal) {
      canvas.drawCircle(
        Offset(cx, cy),
        16 + pulse * 10,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color =
              theme.textSecondary.withValues(alpha: 0.15 + pulse * 0.20),
      );
    }
  }

  @override
  bool shouldRepaint(_ArcPainter old) =>
      old.needlePos != needlePos ||
      old.showNeedle != showNeedle ||
      old.stateColor != stateColor ||
      old.isListening != isListening ||
      old.hasSignal != hasSignal ||
      old.pulse != pulse ||
      old.theme != theme;
}

// ── Idle readout ──────────────────────────────────────────────────────────────

class _IdleReadout extends StatelessWidget {
  final bool isListening;
  final Animation<double> pulse;
  final TunerThemeData theme;

  const _IdleReadout({
    required this.isListening,
    required this.pulse,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AnimatedBuilder(
      animation: pulse,
      builder: (ctx, child) => Opacity(
        opacity: isListening ? (0.80 + pulse.value * 0.20) : 1.0,
        child: child,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isListening ? Icons.mic_rounded : Icons.music_note_rounded,
            size: 48,
            color: isListening ? theme.textSecondary : theme.textDim,
          ),
          const SizedBox(height: 16),
          Text(
            isListening ? l10n.gaugeListeningMsg : l10n.gaugeTapToBeginMsg,
            style: theme.sans(22,
                weight: FontWeight.w500, color: theme.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ── Signal readout ────────────────────────────────────────────────────────────

class _SignalReadout extends StatelessWidget {
  final double cents;
  final String noteName;
  final Color stateColor;
  final TunerThemeData theme;

  const _SignalReadout({
    required this.cents,
    required this.noteName,
    required this.stateColor,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final centsStr =
        cents >= 0 ? '+${cents.toStringAsFixed(1)}' : cents.toStringAsFixed(1);

    // Parse e.g. "B♭4" → letter "B", accidental "♭", octave "4"
    final match = RegExp(r'^([A-G])(♭|♯)?(\d+)?$').firstMatch(noteName);
    final noteLetter = match?.group(1) ?? noteName;
    final noteAcc    = match?.group(2) ?? '';
    final noteOctave = match?.group(3) ?? '';

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              noteLetter,
              style: theme.sans(100, weight: FontWeight.w400).copyWith(height: 1),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (noteAcc.isNotEmpty)
                    Text(
                      noteAcc,
                      style: theme.sans(42, weight: FontWeight.w400).copyWith(height: 1),
                    ),
                  if (noteOctave.isNotEmpty)
                    Text(
                      noteOctave,
                      style: theme.sans(30, weight: FontWeight.w300, color: theme.textSecondary).copyWith(height: 1),
                    ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          '$centsStr¢',
          style: theme.sans(18, weight: FontWeight.w500, color: stateColor),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
