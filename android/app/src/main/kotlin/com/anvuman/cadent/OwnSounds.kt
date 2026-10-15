package com.anvuman.cadent

import android.content.Context
import android.media.RingtoneManager
import android.net.Uri
import java.io.File
import java.io.IOException

/**
 * The sounds the user picked instead of ours.
 *
 * Kept as **copies**, and that is the whole design. The system picker hands
 * back a `content://` URI, and holding on to one is a promise the app cannot
 * keep: the read grant is not persisted, the file behind it can be moved or
 * deleted, and either way the failure arrives silently halfway through a
 * workout. A copy cannot do any of that. It also means a picked sound goes
 * down the identical path as every other clip from here on — loaded by name,
 * played by name — so nothing downstream learns it came from somewhere else.
 *
 * They live in `filesDir`, not in the audio cache, because the cache is
 * disposable: it is wiped whenever the phone's voice changes and trimmed when
 * it grows. These are the opposite of disposable — losing one means the user
 * has to go and find their sound again.
 *
 * The audio is copied byte for byte in whatever format it arrived in.
 * `SoundPool` reads mp3, ogg and wav by sniffing the content rather than the
 * name, so there is nothing to decode and no codec to get wrong. What a long
 * sound needs instead is a limit on how long it is allowed to play, and that
 * belongs to [CueEngine], which is the half that knows when the next cue is
 * due.
 */
object OwnSounds {
    /** Beyond this it is a song, not a notification sound. */
    private const val MAX_BYTES = 2L * 1024 * 1024

    private fun dir(context: Context): File =
        File(context.filesDir, "own-sounds").also { it.mkdirs() }

    /**
     * How a sound of the user's own is filed, given the clip it stands in for.
     *
     * **Without the set.** A clip is named `tone-<set>-<cue>` so that changing
     * sets cannot go on playing what was cached under the old name; a sound
     * the user chose is named `tone-<cue>`, because it is theirs whichever set
     * is on and losing it because they tried the tabla would be absurd. Taking
     * the last part of the clip name is all it takes to get from one to the
     * other, and neither half has to know anything else about the other.
     *
     * Null for anything that is not a tone — a rendered phrase is sixteen hex
     * characters and has no business here.
     */
    fun idOf(key: String): String? =
        if (key.startsWith("tone-")) "tone-" + key.substringAfterLast('-') else null

    /** The audio standing in for [key], or null where it has not been replaced. */
    fun file(context: Context, key: String): File? {
        val id = idOf(key) ?: return null
        return File(dir(context), id).takeIf { it.isFile && it.length() > 0 }
    }

    /** Every tone the user has replaced, and what they chose, for the UI. */
    fun names(context: Context): Map<String, String> {
        val files = dir(context).listFiles() ?: return emptyMap()
        return files
            .filter { it.isFile && !it.name.endsWith(NAME_SUFFIX) && it.length() > 0 }
            .associate { it.name to (nameOf(context, it.name) ?: "Your own sound") }
    }

    /**
     * Copies what the picker returned and answers what to call it.
     *
     * Done here and now, while the grant from the picker is still good, rather
     * than remembered and read later when it may not be.
     */
    fun save(context: Context, key: String, uri: Uri): String? {
        val target = File(dir(context), key)
        val temp = File(dir(context), "$key.tmp")
        try {
            val copied = context.contentResolver.openInputStream(uri)?.use { input ->
                temp.outputStream().use { output -> input.copyTo(output, 64 * 1024) }
            } ?: return null

            if (copied <= 0 || copied > MAX_BYTES) {
                temp.delete()
                return null
            }
            if (!temp.renameTo(target)) {
                temp.delete()
                return null
            }
        } catch (_: IOException) {
            temp.delete()
            return null
        } catch (_: SecurityException) {
            // The grant was already gone. Nothing to do but say so.
            temp.delete()
            return null
        }

        val title = titleOf(context, uri)
        File(dir(context), key + NAME_SUFFIX).writeText(title)
        return title
    }

    /** Puts our own tone back. */
    fun clear(context: Context, key: String) {
        File(dir(context), key).delete()
        File(dir(context), key + NAME_SUFFIX).delete()
    }

    /**
     * What the system calls the sound. Only ever shown, never matched on — a
     * title can change or come back empty, and the copy is what matters.
     */
    private fun titleOf(context: Context, uri: Uri): String = try {
        RingtoneManager.getRingtone(context, uri)?.getTitle(context)
            ?.takeIf { it.isNotBlank() } ?: "Your own sound"
    } catch (_: Exception) {
        "Your own sound"
    }

    private fun nameOf(context: Context, key: String): String? = try {
        File(dir(context), key + NAME_SUFFIX).takeIf { it.isFile }?.readText()
    } catch (_: IOException) {
        null
    }

    private const val NAME_SUFFIX = ".name"
}
