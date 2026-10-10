import '../timeline/timeline.dart';
import '../timeline/workout.dart';
import 'cue.dart';
import 'phrase.dart';

/// Two cues closer together than this are the same moment as far as a listener
/// is concerned, so only the more important one is spoken.
const minCueGapMs = 300;

/// A countdown needs this much room on top of its own length, so the first
/// number never treads on the phase word that opened the phase.
const _countdownHeadroomMs = 2000;

/// Below this, "halfway" is noise rather than information.
const _halfwayFloorMs = 20000;

/// Works out everything the app will say for one session, in advance.
///
/// This is the whole script, and the only place that decides when the app
/// speaks. It is pure — no clock, no audio, no I/O — so the entire spoken
/// behaviour of the app is unit-testable, and so the result can be handed to
/// the platform in one go and still be right if Dart never runs again.
///
/// [offsetMs] is the user's calibration: Bluetooth earbuds lag by 150–300 ms
/// that cannot be queried, so the whole script shifts. Negative plays earlier.
List<Cue> planCues(
  Timeline timeline,
  CueSettings settings, {
  int offsetMs = 0,
  Phrases phrases = const Phrases(),
}) {
  if (timeline.isEmpty) return const [];

  final cues = <Cue>[];
  final from = settings.countdownFrom.clamp(1, 10);

  for (final segment in timeline.segments) {
    if (settings.phaseWords) {
      cues.add(
        Cue(
          atMs: segment.startMs,
          text: _phaseText(segment, settings, phrases),
          priority: CuePriority.phaseWord,
        ),
      );
    }

    if (settings.halfway &&
        segment.kind == SegmentKind.work &&
        segment.durationMs >= _halfwayFloorMs) {
      cues.add(
        Cue(
          atMs: segment.startMs + segment.durationMs ~/ 2,
          text: phrases.halfway,
          priority: CuePriority.halfway,
        ),
      );
    }

    // The countdown belongs to the phase that is ending, and runs out exactly
    // as the next one begins. A phase too short to hold it gets none at all,
    // which is what stops the app saying "one rest three".
    if (settings.countdown &&
        segment.durationMs >= from * 1000 + _countdownHeadroomMs) {
      for (var n = from; n >= 1; n--) {
        cues.add(
          Cue(
            atMs: segment.endMs - n * 1000,
            text: phrases.count(n),
            priority: CuePriority.countdown,
          ),
        );
      }
    }
  }

  cues.add(
    Cue(
      atMs: timeline.totalMs,
      text: phrases.done,
      priority: CuePriority.phaseWord,
    ),
  );

  return resolveCollisions([
    if (offsetMs == 0) ...cues else for (final c in cues) c.shiftedBy(offsetMs),
  ]);
}

/// The part of a script still to come at [elapsedMs], rebased so the first cue
/// is relative to now.
///
/// This is how pause, resume and skip work: there is no way to "adjust" a
/// schedule the native side is already holding, so we hand it a fresh one.
List<Cue> remainingFrom(List<Cue> cues, int elapsedMs) => [
  for (final c in cues)
    if (c.atMs >= elapsedMs) c.shiftedBy(-elapsedMs),
];

/// The sentence spoken as a phase begins, qualifier included.
String _phaseText(Segment segment, CueSettings settings, Phrases phrases) {
  final word = phrases.phase(segment.kind);
  if (segment.kind != SegmentKind.work) return word;

  if (settings.lastRound && segment.isLastWork) {
    return phrases.join(word, phrases.lastRound);
  }
  if (settings.roundLabels) {
    final label = segment.label.isNotEmpty
        ? segment.label
        : phrases.round(segment.index);
    return phrases.join(word, label);
  }
  return word;
}

/// Drops cues that would talk over each other, keeping the one that matters.
///
/// Walks the cues most-important first and accepts one only if nothing already
/// accepted is within [minCueGapMs]. That way a dropped cue is always the less
/// important of the pair, whichever came first in time. The result is sorted by
/// time.
///
/// The script rules make a real collision hard to reach, which is the point of
/// them; this is the safety net under a hand-edited preset.
List<Cue> resolveCollisions(List<Cue> cues, {int minGapMs = minCueGapMs}) {
  final byImportance = [...cues]..sort((a, b) {
    final p = b.priority.index.compareTo(a.priority.index);
    return p != 0 ? p : a.atMs.compareTo(b.atMs);
  });

  final kept = <Cue>[];
  for (final cue in byImportance) {
    final clash = kept.any((k) => (k.atMs - cue.atMs).abs() < minGapMs);
    if (!clash) kept.add(cue);
  }

  return kept..sort((a, b) => a.atMs.compareTo(b.atMs));
}
