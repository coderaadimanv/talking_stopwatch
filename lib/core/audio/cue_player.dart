import '../cues/cue.dart';

/// Plays cues at exact times, on the other side of the platform channel.
///
/// The contract is deliberately tiny, and it holds no idea of a workout:
/// it is handed a list of "say this, that many milliseconds from now" and it
/// plays them. All workout state stays in Dart. That is what lets the native
/// side keep talking while Dart is frozen with the screen off — it already has
/// the whole list and needs nothing more from us.
abstract class CuePlayer {
  /// Renders anything in [cues] that is not in the audio cache yet.
  ///
  /// Called before a session starts, so the first "go" never waits on the
  /// speech engine. Safe to call with phrases that are already cached.
  Future<void> warm(List<Cue> cues);

  /// Arms the whole list and starts the session clock.
  ///
  /// [leadMs] is the head start the native side gets before cue time zero, to
  /// cover the channel round trip and the first buffer. Replaces any schedule
  /// already armed.
  Future<void> schedule(List<Cue> cues, {int leadMs});

  /// Drops everything armed and ends the session.
  Future<void> cancel();

  /// How long the native session has been running, or null when there is none.
  ///
  /// Native owns the clock, because it is the side that keeps running. The UI
  /// re-anchors to this after the app has been in the background.
  Future<int?> elapsedMs();
}

/// A [CuePlayer] that makes no sound and remembers what it was asked to do.
///
/// Used by the tests, and by the app itself when a device has no usable voice:
/// the timer still runs, it just says nothing.
class FakeCuePlayer implements CuePlayer {
  final List<List<Cue>> schedules = [];
  final List<List<Cue>> warmed = [];
  int cancels = 0;
  int? fakeElapsedMs;

  /// The most recent schedule, or null if nothing has been armed.
  List<Cue>? get lastSchedule => schedules.isEmpty ? null : schedules.last;

  @override
  Future<void> warm(List<Cue> cues) async => warmed.add(List.of(cues));

  @override
  Future<void> schedule(List<Cue> cues, {int leadMs = 0}) async =>
      schedules.add(List.of(cues));

  @override
  Future<void> cancel() async => cancels++;

  @override
  Future<int?> elapsedMs() async => fakeElapsedMs;
}
