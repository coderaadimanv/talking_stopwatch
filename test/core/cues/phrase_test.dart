import 'package:flutter_test/flutter_test.dart';
import 'package:cadent/core/cues/phrase.dart';
import 'package:cadent/core/timeline/workout.dart';

void main() {
  group('Phrases', () {
    const p = Phrases();

    test('names every phase kind', () {
      for (final kind in SegmentKind.values) {
        expect(p.phase(kind), isNotEmpty, reason: '$kind has no word');
      }
    });

    test('counts down in words', () {
      expect(p.count(3), 'three');
      expect(p.count(1), 'one');
      expect(p.count(5), 'five');
    });

    test('numbers rounds past ten without blowing up', () {
      expect(p.round(1), 'round 1');
      expect(p.round(11), 'round 11');
      expect(p.round(40), 'round 40');
    });

    test('joins a phase word to its qualifier as one sentence', () {
      expect(p.join(p.go, p.round(2)), 'Go, round 2');
      expect(p.join(p.go, p.lastRound), 'Go, last round');
    });

    test('reads elapsed time the way a person would say it', () {
      expect(p.elapsed(30), '30 seconds');
      expect(p.elapsed(60), '1 minute');
      expect(p.elapsed(90), '1 minute 30');
      expect(p.elapsed(120), '2 minutes');
      expect(p.elapsed(185), '3 minutes 5');
    });
  });

  group('phraseKey', () {
    test('is stable for the same text', () {
      expect(phraseKey('Go, round 1'), phraseKey('Go, round 1'));
    });

    test('differs for different text and for different voices', () {
      expect(phraseKey('Go'), isNot(phraseKey('Rest')));
      expect(phraseKey('Go', voice: 'a'), isNot(phraseKey('Go', voice: 'b')));
    });

    test('is a fixed-length filesystem-safe name', () {
      for (final text in ['Go', 'Rest', 'Go, push ups', 'सबसे', '']) {
        final key = phraseKey(text);
        expect(key.length, 16);
        expect(key, matches(RegExp(r'^[0-9a-f]{16}$')));
      }
    });

    test('does not collide across a realistic vocabulary', () {
      const p = Phrases();
      final texts = <String>{
        p.ready, p.go, p.rest, p.breakBetween, p.cooldown, p.halfway, p.done,
        for (var n = 1; n <= 10; n++) p.count(n),
        for (var n = 1; n <= 60; n++) p.join(p.go, p.round(n)),
        for (var s = 1; s <= 600; s++) p.elapsed(s),
        p.join(p.go, p.lastRound),
      };
      final keys = texts.map((t) => phraseKey(t)).toSet();
      expect(keys.length, texts.length);
    });
  });
}
