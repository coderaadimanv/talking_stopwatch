import 'package:flutter/material.dart';

import '../style.dart';

/// The ground a running screen stands on: one colour, with a few very soft
/// shapes drifting through it.
///
/// A flat fill at this size reads as a blank wall. The shapes are the same
/// colour lifted or dropped a little and have no edges at all, so they give
/// the screen depth without ever being noticed as shapes — which is the point.
/// Nothing here moves: this screen is looked at while out of breath, and
/// something drifting in the corner of it would only pull the eye.
class SoftBackground extends StatelessWidget {
  const SoftBackground({super.key, required this.color, required this.child});

  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(color: color),
    child: CustomPaint(
      painter: _Blobs(),
      // The painter has no size of its own; it fills whatever the child needs.
      child: SizedBox.expand(child: child),
    ),
  );
}

class _Blobs extends CustomPainter {
  /// Where each shape sits and how big it is, as fractions of the screen, so
  /// the arrangement is the same on every phone.
  static const _shapes = [
    (x: 0.95, y: 0.02, r: 0.52, light: true),
    (x: 0.05, y: 0.28, r: 0.60, light: true),
    (x: 0.85, y: 0.72, r: 0.70, light: false),
    (x: 0.10, y: 0.98, r: 0.45, light: true),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    for (final shape in _shapes) {
      final centre = Offset(size.width * shape.x, size.height * shape.y);
      final radius = size.width * shape.r;
      final colour = shape.light ? Brand.veilLight : Brand.veilDark;
      canvas.drawCircle(
        centre,
        radius,
        Paint()
          ..shader = RadialGradient(
            // Solid in the middle and gone by the edge, so there is no rim to
            // catch the eye.
            colors: [colour, colour.withValues(alpha: 0)],
          ).createShader(Rect.fromCircle(center: centre, radius: radius)),
      );
    }
  }

  @override
  bool shouldRepaint(_Blobs oldDelegate) => false;
}
