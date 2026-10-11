import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cadent/core/audio/platform_cue_player.dart';
import 'package:cadent/core/cues/cue.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel(PlatformCuePlayer.channelName);
  final calls = <MethodCall>[];
  Object? reply;
  Object? Function(MethodCall)? onCall;

  late PlatformCuePlayer player;

  setUp(() {
    calls.clear();
    reply = null;
    onCall = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          if (onCall != null) return onCall!(call);
          return reply;
        });
    player = PlatformCuePlayer();
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    player.dispose();
  });

  MethodCall callNamed(String name) =>
      calls.firstWhere((c) => c.method == name);

  const cues = [
    Cue(atMs: 0, text: 'Ready', priority: CuePriority.phaseWord),
    Cue(atMs: 7000, text: 'three', priority: CuePriority.countdown),
    Cue(atMs: 10000, text: 'Go, round 1', priority: CuePriority.phaseWord),
    Cue(atMs: 17000, text: 'three', priority: CuePriority.countdown),
  ];

  group('warm', () {
    test('sends one entry per distinct phrase, keyed by its file name', () async {
      reply = <Object?>[];
      await player.warm(cues);

      final phrases =
          callNamed('warm').arguments['phrases'] as Map<Object?, Object?>;
      // "three" appears twice in the cue list but is one clip.
      expect(phrases.length, 3);
      expect(phrases[cues[1].key], 'three');
      expect(phrases[cues[2].key], 'Go, round 1');
    });

    test('remembers the phrases the engine could not render', () async {
      reply = <Object?>[cues[2].key];
      await player.warm(cues);
      expect(player.unrenderable, {cues[2].key});
    });

    test('says nothing at all for an empty script', () async {
      await player.warm(const []);
      expect(calls, isEmpty);
    });
  });

  group('schedule', () {
    test('sends times and keys as two parallel lists', () async {
      await player.describe('Tabata', 'Work');
      await player.schedule(cues, leadMs: 0);

      final args = callNamed('schedule').arguments as Map<Object?, Object?>;
      expect(args['at'], [0, 7000, 10000, 17000]);
      expect(args['keys'], [for (final c in cues) c.key]);
      expect(args['leadMs'], 0);
      // The platform shows whatever it was last told to show.
      expect(args['title'], 'Tabata');
      expect(args['text'], 'Work');
    });

    test('arms nothing for an empty list', () async {
      await player.schedule(const [], leadMs: 0);
      expect(calls.where((c) => c.method == 'schedule'), isEmpty);
    });
  });

  test('elapsed comes straight from the platform clock', () async {
    reply = 4200;
    expect(await player.elapsedMs(), 4200);
  });

  test('keepAwake and askToNotify reach the platform', () async {
    await player.keepAwake(true);
    await player.askToNotify();
    expect(callNamed('keepAwake').arguments, {'on': true});
    expect(calls.map((c) => c.method), contains('askToNotify'));
  });

  group('whether the session can be seen', () {
    test('comes from the platform', () async {
      reply = false;
      expect(await player.canNotify(), isFalse);
      reply = true;
      expect(await player.canNotify(), isTrue);
    });

    test('is not a question everywhere, and says so', () async {
      // iOS answers nothing: its lock-screen controls come with the audio
      // session and no permission is involved. Null means do not ask.
      reply = null;
      expect(await player.canNotify(), isNull);
      // Nor may failing to silence the phone take a session down with it.
      await player.silence(true);
      await player.openSilenceSettings();
      expect(await player.canSilence(), isNull);
    });

    test('can be sent to the system screen that turns it back on', () async {
      await player.openNotifySettings();
      expect(calls.map((c) => c.method), contains('openNotifySettings'));
    });
  });

  group('silencing the phone', () {
    test('asks the platform whether it can', () async {
      reply = true;
      expect(await player.canSilence(), isTrue);
      reply = false;
      expect(await player.canSilence(), isFalse);
    });

    test('is not possible everywhere, and says so', () async {
      // iOS answers nothing: an app cannot turn on a Focus there at all.
      // Null is what keeps the switch off that screen.
      reply = null;
      expect(await player.canSilence(), isNull);
    });

    test('turns it on and off by the same method', () async {
      await player.silence(true);
      await player.silence(false);
      expect(
        calls.where((c) => c.method == 'silence').map((c) => c.arguments),
        [
          {'on': true},
          {'on': false},
        ],
      );
    });

    test('can send the user to the screen that allows it', () async {
      await player.openSilenceSettings();
      expect(calls.map((c) => c.method), contains('openSilenceSettings'));
    });
  });

  group('degrading instead of throwing', () {
    test('a platform error leaves the timer running silently', () async {
      onCall = (_) => throw PlatformException(code: 'boom');

      // None of these may throw: losing the voice must not lose the workout.
      await player.warm(cues);
      await player.schedule(cues, leadMs: 0);
      await player.describe('x', 'y');
      await player.cancel();
      await player.keepAwake(true);
      await player.openNotifySettings();
      expect(await player.available(), isFalse);
      expect(await player.elapsedMs(), isNull);
      // Unknown, not "off": a notice about a missing notification is the last
      // thing to show on a phone where the question could not even be asked.
      expect(await player.canNotify(), isNull);
    });

    test('a platform with no native half reports no voice', () async {
      onCall = (_) => throw MissingPluginException('none');
      expect(await player.available(), isFalse);
      await player.schedule(cues, leadMs: 0);
    });
  });

  group('events from the platform', () {
    test('reports each cue as it plays', () async {
      final fired = <String>[];
      player.fired.listen(fired.add);

      await TestDefaultBinaryMessengerBinding
          .instance
          .defaultBinaryMessenger
          .handlePlatformMessage(
            PlatformCuePlayer.channelName,
            const StandardMethodCodec().encodeMethodCall(
              const MethodCall('fired', 'abc123'),
            ),
            (_) {},
          );

      await Future<void>.delayed(Duration.zero);
      expect(fired, ['abc123']);
    });

    test('reports Stop pressed on the notification', () async {
      var stopped = 0;
      player.stopped.listen((_) => stopped++);

      await TestDefaultBinaryMessengerBinding
          .instance
          .defaultBinaryMessenger
          .handlePlatformMessage(
            PlatformCuePlayer.channelName,
            const StandardMethodCodec().encodeMethodCall(
              const MethodCall('stopped'),
            ),
            (_) {},
          );

      await Future<void>.delayed(Duration.zero);
      expect(stopped, 1);
    });
  });
}
