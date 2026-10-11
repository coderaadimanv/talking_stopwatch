import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/session/session.dart';
import '../../../core/timeline/timeline.dart';
import '../../../core/timeline/workout.dart';

/// What a phase is called on screen. Not the same as what is spoken: the voice
/// says "go" because it is shorter to hear, the screen says "Work" because it
/// is clearer to read.
String phaseLabel(SegmentKind kind) => switch (kind) {
  SegmentKind.prepare => 'Get ready',
  SegmentKind.work => 'Work',
  SegmentKind.rest => 'Rest',
  SegmentKind.breakBetween => 'Break',
  SegmentKind.cooldown => 'Cool down',
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

    // Stop, from the notification on the lock screen.
    final stopped = ref
        .read(cuePlayerProvider)
        .stopped
        .listen((_) => stop());

    ref.onDispose(() {
      _ticker?.cancel();
      stopped.cancel();
    });

    return RunState(session: _session.state);
  }

  Workout get _workout => ref.read(workoutProvider);
  String get _title => _workout.name.isEmpty ? 'Workout' : _workout.name;

  Future<void> start() async {
    final data = ref.read(appDataProvider);
    _session.load(_workout, offsetMs: data.settings.offsetMs);

    final player = ref.read(cuePlayerProvider);
    await player.askToNotify();
    await player.describe(_title, 'Starting');
    if (data.settings.keepScreenOn) await player.keepAwake(true);

    // Rendering the phrases happens inside start(), and on a first run it can
    // take a few seconds, so the screen says what it is waiting for.
    state = state.copyWith(preparing: true);
    try {
      await _session.start();
    } finally {
      state = state.copyWith(preparing: false);
    }
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
    await ref.read(cuePlayerProvider).keepAwake(false);
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

  void _tick() {
    final session = _session.state;
    state = state.copyWith(session: session);
    _describe(session);
    if (session.status == SessionStatus.finished) {
      _stopTicking();
      ref.read(cuePlayerProvider).keepAwake(false);
    }
  }

  void _refresh() {
    final session = _session.state;
    state = state.copyWith(session: session);
    _describe(session);
  }

  /// Keeps the notification honest as the phases change, so a glance at the
  /// lock screen says something true.
  void _describe(SessionState session) {
    final segment = session.segment;
    final text = segment == null
        ? 'Done'
        : segment.kind == SegmentKind.work && segment.index > 0
              ? '${phaseLabel(segment.kind)} · round ${segment.index}'
              : phaseLabel(segment.kind);
    if (text == _described) return;
    _described = text;
    ref.read(cuePlayerProvider).describe(_title, text);
  }
}

final runProvider = NotifierProvider<RunController, RunState>(
  RunController.new,
);
