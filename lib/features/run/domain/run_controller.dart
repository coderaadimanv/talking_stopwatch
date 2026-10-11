import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/session/session.dart';
import '../../../core/timeline/timeline.dart';
import '../../../core/timeline/workout.dart';

/// What a phase is called on screen. Not the same as what is spoken: the voice
/// says "go" because it is shorter to hear, the screen says "Work" because it
/// is clearer to read.
String phaseLabel(SegmentKind kind, {TimerKind of = TimerKind.workout}) =>
    switch (of) {
      TimerKind.workout => switch (kind) {
        SegmentKind.prepare => 'Get ready',
        SegmentKind.work => 'Work',
        SegmentKind.rest => 'Rest',
        SegmentKind.breakBetween => 'Break',
        SegmentKind.cooldown => 'Cool down',
      },
      // A focus session has two phases worth naming and the screen says them
      // quietly. "Cool down" is the long break here: it is the phase after
      // the last block rather than one between blocks.
      TimerKind.focus => switch (kind) {
        SegmentKind.prepare => 'Starting',
        SegmentKind.work => 'Focus',
        SegmentKind.rest => 'Break',
        SegmentKind.breakBetween => 'Long break',
        SegmentKind.cooldown => 'Long break',
      },
    };

/// The line under the phase name.
///
/// An exercise's own name if it has one, because that is the most useful thing
/// the screen can say; otherwise a word about the phase, which at least tells
/// you the screen is alive.
String phaseCaption(Segment segment) {
  if (segment.kind == SegmentKind.work && segment.label.isNotEmpty) {
    return segment.label.toUpperCase();
  }
  return switch (segment.kind) {
    SegmentKind.prepare => 'GET SET',
    SegmentKind.work => 'KEEP GOING',
    SegmentKind.rest => 'BREATHE',
    SegmentKind.breakBetween => 'TAKE A BREATHER',
    SegmentKind.cooldown => 'EASE DOWN',
  };
}

/// What the notification says under the title.
///
/// In the mode's own words: a focus session on the lock screen saying
/// "Work · round 1" would be the one place the app forgot which of the two it
/// was running.
String notificationText(Segment? segment, TimerKind kind) {
  if (segment == null) return 'Done';
  final label = phaseLabel(segment.kind, of: kind);
  if (segment.kind != SegmentKind.work || segment.index <= 0) return label;
  final unit = kind == TimerKind.focus ? 'block' : 'round';
  return '$label · $unit ${segment.index}';
}

class RunState {
  const RunState({required this.session, this.preparing = false});

  final SessionState session;

  /// True while phrases are being rendered. Only ever on the first run after
  /// an install or a voice change; after that the clips are cached.
  final bool preparing;

  RunState copyWith({SessionState? session, bool? preparing}) => RunState(
    session: session ?? this.session,
    preparing: preparing ?? this.preparing,
  );
}

/// Drives the run screen.
///
/// The ticker here only redraws; it never makes a sound. Every cue was handed
/// to the platform when the session was armed, which is why the workout keeps
/// its timing when this timer stops running — as it does the moment the screen
/// goes off.
class RunController extends Notifier<RunState> {
  late final Session _session;
  Timer? _ticker;
  String _described = '';

  @override
  RunState build() {
    _session = Session(
      player: ref.read(cuePlayerProvider),
      clock: ref.read(clockProvider),
    );

    final player = ref.read(cuePlayerProvider);

    // Stop and Pause, from the notification on the lock screen.
    final stopped = player.stopped.listen((_) => stop());
    final paused = player.pauseChanged.listen(followPlatformPause);

    ref.onDispose(() {
      _ticker?.cancel();
      stopped.cancel();
      paused.cancel();
    });

    // A workout may already be running, started by a screen that no longer
    // exists. Find out before drawing anything.
    unawaited(restore());

    return RunState(session: _session.state);
  }

  Workout get _workout => ref.read(workoutProvider);
  String get _title => _workout.name.isEmpty ? 'Workout' : _workout.name;

  /// Takes over a workout the platform is already running.
  ///
  /// The foreground service outlives the UI, so the cues can still be playing
  /// long after the screen that started them was destroyed. Without this the
  /// app comes back saying "Start" over a workout that is plainly still
  /// counting, and starting again would cancel it and begin from the top.
  Future<void> restore() async {
    final data = ref.read(appDataProvider);
    final id = data.runningWorkoutId;
    if (id == null) return;

    final player = ref.read(cuePlayerProvider);
    final elapsed = await player.elapsedMs();
    if (elapsed == null) {
      // The process died with the session. Nothing to come back to.
      ref.read(appDataProvider.notifier).setRunning(null);
      return;
    }

    final workout = data.presets.where((w) => w.id == id).firstOrNull;
    if (workout == null) return;

    ref.read(selectedWorkoutIdProvider.notifier).select(id);
    _session.load(workout, offsetMs: data.settings.offsetMs);
    _session.adopt(elapsedMs: elapsed, paused: await player.isPaused());

    if (_session.state.status == SessionStatus.running) _beginTicking();
    _refresh();
  }

  /// The notification's Pause button, which reaches the platform directly and
  /// tells us afterwards.
  void followPlatformPause(bool paused) {
    if (paused) {
      _session.holdForPlatform();
      _stopTicking();
    } else {
      _session.releaseForPlatform();
      _beginTicking();
    }
    _refresh();
  }

  Future<void> start() async {
    final data = ref.read(appDataProvider);
    _session.load(_workout, offsetMs: data.settings.offsetMs);

    final player = ref.read(cuePlayerProvider);
    await player.askToNotify();
    await player.describe(_title, 'Starting');
    if (data.settings.keepScreenOn) await player.keepAwake(true);
    // Focus only, and only when asked for. A workout wants to be heard over
    // music, not to silence the phone it is playing from.
    if (_workout.kind == TimerKind.focus && data.settings.silenceDuringFocus) {
      await player.silence(true);
    }

    // Rendering the phrases happens inside start(), and on a first run it can
    // take a few seconds, so the screen says what it is waiting for.
    state = state.copyWith(preparing: true);
    try {
      await _session.start();
    } finally {
      state = state.copyWith(preparing: false);
    }
    ref.read(appDataProvider.notifier).setRunning(_workout.id);
    _beginTicking();
  }

  Future<void> pause() async {
    await _session.pause();
    _stopTicking();
    _refresh();
  }

  Future<void> resume() async {
    await _session.resume();
    _beginTicking();
  }

  Future<void> skip() async {
    await _session.skip();
    _refresh();
  }

  Future<void> stop() async {
    await _session.stop();
    _stopTicking();
    _described = '';
    ref.read(appDataProvider.notifier).setRunning(null);
    final player = ref.read(cuePlayerProvider);
    await player.keepAwake(false);
    // Unconditional, and harmless when nothing was silenced: the platform
    // only gives back what it wrote down.
    await player.silence(false);
    _refresh();
  }

  /// Called when the app comes back to the front, where Dart may have been
  /// frozen for twenty minutes while the cues carried on without it.
  Future<void> resync() async {
    await _session.resync();
    _refresh();
  }

  void _beginTicking() {
    _ticker?.cancel();
    // Fast enough that the big number never looks like it skipped a second.
    _ticker = Timer.periodic(const Duration(milliseconds: 100), (_) => _tick());
    _tick();
  }

  void _stopTicking() {
    _ticker?.cancel();
    _ticker = null;
  }

  void _tick() => _refresh();

  /// Publishes the session, and clears up after it if it has ended.
  ///
  /// One place rather than two: the finish used to be handled only on a tick,
  /// so a workout that ran out while the app was away stayed written down as
  /// running.
  void _refresh() {
    final session = _session.state;
    state = state.copyWith(session: session);
    _describe(session);
    if (session.status == SessionStatus.finished) {
      _stopTicking();
      ref.read(appDataProvider.notifier).setRunning(null);
      ref.read(cuePlayerProvider)
        ..keepAwake(false)
        ..silence(false);
    }
  }

  /// Keeps the notification honest as the phases change, so a glance at the
  /// lock screen says something true.
  void _describe(SessionState session) {
    final text = notificationText(session.segment, _workout.kind);
    if (text == _described) return;
    _described = text;
    ref.read(cuePlayerProvider).describe(_title, text);
  }
}

final runProvider = NotifierProvider<RunController, RunState>(
  RunController.new,
);
