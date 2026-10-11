# Cadent

A timer that keeps the rhythm out loud, so you never have to look at it.

Two things a timer gets used for, and both of them want your eyes somewhere
else:

- **Workouts** — work, rest, rounds. It counts you into every change:
  "three, two, one, go" … "three, two, one, rest". Read from across a gym,
  heard from a pocket.
- **Focus** — blocks of concentrated work with breaks between them. One word
  at each change and silence in between, on a screen with nothing on it to
  look at, with the phone in Do Not Disturb for the duration.

Plus a count-up stopwatch that calls out the time.

Android and iOS. No account, no network, no ads.

## The idea that makes it work

**Nothing ticks.** The script is deterministic: given a workout and a start
instant, every cue's time is known in advance. Dart computes the whole list
and hands it to the platform, which plays each cue at an absolute time.

```
Dart (pure, tested)              Platform channel          Native
Workout → Timeline → [Cue]  ──▶  schedule(cues, lead)  ──▶  plays at exact times
                                 cancel() / elapsed()       owns the clock
```

So the cues keep landing while Dart is frozen with the screen off, timing is
an audio problem rather than a `Timer` problem, and everything worth testing
is pure Dart with no clock and no sound in it.

**Nothing is ever spoken live.** A speech engine takes 100–400 unpredictable
milliseconds to start — enough to land "three" after the phase it was counting
down has already changed. Every phrase is rendered to a cached audio file once,
with the phone's own voice, and played from there.

## Running it

```bash
flutter pub get
flutter run
```

```bash
flutter analyze && flutter test
```

Three dependencies — `flutter_riverpod`, `go_router`, `path_provider`. Audio,
text-to-speech, the foreground service, the wake lock, hashing, storage and
the font are all hand-rolled on purpose.

`CLAUDE.md` is the house guide: the architecture, the rules that keep it, and
the things that are easy to undo by accident.
