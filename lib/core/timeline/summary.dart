import '../format.dart';
import 'timeline.dart';
import 'workout.dart';

/// The one-line description under a workout's name in the list.
///
/// Says the shape of the workout, not its contents: a list is read at a glance
/// to tell one workout from another, and "30s · 10s rest · 8 rounds" does that
/// where a list of every exercise would not.
extension WorkoutSummary on Workout {
  String get summary {
    if (rounds.isEmpty) return 'Empty';

    final parts = <String>[];
    if (rounds.length == 1) {
      final round = rounds.single;
      parts.add('${round.workSeconds}s work');
      if (round.restSeconds > 0) parts.add('${round.restSeconds}s rest');
      parts.add(_plural(repeats, 'round'));
    } else {
      parts.add(_plural(rounds.length, 'exercise'));
      if (repeats > 1) parts.add(_plural(repeats, 'set'));
    }
    return parts.join(' · ');
  }

  /// How long the whole thing takes, ready to show.
  String get totalLabel => countdown(expand(this).totalMs);
}

String _plural(int n, String noun) => '$n $noun${n == 1 ? '' : 's'}';
