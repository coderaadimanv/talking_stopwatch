import 'dart:async';

import 'package:flutter/services.dart';

import '../cues/cue.dart';
import 'cue_player.dart';

/// The real [CuePlayer]: hands the cue list to the platform and lets it play.
///
/// Every call degrades to silence rather than throwing. A phone with no speech
/// engine, or a platform where the native half is not written yet, should still
/// run the timer — it just will not talk. An exception here would take the
/// whole workout down with it.
class PlatformCuePlayer implements CuePlayer {
  PlatformCuePlayer({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(channelName) {
    _channel.setMethodCallHandler(_onCall);
  }

  static const channelName = 'com.anvuman.cadent/cues';

  final MethodChannel _channel;
  final _fired = StreamController<String>.broadcast();
  final _stopped = StreamController<void>.broadcast();
  final _pauseChanged = StreamController<bool>.broadcast();

  String _title = 'Workout';
  String _text = '';

  /// Keys the speech engine could not render. Those cues stay silent.
  final Set<String> unrenderable = {};

  /// The key of each cue as it plays.
  Stream<String> get fired => _fired.stream;

  @override
  Stream<void> get stopped => _stopped.stream;

  @override
  Stream<bool> get pauseChanged => _pauseChanged.stream;

  Future<void> _onCall(MethodCall call) async {
    switch (call.method) {
      case 'fired':
        final key = call.arguments;
        if (key is String) _fired.add(key);
      case 'stopped':
        _stopped.add(null);
      case 'paused':
        final paused = call.arguments;
        if (paused is bool) _pauseChanged.add(paused);
    }
  }

  @override
  Future<bool> available() async => await _invoke<bool>('available') ?? false;

  @override
  Future<void> warm(List<Cue> cues) async {
    // One entry per distinct phrase: a 30/10 x 8 workout has 73 cues but only
    // about 20 different things to say.
    final phrases = <String, String>{};
    for (final cue in cues) {
      phrases[cue.key] = cue.text;
    }
    if (phrases.isEmpty) return;

    final failed = await _invoke<List<Object?>>('warm', {'phrases': phrases});
    unrenderable
      ..clear()
      ..addAll(failed?.whereType<String>() ?? const []);
  }

  @override
  Future<void> schedule(
    List<Cue> cues, {
    int leadMs = 0,
    bool countUp = false,
  }) async {
    if (cues.isEmpty) return;
    // Two parallel lists rather than a list of maps: it crosses the channel as
    // two primitive arrays instead of several hundred small dictionaries.
    await _invoke<Object?>('schedule', {
      'at': [for (final c in cues) c.atMs],
      'keys': [for (final c in cues) c.key],
      'leadMs': leadMs,
      'title': _title,
      'text': _text,
      'countUp': countUp,
    });
  }

  @override
  Future<void> pause() => _invoke<void>('pause');

  @override
  Future<void> resume() => _invoke<void>('resume');

  @override
  Future<bool> isPaused() async => await _invoke<bool>('isPaused') ?? false;

  @override
  Future<void> cancel() => _invoke<void>('cancel');

  @override
  Future<void> describe(String title, String text) async {
    _title = title;
    _text = text;
    await _invoke<void>('describe', {'title': title, 'text': text});
  }

  @override
  Future<int?> elapsedMs() => _invoke<int>('elapsed');

  @override
  Future<void> keepAwake(bool on) => _invoke<void>('keepAwake', {'on': on});

  @override
  Future<void> askToNotify() => _invoke<void>('askToNotify');

  @override
  Future<bool?> canNotify() => _invoke<bool>('canNotify');

  @override
  Future<void> openNotifySettings() => _invoke<void>('openNotifySettings');

  @override
  Future<bool?> canSilence() => _invoke<bool>('canSilence');

  @override
  Future<void> silence(bool on) => _invoke<void>('silence', {'on': on});

  @override
  Future<void> openSilenceSettings() => _invoke<void>('openSilenceSettings');

  Future<T?> _invoke<T>(String method, [Map<String, Object?>? args]) async {
    try {
      return await _channel.invokeMethod<T>(method, args);
    } on MissingPluginException {
      return null; // No native half here: run silently.
    } on PlatformException {
      return null;
    }
  }

  void dispose() {
    _fired.close();
    _stopped.close();
    _pauseChanged.close();
  }
}
