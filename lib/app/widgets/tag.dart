import 'package:flutter/material.dart';

import '../style.dart';

/// A small labelled chip, in the colour of whatever it belongs to.
///
/// What a preset card says about itself beyond its name and its numbers. Two
/// per card and no more: a row of chips stops being read at about three, and
/// the card is already carrying a ring, a name and a line of detail.
class Tag extends StatelessWidget {
  const Tag({
    super.key,
    required this.label,
    required this.accent,
    this.icon,
    this.filled = true,
  });

  final String label;
  final Color accent;
  final IconData? icon;

  /// Filled chips carry the colour; plain ones are a hairline and the muted
  /// text. The first chip on a card is filled and the second is not, because
  /// two filled chips side by side read as two buttons.
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final foreground = filled ? accent : colors.muted;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Sizes.gap,
        vertical: Sizes.gap / 2,
      ),
      decoration: BoxDecoration(
        color: filled ? colors.washOf(accent) : null,
        border: filled
            ? null
            : Border.all(color: colors.line, width: Sizes.hairline),
        borderRadius: BorderRadius.circular(Sizes.control / 2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: Sizes.chipIcon, color: foreground),
            const SizedBox(width: Sizes.gap / 2),
          ],
          // Shrinks rather than wraps, like every other label in the app: two
          // chips and a card's padding leave little room on a 320dp phone.
          Flexible(
            child: DefaultTextStyle.merge(
              style: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(color: foreground),
              child: ActionLabel(label),
            ),
          ),
        ],
      ),
    );
  }
}
