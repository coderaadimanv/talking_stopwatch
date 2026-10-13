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

  /// Whether the session would actually be visible: true when a notification
  /// can be shown, false when every route to one is switched off, and **null
  /// where the question does not apply** — iOS, where the lock-screen controls
  /// come with the audio session and no permission is involved, and any
  /// platform the native half does not answer for.
  ///
  /// Null and false are deliberately different. A workout runs and talks
  /// either way; the only thing a denial costs is the lock screen, so this
  /// exists to explain one that stayed empty, and that is worth saying only
  /// where it is actually true.
  Future<bool?> canNotify();

  /// Whether the phone can be silenced for a session: true when the app has
  /// been allowed to, false when it has not been allowed yet, and **null
  /// where it is not possible at all** — iOS, where no app can turn a Focus
  /// on, and any platform the native half does not answer for.
  ///
  /// The same three-way answer as [canNotify], for the same reason: false is
  /// something the user can fix and null is something nobody can, and a
  /// switch offering the second would be a lie.
  Future<bool?> canSilence();

  /// Silences the phone for the session, and gives back exactly what was
  /// there before when it ends.
  ///
  /// The platform keeps that promise on its own, because the session outlives
  /// the UI: the Stop button on the notification can end a session with no
  /// Dart left alive to call this with false.
  Future<void> silence(bool on);

  /// Opens the system screen where the app can be allowed to silence the
  /// phone. Do Not Disturb is a special access, granted there and nowhere
  /// else — there is no prompt to show.
  Future<void> openSilenceSettings();

  /// Which tones the user has replaced with a sound of their own, as the
  /// tone's key to the name of what they chose.
  ///
  /// **Null where picking is not possible at all** — iOS, where no app can
  /// read or offer the system's sounds, and any platform the native half does
  /// not answer for. The same three-way answer as [canNotify] and
  /// [canSilence], and for the same reason: an empty map means "none yet" and
  /// null means "never", and only one of those should put a row on a screen.
  Future<Map<String, String>?> ownSounds();

  /// Opens the system's sound picker for one tone, and answers what the user
  /// chose — or null if they backed out, or if there is no picker here.
  ///
  /// The sound is copied as it is chosen rather than remembered by reference;
  /// see the platform half for why that is not an optimisation but the whole
  /// design.
  Future<String?> pickSound(String toneKey);

  /// Puts the app's own tone back.
  Future<void> clearSound(String toneKey);

  /// Opens the system screen where the session notification can be switched
  /// back on.
  ///
  /// Not another in-app prompt: Android spends its one notification prompt on
  /// the first refusal and a later request does nothing at all, silently. The
  /// system screen always works.
  Future<void> openNotifySettings();

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

  /// What [canNotify] answers. Null is the iOS answer: not a question here.
  bool? notifyAllowed = true;
  int notifySettingsOpened = 0;

  /// What [canSilence] answers, and every [silence] it was asked for.
  bool? silenceAllowed = true;
  final List<bool> silences = [];
  int silenceSettingsOpened = 0;

  /// What [ownSounds] answers. Null is the iOS answer: not a question here.
  Map<String, String>? own = const {};

  /// What the next [pickSound] comes back with, and every key it was asked
  /// for.
  String? picks;
  final List<String> picked = [];
  final List<String> cleared = [];

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
  Future<bool?> canNotify() async => notifyAllowed;

  @override
  Future<void> openNotifySettings() async => notifySettingsOpened++;

  @override
  Future<bool?> canSilence() async => silenceAllowed;

  @override
  Future<void> silence(bool on) async => silences.add(on);

  @override
  Future<void> openSilenceSettings() async => silenceSettingsOpened++;

  @override
  Future<Map<String, String>?> ownSounds() async => own;

  @override
  Future<String?> pickSound(String toneKey) async {
    picked.add(toneKey);
    if (picks != null) own = {...?own, toneKey: picks!};
    return picks;
  }

  @override
  Future<void> clearSound(String toneKey) async {
    cleared.add(toneKey);
    own = {...?own}..remove(toneKey);
  }

  @override
  Stream<void> get stopped => const Stream<void>.empty();

  @override
  Stream<bool> get pauseChanged => const Stream<bool>.empty();
}
