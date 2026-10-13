import '../audio/cue_player.dart';
import '../clock/clock.dart';
import '../cues/cue.dart';
import '../cues/phrase.dart';
import '../cues/plan_cues.dart';
import '../cues/sound_settings.dart';
import '../timeline/timeline.dart';
import '../timeline/workout.dart';

enum SessionStatus { idle, running, paused, finished }

/// What the screen draws. Derived, never stored: there is one number of record
/// in a session — how long it has been running — and everything else comes
/// from the timeline.
class SessionState {
  const SessionState({
    required this.status,
    required this.elapsedMs,
    required this.timeline,
  });

  final SessionStatus status;
  final int elapsedMs;
  final Timeline timeline;

  /// The phase running now, or null before the start and after the end.
  Segment? get segment => timeline.at(elapsedMs);

  int get remainingMs => timeline.totalMs - elapsedMs;

  /// How long is left of the current phase — the big number on the screen.
  int get segmentRemainingMs {
    final s = segment;
    return s == null ? 0 : s.endMs - elapsedMs;
  }

  bool get isActive =>
      status == SessionStatus.running || status == SessionStatus.paused;

  /// The phase the screen should colour itself after, or null when no session
  /// is under way.
  ///
  /// Not the same as [segment]: a loaded-but-idle session still has a phase
  /// sitting at time zero, and painting the setup screen in that phase's
  /// colour says a workout is running when none is.
  Segment? get activeSegment => isActive ? segment : null;
}

/// Runs one workout.
///
/// Dart is the single owner of session state. The player is told only what to
/// say and when; every change of plan is `cancel()` then schedule the rest
/// again, so there is no second copy of the truth to drift out of step.
class Session {
  Session({required this.player, required this.clock});

  final CuePlayer player;
  final Clock clock;

  Workout? _workout;
  Timeline _timeline = Timeline.empty;
  List<Cue> _cues = const [];

  SessionStatus _status = SessionStatus.idle;

  /// Elapsed time as at the last change of state — the anchor for the clock.
  int _elapsedAtAnchor = 0;
  int _anchorMs = 0;

  Workout? get workout => _workout;

  /// The whole script for the loaded workout, from time zero.
  List<Cue> get cues => _cues;

  int get elapsedMs {
    final raw = _status == SessionStatus.running
        ? _elapsedAtAnchor + (clock.nowMs - _anchorMs)
        : _elapsedAtAnchor;
    if (raw <= 0) return 0;
    return raw > _timeline.totalMs ? _timeline.totalMs : raw;
  }

  SessionState get state {
    final elapsed = elapsedMs;
    var status = _status;
    if (status == SessionStatus.running && elapsed >= _timeline.totalMs) {
      status = SessionStatus.finished;
    }
    return SessionState(
      status: status,
      elapsedMs: elapsed,
      timeline: _timeline,
    );
  }

  /// Loads a workout and works out its whole script. Nothing is scheduled and
  /// nothing makes a sound until [start].
  void load(
    Workout workout, {
    int offsetMs = 0,
    SoundSettings sounds = const SoundSettings(),
  }) {
    _workout = workout;
    _timeline = expand(workout);
    _cues = planCues(
      _timeline,
      workout.cues,
      offsetMs: offsetMs,
      phrases: phrasesFor(workout.kind),
      sounds: sounds,
    );
    _status = SessionStatus.idle;
    _elapsedAtAnchor = 0;
    _anchorMs = clock.nowMs;
  }

  Future<void> start() async {
    if (_timeline.isEmpty) return;
    // Warm first, and only then start the clock. Rendering the phrases can
    // take seconds on a first run, and anchoring before it would leave the
    // session believing it was already that far in.
    await player.warm(_cues);
    _elapsedAtAnchor = 0;
    _anchorMs = clock.nowMs;
    _status = SessionStatus.running;
    await player.schedule(_cues, leadMs: _leadMs);
  }

  /// Holds the session. The platform keeps the armed list and its own clock,
  /// so this is a pause rather than a cancel and a rebuild — which also means
  /// the notification's Pause button can do it with no UI alive.
  Future<void> pause() async {
    if (_status != SessionStatus.running) return;
    _elapsedAtAnchor = elapsedMs;
    _status = SessionStatus.paused;
    await player.pause();
  }

  Future<void> resume() async {
    if (_status != SessionStatus.paused) return;
    _anchorMs = clock.nowMs;
    _status = SessionStatus.running;
    await player.resume();
  }

  /// Follows a pause that the platform made on its own — the notification's
  /// Pause button, pressed with no UI alive to route it through. The platform
  /// has already stopped; this only catches the state up.
  void holdForPlatform() {
    if (_status != SessionStatus.running) return;
    _elapsedAtAnchor = elapsedMs;
    _status = SessionStatus.paused;
  }

  void releaseForPlatform() {
    if (_status != SessionStatus.paused) return;
    _anchorMs = clock.nowMs;
    _status = SessionStatus.running;
  }

  /// Takes over a session the platform is already running.
  ///
  /// The UI can die while a workout carries on — the foreground service keeps
  /// the cues playing long after the screen that started them is gone. Coming
  /// back to a timer that says "Start" while it is plainly still counting is
  /// the worst thing this app could do, so the state is picked up rather than
  /// started again. Nothing is scheduled here: the platform already holds the
  /// list and is playing from it.
  void adopt({required int elapsedMs, required bool paused}) {
    if (_timeline.isEmpty) return;
    _elapsedAtAnchor = elapsedMs;
    _anchorMs = clock.nowMs;
    _status = paused ? SessionStatus.paused : SessionStatus.running;
  }

  /// Jumps to the end of the current phase. Nothing is skipped silently: the
  /// next phase announces itself as it begins, exactly as it would have.
  Future<void> skip() async {
    final here = state.segment;
    if (here == null) return;
    _elapsedAtAnchor = here.endMs;
    _anchorMs = clock.nowMs;
    await player.cancel();
    if (_elapsedAtAnchor < _timeline.totalMs &&
        _status == SessionStatus.running) {
      await _rearm();
    }
  }

  Future<void> stop() async {
    _status = SessionStatus.idle;
    _elapsedAtAnchor = 0;
    _anchorMs = clock.nowMs;
    await player.cancel();
  }

  /// Adopts the native side's clock after the app has been in the background,
  /// where Dart may have been frozen and its own reckoning has drifted.
  Future<void> resync() async {
    if (_status != SessionStatus.running) return;
    final native = await player.elapsedMs();
    if (native == null) return;
    _elapsedAtAnchor = native;
    _anchorMs = clock.nowMs;
  }

  /// Arms what is left of the script, rebased so the next cue is relative to
  /// now. Only skipping needs this: pausing keeps the platform's own list.
  Future<void> _rearm() async => player.schedule(
    remainingFrom(_cues, _elapsedAtAnchor),
    leadMs: _leadMs,
  );

  /// Zero on purpose. The platform pins cue time zero this far in the future,
  /// while this class pins it to the moment of the call, so anything but zero
  /// is the display and the voice disagreeing by exactly that much. If a head
  /// start is ever wanted, it has to be compensated for here too.
  static const _leadMs = 0;
}
