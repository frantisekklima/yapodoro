import 'dart:math' as math;
import 'package:flutter/material.dart';

class CircularTimerProgress extends StatefulWidget {
  final double progress;
  final List<Color> gradientColors;
  final double strokeWidth;
  final Widget? child;
  final bool isWavy; // Whether to render wavy squiggles (M3 Expressive)

  const CircularTimerProgress({
    super.key,
    required this.progress,
    required this.gradientColors,
    this.strokeWidth = 12.0,
    this.child,
    this.isWavy = false,
  });

  @override
  State<CircularTimerProgress> createState() => _CircularTimerProgressState();
}

class _CircularTimerProgressState extends State<CircularTimerProgress> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    // Continuous flowing wave animation driven by controller (for shifting wave phase)
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3600),
    );
    if (widget.isWavy) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(CircularTimerProgress oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isWavy != oldWidget.isWavy) {
      if (widget.isWavy) {
        _controller.repeat();
      } else {
        _controller.stop();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        // Dynamic wave phase shift (continuous flowing animation)
        final double phase = widget.isWavy ? _controller.value * 2 * math.pi : 0.0;

        return AspectRatio(
          aspectRatio: 1.0,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: Size.infinite,
                painter: _CircularTimerExpressivePainter(
                  progress: widget.progress,
                  gradientColors: widget.gradientColors,
                  strokeWidth: widget.strokeWidth,
                  isWavy: widget.isWavy,
                  phase: phase,
                  theme: theme,
                ),
              ),
              if (widget.child != null) widget.child!,
            ],
          ),
        );
      },
    );
  }
}

class _CircularTimerExpressivePainter extends CustomPainter {
  final double progress;
  final List<Color> gradientColors;
  final double strokeWidth;
  final bool isWavy;
  final double phase;
  final ThemeData theme;

  _CircularTimerExpressivePainter({
    required this.progress,
    required this.gradientColors,
    required this.strokeWidth,
    required this.isWavy,
    required this.phase,
    required this.theme,
  });

  @override
  void paint(Canvas canvas, Size s) {
    final center = s.center(Offset.zero);
    final baseRadius = (math.min(s.width, s.height) - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: baseRadius);

    final trackColor = theme.colorScheme.onSurface.withOpacity(0.08);
    final Color activeColor = gradientColors.isNotEmpty ? gradientColors.first : theme.colorScheme.primary;

    // Check if progress is <= 0 and we are NOT wavy (idle state)
    if (progress <= 0.0 && !isWavy) {
      // Draw standard solid closed background track ring
      final trackPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..isAntiAlias = true
        ..color = trackColor;
      canvas.drawCircle(center, baseRadius, trackPaint);
      return;
    }

    // Determine active progress angle sweep (maximum 360 degrees)
    final double activeSweep = progress.clamp(0.0, 1.0) * math.pi * 2;
    
    // STATIONARY Determinate Arc: fixed start at 12 o'clock (-pi / 2). No spinning!
    final start = -math.pi / 2;
    final end = start + activeSweep;

    // Proportional gap before & after active progress sweep (highly visible and balanced)
    final gapDp = strokeWidth * 1.2;
    final gapAngle = gapDp / baseRadius; 

    // 1. Draw Broken Background Track (Only if not a complete 360 degree sweep)
    final bool waveOnly = progress >= 1.0;
    if (!waveOnly) {
      final trackPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..isAntiAlias = true
        ..color = trackColor;
      
      final total = math.pi * 2;
      final a1 = end + gapAngle;
      final a2 = start - gapAngle;
      
      double sweep1 = (a2 - a1);
      while (sweep1 <= 0) {
        sweep1 += total;
      }
      
      canvas.drawArc(rect, a1, sweep1, false, trackPaint);
    }

    // 2. Draw Active Path
    final activePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true
      ..color = activeColor;

    if (isWavy) {
      // Refined waves for low-frequency elegant flow (Material 3 Expressive compliant)
      final amp = 5.0; // Radial amplitude of squiggle (optimized for a visible but elegant wave)
      final scallopLen = 46.0; // Wavelength proxy (increased for lower frequency, gentle curves)
      final taperLen = scallopLen / 2; // Fade amplitude to zero at the end for clean closure

      // Dynamic high-density steps to guarantee perfectly smooth, curved waves with zero sharp edges/aliasing
      final double arcLength = baseRadius * activeSweep;
      final int steps = math.max(360, (arcLength * 3.0).round());
      final path = Path();

      final double totalArcLen = baseRadius * activeSweep;
      final bool isClosedCircle = progress >= 1.0;

      // Adjust scallop length for closed circles to ensure a perfectly seamless loop
      double effectiveScallopLen = scallopLen;
      if (isClosedCircle) {
        final double numWaves = (totalArcLen / scallopLen).roundToDouble();
        if (numWaves > 0) {
          effectiveScallopLen = totalArcLen / numWaves;
        }
      }

      for (int i = 0; i <= steps; i++) {
        final t = i / steps;
        final ang = start + (end - start) * t;
        final arcLen = baseRadius * (ang - start);
        final arcToEnd = baseRadius * (end - ang);
        
        double taperFactor = 1.0;
        if (!isClosedCircle) {
          // Open arc: taper both start and end caps so they sit cleanly on baseRadius
          final double distFromStart = arcLen;
          final double distFromEnd = arcToEnd;
          final double minDist = math.min(distFromStart, distFromEnd);
          if (minDist < taperLen) {
            final double tTaper = (minDist / taperLen).clamp(0.0, 1.0);
            taperFactor = math.sin(tTaper * math.pi / 2);
          }
        }
        
        // Shifting wave phase continuously along the stationary progress arc
        final r = baseRadius + (amp * taperFactor) * math.sin(arcLen / effectiveScallopLen * 2 * math.pi - phase);
        final p = Offset(center.dx + r * math.cos(ang), center.dy + r * math.sin(ang));

        if (i == 0) {
          path.moveTo(p.dx, p.dy);
        } else {
          path.lineTo(p.dx, p.dy);
        }
      }

      if (isClosedCircle) {
        path.close();
      }

      canvas.drawPath(path, activePaint);
    } else {
      // Draw standard solid expressive rounded arc (Flat and clean, no spinning, no glows)
      canvas.drawArc(rect, start, activeSweep, false, activePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _CircularTimerExpressivePainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.gradientColors != gradientColors ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.isWavy != isWavy ||
        oldDelegate.phase != phase ||
        oldDelegate.theme != theme;
  }
}
