import 'package:flutter/material.dart';

import '../sizes.dart';

/// A label, a number, and a thumb-sized minus and plus.
///
/// Typing a number means a keyboard over the screen and a field to dismiss;
/// nudging one is two taps and no keyboard, which is what setting up a workout
/// actually is.
class NumberRow extends StatelessWidget {
  const NumberRow({
    super.key,
    required this.label,
    required this.value,
    required this.onChange,
  });

  final String label;
  final String value;

  /// Called with -1 or 1. What a step means is the caller's business.
  final void Function(int by) onChange;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: Sizes.row,
    child: Row(
      children: [
        Expanded(
          child: Text(label, style: Theme.of(context).textTheme.titleMedium),
        ),
        IconButton.filledTonal(
          onPressed: () => onChange(-1),
          icon: const Icon(Icons.remove),
        ),
        SizedBox(
          width: Sizes.bigControl,
          child: Text(
            value,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        IconButton.filledTonal(
          onPressed: () => onChange(1),
          icon: const Icon(Icons.add),
        ),
      ],
    ),
  );
}
