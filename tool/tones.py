#!/usr/bin/env python3
"""Makes the app's cue tones.

Run from the repo root:

    python3 tool/tones.py

and it rewrites `assets/sounds/*.wav`. Nothing else uses it; the tones are
committed, so this only runs when one of them is being changed.

Why a script and not six sound files from somewhere
---------------------------------------------------

Two reasons, and the second is the real one. Sourced audio carries licences
that have to be tracked and attributed. And a tone written down as numbers can
be retuned by changing a number — "the work tone is a fifth too low" is a
one-line edit here and an afternoon of searching otherwise.

What these are
--------------

Struck wooden bars — marimba, near enough. A bar's partials are *inharmonic*:
they sit at roughly 1 : 3.9 : 9.2 times the fundamental rather than at 2x and
3x, and the high ones die away much faster than the low one. Those two facts
are the whole difference between wood and a beeper. A stack of exact harmonics
with one shared envelope is a microwave; the same notes with stretched partials
and per-partial decay are an instrument.

Three more things, none of them obvious:

* **The mallet.** A few milliseconds of filtered noise at the onset. It is
  what the ear hears as something being *hit*, and without it even correct
  partials sound synthesised. It is also almost inaudible on its own.
* **Pitch sits where a phone speaker lives.** Fundamentals stay in the A4-A5
  range. Lower would be warmer on a desk and gone on a phone, which can barely
  move air below about 500 Hz; this way the fundamental is reproducible and the
  3.9 partial lands between 1.5 and 3.5 kHz, where both the speaker and the ear
  are at their best.
* **The same loudness as the voice.** The last step is exactly the arithmetic
  in `Loudness.kt` and `CuePlayer.swift` — lifted to -11 dBFS RMS with a soft
  knee into the ceiling — so a tone and a spoken cue land at the same level,
  and so the device-side lift measures these as already-there and leaves them
  alone.
"""

import math
import os
import random
import struct
import wave

RATE = 24000          # what the speech engine renders at
TARGET_RMS = 0.282    # -11 dBFS, the same figure as Loudness.kt
MAX_GAIN = 4.0
KNEE = 0.70
CEILING = 0.99
SILENCE = 1 / 32

# Pitches, so the notes below read as music rather than as frequencies.
#
# A narrow octave, and chosen by measurement rather than by taste. Below about
# 500 Hz a phone speaker throws most of a bar away — at F4 essentially all of
# it — so a warm-sounding low note is a silent one. Above E5 the bar's 3.9
# partial climbs past 2.6 kHz into the band the ear finds most aggressive, and
# the first attempt at these, pitched an octave up, measured *harsher* than the
# beeps it replaced. C5 to G5 is what is left: nothing lost to the speaker,
# nothing pushed into the harsh band.
C5, D5, E5, F5, G5 = 523.25, 587.33, 659.25, 698.46, 783.99

# A marimba bar's first three partials, as multiples of the fundamental, with
# how loud each is and how fast each dies away (in decay constants per second).
#
# The stretched ratios are what make it wood rather than a beeper: a stack of
# exact harmonics under one shared envelope is a microwave. The decay rates are
# what make it *struck* wood — the 9.2 partial is a knock that is gone in a
# tenth of a second, the 3.9 gives it body for a quarter, and the fundamental
# rings on under both. The two upper amplitudes are deliberately low; they are
# where harshness comes from, and the ear only needs a trace of them to hear
# the sound as a bar.
BAR = [
    (1.00, 1.00, 4.2),
    (3.93, 0.30, 10.0),
    (9.22, 0.035, 26.0),
]


def note(freq, ms, *, level=1.0, decay=1.0, mallet=0.5, bright=1.0):
    """One struck bar.

    [bright] scales the upper partials only. The top note of a rising figure
    needs less of the 3.9 partial than the note under it: by F5 that partial is
    already at 2.7 kHz, and leaving it at full strength is what put the first
    version of these above the beeps they replaced for harshness.
    """
    total = int(RATE * ms / 1000)
    # A couple of milliseconds, so the onset is not a step — a step is a click,
    # and the click is the harshest thing in the sound.
    attack = max(1, int(RATE * 0.002))
    out = []

    for i in range(total):
        t = i / RATE
        value = 0.0
        for ratio, amp, rate in BAR:
            # Partials above the speaker's reach only add harshness.
            if freq * ratio > RATE / 2.2:
                continue
            gain = amp if ratio == 1.0 else amp * bright
            value += gain * math.exp(-rate * decay * t) * math.sin(
                2 * math.pi * freq * ratio * t
            )
        out.append(value * min(1.0, i / attack) * level / 1.52)

    # The mallet: a few milliseconds of noise, lowpassed so it reads as a soft
    # beater on wood rather than as a tick. Seeded, so the file is the same
    # every time this script runs.
    noise = random.Random(int(freq))
    knock = int(RATE * 0.007)
    previous = 0.0
    for i in range(min(knock, total)):
        raw = noise.uniform(-1.0, 1.0)
        previous += 0.07 * (raw - previous)  # one-pole lowpass, well down
        out[i] += previous * mallet * level * math.exp(-320 * i / RATE)

    return out


def silence(ms):
    return [0.0] * int(RATE * ms / 1000)


def mix(*parts):
    """Lays notes end to end."""
    out = []
    for part in parts:
        out.extend(part)
    return out


def level(samples):
    """Peak, and RMS over the sounding part. Silence is left out, because a
    clip is mostly the gap around it and averaging that in asks for a gain the
    sound does not need."""
    peak = max((abs(s) for s in samples), default=0.0)
    if peak == 0:
        return 0.0, 0.0
    floor = peak * SILENCE
    loud = [s for s in samples if abs(s) > floor]
    rms = math.sqrt(sum(s * s for s in loud) / len(loud))
    return peak, rms


def shape_limit(value):
    """Linear to the knee, then a curve that flattens into the ceiling."""
    size = abs(value)
    if size <= KNEE:
        return value
    over = (size - KNEE) / (1 - KNEE)
    return math.copysign(min(KNEE + (1 - KNEE) * math.tanh(over), CEILING), value)


def to_level(samples):
    """The same lift the app applies to a rendered phrase, applied here so the
    app's own lift finds nothing left to do."""
    _, rms = level(samples)
    if rms == 0:
        return samples
    gain = min(TARGET_RMS / rms, MAX_GAIN)
    return [shape_limit(s * gain) for s in samples]


def write(name, samples):
    samples = to_level(samples)
    peak, rms = level(samples)
    path = os.path.join("assets", "sounds", name + ".wav")
    with wave.open(path, "wb") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(RATE)
        f.writeframes(
            b"".join(
                struct.pack("<h", max(-32767, min(32767, int(round(s * 32767)))))
                for s in samples
            )
        )
    db = lambda v: 20 * math.log10(v) if v else -99
    print(
        f"{name:9} {os.path.getsize(path) / 1024:6.1f} KB  "
        f"{len(samples) / RATE * 1000:5.0f} ms  "
        f"peak {db(peak):5.1f} dBFS  rms {db(rms):5.1f} dBFS"
    )


# The six sounds. Each one has to be recognisable on its own, about a third of
# a second long, and tell you something the others do not.
TONES = {
    # Starting. One bar, left to ring: nothing is happening yet.
    "ready": lambda: note(C5, 420, decay=0.8, level=0.85),
    # Work. Rising a fourth, and the longest ring of the set — this is the one
    # that has to carry across a gym.
    "work": lambda: mix(note(C5, 150), note(F5, 420, decay=0.75, bright=0.6)),
    # Rest. The same interval falling, which is the whole trick: you do not
    # have to learn these two, you only have to hear which way they go.
    "rest": lambda: mix(
        note(F5, 150, level=0.9, bright=0.6), note(C5, 440, decay=0.75, level=0.9)
    ),
    # The countdown. Short and dry, because three of them land a second apart
    # and anything with a tail would smear into the next. A harder mallet and
    # a fast decay: this one is a knock, not a note.
    "tick": lambda: note(E5, 110, decay=3.4, mallet=0.8, level=0.8, bright=0.7),
    # Halfway. One bar in the middle of the set, in the middle of the phase.
    "halfway": lambda: note(D5, 320, decay=1.1, level=0.85),
    # Finished. A major triad up — the only cue in the app that is allowed to
    # sound pleased with itself.
    "done": lambda: mix(
        note(C5, 140), note(E5, 140, bright=0.7), note(G5, 600, decay=0.6, bright=0.45)
    ),
}


def main():
    os.makedirs(os.path.join("assets", "sounds"), exist_ok=True)
    for name, make in TONES.items():
        write(name, make())


if __name__ == "__main__":
    main()
