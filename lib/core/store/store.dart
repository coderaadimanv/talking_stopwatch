import 'dart:convert';
import 'dart:io';

import '../timeline/workout.dart';

/// The version of the file layout. Bumped only when old files need reading
/// differently; a file from the future is ignored rather than guessed at.
const storeSchema = 1;

/// Settings that are not part of any one workout.
class AppSettings {
  const AppSettings({
    this.offsetMs = 0,
    this.keepScreenOn = false,
    this.stopwatchAnnounceSeconds = 60,
  });

  factory AppSettings.fromJson(Map<String, Object?> json) => AppSettings(
    offsetMs: json['offsetMs'] as int? ?? 0,
    keepScreenOn: json['keepScreenOn'] as bool? ?? false,
    stopwatchAnnounceSeconds: json['stopwatchAnnounce'] as int? ?? 60,
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

  AppSettings copyWith({
    int? offsetMs,
    bool? keepScreenOn,
    int? stopwatchAnnounceSeconds,
  }) => AppSettings(
    offsetMs: offsetMs ?? this.offsetMs,
    keepScreenOn: keepScreenOn ?? this.keepScreenOn,
    stopwatchAnnounceSeconds:
        stopwatchAnnounceSeconds ?? this.stopwatchAnnounceSeconds,
  );

  Map<String, Object?> toJson() => {
    'offsetMs': offsetMs,
    'keepScreenOn': keepScreenOn,
    'stopwatchAnnounce': stopwatchAnnounceSeconds,
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

  /// What the app starts life with, so the first screen is usable rather than
  /// empty: the interval everybody tries first.
  static AppData get initial => AppData(
    presets: [
      Workout.simple(
        id: 'default-30-10',
        name: '30 / 10 × 8',
        workSeconds: 30,
        restSeconds: 10,
        rounds: 8,
      ),
    ],
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
