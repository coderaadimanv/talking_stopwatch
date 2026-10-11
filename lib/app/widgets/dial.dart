import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../style.dart';

/// The big round face that carries the time, with the phase's progress drawn
/// around its edge.
///
/// The arc is the only thing on the screen that says how far through you are
/// without having to be read, which is what it is for: a glance from across a
/// room gets the phase from the colour and the progress from the arc, and only
/// a proper look needs the number.
class Dial extends StatelessWidget {
  const Dial({
    super.key,
    required this.progress,
    required this.face,
    required this.arc,
    required this.child,
  });

  /// How far through, from 0 to 1. Values outside that are clamped rather than
  /// drawn, because a timer that is a little over should look finished.
  final double progress;

  /// The pale disc.
  final Color face;

  /// The arc around it.
  final Color arc;

  final Widget child;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      // Bounded by the width it may take, the height it is given, and a cap
      // so it does not become absurd on a tablet. The height matters: on a
      // short screen the dial gives way rather than pushing the controls off.
      final size = math.min(
        math.min(
          constraints.maxWidth * Sizes.dialFraction,
          constraints.maxHeight,
        ),
        Sizes.dialMax,
      );
      return SizedBox(
        width: size,
        height: size,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: face,
            shape: BoxShape.circle,
            boxShadow: Shadows.dial,
          ),
          child: CustomPaint(
            painter: _Arc(
              progress: progress.clamp(0, 1),
              color: arc,
              stroke: Sizes.dialStroke,
            ),
            child: Padding(
              // Clear of the arc, and of the curve of the disc behind it.
              padding: EdgeInsets.all(size * 0.17),
              child: Center(child: child),
            ),
          ),
        ),
      );
    },
  );
}

class _Arc extends CustomPainter {
  const _Arc({
    required this.progress,
    required this.color,
    required this.stroke,
  });

  final double progress;
  final Color color;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;

    // Sits on the disc's edge rather than outside it, so the dial keeps one
    // clean silhouette however far round the arc has gone.
    final rect = Rect.fromLTWH(
      0,
      0,
      size.width,
      size.height,
    ).deflate(stroke / 2);

    canvas.drawArc(
      rect,
      -math.pi / 2, // noon, where a clock starts
      2 * math.pi * progress,
      false,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_Arc old) =>
      old.progress != progress || old.color != color || old.stroke != stroke;
}
