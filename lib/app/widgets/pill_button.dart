import 'package:flutter/material.dart';

import '../style.dart';

/// A wide, fully rounded action.
///
/// Two of them: the one a screen is really offering, which is filled, lit and
/// glowing, and the one beside it, which is an outline. The difference between
/// them should be obvious from the far side of the room, because on the screen
/// before a workout the wrong one is only a tap away from the right one.
class PillButton extends StatelessWidget {
  const PillButton.primary({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    required this.accent,
    required this.foreground,
  }) : _filled = true;

  const PillButton.outlined({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    required this.accent,
  }) : foreground = accent,
       _filled = false;

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final Color foreground;

  /// The colour this action is made of.
  final Color accent;

  final bool _filled;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final colors = context.colors;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Sizes.pill / 2),
        gradient: _filled && enabled ? colors.gradientOn(accent) : null,
        color: _filled && !enabled ? Brand.raised : null,
        border: _filled
            ? null
            : Border.all(
                color: enabled ? accent : Brand.raised,
                width: Sizes.hairline,
              ),
        boxShadow: _filled && enabled ? Shadows.glow(accent) : null,
      ),
      child: Material(
        color: Brand.transparent,
        borderRadius: BorderRadius.circular(Sizes.pill / 2),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: SizedBox(
            height: Sizes.pill,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: Sizes.icon,
                  color: enabled ? foreground : colors.muted,
                ),
                const SizedBox(width: Sizes.gap),
                Flexible(
                  child: DefaultTextStyle.merge(
                    style: TextStyle(
                      color: enabled ? foreground : colors.muted,
                    ),
                    child: ActionLabel(label),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
