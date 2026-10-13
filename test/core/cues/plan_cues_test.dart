import 'package:flutter_test/flutter_test.dart';
import 'package:cadent/core/cues/cue.dart';
import 'package:cadent/core/cues/phrase.dart';
import 'package:cadent/core/cues/plan_cues.dart';
import 'package:cadent/core/cues/sound_settings.dart';
import 'package:cadent/core/timeline/timeline.dart';
import 'package:cadent/core/timeline/workout.dart';

/// `'10000 Go, round 1'` per cue, or `'10000 <work>'` for a tone — so a
/// failure reads like the script.
List<String> script(List<Cue> cues) =>
    cues.map((c) => '${c.atMs} ${c.tone == null ? c.text : "<${c.tone!.name}>"}')
        .toList();

List<Cue> cuesFor(Workout w, {int offsetMs = 0}) =>
    planCues(expand(w), w.cues, offsetMs: offsetMs);

void main() {
  group('tones', () {
    /// Two short rounds, so a whole script fits in a test: 30 seconds of work
    /// and 10 of rest, twice, with everything switched on.
    const loud = Workout(
      id: 'loud',
      prepareSeconds: 0,
      rounds: [Round(workSeconds: 30, restSeconds: 10)],
      repeats: 2,
      cues: CueSettings(halfway: false, lastRound: false),
    );

    List<Cue> plan(SoundSettings sounds) =>
        planCues(expand(loud), loud.cues, sounds: sounds);

    test('the voice is what you get by default, exactly as before', () {
      // Note there is no rest after the last round and no countdown into the
      // end: the timeline drops the one and the planner never adds the other.
      expect(script(plan(const SoundSettings())), [
        '0 Go, round 1',
        '27000 three',
        '28000 two',
        '29000 one',
        '30000 Rest',
        '37000 three',
        '38000 two',
        '39000 one',
        '40000 Go, round 2',
        '67000 three',
        '68000 two',
        '69000 one',
        '70000 Done',
      ]);
    });

    test('tones replace every word, one for one', () {
      // The same script with nothing said. Note what is gone and what is not:
      // the round number has vanished, because it was never a cue of its own,
      // and a rest and the end are still told apart.
      expect(script(plan(SoundSettings.tones)), [
        '0 <work>',
        '27000 <tick>',
        '28000 <tick>',
        '29000 <tick>',
        '30000 <rest>',
        '37000 <tick>',
        '38000 <tick>',
        '39000 <tick>',
        '40000 <work>',
        '67000 <tick>',
        '68000 <tick>',
        '69000 <tick>',
        '70000 <done>',
      ]);
    });

    test('both puts the tone ahead of the word, and the word on time', () {
      // The word must not move: it is what the countdown on the screen is
      // agreeing with. So the tone leads instead, by exactly the gap the
      // collision rule calls "the same moment", which is the smallest lead
      // that survives it.
      final cues = plan(const SoundSettings(phase: SoundMode.both));
      expect(script(cues).take(3), [
        // Nothing at -300: there is no room for a lead-in before the session
        // has started, so the first phase keeps its word and loses its tone.
        '0 Go, round 1',
        '27000 three',
        '28000 two',
      ]);
      expect(script(cues).skip(3), [
        '29000 one',
        '29700 <rest>',
        '30000 Rest',
        '37000 three',
        '38000 two',
        '39000 one',
        '39700 <work>',
        '40000 Go, round 2',
        '67000 three',
        '68000 two',
        '69000 one',
        '69700 <done>',
        '70000 Done',
      ]);
    });

    test('each kind of cue is chosen on its own', () {
      // The point of the feature: the repetitive countdown becomes a tick
      // while the phase, which is the part worth words, keeps talking.
      final cues = plan(const SoundSettings(countdown: SoundMode.tone));
      expect(script(cues), [
        '0 Go, round 1',
        '27000 <tick>',
        '28000 <tick>',
        '29000 <tick>',
        '30000 Rest',
        '37000 <tick>',
        '38000 <tick>',
        '39000 <tick>',
        '40000 Go, round 2',
        '67000 <tick>',
        '68000 <tick>',
        '69000 <tick>',
        '70000 Done',
      ]);
    });

    test('halfway is a tone of its own, in a phase long enough to have one', () {
      const long = Workout(
        id: 'long',
        prepareSeconds: 0,
        rounds: [Round(workSeconds: 60, restSeconds: 10)],
        cues: CueSettings(countdown: false, lastRound: false),
      );
      expect(
        script(planCues(expand(long), long.cues, sounds: SoundSettings.tones)),
        ['0 <work>', '30000 <halfway>', '60000 <done>'],
      );
    });

    test('a tone and its word never collide, however they are combined', () {
      // Every combination of the four settings, on a workout with every kind
      // of cue in it. Nothing may be dropped by the collision rule and no two
      // sounds may land closer than it allows — which is the one way this
      // feature could quietly break the script.
      const everything = Workout(
        id: 'everything',
        prepareSeconds: 10,
        rounds: [Round(workSeconds: 60, restSeconds: 20)],
        repeats: 3,
        breakSeconds: 30,
        cooldownSeconds: 40,
      );
      for (final phase in SoundMode.values) {
        for (final countdown in SoundMode.values) {
          for (final halfway in SoundMode.values) {
            final sounds = SoundSettings(
              phase: phase,
              countdown: countdown,
              halfway: halfway,
            );
            final cues = planCues(
              expand(everything),
              everything.cues,
              sounds: sounds,
            );
            for (var i = 1; i < cues.length; i++) {
              expect(
                cues[i].atMs - cues[i - 1].atMs,
                greaterThanOrEqualTo(minCueGapMs),
                reason:
                    'in $sounds, ${cues[i - 1]} and ${cues[i]} are on top of '
                    'each other',
              );
            }
          }
        }
      }
    });

    test('a tone cue carries no words and keys to its own file', () {
      final cues = plan(SoundSettings.tones);
      for (final cue in cues) {
        expect(cue.text, isEmpty, reason: 'a tone has nothing to say');
        expect(cue.key, startsWith('tone-'));
      }
      // And the keys are stable, because they name a file in a cache that
      // outlives the app.
      expect(cues.first.key, 'tone-work');
    });
  });

  group('a focus session', () {
    /// The pomodoro, in the shape the model already has: four blocks of 25
    /// with 5 between them, and the long break as the cool down, which is the
    /// only phase that comes after the last block rather than between them.
    final pomodoro = Workout(
      id: 'focus',
      kind: TimerKind.focus,
      prepareSeconds: 0,
      rounds: const [Round(workSeconds: 25 * 60, restSeconds: 5 * 60)],
      repeats: 4,
      cooldownSeconds: 15 * 60,
      cues: CueSettings.quiet,
    );

    test('says one word at each change and nothing else', () {
      final cues = planCues(
        expand(pomodoro),
        pomodoro.cues,
        phrases: phrasesFor(TimerKind.focus),
      );

      // Nine cues in two hours and ten minutes. Everything the mode is for is
      // in this list: no countdown into a block, no halfway through one, no
      // block numbers — the phase word, and then silence.
      expect(script(cues), [
        '0 Focus',
        '1500000 Break',
        '1800000 Focus',
        '3300000 Break',
        '3600000 Focus',
        '5100000 Break',
        '5400000 Focus',
        '6900000 Long break',
        '7800000 Done',
      ]);
    });

    test('is quiet because of its settings, not because of its words', () {
      // The same session with the normal settings counts into every change
      // and calls the halfway. Proof that nothing in the planner knows what a
      // focus session is: only the switches it was handed.
      final chatty = planCues(
        expand(pomodoro),
        const CueSettings(),
        phrases: phrasesFor(TimerKind.focus),
      );
      expect(chatty.map((c) => c.text), contains('three'));
      expect(chatty.map((c) => c.text), contains('Halfway'));

      final quiet = planCues(
        expand(pomodoro),
        CueSettings.quiet,
        phrases: phrasesFor(TimerKind.focus),
      );
      expect(quiet.map((c) => c.text), isNot(contains('three')));
      expect(quiet.map((c) => c.text), isNot(contains('Halfway')));
    });

    test('a workout still speaks with the workout words', () {
      expect(phrasesFor(TimerKind.workout).phase(SegmentKind.work), 'Go');
      expect(phrasesFor(TimerKind.focus).phase(SegmentKind.work), 'Focus');
    });
  });

  group('planCues', () {
    test('speaks the documented script for 30s work, 10s rest, 8 rounds', () {
      final cues = cuesFor(
        Workout.simple(workSeconds: 30, restSeconds: 10, rounds: 8),
      );

      expect(script(cues).take(14), [
        '0 Ready',
        '7000 three',
        '8000 two',
        '9000 one',
        '10000 Go, round 1',
        '25000 Halfway',
        '37000 three',
        '38000 two',
        '39000 one',
        '40000 Rest',
        '47000 three',
        '48000 two',
        '49000 one',
        '50000 Go, round 2',
      ]);

      expect(script(cues).skip(cues.length - 6), [
        '290000 Go, last round',
        '305000 Halfway',
        '317000 three',
        '318000 two',
        '319000 one',
        '320000 Done',
      ]);

      // 1 ready + 3 prepare countdown + 8 work words + 8 halfway
      // + 24 work countdown + 7 rest words + 21 rest countdown + 1 done
      expect(cues.length, 73);
    });

    test('cues come back sorted and never before zero', () {
      final cues = cuesFor(
        Workout.simple(workSeconds: 30, restSeconds: 10, rounds: 4),
      );
      for (var i = 1; i < cues.length; i++) {
        expect(cues[i].atMs, greaterThanOrEqualTo(cues[i - 1].atMs));
      }
      expect(cues.every((c) => c.atMs >= 0), isTrue);
    });

    test('a phase shorter than countdownFrom + 2 gets no countdown', () {
      final cues = cuesFor(
        Workout.simple(
          workSeconds: 30,
          restSeconds: 3,
          rounds: 2,
          prepareSeconds: 0,
        ),
      );

      // The 3 s rest runs 30000..33000: its word, and nothing else inside it.
      final inRest = cues.where((c) => c.atMs > 30000 && c.atMs < 33000);
      expect(inRest, isEmpty, reason: 'would say "one rest three"');
      expect(
        cues.singleWhere((c) => c.atMs == 30000).text,
        'Rest',
      );
      expect(cues.any((c) => c.atMs == 33000 && c.text == 'Go, last round'),
          isTrue);
    });

    test('a 5 s phase is exactly long enough to count down from three', () {
      final cues = cuesFor(
        Workout.simple(
          workSeconds: 5,
          restSeconds: 5,
          rounds: 2,
          prepareSeconds: 0,
        ),
      );
      expect(script(cues), [
        '0 Go, round 1',
        '2000 three',
        '3000 two',
        '4000 one',
        '5000 Rest',
        '7000 three',
        '8000 two',
        '9000 one',
        '10000 Go, last round',
        '12000 three',
        '13000 two',
        '14000 one',
        '15000 Done',
      ]);
    });

    test('halfway only on a work phase of 20 s or more', () {
      final short = cuesFor(
        Workout.simple(
          workSeconds: 19,
          restSeconds: 0,
          rounds: 1,
          prepareSeconds: 0,
        ),
      );
      expect(short.any((c) => c.text == 'Halfway'), isFalse);

      final long = cuesFor(
        Workout.simple(
          workSeconds: 20,
          restSeconds: 0,
          rounds: 1,
          prepareSeconds: 0,
        ),
      );
      expect(long.singleWhere((c) => c.text == 'Halfway').atMs, 10000);
    });

    test('a labelled round says its label instead of a number', () {
      final cues = cuesFor(
        Workout(
          id: 'circuit',
          prepareSeconds: 0,
          rounds: const [
            Round(label: 'push ups', workSeconds: 30, restSeconds: 10),
            Round(label: 'squats', workSeconds: 30, restSeconds: 10),
          ],
        ),
      );
      expect(cues.first.text, 'Go, push ups');
      // The last work phase gives up its label for the warning.
      expect(cues.any((c) => c.text == 'Go, last round'), isTrue);
    });

    test('the phase word and its qualifier are one utterance, not two cues', () {
      final cues = cuesFor(
        Workout.simple(
          workSeconds: 30,
          restSeconds: 10,
          rounds: 3,
          prepareSeconds: 0,
        ),
      );
      expect(cues.where((c) => c.atMs == 0).length, 1);
      expect(cues.first.text, 'Go, round 1');
    });

    test('settings turn each kind of cue off', () {
      final w = Workout.simple(
        workSeconds: 30,
        restSeconds: 10,
        rounds: 2,
        prepareSeconds: 0,
        cues: const CueSettings(
          countdown: false,
          halfway: false,
          roundLabels: false,
          lastRound: false,
        ),
      );
      expect(script(cuesFor(w)), [
        '0 Go',
        '30000 Rest',
        '40000 Go',
        '70000 Done',
      ]);
    });

    test('countdownFrom 5 counts five down to one', () {
      final cues = cuesFor(
        Workout.simple(
          workSeconds: 30,
          restSeconds: 0,
          rounds: 1,
          prepareSeconds: 0,
          cues: const CueSettings(countdownFrom: 5, halfway: false),
        ),
      );
      expect(script(cues), [
        '0 Go, last round',
        '25000 five',
        '26000 four',
        '27000 three',
        '28000 two',
        '29000 one',
        '30000 Done',
      ]);
    });

    test('the calibration offset shifts every cue and clamps at zero', () {
      final w = Workout.simple(
        workSeconds: 30,
        restSeconds: 0,
        rounds: 1,
        prepareSeconds: 0,
        cues: const CueSettings(halfway: false),
      );

      final early = cuesFor(w, offsetMs: -500);
      expect(script(early), [
        '0 Go, last round', // clamped from -500
        '26500 three',
        '27500 two',
        '28500 one',
        '29500 Done',
      ]);

      final late = cuesFor(w, offsetMs: 200);
      expect(late.first.atMs, 200);
      expect(late.last.atMs, 30200);
    });

    test('a break between repeats is announced', () {
      final cues = cuesFor(
        Workout(
          id: 'two sets',
          prepareSeconds: 0,
          rounds: const [Round(workSeconds: 30, restSeconds: 0)],
          repeats: 2,
          breakSeconds: 60,
          cues: const CueSettings(halfway: false),
        ),
      );
      expect(cues.any((c) => c.atMs == 30000 && c.text == 'Break'), isTrue);
    });

    test('an empty workout says nothing at all', () {
      final cues = cuesFor(
        Workout(id: 'empty', prepareSeconds: 0, rounds: const []),
      );
      expect(cues, isEmpty);
    });
  });

  // The script rules above make a real collision very hard to reach, which is
  // the point of them. The rule is still enforced, so it is tested directly.
  group('resolveCollisions', () {
    test('drops the lower-priority cue when two land within 300 ms', () {
      final kept = resolveCollisions(const [
        Cue(atMs: 1000, text: 'Halfway', priority: CuePriority.halfway),
        Cue(atMs: 1100, text: 'Rest', priority: CuePriority.phaseWord),
        Cue(atMs: 1200, text: 'three', priority: CuePriority.countdown),
      ]);
      expect(script(kept), ['1100 Rest']);
    });

    test('keeps cues exactly 300 ms apart', () {
      final kept = resolveCollisions(const [
        Cue(atMs: 1000, text: 'Rest', priority: CuePriority.phaseWord),
        Cue(atMs: 1300, text: 'three', priority: CuePriority.countdown),
      ]);
      expect(kept.length, 2);
    });

    test('the earlier of two equal-priority cues wins', () {
      final kept = resolveCollisions(const [
        Cue(atMs: 1100, text: 'Rest', priority: CuePriority.phaseWord),
        Cue(atMs: 1000, text: 'Go', priority: CuePriority.phaseWord),
      ]);
      expect(script(kept), ['1000 Go']);
    });

    test('a high-priority cue does not cascade into dropping distant ones', () {
      final kept = resolveCollisions(const [
        Cue(atMs: 0, text: 'Go', priority: CuePriority.phaseWord),
        Cue(atMs: 100, text: 'three', priority: CuePriority.countdown),
        Cue(atMs: 5000, text: 'Halfway', priority: CuePriority.halfway),
      ]);
      expect(script(kept), ['0 Go', '5000 Halfway']);
    });
  });
}
