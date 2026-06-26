// lib/core/widgets/radar_animation.dart
// A radar-style scanning animation. Concentric circles + rotating sweep
// with a trailing gradient. Used by the device screen during BLE scan.

import 'dart:math' as math;

import 'package:flutter/material.dart';

class RadarAnimation extends StatefulWidget {
  /// Overall size in logical pixels. Animation fits inside a square of this size.
  final double size;

  /// Primary color used for circles, sweep, and center glow.
  final Color color;

  /// How long one full sweep takes.
  final Duration period;

  const RadarAnimation({
    super.key,
    this.size = 280,
    this.color = const Color(0xFF2E7D32),
    this.period = const Duration(seconds: 3),
  });

  @override
  State<RadarAnimation> createState() => _RadarAnimationState();
}

class _RadarAnimationState extends State<RadarAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  // Pseudo-random fixed positions for the four "detected" pings, so they
  // feel organic but don't jitter between frames.
  static final List<_Ping> _pings = List.generate(4, (i) {
    final angle = (i * math.pi / 2) + (math.pi / 8);
    final radius = 0.45 + (i % 3) * 0.15;
    return _Ping(angle: angle, radius: radius, phase: i * 0.27);
  });

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.period)
      ..repeat();
  }

  @override
  void didUpdateWidget(covariant RadarAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.period != widget.period) {
      _controller.duration = widget.period;
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return CustomPaint(
            painter: _RadarPainter(
              progress: _controller.value,
              color: widget.color,
              pings: _pings,
            ),
          );
        },
      ),
    );
  }
}

class _Ping {
  final double angle;     // direction from center (radians)
  final double radius;    // 0..1 of painter radius
  final double phase;     // 0..1, used to stagger blink
  const _Ping({required this.angle, required this.radius, required this.phase});
}

class _RadarPainter extends CustomPainter {
  final double progress; // 0..1 (loops every animation period)
  final Color color;
  final List<_Ping> pings;

  _RadarPainter({
    required this.progress,
    required this.color,
    required this.pings,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.shortestSide / 2;

    // ── Outer dark disc (gives the radar its "screen" feel) ─────────────
    final bgPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          color.withValues(alpha: 0.10),
          color.withValues(alpha: 0.04),
          Colors.black.withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.7, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: maxRadius));
    canvas.drawCircle(center, maxRadius, bgPaint);

    // ── Concentric rings ────────────────────────────────────────────────
    for (int i = 1; i <= 3; i++) {
      final r = maxRadius * i / 3;
      final opacity = 0.18 + (1.0 - (i / 4.0)) * 0.12;
      final paint = Paint()
        ..color = color.withValues(alpha: opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2;
      canvas.drawCircle(center, r, paint);
    }

    // Crosshair lines (very subtle).
    final crossPaint = Paint()
      ..color = color.withValues(alpha: 0.10)
      ..strokeWidth = 1.0;
    canvas.drawLine(
      Offset(center.dx - maxRadius, center.dy),
      Offset(center.dx + maxRadius, center.dy),
      crossPaint,
    );
    canvas.drawLine(
      Offset(center.dx, center.dy - maxRadius),
      Offset(center.dx, center.dy + maxRadius),
      crossPaint,
    );

    // ── Sweep ───────────────────────────────────────────────────────────
    // The sweep uses a SweepGradient over a full circle, masked so only
    // the trailing ~80° of the sweep is visible. This is more elegant
    // than drawing a straight line + gradient.
    final sweepStart = progress * 2 * math.pi;
    final sweepSpan = math.pi * 0.42; // ~75° trailing arc

    final sweepPaint = Paint()
      ..shader = SweepGradient(
      startAngle: sweepStart - sweepSpan,
      endAngle: sweepStart,
      tileMode: TileMode.clamp,
      colors: [
        color.withValues(alpha: 0.0),
        color.withValues(alpha: 0.45),
        color.withValues(alpha: 0.0),
      ],
      stops: const [0.0, 0.85, 1.0],
      transform: GradientRotation(-math.pi / 2),
    ).createShader(Rect.fromCircle(center: center, radius: maxRadius));

    final sweepPath = Path()
      ..addArc(
        Rect.fromCircle(center: center, radius: maxRadius),
        sweepStart - sweepSpan,
        sweepSpan,
      );
    canvas.drawPath(sweepPath, sweepPaint);

    // Leading edge of the sweep — a thin bright line.
    final leadingEdgeStart = Offset(
      center.dx + maxRadius * math.cos(sweepStart - math.pi / 2),
      center.dy + maxRadius * math.sin(sweepStart - math.pi / 2),
    );
    final edgePaint = Paint()
      ..color = color.withValues(alpha: 0.85)
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(center, leadingEdgeStart, edgePaint);

    // ── Detected pings ─────────────────────────────────────────────────
    // Each ping blinks based on its phase relative to sweep progress.
    for (final ping in pings) {
      // Distance the sweep has travelled through this ping's angle.
      var delta = (progress * 2 * math.pi) - ping.angle;
      // Wrap to [0, 2π).
      delta = delta % (2 * math.pi);
      if (delta < 0) delta += 2 * math.pi;

      // Ping lights up briefly after the sweep passes it, then fades.
      double alpha = 0;
      if (delta < math.pi * 0.7) {
        alpha = (1.0 - (delta / (math.pi * 0.7)));
      }

      if (alpha > 0.01) {
        final pingPos = Offset(
          center.dx + maxRadius * ping.radius * math.cos(ping.angle - math.pi / 2),
          center.dy + maxRadius * ping.radius * math.sin(ping.angle - math.pi / 2),
        );

        // Halo
        canvas.drawCircle(
          pingPos,
          8,
          Paint()..color = color.withValues(alpha: alpha * 0.25),
        );
        // Bright dot
        canvas.drawCircle(
          pingPos,
          3.5,
          Paint()..color = color.withValues(alpha: alpha),
        );
      }
    }

    // ── Center dot ─────────────────────────────────────────────────────
    canvas.drawCircle(
      center,
      4,
      Paint()..color = color,
    );
    canvas.drawCircle(
      center,
      8,
      Paint()..color = color.withValues(alpha: 0.25),
    );
  }

  @override
  bool shouldRepaint(_RadarPainter old) =>
      old.progress != progress || old.color != color;
}
