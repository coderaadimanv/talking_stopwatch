import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/audio/cue_player.dart';
import '../../../core/clock/clock.dart';
import '../../../core/cues/cue.dart';
import '../../../core/cues/plan_cues.dart';
import '../../../core/cues/plan_stopwatch.dart';

class StopwatchState {
  const StopwatchState({
    this.running = false,
    this.elapsedMs = 0,
    this.laps = const [],
    this.preparing = false,
  });

  final bool running;
  final int elapsedMs;
  final List<int> laps;
  final bool preparing;

  /// Running, or paused part-way through: either way there is something to
  /// reset, which is what tells Reset from a fresh start.
  bool get started => running || elapsedMs > 0;
}

/// The count-up stopwatch.
///
/// A sibling of [Session] rather than a use of it: a workout has a timeline
/// with an end, and a stopwatch has neither. What they share is the rule that
/// Dart owns the clock and the platform is only ever handed cues.
///
/// The one real difference is that an endless script cannot be armed in one
/// go, so it goes down ten minutes at a time and is extended while there is
/// still five minutes in hand. If the app is frozen past the end of a window
/// the stopwatch stops talking until it is opened again — the count is never
/// wrong, only the voice goes quiet.
class StopwatchController extends Notifier<StopwatchState> {
  Timer? _ticker;

  bool _running = false;
  bool _preparing = false;
  int _elapsedAtAnchor = 0;
  int _anchorMs = 0;
  List<int> _laps = const [];

  List<Cue> _cues = const [];
  int _armedUntil = 0;
  bool _arming = false;

  Clock get _clock => ref.read(clockProvider);
  CuePlayer get _player => ref.read(cuePlayerProvider);

  @override
  StopwatchState build() {
    ref.onDispose(() => _ticker?.cancel());
    return const StopwatchState();
  }

  int get _elapsed {
    final raw = _running
        ? _elapsedAtAnchor + (_clock.nowMs - _anchorMs)
        : _elapsedAtAnchor;
    return raw < 0 ? 0 : raw;
  }

  /// Starts, or carries on from a pause.
  Future<void> start() async {
    if (_running) return;

    // Plan and render before the clock starts, so a first run's rendering
    // does not come out of the user's time.
    _plan();
    _preparing = true;
    _publish();
    await _player.warm(_cues);
    _preparing = false;

    _anchorMs = _clock.nowMs;
    _running = true;

    if (ref.read(appDataProvider).settings.keepScreenOn) {
      await _player.keepAwake(true);
    }
    await _player.describe('Stopwatch', 'Running');
    await _player.schedule(remainingFrom(_cues, _elapsed), countUp: true);

    _publish();
    _beginTicking();
  }

  Future<void> pause() async {
    if (!_running) return;
    _elapsedAtAnchor = _elapsed;
    _running = false;
    _stopTicking();
    await _player.cancel();
    _publish();
  }

  /// Marks the time. Shown, not spoken: a lap time is not known until it
  /// happens, and this app never speaks anything it has not already rendered.
  void lap() {
    if (!_running) return;
    _laps = [..._laps, _elapsed];
    _publish();
  }

  Future<void> reset() async {
    _stopTicking();
    _running = false;
    _elapsedAtAnchor = 0;
    _laps = const [];
    _armedUntil = 0;
    _cues = const [];
    await _player.cancel();
    await _player.keepAwake(false);
    _publish();
  }

  /// Driven by the ticker while the screen is up. Redraws, and tops up the
  /// armed window before it runs out.
  void tick() {
    _publish();
    if (_running &&
        needsExtending(elapsedMs: _elapsed, armedUntilMs: _armedUntil)) {
      unawaited(_extend());
    }
  }

  Future<void> _extend() async {
    if (_arming) return;
    _arming = true;
    try {
      _plan();
      await _player.warm(_cues);
      // Worked out after the warm, not before: rendering takes time, and the
      // schedule has to be relative to when it is actually armed.
      await _player.schedule(remainingFrom(_cues, _elapsed), countUp: true);
    } finally {
      _arming = false;
    }
  }

  void _plan() {
    final settings = ref.read(appDataProvider).settings;
    _armedUntil = _elapsed + stopwatchWindowMs;
    _cues = planStopwatchCues(
      everySeconds: settings.stopwatchAnnounceSeconds,
      untilMs: _armedUntil,
      offsetMs: settings.offsetMs,
      sound: settings.sounds.elapsed,
      pack: settings.sounds.pack,
    );
  }

  void _beginTicking() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(milliseconds: 100), (_) => tick());
  }

  void _stopTicking() {
    _ticker?.cancel();
    _ticker = null;
  }

  void _publish() => state = StopwatchState(
    running: _running,
    elapsedMs: _elapsed,
    laps: _laps,
    preparing: _preparing,
  );
}

final stopwatchProvider =
    NotifierProvider<StopwatchController, StopwatchState>(
      StopwatchController.new,
    );
