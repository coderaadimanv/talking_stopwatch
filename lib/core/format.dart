/// Times on screen, in the shape a person reads them.
library;

/// A countdown: `0:22`, `1:05`, and `1:00:00` only once there is an hour to
/// show. Rounds up, because a timer showing 0:00 while still running is a lie.
String countdown(int ms) {
  final total = (ms / 1000).ceil();
  return _clock(total < 0 ? 0 : total);
}

/// A count-up stopwatch: the same shape, but rounded down, because 0:00 is
/// exactly right for the first second of a stopwatch.
String elapsed(int ms) => _clock(ms < 0 ? 0 : ms ~/ 1000);

String _clock(int seconds) {
  final hours = seconds ~/ 3600;
  final minutes = (seconds % 3600) ~/ 60;
  final rest = seconds % 60;
  final tail = '${minutes.toString().padLeft(hours > 0 ? 2 : 1, '0')}'
      ':${rest.toString().padLeft(2, '0')}';
  return hours > 0 ? '$hours:$tail' : tail;
}
