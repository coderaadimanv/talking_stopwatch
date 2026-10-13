import 'phrase.dart';
import 'tone.dart';

/// How much a cue matters when two of them land on top of each other. The
/// order is ascending: a later value wins.
///
/// There is no separate level for a round label, because a label is spoken as
/// part of its phase word — "Go, round 1" is one cue, not two.
enum CuePriority { halfway, countdown, phaseWord }

/// One sound, at one moment, measured in milliseconds from the start of the
/// session.
///
/// A spoken cue carries the whole utterance. "Go, round 1" is a single cue so
/// that it renders to a single audio file and plays as one sound — two cues at
/// the same instant would race, and the collision rule would throw one away.
///
/// A cue is either spoken or a [tone], and from the platform's point of view
/// there is no difference at all: both are "play the clip named [key] at
/// [atMs]". That is what makes tones cheap — the schedule, the wake lock, the
/// foreground service and the lock-screen controls never learn they exist.
class Cue {
  const Cue({
    required this.atMs,
    required this.priority,
    this.text = '',
    this.tone,
  });

  final int atMs;

  /// What is said, for a spoken cue. Empty for a tone.
  final String text;

  /// Which sound to play instead of speaking, or null for a spoken cue.
  final Tone? tone;

  final CuePriority priority;

  /// The name of the audio file this cue plays.
  String get key => tone?.key ?? phraseKey(text);

  /// What this cue is, for a log or a test failure.
  String get label => tone == null ? '"$text"' : '<${tone!.name}>';

  Cue shiftedBy(int ms) {
    final at = atMs + ms;
    return Cue(
      atMs: at < 0 ? 0 : at,
      text: text,
      tone: tone,
      priority: priority,
    );
  }

  Map<String, Object?> toJson() => {
    'at': atMs,
    'key': key,
    if (tone == null) 'text': text else 'tone': tone!.name,
  };

  @override
  bool operator ==(Object other) =>
      other is Cue &&
      other.atMs == atMs &&
      other.text == text &&
      other.tone == tone &&
      other.priority == priority;

  @override
  int get hashCode => Object.hash(atMs, text, tone, priority);

  @override
  String toString() => 'Cue($atMs, $label)';
}
