import 'dart:math';

final _random = Random();

/// An id for a newly made workout.
///
/// Time first so ids sort roughly by age, then randomness so two made in the
/// same microsecond cannot collide. Nothing here is shared with a server, so
/// it does not need to be a UUID — it needs to be unique on one phone, and
/// short enough to read in a file.
String newId() {
  final at = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
  final salt = _random.nextInt(1 << 24).toRadixString(36).padLeft(5, '0');
  return '$at-$salt';
}
