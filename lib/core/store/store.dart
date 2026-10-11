import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../timeline/workout.dart';

/// The version of the file layout. Bumped only when old files need reading
/// differently; a file from the future is ignored rather than guessed at.
const storeSchema = 1;

/// Whether a fresh install keeps the screen on during a workout.
///
/// True on iOS, and only there. Android keeps the cues coming from a
/// foreground service holding a wake lock, which is about as certain as the
/// platform allows. iOS has no equivalent: an app stays alive in the
/// background because it is playing audio, and how long that lasts has moved
/// between iOS versions. Until it is proven on the phone it is meant for, the
/// screen staying on is the fallback that cannot fail — and it is one switch
/// away in settings once it is proven unnecessary.
///
/// A default, not a rule: it is only consulted on a first run, so turning it
/// off sticks.
final bool keepScreenOnByDefault = defaultTargetPlatform == TargetPlatform.iOS;

/// Settings that are not part of any one workout.
class AppSettings {
  const AppSettings({
    this.offsetMs = 0,
    this.keepScreenOn = false,
    this.stopwatchAnnounceSeconds = 60,
    this.silenceDuringFocus = false,
  });

  factory AppSettings.fromJson(Map<String, Object?> json) => AppSettings(
    offsetMs: json['offsetMs'] as int? ?? 0,
    keepScreenOn: json['keepScreenOn'] as bool? ?? false,
    stopwatchAnnounceSeconds: json['stopwatchAnnounce'] as int? ?? 60,
    silenceDuringFocus: json['silenceDuringFocus'] as bool? ?? false,
  );

  /// Calibration for output lag. Bluetooth earbuds run 150–300 ms behind and
  /// will not say how far, so this is a slider the user sets by ear. Negative
  /// speaks earlier.
  final int offsetMs;

  /// Keep the screen awake for the whole session. The belt to the braces of
  /// background audio.
  final bool keepScreenOn;

  /// How often the count-up stopwatch reads the time out. Zero is never.
  final int stopwatchAnnounceSeconds;

  /// Put the phone in Do Not Disturb for a focus session, and take it out
  /// afterwards. Off by default: silencing someone's phone is not something
  /// to do because they opened a timer. Android only — no iOS app can.
  final bool silenceDuringFocus;

  AppSettings copyWith({
    int? offsetMs,
    bool? keepScreenOn,
    int? stopwatchAnnounceSeconds,
    bool? silenceDuringFocus,
  }) => AppSettings(
    offsetMs: offsetMs ?? this.offsetMs,
    keepScreenOn: keepScreenOn ?? this.keepScreenOn,
    stopwatchAnnounceSeconds:
        stopwatchAnnounceSeconds ?? this.stopwatchAnnounceSeconds,
    silenceDuringFocus: silenceDuringFocus ?? this.silenceDuringFocus,
  );

  Map<String, Object?> toJson() => {
    'offsetMs': offsetMs,
    'keepScreenOn': keepScreenOn,
    'stopwatchAnnounce': stopwatchAnnounceSeconds,
    'silenceDuringFocus': silenceDuringFocus,
  };
}

/// Everything the app keeps between runs. It is small, so it lives in one
/// file: a database here would be machinery with nothing to do.
class AppData {
  const AppData({
    this.presets = const [],
    this.settings = const AppSettings(),
    this.runningWorkoutId,
  });

  factory AppData.fromJson(Map<String, Object?> json) => AppData(
    runningWorkoutId: json['running'] as String?,
    presets: [
      for (final p in (json['presets'] as List<Object?>? ?? const []))
        Workout.fromJson(p as Map<String, Object?>),
    ],
    settings: AppSettings.fromJson(
      json['settings'] as Map<String, Object?>? ?? const {},
    ),
  );

  /// What the app starts life with, so neither mode opens on an empty list:
  /// the interval everybody tries first, and the pomodoro.
  static AppData get initial => AppData(
    presets: [
      Workout.simple(
        id: 'default-30-10',
        name: '30 / 10 × 8',
        workSeconds: 30,
        restSeconds: 10,
        rounds: 8,
      ),
      Workout.focus(
        id: 'default-pomodoro',
        name: '25 / 5 × 4',
        focusMinutes: 25,
        breakMinutes: 5,
        blocks: 4,
        longBreakMinutes: 15,
      ),
    ],
    settings: AppSettings(keepScreenOn: keepScreenOnByDefault),
  );

  final List<Workout> presets;
  final AppSettings settings;

  /// The workout that was running when the app last wrote this file.
  ///
  /// Written down because the UI can die while the workout carries on, and
  /// the platform deliberately knows nothing about workouts — it holds a list
  /// of cues and a clock. This is the one thread back from one to the other.
  final String? runningWorkoutId;

  AppData copyWith({
    List<Workout>? presets,
    AppSettings? settings,
    String? runningWorkoutId,
    bool clearRunning = false,
  }) => AppData(
    presets: presets ?? this.presets,
    settings: settings ?? this.settings,
    runningWorkoutId: clearRunning
        ? null
        : runningWorkoutId ?? this.runningWorkoutId,
  );

  Map<String, Object?> toJson() => {
    'schema': storeSchema,
    'presets': [for (final p in presets) p.toJson()],
    'settings': settings.toJson(),
    if (runningWorkoutId != null) 'running': runningWorkoutId,
  };
}

/// Reads and writes the one JSON file.
///
/// A phone can be unplugged, or run out of space, in the middle of a write, so
/// a save goes to a temporary file and is renamed over the real one. Rename is
/// atomic: the file on disk is either entirely the old data or entirely the
/// new, never half of each.
class Store {
  Store(this.file);

  final File file;

  /// Reads the file, falling back to [AppData.initial] when there is nothing
  /// readable there. Losing presets is bad; refusing to start is worse.
  Future<AppData> load() async {
    try {
      if (!await file.exists()) return AppData.initial;
      final json = jsonDecode(await file.readAsString());
      if (json is! Map<String, Object?>) return AppData.initial;
      if (json['schema'] != storeSchema) return AppData.initial;
      final data = AppData.fromJson(json);
      // Restore the starter preset if the list has been emptied, but keep the
      // settings that were read — they are not the thing that went missing.
      return data.presets.isEmpty
          ? data.copyWith(presets: AppData.initial.presets)
          : data;
    } on FormatException {
      return AppData.initial;
    } on FileSystemException {
      return AppData.initial;
    } on TypeError {
      // A hand-edited file with the right schema but the wrong shapes.
      return AppData.initial;
    }
  }

  Future<void> save(AppData data) async {
    final temp = File('${file.path}.writing');
    await temp.parent.create(recursive: true);
    await temp.writeAsString(jsonEncode(data.toJson()), flush: true);
    await temp.rename(file.path);
  }
}
