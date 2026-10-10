import 'phrase.dart';

/// How much a cue matters when two of them land on top of each other. The
/// order is ascending: a later value wins.
///
/// There is no separate level for a round label, because a label is spoken as
/// part of its phase word — "Go, round 1" is one cue, not two.
enum CuePriority { halfway, countdown, phaseWord }

/// One thing to say, at one moment, measured in milliseconds from the start
/// of the session.
///
/// A cue carries the whole utterance. "Go, round 1" is a single cue so that it
/// renders to a single audio file and plays as one sound — two cues at the
/// same instant would race, and the collision rule would throw one away.
class Cue {
  const Cue({
    required this.atMs,
    required this.text,
    required this.priority,
  });

  final int atMs;
  final String text;
  final CuePriority priority;

  /// The name of the audio file this cue plays.
  String get key => phraseKey(text);

  Cue shiftedBy(int ms) {
    final at = atMs + ms;
    return Cue(atMs: at < 0 ? 0 : at, text: text, priority: priority);
  }

  Map<String, Object?> toJson() => {'at': atMs, 'key': key, 'text': text};

  @override
  bool operator ==(Object other) =>
      other is Cue &&
      other.atMs == atMs &&
      other.text == text &&
      other.priority == priority;

  @override
  int get hashCode => Object.hash(atMs, text, priority);

  @override
  String toString() => 'Cue($atMs, "$text")';
}
