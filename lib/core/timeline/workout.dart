/// What the user set up: a workout, and which cues it should speak.
///
/// Durations are whole seconds here, because that is what the user types.
/// Everything downstream of [expand] is integer milliseconds.
library;

/// What a saved timer is for.
///
/// The two share this whole model — a focus session is work phases with rests
/// between them, which is what a workout is — and differ in everything around
/// it: what the phases are called, how much is said, and how loudly the screen
/// says it. So this is the one field the rest of the app branches on, and the
/// model itself never reads it.
enum TimerKind {
  /// Counted out loud and read across a gym.
  workout,

  /// A block of concentrated work. One word at each change, and a screen with
  /// nothing on it to look at.
  focus,
}

/// The kind of phase a [Segment] is, which decides the word spoken as it
/// begins.
enum SegmentKind {
  /// Before the first work phase: "ready".
  prepare,

  /// Working: "go".
  work,

  /// Resting between rounds: "rest".
  rest,

  /// Resting between repeats of the whole round list: "break".
  breakBetween,

  /// After the last work phase: "cool down".
  cooldown,
}

/// One round: work, then rest. A round with a [label] says the label out loud
/// instead of its number, so a circuit can call out "push ups".
class Round {
  const Round({
    this.label = '',
    required this.workSeconds,
    required this.restSeconds,
  });

  factory Round.fromJson(Map<String, Object?> json) => Round(
    label: json['label'] as String? ?? '',
    workSeconds: json['work'] as int? ?? 0,
    restSeconds: json['rest'] as int? ?? 0,
  );

  final String label;
  final int workSeconds;
  final int restSeconds;

  Round copyWith({String? label, int? workSeconds, int? restSeconds}) => Round(
    label: label ?? this.label,
    workSeconds: workSeconds ?? this.workSeconds,
    restSeconds: restSeconds ?? this.restSeconds,
  );

  Map<String, Object?> toJson() => {
    if (label.isNotEmpty) 'label': label,
    'work': workSeconds,
    'rest': restSeconds,
  };
}

/// Which cues to speak. Every one of these is a switch in settings, because
/// what one person finds useful another finds chatty.
class CueSettings {
  const CueSettings({
    this.countdown = true,
    this.countdownFrom = 3,
    this.phaseWords = true,
    this.roundLabels = true,
    this.halfway = true,
    this.lastRound = true,
  });

  /// One word as each phase begins, and nothing else: no countdown into a
  /// change, no halfway, no round numbers.
  ///
  /// What a focus session runs on, and nothing in the planner has to know
  /// that — this is the script the existing rules already produce with the
  /// switches off.
  static const quiet = CueSettings(
    countdown: false,
    roundLabels: false,
    halfway: false,
    lastRound: false,
  );

  factory CueSettings.fromJson(Map<String, Object?> json) => CueSettings(
    countdown: json['countdown'] as bool? ?? true,
    countdownFrom: json['countdownFrom'] as int? ?? 3,
    phaseWords: json['phaseWords'] as bool? ?? true,
    roundLabels: json['roundLabels'] as bool? ?? true,
    halfway: json['halfway'] as bool? ?? true,
    lastRound: json['lastRound'] as bool? ?? true,
  );

  /// Count the last few seconds of a phase down to the change.
  final bool countdown;

  /// Where the countdown starts: 3 says "three, two, one".
  final int countdownFrom;

  /// Name the phase as it begins: "go", "rest".
  final bool phaseWords;

  /// Add the round's label or number: "go, round one".
  final bool roundLabels;

  /// Say "halfway" in the middle of a long work phase.
  final bool halfway;

  /// Warn on the final work phase: "go, last round".
  final bool lastRound;

  CueSettings copyWith({
    bool? countdown,
    int? countdownFrom,
    bool? phaseWords,
    bool? roundLabels,
    bool? halfway,
    bool? lastRound,
  }) => CueSettings(
    countdown: countdown ?? this.countdown,
    countdownFrom: countdownFrom ?? this.countdownFrom,
    phaseWords: phaseWords ?? this.phaseWords,
    roundLabels: roundLabels ?? this.roundLabels,
    halfway: halfway ?? this.halfway,
    lastRound: lastRound ?? this.lastRound,
  );

  Map<String, Object?> toJson() => {
    'countdown': countdown,
    'countdownFrom': countdownFrom,
    'phaseWords': phaseWords,
    'roundLabels': roundLabels,
    'halfway': halfway,
    'lastRound': lastRound,
  };
}

/// A whole workout. One model covers both shapes we care about:
///
/// * 30 s work / 10 s rest × 8 — one [Round] with `repeats: 8`
/// * a circuit — several [Round]s with labels, repeated `repeats` times
class Workout {
  const Workout({
    required this.id,
    this.name = '',
    this.kind = TimerKind.workout,
    this.prepareSeconds = 10,
    required this.rounds,
    this.repeats = 1,
    this.breakSeconds = 0,
    this.cooldownSeconds = 0,
    this.cues = const CueSettings(),
  });

  /// The other common case: blocks of focused work with breaks between them,
  /// and a longer one at the end.
  ///
  /// The long break is the cool down rather than [breakSeconds], because it
  /// comes after the last block and not between every pair of them.
  factory Workout.focus({
    required int focusMinutes,
    required int breakMinutes,
    required int blocks,
    int longBreakMinutes = 0,
    String id = 'focus',
    String name = '',
  }) => Workout(
    id: id,
    name: name,
    kind: TimerKind.focus,
    prepareSeconds: 0,
    rounds: [
      Round(workSeconds: focusMinutes * 60, restSeconds: breakMinutes * 60),
    ],
    repeats: blocks,
    cooldownSeconds: longBreakMinutes * 60,
    cues: CueSettings.quiet,
  );

  /// The common case: one exercise, the same work and rest every round.
  factory Workout.simple({
    required int workSeconds,
    required int restSeconds,
    required int rounds,
    int prepareSeconds = 10,
    String id = 'simple',
    String name = '',
    CueSettings cues = const CueSettings(),
  }) => Workout(
    id: id,
    name: name,
    prepareSeconds: prepareSeconds,
    rounds: [Round(workSeconds: workSeconds, restSeconds: restSeconds)],
    repeats: rounds,
    cues: cues,
  );

  factory Workout.fromJson(Map<String, Object?> json) => Workout(
    id: json['id'] as String,
    name: json['name'] as String? ?? '',
    // Absent means workout, which is what every preset was before focus
    // existed. That is the whole migration.
    kind: json['kind'] == 'focus' ? TimerKind.focus : TimerKind.workout,
    prepareSeconds: json['prepare'] as int? ?? 0,
    rounds: [
      for (final r in (json['rounds'] as List<Object?>? ?? const []))
        Round.fromJson(r as Map<String, Object?>),
    ],
    repeats: json['repeats'] as int? ?? 1,
    breakSeconds: json['break'] as int? ?? 0,
    cooldownSeconds: json['cooldown'] as int? ?? 0,
    cues: CueSettings.fromJson(
      json['cues'] as Map<String, Object?>? ?? const {},
    ),
  );

  final String id;
  final String name;

  /// What this timer is for: it decides the words, the screen and the script.
  final TimerKind kind;

  /// Time to get into position before the first work phase.
  final int prepareSeconds;

  /// The rounds, in order. More than one makes it a circuit.
  final List<Round> rounds;

  /// How many times to run the whole round list.
  final int repeats;

  /// Rest between repeats of the round list — a longer breather than the
  /// rest inside a round.
  final int breakSeconds;

  final int cooldownSeconds;
  final CueSettings cues;

  /// How many work phases the whole workout has.
  int get workPhases => rounds.length * repeats;

  Workout copyWith({
    String? id,
    String? name,
    TimerKind? kind,
    int? prepareSeconds,
    List<Round>? rounds,
    int? repeats,
    int? breakSeconds,
    int? cooldownSeconds,
    CueSettings? cues,
  }) => Workout(
    id: id ?? this.id,
    name: name ?? this.name,
    kind: kind ?? this.kind,
    prepareSeconds: prepareSeconds ?? this.prepareSeconds,
    rounds: rounds ?? this.rounds,
    repeats: repeats ?? this.repeats,
    breakSeconds: breakSeconds ?? this.breakSeconds,
    cooldownSeconds: cooldownSeconds ?? this.cooldownSeconds,
    cues: cues ?? this.cues,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    if (kind != TimerKind.workout) 'kind': kind.name,
    'prepare': prepareSeconds,
    'rounds': [for (final r in rounds) r.toJson()],
    'repeats': repeats,
    'break': breakSeconds,
    'cooldown': cooldownSeconds,
    'cues': cues.toJson(),
  };
}
