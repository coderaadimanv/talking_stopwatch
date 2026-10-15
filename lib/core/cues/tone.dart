import '../timeline/workout.dart';

/// The six sounds the app can make instead of speaking.
///
/// Six, and not one per thing the voice can say, because that is the honest
/// limit of the form. A tone can tell you *that* something changed; it cannot
/// tell you it is round three of eight, and no amount of sound design will
/// make it. So tone mode trades the detail for quiet, and anyone who wants
/// both can have the tone and the word — see `SoundMode.both`.
///
/// The files are made by `tool/tones.py` and committed under `assets/sounds/`.
/// They are rendered at the same loudness the spoken cues are lifted to, so a
/// tone and a word land at the same level and the device-side lift finds
/// nothing left to do.
/// A set of the six sounds.
///
/// One at a time, and designed together rather than mixed: the work and rest
/// cues only work because within a set they are the same figure one way up and
/// the other, so you never have to learn them, only hear which way they go.
/// Mixing sets would throw that away, and anyone who wants one particular
/// sound somewhere can replace it with their own.
enum TonePack {
  /// Struck wooden bars. The default, and the warmest.
  wood('Wood', 'Marimba bars, warm and short'),

  /// The dayan of a tabla pair. Pitched, because a tabla's overtones are
  /// harmonic — which is also why it carries out of a phone speaker better
  /// than any other drum.
  tabla('Tabla', 'Dayan strokes, open and closed'),

  /// Rim, stick and block: the bright end of a kit, and the sharpest of the
  /// three. No kick and no floor tom — a phone reproduces almost nothing
  /// below 500 Hz, so the bottom of a kit would be silence.
  drum('Drum', 'Rim and block, sharp and dry');

  const TonePack(this.label, this.detail);

  final String label;
  final String detail;

  /// The set [name] names, or [wood] for a name this build does not know.
  static TonePack byName(String? name) =>
      values.firstWhere((p) => p.name == name, orElse: () => wood);
}

enum Tone {
  /// The session is starting. One soft note: nothing is happening yet.
  ready,

  /// Work begins. Rising, and the brightest of the set.
  work,

  /// Rest, a break or the cool down begins. The work tone falling — so the
  /// pair does not have to be learned, only heard which way it goes.
  rest,

  /// One second of the countdown. Short and dry, because three of them land a
  /// second apart.
  tick,

  /// Halfway through a work phase.
  halfway,

  /// The end of the session.
  done;

  /// The bundled file this plays, in one set.
  String assetIn(TonePack pack) => 'assets/sounds/${pack.name}/$name.wav';

  /// The name of the clip in the audio cache.
  ///
  /// Carries the set, because the sets are six different sounds for the same
  /// six moments: without it, switching from wood to tabla would go on playing
  /// whatever was cached under the old name.
  ///
  /// Deliberately unlike [phraseKey]'s sixteen hex characters, so a tone and a
  /// phrase can never be mistaken for each other in the cache, in a log or in
  /// a schedule crossing the channel.
  String keyIn(TonePack pack) => 'tone-${pack.name}-$name';

  /// How a sound of the user's own is filed, which is **without the set**.
  ///
  /// A sound you chose is yours whichever set is on; losing it because you
  /// tried the tabla would be absurd. The platform derives this from the clip
  /// key by taking the last part, so the two names stay in step without the
  /// two halves having to agree about anything else.
  String get key => 'tone-$name';

  /// The sound a phase begins with.
  ///
  /// A break and a cool down share the rest tone. They are different lengths
  /// of the same thing — stop moving — and telling them apart is exactly the
  /// detail tone mode gives up.
  static Tone forPhase(SegmentKind kind) => switch (kind) {
    SegmentKind.prepare => ready,
    SegmentKind.work => work,
    SegmentKind.rest => rest,
    SegmentKind.breakBetween => rest,
    SegmentKind.cooldown => rest,
  };
}
