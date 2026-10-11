import 'package:flutter/material.dart';

import '../style.dart';

/// A round control with its name under it.
///
/// Round rather than square because these are hit without being looked at, and
/// a circle has no corner to miss. The primary one is larger and raised; the
/// other two are quiet discs that sit on the ground.
class CircleControl extends StatelessWidget {
  const CircleControl({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    required this.background,
    required this.foreground,
    required this.labelColor,
    this.primary = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  final Color background;
  final Color foreground;
  final Color labelColor;

  /// The one you reach for without looking.
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final size = primary ? Sizes.circleControlBig : Sizes.circleControl;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Every control reserves the primary's height, so the labels line up
        // although the middle button is the big one.
        SizedBox(
          height: Sizes.circleControlBig,
          child: Center(
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: background,
                shape: BoxShape.circle,
                boxShadow: primary ? Shadows.control : null,
              ),
              child: Material(
                color: Brand.transparent,
                shape: const CircleBorder(),
                clipBehavior: Clip.antiAlias,
                child: IconButton(
                  onPressed: onPressed,
                  icon: Icon(icon),
                  color: foreground,
                  iconSize: primary ? Sizes.bigIcon : Sizes.icon,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: Sizes.gap),
        Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: labelColor,
          ),
        ),
      ],
    );
  }
}
