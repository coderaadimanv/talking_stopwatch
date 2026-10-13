package com.anvuman.cadent

import android.content.Context
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.speech.tts.TextToSpeech
import android.speech.tts.UtteranceProgressListener
import java.io.File

/**
 * Turns phrases into audio files, once, using the phone's own voice.
 *
 * Speaking a cue at the moment it is due does not work: TextToSpeech takes
 * somewhere between 100 and 400 unpredictable milliseconds to start, which is
 * enough to land "three" after the phase it was counting down has already
 * changed. So nothing is ever spoken live. Every phrase is synthesised to a
 * file ahead of time and played from there, where the only delay left is the
 * audio path itself and it is the same every time.
 *
 * Files are named by the key Dart computed for the text, and kept in the cache
 * directory: losing them costs one re-render, not any user data.
 */
class PhraseRenderer(private val context: Context) {
    private var tts: TextToSpeech? = null
    private var ready: Boolean? = null // null while the engine starts
    private val waiting = mutableListOf<() -> Unit>()
    private val main = Handler(Looper.getMainLooper())

    /** Utterances in flight, and what to do when the last one lands. */
    private val pending = mutableSetOf<String>()
    private val failed = mutableSetOf<String>()
    private var onBatchDone: ((List<String>) -> Unit)? = null

    private val dir: File
        get() = File(context.cacheDir, "phrases").also { it.mkdirs() }

    private companion object {
        /**
         * Bumped whenever a clip would come out differently from the same
         * voice saying the same words.
         *
         * It rides along in the voice stamp because it is the same promise:
         * a cached file is only good while the thing that made it is
         * unchanged, and the engine is only half of that. Without this, every
         * phone that has already run a workout keeps the quiet clips it
         * rendered before [Loudness] existed, forever.
         */
        const val RENDERING = "gain1"
    }

    fun fileFor(key: String): File = File(dir, "$key.wav")

    /**
     * Puts a bundled clip into the cache, so that from here on it is
     * indistinguishable from a rendered phrase.
     *
     * That is the whole trick behind tone mode: the cue engine loads clips by
     * name and plays them by name, so a tone only has to arrive in the same
     * place under the same sort of name and nothing downstream learns it
     * exists.
     *
     * Not lifted by [Loudness], and not because it is skipped — the tones are
     * made at the level the lift targets, so measuring one gives a gain of
     * about 1.00 and it would be left alone anyway. Writing them straight to
     * disk just saves the arithmetic.
     *
     * Already-present clips are left alone: a session starts with this call,
     * and rewriting six files every time would be work for nothing.
     */
    fun install(clips: Map<String, ByteArray>) {
        for ((key, bytes) in clips) {
            val file = fileFor(key)
            if (file.exists() && file.length() == bytes.size.toLong()) continue
            try {
                val temp = File(dir, "$key.wav.tmp")
                temp.writeBytes(bytes)
                if (!temp.renameTo(file)) temp.delete()
            } catch (_: java.io.IOException) {
                // A tone we cannot write is a cue that stays silent, which is
                // the same way every other failure in here is handled.
            }
        }
    }

    /** Whether this phone has a voice at all. Without one the app stays silent. */
    fun available(callback: (Boolean) -> Unit) = whenReady {
        callback(ready == true && tts?.voice != null)
    }

    /**
     * Renders every phrase that is not already cached, then calls back with the
     * keys it could not render. Already-cached phrases cost nothing.
     *
     * Called before a session starts and awaited, so the first "go" never waits
     * on the speech engine.
     */
    fun render(phrases: Map<String, String>, callback: (List<String>) -> Unit) {
        whenReady {
            val engine = tts
            if (ready != true || engine == null) {
                callback(phrases.keys.toList())
                return@whenReady
            }

            dropCacheIfVoiceChanged()

            val todo = phrases.filterKeys { !fileFor(it).exists() }
            if (todo.isEmpty()) {
                callback(emptyList())
                return@whenReady
            }

            // One batch at a time. A second caller would otherwise steal the
            // completion callback from the first.
            if (onBatchDone != null) {
                callback(todo.keys.toList())
                return@whenReady
            }

            pending.clear()
            failed.clear()
            pending.addAll(todo.keys)
            onBatchDone = callback

            for ((key, text) in todo) {
                val params = Bundle()
                val status = engine.synthesizeToFile(text, params, fileFor(key), key)
                if (status != TextToSpeech.SUCCESS) finished(key, ok = false)
            }
        }
    }

    /**
     * The cached files are only good for the voice that made them, so the voice
     * in use is stamped beside them and the cache is dropped when it changes.
     * Dart's cache keys know nothing about voices, which is deliberate — this is
     * the only place that has to care.
     */
    private fun dropCacheIfVoiceChanged() {
        val stamp = File(dir, "voice.txt")
        val now = voiceStamp()
        if (stamp.exists() && stamp.readText() == now) return
        dir.listFiles()?.forEach { if (it.name.endsWith(".wav")) it.delete() }
        stamp.writeText(now)
    }

    private fun voiceStamp(): String {
        val engine = tts ?: return "none"
        val voice = engine.voice
        return "$RENDERING|${engine.defaultEngine}|${voice?.name ?: "?"}|${voice?.locale ?: "?"}"
    }

    /** Keeps the cache small enough to ignore: oldest files go first. */
    private fun trimCache(limitBytes: Long = 5L * 1024 * 1024) {
        // Tones are exempt. They are a hundred kilobytes in total, they are
        // wanted by every session that uses them, and evicting one would mean
        // a silent cue until the next warm put it back.
        val files = dir.listFiles { f: File ->
            f.name.endsWith(".wav") && !f.name.startsWith("tone-")
        } ?: return
        var total = files.sumOf { it.length() }
        if (total <= limitBytes) return
        for (file in files.sortedBy { it.lastModified() }) {
            if (total <= limitBytes) break
            total -= file.length()
            file.delete()
        }
    }

    private fun finished(id: String?, ok: Boolean) {
        val key = id ?: return
        main.post {
            if (!ok) failed.add(key)
            // A zero-length file is a failure the engine did not report.
            if (ok && fileFor(key).length() <= 0L) failed.add(key)
            pending.remove(key)
            if (pending.isEmpty()) {
                trimCache()
                val done = onBatchDone
                val bad = failed.toList()
                onBatchDone = null
                failed.clear()
                done?.invoke(bad)
            }
        }
    }

    private fun whenReady(action: () -> Unit) {
        if (ready != null) {
            action()
            return
        }
        waiting.add(action)
        if (tts == null) start()
    }

    private fun start() {
        tts = TextToSpeech(context) { status ->
            main.post {
                ready = status == TextToSpeech.SUCCESS
                val queued = waiting.toList()
                waiting.clear()
                queued.forEach { it() }
            }
        }
        tts?.setOnUtteranceProgressListener(object : UtteranceProgressListener() {
            override fun onStart(utteranceId: String?) = Unit

            override fun onDone(utteranceId: String?) {
                // Here rather than anywhere later, because this runs on the
                // engine's own thread and before the batch reports back — so
                // the file is already loud by the time anything loads it,
                // and the main thread never waits on the arithmetic.
                utteranceId?.let { Loudness.lift(fileFor(it)) }
                finished(utteranceId, ok = true)
            }

            @Deprecated("Replaced by the two-argument form, still called below 21")
            override fun onError(utteranceId: String?) = finished(utteranceId, ok = false)

            override fun onError(utteranceId: String?, errorCode: Int) =
                finished(utteranceId, ok = false)
        })
    }

    fun release() {
        tts?.shutdown()
        tts = null
        ready = null
    }
}
