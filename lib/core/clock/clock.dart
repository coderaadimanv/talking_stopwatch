/// A monotonic millisecond clock.
///
/// Never the wall clock: a session measures how long it has been running, and
/// the wall clock can jump backwards when the network corrects it or the user
/// changes the time zone mid-workout.
abstract class Clock {
  int get nowMs;
}

/// The real clock, counting from the moment it is created.
class MonotonicClock implements Clock {
  MonotonicClock() {
    _stopwatch.start();
  }

  final _stopwatch = Stopwatch();

  @override
  int get nowMs => _stopwatch.elapsedMilliseconds;
}

/// A clock that only moves when a test says so.
class FakeClock implements Clock {
  FakeClock([this.nowMs = 0]);

  @override
  int nowMs;

  void advance(int ms) => nowMs += ms;
}
