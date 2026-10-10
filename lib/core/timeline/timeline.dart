import 'workout.dart';

/// One phase of a workout, laid out on the clock. Milliseconds from the start
/// of the session, so a segment can be compared against the elapsed time
/// without any date arithmetic.
class Segment {
  const Segment({
    required this.kind,
    required this.startMs,
    required this.endMs,
    this.label = '',
    this.index = 0,
    this.isLastWork = false,
  });

  final SegmentKind kind;
  final int startMs;
  final int endMs;

  /// The round's label, empty if it has none.
  final String label;

  /// Which work phase this is, counting from 1 across the whole workout.
  /// Zero for anything that is not work.
  final int index;

  /// The final work phase, which earns the "last round" warning.
  final bool isLastWork;

  int get durationMs => endMs - startMs;

  bool contains(int atMs) => atMs >= startMs && atMs < endMs;
}

/// A workout flattened into consecutive phases. The segments are contiguous:
/// each starts where the last ended, the first starts at zero, and the last
/// ends at [totalMs].
class Timeline {
  const Timeline(this.segments, this.totalMs);

  static const empty = Timeline(<Segment>[], 0);

  final List<Segment> segments;
  final int totalMs;

  bool get isEmpty => segments.isEmpty;

  /// The phase running at [atMs], or null once the workout is over.
  Segment? at(int atMs) {
    for (final s in segments) {
      if (s.contains(atMs)) return s;
    }
    return null;
  }
}

/// Lays a [Workout] out on the clock.
///
/// Pure: no clock, no I/O. Two rules are worth knowing because they are what
/// people expect from a timer and forget to implement:
///
/// * A phase of zero seconds is skipped rather than emitted empty.
/// * The rest after the very last work phase is dropped — nobody rests at the
///   end, they stop.
Timeline expand(Workout w) {
  final segments = <Segment>[];
  var at = 0;
  var workIndex = 0;

  void add(SegmentKind kind, int seconds, {String label = '', int index = 0}) {
    if (seconds <= 0) return;
    final end = at + seconds * 1000;
    segments.add(
      Segment(
        kind: kind,
        startMs: at,
        endMs: end,
        label: label,
        index: index,
      ),
    );
    at = end;
  }

  final totalWorkPhases = w.workPhases;
  if (totalWorkPhases == 0) return Timeline.empty;

  add(SegmentKind.prepare, w.prepareSeconds);

  for (var repeat = 0; repeat < w.repeats; repeat++) {
    for (final round in w.rounds) {
      workIndex++;
      add(
        SegmentKind.work,
        round.workSeconds,
        label: round.label,
        index: workIndex,
      );
      // No rest after the final work phase of the whole workout.
      if (workIndex < totalWorkPhases) {
        add(SegmentKind.rest, round.restSeconds);
      }
    }
    if (repeat < w.repeats - 1) {
      add(SegmentKind.breakBetween, w.breakSeconds);
    }
  }

  add(SegmentKind.cooldown, w.cooldownSeconds);

  // Mark the last work phase now that we know which one it was.
  for (var i = segments.length - 1; i >= 0; i--) {
    if (segments[i].kind == SegmentKind.work) {
      final s = segments[i];
      segments[i] = Segment(
        kind: s.kind,
        startMs: s.startMs,
        endMs: s.endMs,
        label: s.label,
        index: s.index,
        isLastWork: true,
      );
      break;
    }
  }

  return Timeline(segments, at);
}
