import 'cue.dart';
import 'phrase.dart';

/// How far ahead the stopwatch arms its announcements.
///
/// Unlike a workout, a stopwatch has no end, so its script cannot be handed
/// over in one go. Ten minutes is the compromise: long enough that a pocket
/// never outlasts it in normal use, short enough that starting the stopwatch
/// only ever renders a handful of new phrases.
const stopwatchWindowMs = 10 * 60 * 1000;

/// Arm the next window once this much of the current one is left.
const stopwatchExtendAtMs = 5 * 60 * 1000;

/// What the count-up stopwatch says, and when.
///
/// Pure, like the workout planner, and for the same reason: this is the whole
/// spoken behaviour of the mode, and it should be testable without a clock or
/// a speaker.
List<Cue> planStopwatchCues({
  required int everySeconds,
  required int untilMs,
  int offsetMs = 0,
  Phrases phrases = const Phrases(),
}) {
  if (everySeconds <= 0) return const [];

  final step = everySeconds * 1000;
  final cues = <Cue>[];
  // Nothing at zero: the user has just pressed the button and knows.
  for (var at = step; at <= untilMs; at += step) {
    cues.add(
      Cue(
        atMs: at,
        text: phrases.elapsed(at ~/ 1000),
        priority: CuePriority.phaseWord,
      ),
    );
  }

  if (offsetMs == 0) return cues;
  return [for (final c in cues) c.shiftedBy(offsetMs)];
}

/// Whether the armed window is running out and the next should go down now.
///
/// While the app is awake its own ticker drives this. If it has been frozen
/// past the end of the window the stopwatch falls silent until the app is
/// opened again — the count itself is never wrong, only the talking stops.
bool needsExtending({required int elapsedMs, required int armedUntilMs}) {
  if (armedUntilMs <= 0) return false;
  return elapsedMs >= armedUntilMs - stopwatchExtendAtMs;
}
