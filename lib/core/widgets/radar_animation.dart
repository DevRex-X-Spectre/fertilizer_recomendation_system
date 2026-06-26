// lib/core/widgets/radar_animation.dart
// Radar-style scanning animation with tappable device pings.
//
// The sweep rotates underneath via a CustomPainter. Each discovered device
// is rendered as a separate widget (Positioned + GestureDetector) so it can
// be tapped individually to open the device details screen.

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../ble/ble_service.dart' show DiscoveredDevice;
import '../theme.dart';

/// One ping position on the radar — wraps a discovered device with the
/// computed radar angle/radius so the parent doesn't recompute per frame.
class RadarPing {
  final String id;
  final String label;
  final double angle;        // radians; 0 = top, clockwise positive
  final double radius;       // 0..1 of radar radius (smaller = closer to center)
  final bool isHighlighted;  // true = SoilSense (larger, brighter, labelled)
  final Color color;

  const RadarPing({
    required this.id,
    required this.label,
    required this.angle,
    required this.radius,
    required this.isHighlighted,
    required this.color,
  });

  /// Build a RadarPing from a DiscoveredDevice + display label.
  factory RadarPing.fromDevice(DiscoveredDevice device) {
    return RadarPing(
      id: device.id,
      label: device.isSoilSense && device.name.startsWith('SoilSense')
          ? device.name
          : device.name,
      angle: device.radarAngle(),
      radius: device.radarRadius(),
      isHighlighted: device.isSoilSense,
      color: device.isSoilSense ? AppTheme.primary : const Color(0xFF9CA39B),
    );
  }
}

class RadarAnimation extends StatefulWidget {
  final double size;
  final Color color;
  final Duration period;
  final List<RadarPing> pings;
  final ValueChanged<RadarPing>? onPingTap;

  const RadarAnimation({
    super.key,
    this.size = 280,
    this.color = const Color(0xFF1B5E20),
    this.period = const Duration(seconds: 3),
    this.pings = const [],
    this.onPingTap,
  });

  @override
  State<RadarAnimation> createState() => _RadarAnimationState();
}

class _RadarAnimationState extends State<RadarAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

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
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Sweep animation underneath
          AnimatedBuilder(
            animation: _controller,
            builder: (context, _) => CustomPaint(
              size: Size(widget.size, widget.size),
              painter: _RadarSweepPainter(
                progress: _controller.value,
                color: widget.color,
              ),
            ),
          ),
          // Tappable device pings on top
          ...widget.pings.map(_buildPing),
        ],
      ),
    );
  }

  Widget _buildPing(RadarPing ping) {
    final maxRadius = widget.size / 2;
    // Convert angle (0=top, clockwise) to x,y. 0 rad → top → (0, -r).
    final dx = ping.radius * maxRadius * math.sin(ping.angle);
    final dy = -ping.radius * maxRadius * math.cos(ping.angle);

    final outerSize = ping.isHighlighted ? 28.0 : 14.0;
    final innerSize = ping.isHighlighted ? 10.0 : 5.0;

    final pingWidget = _PingDot(
      outerSize: outerSize,
      innerSize: innerSize,
      color: ping.color,
      isHighlighted: ping.isHighlighted,
    );

    final positioned = Positioned(
      left: widget.size / 2 + dx - outerSize / 2,
      top: widget.size / 2 + dy - outerSize / 2,
      width: outerSize,
      height: outerSize,
      child: GestureDetector(
        onTap: widget.onPingTap == null ? null : () => widget.onPingTap!(ping),
        behavior: HitTestBehavior.opaque,
        child: Center(child: pingWidget),
      ),
    );

    if (!ping.isHighlighted) return positioned;

    // Highlighted (SoilSense) pings: also show the device label so the
    // user can identify their device without tapping.
    return Stack(
      clipBehavior: Clip.none,
      children: [
        positioned,
        Positioned(
          left: widget.size / 2 + dx + outerSize / 2 + 4,
          top: widget.size / 2 + dy - 8,
          child: _PingLabel(text: ping.label),
        ),
      ],
    );
  }
}

class _PingDot extends StatelessWidget {
  final double outerSize;
  final double innerSize;
  final Color color;
  final bool isHighlighted;

  const _PingDot({
    required this.outerSize,
    required this.innerSize,
    required this.color,
    required this.isHighlighted,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: outerSize,
      height: outerSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: isHighlighted ? 0.25 : 0.18),
      ),
      child: Center(
        child: Container(
          width: innerSize,
          height: innerSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
            border: isHighlighted
                ? Border.all(color: Colors.white, width: 2)
                : null,
          ),
        ),
      ),
    );
  }
}

class _PingLabel extends StatelessWidget {
  final String text;
  const _PingLabel({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppTheme.primary,
        borderRadius: BorderRadius.circular(99),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withValues(alpha: 0.30),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.sensors, size: 12, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Sweep + concentric rings (no pings — those live in the widget tree) ──

class _RadarSweepPainter extends CustomPainter {
  final double progress;
  final Color color;

  _RadarSweepPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.shortestSide / 2;

    // Outer dark disc
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

    // Concentric rings
    for (int i = 1; i <= 3; i++) {
      final r = maxRadius * i / 3;
      final opacity = 0.18 + (1.0 - (i / 4.0)) * 0.12;
      final paint = Paint()
        ..color = color.withValues(alpha: opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2;
      canvas.drawCircle(center, r, paint);
    }

    // Crosshair lines
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

    // Sweep
    final sweepStart = progress * 2 * math.pi;
    final sweepSpan = math.pi * 0.42;

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

    // Leading edge
    final leadingEdgeEnd = Offset(
      center.dx + maxRadius * math.cos(sweepStart - math.pi / 2),
      center.dy + maxRadius * math.sin(sweepStart - math.pi / 2),
    );
    final edgePaint = Paint()
      ..color = color.withValues(alpha: 0.85)
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(center, leadingEdgeEnd, edgePaint);

    // Center dot
    canvas.drawCircle(center, 4, Paint()..color = color);
    canvas.drawCircle(
      center,
      8,
      Paint()..color = color.withValues(alpha: 0.25),
    );
  }

  @override
  bool shouldRepaint(_RadarSweepPainter old) =>
      old.progress != progress || old.color != color;
}
