package com.anvuman.cadent

import java.io.File
import java.io.IOException
import java.nio.ByteBuffer
import java.nio.ByteOrder
import kotlin.math.abs
import kotlin.math.min
import kotlin.math.roundToInt
import kotlin.math.sqrt
import kotlin.math.tanh

/**
 * Lifts a rendered clip to a loudness you can hear across a gym.
 *
 * The phone's own voice renders quietly. Measured on Google's engine, a cue
 * comes back at about -6 dBFS peak and -17 dBFS across the speech itself:
 * a sensible level for a file, and the wrong one for this app, where the clip
 * has to carry from a phone in a stand, over music, out of a speaker the size
 * of a fingernail, to someone halfway through a set.
 *
 * There is nowhere else to make it up. [android.media.SoundPool]'s volume is a
 * fraction of the media stream, so the 1.0 it is already played at is the
 * ceiling, and the only room left is inside the file.
 *
 * So each clip is given the gain that brings its speech to [TARGET_RMS], and
 * the few samples that would then pass [KNEE] are bent smoothly into the
 * ceiling instead of being clipped flat against it. On real cues that works
 * out at about +6 dB with roughly one sample in a hundred touched: clearly
 * louder, and a long way short of the distortion that makes a small speaker
 * rattle.
 *
 * The silence is left out of the measurement. A clip is mostly the pause
 * around the word, and averaging that in would ask for a gain the word does
 * not need.
 */
object Loudness {
    /** Where a clip's speech should sit. -11 dBFS, as a fraction of full scale. */
    private const val TARGET_RMS = 0.282f

    /** However quiet the clip, never more gain than this. */
    private const val MAX_GAIN = 4f

    /** Where the curve starts bending. Below this nothing is touched at all. */
    private const val KNEE = 0.70f

    /** Nothing is allowed past this, so the shaping can never wrap around. */
    private const val CEILING = 0.99f

    /** Quieter than this share of the peak is the pause, not the word. */
    private const val SILENCE = 1 / 32f

    private const val FULL = 32767f

    /**
     * Rewrites [file] louder, in place. Answers whether it changed anything.
     *
     * Anything it does not understand — a format that is not 16-bit PCM, a
     * header it cannot walk, a clip that is already loud — it leaves exactly
     * as it found it. A quiet cue is a small disappointment; a corrupted one
     * is a cue that never plays again, because the cache would keep it.
     *
     * The new bytes go to a temporary file and are moved into place, so a
     * process killed mid-write leaves the old clip rather than half of a new
     * one.
     */
    fun lift(file: File): Boolean {
        val bytes = try {
            file.readBytes()
        } catch (_: IOException) {
            return false
        }

        val samples = samplesOf(bytes) ?: return false
        if (!amplify(samples)) return false

        val temp = File(file.parentFile, "${file.name}.tmp")
        return try {
            temp.writeBytes(bytes)
            temp.renameTo(file) || run { temp.delete(); false }
        } catch (_: IOException) {
            temp.delete()
            false
        }
    }

    /**
     * Measures the clip and applies the gain, writing through to the array the
     * buffer is a view of. Answers whether it was worth doing.
     */
    private fun amplify(samples: java.nio.ShortBuffer): Boolean {
        val count = samples.limit()
        if (count == 0) return false

        var peak = 0
        for (i in 0 until count) {
            val size = abs(samples[i].toInt())
            if (size > peak) peak = size
        }
        if (peak == 0) return false

        // The speech, not the pause either side of it.
        val floor = peak * SILENCE
        var sum = 0.0
        var spoken = 0
        for (i in 0 until count) {
            val value = samples[i].toInt()
            if (abs(value) <= floor) continue
            sum += value.toDouble() * value
            spoken++
        }
        if (spoken == 0) return false

        val rms = sqrt(sum / spoken) / FULL
        val gain = min(TARGET_RMS / rms, MAX_GAIN.toDouble()).toFloat()
        // Under a fifth of a decibel. Not worth rewriting a file for.
        if (gain <= 1.02f) return false

        for (i in 0 until count) {
            val lifted = shape(samples[i] * gain / FULL)
            samples.put(i, (lifted * FULL).roundToInt().toShort())
        }
        return true
    }

    /**
     * The limiter: linear up to the knee, then a curve that flattens into the
     * ceiling and never reaches it.
     *
     * `tanh` because it is smooth where it meets the straight part. A hard
     * clip puts a corner in the waveform, and a corner is a click.
     */
    private fun shape(value: Float): Float {
        val size = abs(value)
        if (size <= KNEE) return value
        val over = (size - KNEE) / (1 - KNEE)
        val shaped = min(KNEE + (1 - KNEE) * tanh(over), CEILING)
        return if (value < 0) -shaped else shaped
    }

    /**
     * The clip's samples, as a view onto [bytes] that writes back through.
     *
     * Null for anything that is not 16-bit PCM, which the speech engine has
     * never produced and which this is in no position to guess at.
     */
    private fun samplesOf(bytes: ByteArray): java.nio.ShortBuffer? {
        if (bytes.size < 44) return null
        if (tag(bytes, 0) != "RIFF" || tag(bytes, 8) != "WAVE") return null

        val buffer = ByteBuffer.wrap(bytes).order(ByteOrder.LITTLE_ENDIAN)
        var at = 12
        var pcm16 = false

        while (at + 8 <= bytes.size) {
            val size = buffer.getInt(at + 4)
            if (size < 0) return null
            val body = at + 8

            when (tag(bytes, at)) {
                "fmt " -> {
                    if (size < 16 || body + 16 > bytes.size) return null
                    pcm16 = buffer.getShort(body).toInt() == 1 &&
                        buffer.getShort(body + 14).toInt() == 16
                }

                "data" -> {
                    if (!pcm16) return null
                    val end = min(body + size, bytes.size)
                    if (end - body < 2) return null
                    return ByteBuffer
                        .wrap(bytes, body, end - body)
                        .order(ByteOrder.LITTLE_ENDIAN)
                        .asShortBuffer()
                }
            }

            // Chunks are padded to an even length, and the pad is not counted.
            at = body + size + (size and 1)
        }
        return null
    }

    private fun tag(bytes: ByteArray, at: Int): String =
        String(bytes, at, 4, Charsets.US_ASCII)
}
