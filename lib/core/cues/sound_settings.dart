/// How one kind of cue is sounded.
enum SoundMode {
  /// The phone's voice, which is what the app has always done.
  voice,

  /// A tone instead of the words.
  tone,

  /// Both: the tone first, then the words.
  both;

  bool get hasVoice => this != tone;
  bool get hasTone => this != voice;

  static SoundMode byName(String? name) =>
      values.firstWhere((m) => m.name == name, orElse: () => voice);
}

/// How each kind of cue is sounded, for the whole app.
///
/// This is deliberately not on a preset. A preset decides *whether* a cue
/// happens — that is what the switches in `CueSettings` are — and this decides
/// how it sounds. Keeping the two apart is what lets tone mode arrive without
/// the workout editor learning anything about it.
///
/// There are four here and not five, because a round label is not a cue of its
/// own: "Go, round 1" is one utterance by design (see `Cue`), so the label can
/// only be as audible as the phase word it is part of. Choosing [tone] for the
/// phase is therefore choosing to lose the round number, and [both] is the
/// answer for anyone who wants it back.
class SoundSettings {
  const SoundSettings({
    this.phase = SoundMode.voice,
    this.countdown = SoundMode.voice,
    this.halfway = SoundMode.voice,
    this.elapsed = SoundMode.voice,
  });

  /// Everything spoken by the voice, which is where the app started.
  static const spoken = SoundSettings();

  /// Nothing spoken at all: the whole session in six sounds.
  static const tones = SoundSettings(
    phase: SoundMode.tone,
    countdown: SoundMode.tone,
    halfway: SoundMode.tone,
    elapsed: SoundMode.tone,
  );

  factory SoundSettings.fromJson(Map<String, Object?> json) => SoundSettings(
    phase: SoundMode.byName(json['phase'] as String?),
    countdown: SoundMode.byName(json['countdown'] as String?),
    halfway: SoundMode.byName(json['halfway'] as String?),
    elapsed: SoundMode.byName(json['elapsed'] as String?),
  );

  /// "Go, round 3", "Rest", "Break" — and "Done" at the end.
  final SoundMode phase;

  /// "three, two, one" into a change.
  final SoundMode countdown;

  /// "Halfway" in the middle of a long work phase.
  final SoundMode halfway;

  /// The stopwatch reading the time out.
  final SoundMode elapsed;

  /// Whether anything at all is going to play a tone.
  bool get usesTones =>
      phase.hasTone || countdown.hasTone || halfway.hasTone || elapsed.hasTone;

  SoundSettings copyWith({
    SoundMode? phase,
    SoundMode? countdown,
    SoundMode? halfway,
    SoundMode? elapsed,
  }) => SoundSettings(
    phase: phase ?? this.phase,
    countdown: countdown ?? this.countdown,
    halfway: halfway ?? this.halfway,
    elapsed: elapsed ?? this.elapsed,
  );

  Map<String, Object?> toJson() => {
    'phase': phase.name,
    'countdown': countdown.name,
    'halfway': halfway.name,
    'elapsed': elapsed.name,
  };

  @override
  bool operator ==(Object other) =>
      other is SoundSettings &&
      other.phase == phase &&
      other.countdown == countdown &&
      other.halfway == halfway &&
      other.elapsed == elapsed;

  @override
  int get hashCode => Object.hash(phase, countdown, halfway, elapsed);
}
