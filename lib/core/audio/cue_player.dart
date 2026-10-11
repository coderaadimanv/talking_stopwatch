import '../cues/cue.dart';

/// Everything the app asks of the platform, and nothing more.
///
/// The contract holds no idea of a workout: it is handed a list of "say this,
/// that many milliseconds from now" and it plays them. All workout state stays
/// in Dart. That is what lets the native side keep talking while Dart is frozen
/// with the screen off — it already has the whole list and needs nothing more
/// from us.
///
/// Every method is allowed to do nothing. A phone with no speech engine, or a
/// platform where the native half is not written yet, must still run the timer.
abstract class CuePlayer {
  /// Whether this device has a voice to render with.
  Future<bool> available();

  /// Renders anything in [cues] that is not in the audio cache yet.
  ///
  /// Awaited before a session starts, so the first "go" never waits on the
  /// speech engine. Safe to call with phrases that are already cached.
  Future<void> warm(List<Cue> cues);

  /// Arms the whole list and starts the session clock.
  ///
  /// [leadMs] is a head start before cue time zero. Replaces any schedule
  /// already armed.
  ///
  /// [countUp] is about the notification only: a workout counts down to its
  /// end, a stopwatch counts up from its start and has no end to count to.
  Future<void> schedule(List<Cue> cues, {int leadMs, bool countUp});

  /// Holds the armed session where it is, without ending it: the cues stop,
  /// the platform's clock stops, and everything stays up to come back to.
  ///
  /// Not done by cancelling and re-scheduling. The buttons that call this are
  /// on a notification that outlives the UI, so the platform has to be able to
  /// do it without Dart — and it already holds the list, so it can.
  Future<void> pause();

  /// Picks the session back up where [pause] left it.
  Future<void> resume();

  /// Whether the platform's session is currently held.
  Future<bool> isPaused();

  /// Drops everything armed and ends the session.
  Future<void> cancel();

  /// Sets what the platform shows about the session — on Android, the text of
  /// the foreground-service notification, which is the only way to stop a
  /// shouting phone from the lock screen.
  ///
  /// Called again as each phase begins, while Dart is awake to call it.
  Future<void> describe(String title, String text);

  /// How long the native session has been running, or null when there is none.
  ///
  /// Native owns the clock, because it is the side that keeps running. The UI
  /// re-anchors to this after the app has been in the background.
  Future<int?> elapsedMs();

  /// Keeps the screen awake for the session: the belt to background audio's
  /// braces, and the fallback where background playback cannot be trusted.
  Future<void> keepAwake(bool on);

  /// Asks for permission to show the session notification. It only decides
  /// whether the user can see the session, never whether it runs.
  Future<void> askToNotify();

  /// Fires when the user stops the session from outside the app — the Stop
  /// button on the notification.
  Stream<void> get stopped;

  /// Fires when the session is paused or resumed from outside the app, with
  /// true for paused.
  Stream<bool> get pauseChanged;
}

/// A [CuePlayer] that makes no sound and remembers what it was asked to do.
///
/// Used by the tests, and usable by the app itself: on a device with no voice
/// the timer still runs, it just says nothing.
class FakeCuePlayer implements CuePlayer {
  FakeCuePlayer({this.hasVoice = true});

  final bool hasVoice;

  final List<List<Cue>> schedules = [];
  final List<List<Cue>> warmed = [];
  final List<String> descriptions = [];
  final List<bool> awake = [];
  int pauses = 0;
  int resumes = 0;
  bool fakePaused = false;

  /// Whether each schedule asked for a counting-up notification.
  final List<bool> countUps = [];
  int cancels = 0;
  int asks = 0;
  int? fakeElapsedMs;

  /// The most recent schedule, or null if nothing has been armed.
  List<Cue>? get lastSchedule => schedules.isEmpty ? null : schedules.last;

  @override
  Future<bool> available() async => hasVoice;

  @override
  Future<void> warm(List<Cue> cues) async => warmed.add(List.of(cues));

  @override
  Future<void> schedule(
    List<Cue> cues, {
    int leadMs = 0,
    bool countUp = false,
  }) async {
    schedules.add(List.of(cues));
    countUps.add(countUp);
  }

  @override
  Future<void> pause() async {
    pauses++;
    fakePaused = true;
  }

  @override
  Future<void> resume() async {
    resumes++;
    fakePaused = false;
  }

  @override
  Future<bool> isPaused() async => fakePaused;

  @override
  Future<void> cancel() async => cancels++;

  @override
  Future<void> describe(String title, String text) async =>
      descriptions.add('$title | $text');

  @override
  Future<int?> elapsedMs() async => fakeElapsedMs;

  @override
  Future<void> keepAwake(bool on) async => awake.add(on);

  @override
  Future<void> askToNotify() async => asks++;

  @override
  Stream<void> get stopped => const Stream<void>.empty();

  @override
  Stream<bool> get pauseChanged => const Stream<bool>.empty();
}
