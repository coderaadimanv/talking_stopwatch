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

  /// The bundled file this plays.
  String get asset => 'assets/sounds/$name.wav';

  /// The name of the clip in the audio cache.
  ///
  /// Deliberately unlike [phraseKey]'s sixteen hex characters, so a tone and a
  /// phrase can never be mistaken for each other in the cache, in a log or in
  /// a schedule crossing the channel.
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
