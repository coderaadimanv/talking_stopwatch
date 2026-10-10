import '../timeline/workout.dart';

/// The words the app says. One class per language; English is all we ship
/// today, and the only thing another language needs is a subclass.
///
/// Capitalisation is for the eye, not the ear — these strings also label the
/// cue in debug output. What matters is that a phrase and its qualifier read
/// as one sentence when joined, so the text can be rendered to a single clip.
class Phrases {
  const Phrases();

  String get ready => 'Ready';
  String get go => 'Go';
  String get rest => 'Rest';
  String get breakBetween => 'Break';
  String get cooldown => 'Cool down';
  String get halfway => 'Halfway';
  String get done => 'Done';

  /// Said on the final work phase instead of its round label.
  String get lastRound => 'last round';

  /// The word spoken as [kind] begins.
  String phase(SegmentKind kind) => switch (kind) {
    SegmentKind.prepare => ready,
    SegmentKind.work => go,
    SegmentKind.rest => rest,
    SegmentKind.breakBetween => breakBetween,
    SegmentKind.cooldown => cooldown,
  };

  /// A countdown number, spelled out: some engines read a bare "3" oddly
  /// next to other words. Only 1–10 can ever be asked for, because
  /// `countdownFrom` is clamped to that range.
  String count(int n) => const [
    'zero',
    'one',
    'two',
    'three',
    'four',
    'five',
    'six',
    'seven',
    'eight',
    'nine',
    'ten',
  ][n.clamp(0, 10)];

  /// The fallback name for an unlabelled round. A numeral, not a word, so it
  /// works for round 11 as well as round 1 — the voice says "round eleven"
  /// either way.
  String round(int n) => 'round $n';

  /// Glues a phase word to its qualifier so the two are spoken as one
  /// utterance — "Go, round one" — rather than as two cues that could drift
  /// apart or be dropped by the collision rule.
  String join(String phase, String qualifier) => '$phase, $qualifier';

  /// How long a stretch of elapsed time is read out in the stopwatch.
  String elapsed(int seconds) {
    final minutes = seconds ~/ 60;
    final rest = seconds % 60;
    if (minutes == 0) return '$rest seconds';
    final m = minutes == 1 ? '1 minute' : '$minutes minutes';
    if (rest == 0) return m;
    return '$m $rest';
  }
}

/// A stable, filesystem-safe name for the audio file a phrase renders to.
///
/// FNV-1a, 64-bit. This is a cache key, not a signature: it only has to avoid
/// collisions among the few hundred short phrases one person's presets can
/// produce, and doing it here keeps a hashing dependency out of the app.
String phraseKey(String text, {String voice = ''}) {
  const offset = 0xcbf29ce484222325;
  const prime = 0x100000001b3;
  var hash = offset;
  for (final unit in '$text\u0000$voice'.codeUnits) {
    hash = (hash ^ unit) * prime;
    // Dart ints are 64-bit and wrap on overflow, which is what FNV wants.
  }
  // Printed as two unsigned 32-bit halves: a 64-bit int is signed, so
  // formatting it whole can come out with a minus sign in front of it, and a
  // file name is no place for one.
  final hi = (hash >> 32).toUnsigned(32);
  final lo = hash.toUnsigned(32);
  return hi.toRadixString(16).padLeft(8, '0') +
      lo.toRadixString(16).padLeft(8, '0');
}
