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

What makes these audible on a phone speaker
-------------------------------------------

Three things, none of them obvious:

* **Harmonics.** A pure sine is the quietest possible sound for its amplitude
  on a small driver, because a phone speaker can barely move air at the
  fundamental. Each note here carries a second and third harmonic, which is
  what the speaker can actually reproduce, and the ear reconstructs the pitch
  from them.
* **An envelope.** A note that starts instantly clicks, and the click is the
  loudest part of it. These fade in over a few milliseconds and decay away.
* **The same loudness as the voice.** The last step is exactly the arithmetic
  in `Loudness.kt` and `CuePlayer.swift` — speech lifted to -11 dBFS RMS with a
  soft knee into the ceiling — so a tone and a spoken cue land at the same
  level, and so the device-side lift measures these as already-there and
  leaves them alone.
"""

import math
import os
import struct
import wave

RATE = 24000          # what the speech engine renders at
TARGET_RMS = 0.282    # -11 dBFS, the same figure as Loudness.kt
MAX_GAIN = 4.0
KNEE = 0.70
CEILING = 0.99
SILENCE = 1 / 32

# Pitches, so the notes below read as music rather than as frequencies.
C5, D5, E5, F5, G5, A5, C6 = 523.25, 587.33, 659.25, 698.46, 783.99, 880.0, 1046.5


def note(freq, ms, *, attack_ms=6, shape=2.6, level=1.0):
    """One note: a fundamental with two harmonics under a decaying envelope."""
    out = []
    total = int(RATE * ms / 1000)
    attack = max(1, int(RATE * attack_ms / 1000))
    for i in range(total):
        t = i / RATE
        # Fade in quickly, then decay. The decay is exponential because that is
        # what a struck object does, and anything else sounds synthetic.
        env = min(1.0, i / attack) * math.exp(-shape * i / total)
        value = (
            math.sin(2 * math.pi * freq * t)
            + 0.25 * math.sin(2 * math.pi * freq * 2 * t)
            + 0.12 * math.sin(2 * math.pi * freq * 3 * t)
        )
        out.append(value * env * level / 1.37)
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


# The six sounds. Each one has to be recognisable on its own, a quarter of a
# second long, and tell you something the others do not.
TONES = {
    # Starting. One soft note, low in the set: nothing is happening yet.
    "ready": lambda: note(C5, 300, shape=2.2, level=0.8),
    # Work. Rising, and the brightest pair here — this is the one that has to
    # cut through a gym.
    "work": lambda: mix(note(D5, 130, shape=3.2), note(A5, 220, shape=2.4)),
    # Rest. The same shape falling, which is the whole trick: you do not have
    # to learn these two, you only have to hear which way they go.
    "rest": lambda: mix(
        note(A5, 130, shape=3.2, level=0.85), note(D5, 240, shape=2.2, level=0.85)
    ),
    # The countdown. Short and dry, because three of them land a second apart
    # and anything with a tail would smear into the next.
    "tick": lambda: note(C6, 60, attack_ms=2, shape=5.0, level=0.75),
    # Halfway. One note in the middle of the set, in the middle of the phase.
    "halfway": lambda: note(F5, 200, shape=2.8, level=0.8),
    # Finished. Three notes up — the only cue in the app that is allowed to
    # sound pleased with itself.
    "done": lambda: mix(
        note(D5, 120, shape=3.4), note(G5, 120, shape=3.4), note(C6, 320, shape=2.0)
    ),
}


def main():
    os.makedirs(os.path.join("assets", "sounds"), exist_ok=True)
    for name, make in TONES.items():
        write(name, make())


if __name__ == "__main__":
    main()
