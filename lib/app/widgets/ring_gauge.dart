import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../style.dart';

/// A ring with something inside it, drawn over part of its circumference.
///
/// The small cousin of [Dial], for the screens where nothing is running yet. A
/// dial says how far through you are; this says something about a session you
/// have not started, and the two look alike on purpose — the shape means "a
/// length of time" in both places.
///
/// **The arc is never decoration.** It is given a [progress] that means
/// something — on a preset card and on the screen before one starts, the share
/// of the session that is actually work — because a ring drawn at
/// three-quarters because three-quarters looks good is decoration pretending
/// to be data, which is the one thing a screen full of numbers may not do.
class RingGauge extends StatelessWidget {
  const RingGauge({
    super.key,
    required this.progress,
    required this.color,
    required this.size,
    this.stroke = Sizes.ringStroke,
    this.child,
  });

  /// How much of the ring is drawn, from 0 to 1. Out-of-range values are
  /// clamped rather than wrapped: a ring that has gone round twice is a bug,
  /// and drawing it as a full ring is the least confusing way to be wrong.
  final double progress;

  final Color color;
  final double size;
  final double stroke;

  /// What sits in the middle. Usually the total, scaled to fit.
  final Widget? child;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size,
    child: CustomPaint(
      painter: _Ring(
        progress: progress.clamp(0, 1),
        color: color,
        track: context.colors.washOf(color),
        stroke: stroke,
      ),
      child: Padding(
        // Clear of the ring, and of the curve inside it.
        padding: EdgeInsets.all(stroke + size * 0.08),
        child: Center(child: child),
      ),
    ),
  );
}

class _Ring extends CustomPainter {
  const _Ring({
    required this.progress,
    required this.color,
    required this.track,
    required this.stroke,
  });

  final double progress;
  final Color color;
  final Color track;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(
      0,
      0,
      size.width,
      size.height,
    ).deflate(stroke / 2);

    // The whole ring first, faintly: without it a short arc reads as a stray
    // mark rather than as a small part of something.
    canvas.drawCircle(
      rect.center,
      rect.width / 2,
      Paint()
        ..color = track
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke,
    );
    if (progress <= 0) return;

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
  bool shouldRepaint(_Ring old) =>
      old.progress != progress ||
      old.color != color ||
      old.track != track ||
      old.stroke != stroke;
}
