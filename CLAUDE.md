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
6. **The whole look lives in `lib/app/style.dart`** — colours, sizes, shapes,
   type and the theme. Never `Colors.green`, `Color(0x…)`, `fontSize:` or
   `minimumSize:` in a widget; screens use the theme or `context.colors`.
   `test/app/conventions_test.dart` fails the build if one starts to.
7. **A button label never wraps.** Use `ActionLabel`, which shrinks instead.
   Wrapping is not an overflow, so nothing throws and "Re / set" just looks
   like a choice — and it happens to anyone who turns their system font up.
8. **Tests before implementation** for anything in `core/timeline`,
   `core/cues`, or `core/audio`.
9. The app must be fully usable offline with no login. There is no account and
   no server.

## Stack (do not change without asking)

- Flutter (stable), Dart, Android + iOS
- **Android minSdk 29** (Android 10). The audio path needs `AudioFocusRequest`
  (26) and `startForeground` with a service type (29); holding the line at 29
  keeps compatibility branches out of the one code path that has to be exactly
  on time.
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
hashing, storage or fonts; those are deliberately hand-rolled.

The typeface is **Jost**, Anvil Lab Studio's, bundled as a single variable
file at `assets/fonts/Jost-Variable.ttf` (135 KB, and smaller than the four
static cuts it replaces). Its licence ships beside it because the SIL OFL says
it must. A variable font needs **both** `fontWeight` and `fontVariations` set —
`TextStyle.weight()` in `style.dart` does both, and setting only the first
renders every weight as Regular.

## Folder layout

```
lib/
  app/              app widget, router, style.dart (the whole look)
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

## The native contract

Four methods and two events, the same on both platforms. Nothing in this list
mentions a workout, and nothing in it makes a decision.

```
available()                        is there a voice on this phone at all
warm(phrases)                      render anything uncached, load it, then call back
schedule(at[], keys[], leadMs, …)  arm the lot; returns the uptime cue zero was pinned to
cancel()                           drop everything armed, end the session
elapsed()                          how long the native session has run, or null
describe(title, text)              what the notification says
→ fired(key)                       a cue played
→ stopped()                        the user pressed Stop on the notification
```

`warm` is the slow one and is awaited: on a first run it renders every phrase
through `TextToSpeech.synthesizeToFile` and loads each clip into `SoundPool`, so
that by the time the first cue is due there is nothing left to decode, allocate
or ask the speech engine for. **Nothing is ever spoken live** — the engine takes
100–400 unpredictable milliseconds to start, enough to land "three" after the
phase it was counting down has already changed.

Two Android details that the app depends on and that are easy to undo:

- The schedule is armed with `Handler.postAtTime`, which runs on
  `SystemClock.uptimeMillis` — a clock that **stops advancing in deep sleep**.
  `TimerService` holds a partial wake lock for the length of the session for
  exactly this reason. Remove it and the countdown silently stretches.
- Audio focus is requested **per cue** and released on a trailing delay, so a
  run of "three, two, one, go" ducks the user's music once and then gives it
  back. Holding focus for the session would leave their music quiet for twenty
  minutes.

`leadMs` is zero from Dart on purpose: the platform pins cue zero that far in
the future while `Session` pins it to the moment of the call, so anything else
is the display and the voice disagreeing by exactly that much.

## The running screens

The run screen and the stopwatch share one language, and it is worth keeping:
a soft coloured ground, a badge and name at the top, a **dial** carrying the
time with the progress drawn around its edge, three round controls, and a
tracker along the foot. The pieces live in `lib/app/widgets/`.

The number sits on the dial's pale face rather than on the colour, and that is
not decoration — it is where it gets its contrast. The heading and caption are
the parts that can afford to be softer.

Two rules the dial follows: it shrinks to the **height** it is given as well as
the width, so a short phone loses dial rather than controls; and the arc is
**elapsed**, drawn clockwise from noon. The stopwatch's arc sweeps once a
minute instead, because a count-up has no end to show progress towards.

This is the only screen allowed a shadow — see `Shadows` in `style.dart` for
why. Everything else in the app stays flat.

**The list and the settings stay dark**, and that is deliberate rather than
unfinished. A phase colour is *information*: it says which phase you are in
from across a room. There is no phase on those screens, so colouring them would
only be shouting — and settings is where the longest explanatory text in the
app lives. What carries over instead is the vocabulary: the soft ground, round
badges, cards with room to breathe, and terracotta for whatever matters.

`SoftBackground` has two moods for this. On a phase colour its shapes are that
colour lifted and dropped a little and stay nearly invisible; on a dark screen
there is nothing to lift, so it takes a `glow` and lays down pools of it
instead. That is where the warmth on the list and the settings comes from.

A badge on a dark screen is filled with `Brand.accentWash` — the accent turned
right down — not with ivory. A pale disc on a dark page is a hole punched in
it.

## The two modes, and why one of them is almost free

A **focus session is a `Workout`**. Twenty-five minutes on, five off, four
times, with a long break at the end is one `Round` with `repeats: 4` and the
long break as the **cool down** — the one phase that comes after the last
block rather than between every pair of them. `expand()`, `planCues()`,
`Session`, the foreground service and the iOS engine all run it unchanged.

`TimerKind` on `Workout` is the one field the app branches on, and the model
itself never reads it. What it decides:

- **The script.** `CueSettings.quiet` — one word as each phase begins and
  nothing else. **Nothing in `core/cues/` knows a focus session exists**: this
  is the script the existing rules already produce with the switches off. Keep
  it that way.
- **The words.** `phrasesFor(kind)` in `core/cues/phrase.dart`: "Focus",
  "Break", "Long break". `Session.load()` is the only place that asks.
- **The screen.** `features/focus/` over the *same* `RunController` — the same
  session, pause, resume, skip and Stop from the lock screen. Two screens, one
  controller, and only the drawing differs.
- **Where it opens.** `startLocation()` in `app/router.dart`, because a
  session outlives the UI and a focus session restored onto the run screen
  would be the right session drawn in the loudest way there is.

The focus screen is the run screen's opposite and every difference is
deliberate: the ground stays dark instead of flooding with the phase colour,
the dial's face is dark instead of pale, the number is smaller, and there is
no badge, no tracker and no caption. A phase colour is information for someone
across a gym; for someone at a desk it is a light left on. The phase is worth
exactly one quiet word.

A focus block is twenty-five minutes, so `TimerService` holds its partial wake
lock for **two hours** to deliver nine cues. That is the known cost of this
mode and it has not been measured on a real phone yet. If it turns out to be
too much, the alternative is `AlarmManager.setExactAndAllowWhileIdle` per cue,
which is a real change to `CueEngine` and needs its own decision.

## The two platforms stay alive in completely different ways

The contract is identical and the implementations have almost nothing in
common. This is the part to understand before changing either.

**Android** keeps the process alive with a foreground service and a partial
wake lock, and fires cues with `Handler.postAtTime` against
`SystemClock.uptimeMillis` — a clock that stops in deep sleep, which is what
the wake lock is for.

**iOS** has no equivalent. An app stays alive in the background because it is
*playing audio*, so the session genuinely is: a silence buffer loops on its own
node for the whole workout and the cues are mixed over it. That is a continuous
stream rather than a trick, which matters both for staying alive and for being
honest about why the app asks for the audio background mode. Cues are scheduled
on the **audio clock by sample**, which is more accurate than Android's, for
free.

Two more differences worth knowing:

- Do Not Disturb is Android only, and not because iOS has not been written
  yet: **no iOS app can turn a Focus on.** `canSilence` answers null there,
  which is what keeps the switch off the focus screen rather than showing one
  that could never work. False means "not allowed yet"; null means "not
  possible". The two are never the same thing.
- **The phone's quiet is borrowed, and giving it back is the whole feature.**
  `TimerService` writes down the filter that was in place — with `commit()`,
  not `apply()` — and restores it in `onDestroy`, on the same lifecycle as the
  wake lock. `onDestroy` does not run when the process is force-stopped, so
  `restoreIfStranded()` checks on the next start: a phone left silent for a
  week because a timer died is the worst thing this app could do. Both halves
  are proven on a device, including the stranding.
- `INTERRUPTION_FILTER_PRIORITY`, never `NONE`: an alarm should still reach
  someone who fell asleep over their work.
- Android's lock-screen controls are the service's notification. iOS's are
  `MPNowPlayingInfoCenter` and `MPRemoteCommandCenter` — the system's own
  playback controls. `askToNotify`, `canNotify` and `openNotifySettings` are
  Android-only; on iOS all three answer nothing, and `canNotify` answering
  null is what keeps settings from offering to fix a permission that does not
  exist there. On Android a refusal is not an error — the workout runs and
  talks exactly the same, and the only thing lost is the lock screen — so it
  is never reported as one. It is a notice at the top of settings, beside the
  one about a phone with no voice, and that notice is the whole reason
  `canNotify` exists: Android spends its one notification prompt on the first
  refusal, and after that the degradation is silent.
- Android ducks the user's music per cue. **iOS does not**: `.mixWithOthers`,
  so cues play over music at full volume. Ducking on iOS lasts as long as the
  session is active and the session is active for the whole workout, so
  ducking there would mean twenty minutes of quiet music rather than a word of
  it. Revisit if it grates.

`keepScreenOnByDefault` is true on iOS and only iOS, and that is a hedge rather
than a preference — see the comment on it in `core/store/store.dart`.

**New Swift files must be added to the Xcode target** or they are silently not
compiled. There is no `xcodeproj` gem on the system ruby; CocoaPods ships one:

```bash
GEM_HOME=/opt/homebrew/Cellar/cocoapods/1.17.0/libexec ruby -e "require 'xcodeproj'; ..."
```

## The stopwatch is the exception to "nothing ticks"

A workout has an end, so its whole script goes down in one call and the app can
be frozen for twenty minutes without missing a cue. A count-up stopwatch has no
end, so its script cannot. It arms **ten minutes at a time** and tops the window
up once five minutes are left (`core/cues/plan_stopwatch.dart`).

The consequence is honest and worth keeping in mind: if the app is frozen past
the end of an armed window, the stopwatch stops talking until it is opened
again. **The count itself is never wrong** — only the voice goes quiet.

The window also exists because every distinct phrase has to be rendered once,
and rendering is the only slow part of starting: a full hour at 15-second
intervals would be 240 clips to synthesise before the first tick.

**A lap is shown, never spoken.** A lap time is not known until it happens, and
this app never speaks anything it has not already rendered.

## Quality gates (run before saying a task is done)

- `flutter analyze` — zero warnings
- `flutter test` — all green
- New logic in `core/timeline`, `core/cues`, or `core/audio` needs unit tests
  **written before the implementation**
- Any new screen goes into `test/features/layout_test.dart`, which pumps every
  screen at 320dp and 360dp and fails on the overflow stripes. Three real
  layout bugs reached a screenshot before that test existed. When you add a
  case to it, prove it can fail: put a `SizedBox(width: 500)` in the row and
  watch the test go red before you take it out again.
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
