# Talking Stopwatch — Agent Guide

Read this file fully before every session.

## What we are building

An interval timer and stopwatch for working out that **talks**, so you never
have to look at the screen. It speaks a countdown into every transition and
names the phase you are entering: "three, two, one, go" … "three, two, one,
rest". Android and iOS, English voice.

The requirement that shapes every decision:

> **A cue must be audible at the right instant while the screen is off and the
> phone is in a pocket, possibly with music playing.**

The UI is secondary. It is the thing the user deliberately does not look at.

Three modes: an interval timer (work / rest / rounds), a count-up talking
stopwatch, and saved named presets with multi-phase circuits.

## The one architectural idea

**Nothing ticks.** The cue schedule is deterministic: given a workout and a
start instant, every cue's time is known in advance. Dart computes the whole
remaining cue list and hands it to the native side, which plays each cue at an
absolute time.

```
Dart (pure, tested)                Platform channel          Native
Workout → Timeline → [Cue]   ──▶   schedule(cues, lead)  ──▶  plays at exact times
                                   cancel() / elapsed()       owns the clock
```

Why it matters:

- If Dart is frozen (screen off, app backgrounded), cues still fire — the native
  side already holds the list. Nothing crosses the channel on the hot path.
- Timing accuracy is a native audio problem, never a Dart `Timer` problem.
- Everything worth testing is pure Dart with no clock and no audio in it.
- Pause / resume / skip is `cancel()` then recompute and `schedule()` again.
  **Dart is the single owner of workout state; native knows nothing about
  workouts.** Do not add workout knowledge to the native side.

## Hard rules

1. **Never drive cues from a Dart `Timer`.** A Dart timer may update the
   display; it must never be what makes a sound happen.
2. **Native holds no workout state** — only a cue list, a clock, and a cache.
3. **Time is integer milliseconds** (`int`). Never `double`, never `Duration`
   arithmetic in the cue planner. Seconds only at the UI edge.
4. **`expand()` and `planCues()` stay pure** — no clock, no I/O, no platform
   calls. They are the heart of the app and they are fully unit-tested.
5. **The cue-script rules live in exactly one place** (`core/cues/`). No screen
   decides when to say something.
6. **Every colour lives in `lib/app/palette.dart`.** Never `Colors.green` or
   `Color(0x…)` in a widget; screens use the theme or `context.colors`.
7. **Every named size lives in `lib/app/sizes.dart`.** No screen gives itself
   `iconSize: 28` or `minimumSize:`.
8. **Tests before implementation** for anything in `core/timeline`,
   `core/cues`, or `core/audio`.
9. The app must be fully usable offline with no login. There is no account and
   no server.

## Stack (do not change without asking)

- Flutter (stable), Dart, Android + iOS
- State: Riverpod. Routing: go_router
- Storage: **one JSON file**, written atomically. No database, no codegen.
- Voice: the phone's own TTS, **pre-rendered to cached audio files** and played
  back with exact timing. Hand-rolled over a `MethodChannel` — no audio or TTS
  package.
- Android: foreground service (`mediaPlayback`) + `SoundPool` +
  `Handler.postAtTime`
- iOS: `AVAudioEngine` + `AVAudioPlayerNode.scheduleBuffer(_:at:)`, background
  audio mode

**Dependencies are `flutter_riverpod`, `go_router`, `path_provider`. That is
all. Do not add a package without asking** — and never one for audio, TTS,
hashing, or storage; those are deliberately hand-rolled.

## Folder layout

```
lib/
  app/              app widget, router, theme, palette.dart, sizes.dart
  core/
    clock/          monotonic clock abstraction (testable)
    timeline/       Workout, Round, Segment, expand()          — pure
    cues/           Phrase, Cue, planCues(), collision rules   — pure
    audio/          CuePlayer interface, platform client, FakeCuePlayer
    store/          the JSON file: presets + settings, atomic write
  features/
    run/            the run screen
    presets/        saved workouts
    edit/           workout editor
    stopwatch/      count-up mode
    settings/
android/app/src/main/kotlin/.../  CuePlayer.kt, PhraseRenderer.kt, TimerService.kt
ios/Runner/                       CuePlayer.swift, PhraseRenderer.swift
test/                             mirrors lib/
```

## The spoken script

For prepare 10 s · work 30 s · rest 10 s · 8 rounds:

```
t=0      "ready"
t=7,8,9  "three" "two" "one"
t=10     "Go, round 1"        (one utterance, one clip; the voice says
                              "round one", and a numeral works past round 10)
t=25     "halfway"
t=37,38,39  "three" "two" "one"
t=40     "rest"
t=47,48,49  "three" "two" "one"
t=50     "go, round two"
...      "go, last round"     on the final work phase
end      "done"
```

Rules, all in `core/cues/` and all unit-tested:

- A countdown is emitted only for a phase of **at least `countdownFrom` + 2
  seconds**, so a 3 s rest gets its phase word and no countdown. This is what
  stops the app saying "one rest three".
- "halfway" only on a work phase of **20 s or more**.
- A phase word and its qualifier are **one utterance, not two cues**
  ("Go, round 1"), so they are rendered and played as a single clip. This is
  also why `CuePriority` has no level for a round label: there is no such cue.
- **Collision rule:** when two cues land within 300 ms the lower-priority one
  is dropped. Priority: phase word > countdown > halfway. The walk is
  most-important-first, so the cue that survives is always the one that
  matters, whichever came first in time.
- The rest after the very last work phase is dropped.
- A round announces its **label** if it has one, otherwise "round N".

## Quality gates (run before saying a task is done)

- `flutter analyze` — zero warnings
- `flutter test` — all green
- New logic in `core/timeline`, `core/cues`, or `core/audio` needs unit tests
  **written before the implementation**
- Phase 2 onward: the only test that really counts is a real phone, screen
  locked, in a pocket, for a whole session — with music playing and with
  Bluetooth earbuds. Record it on a second phone and check the gaps between
  "three / two / one / go" are within 50 ms of right.

## Things to get right

- Bluetooth earbuds add 150–300 ms that cannot be queried. There is a
  calibration offset in settings; apply it in `planCues()`, nowhere else.
- Request audio focus **per cue** (`TRANSIENT_MAY_DUCK`), not for the whole
  session, or the user's music stays ducked for 20 minutes.
- Handle interruptions: a phone call mid-session must not end the workout.
- Pre-render on a background thread and never block the first "go".

## Pushing and CI

- Commit locally as you go; do not push work in progress.
- Run the quality gates locally before pushing.
- One phase = one branch = one push, with the PR opened at that point.
- Once a PR is open, do not push more commits unless asked.
