package com.anvuman.talking_stopwatch

import android.content.Context
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.media.SoundPool
import android.os.Handler
import android.os.HandlerThread
import android.os.Looper
import android.os.SystemClock

/**
 * Plays a list of cues at exact times.
 *
 * This is the only part of the app that has to be punctual, so it is also the
 * only part that is allowed to be dull. It knows nothing about workouts,
 * rounds, phases or rest: it is handed "say this, that many milliseconds from
 * now" and it says it. All of the thinking stays in Dart, which means there is
 * never a second copy of the session to drift out of step with the first.
 *
 * Why it works with the screen off: the whole schedule is armed up front with
 * [Handler.postAtTime], so once a session starts no further instruction from
 * Dart is needed and it does not matter that Flutter is frozen. The catch is
 * that `postAtTime` runs on [SystemClock.uptimeMillis], which stops advancing
 * in deep sleep — so [TimerService] holds a partial wake lock for the length of
 * the session. That wake lock is not a nicety; without it the phone sleeps
 * between cues and the countdown silently stretches.
 *
 * A singleton, because it has to outlive the activity: the user locks the
 * screen, Android may tear the activity down, and the cues must keep coming.
 */
object CueEngine {
    /** Ask for ducking slightly before the cue, so music is already quiet. */
    private const val FOCUS_LEAD_MS = 250L

    /** Hold ducking this long after a cue, and longer if another follows. */
    private const val FOCUS_TAIL_MS = 1200L

    /** Two is enough for a cue that lands while the last one is still ringing. */
    private const val MAX_STREAMS = 2

    /** Let the last cue finish speaking before the notification disappears. */
    private const val TAIL_MS = 2500L

    private lateinit var appContext: Context
    private var renderer: PhraseRenderer? = null

    private var thread: HandlerThread? = null
    private var handler: Handler? = null
    private val main = Handler(Looper.getMainLooper())

    private var pool: SoundPool? = null
    private val soundIds = mutableMapOf<String, Int>()
    private val loadPending = mutableSetOf<Int>()
    private var onLoaded: (() -> Unit)? = null

    private var focusRequest: AudioFocusRequest? = null

    /** uptimeMillis of cue time zero, and whether a session is armed. */
    private var startedAt = 0L
    private var active = false

    /** Told to Dart as cues play, and if the user stops from the notification. */
    var onFired: ((String) -> Unit)? = null
    var onStopped: (() -> Unit)? = null

    private val attributes = AudioAttributes.Builder()
        .setUsage(AudioAttributes.USAGE_MEDIA)
        .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
        .build()

    fun attach(context: Context) {
        if (!::appContext.isInitialized) appContext = context.applicationContext
        if (renderer == null) renderer = PhraseRenderer(appContext)
    }

    fun isActive(): Boolean = active

    /** How long the session has been running, or null when there is none. */
    fun elapsedMs(): Long? {
        if (!active) return null
        val elapsed = SystemClock.uptimeMillis() - startedAt
        return if (elapsed < 0) 0 else elapsed
    }

    fun available(callback: (Boolean) -> Unit) {
        renderer?.available(callback) ?: callback(false)
    }

    /**
     * Renders anything new and loads every clip into memory, then calls back.
     *
     * Dart awaits this before starting, which is what buys the right to be
     * exact afterwards: by the time the first cue is due there is nothing left
     * to decode, allocate or ask the speech engine for.
     */
    fun warm(phrases: Map<String, String>, callback: (List<String>) -> Unit) {
        val renderer = this.renderer ?: return callback(phrases.keys.toList())
        renderer.render(phrases) { failedKeys ->
            load(phrases.keys - failedKeys.toSet()) { callback(failedKeys) }
        }
    }

    /**
     * Arms the whole list and starts the session. Replaces anything already
     * armed. Returns the uptime that cue time zero was pinned to.
     *
     * [leadMs] is the head start before cue zero, covering the channel round
     * trip so that a cue at time zero is not already late when it arrives.
     */
    fun schedule(
        cues: List<Pair<Int, String>>,
        leadMs: Long,
        title: String,
        text: String,
    ): Long {
        clearTimers()
        val handler = ensureHandler()

        val now = SystemClock.uptimeMillis()
        startedAt = now + leadMs
        active = true

        val lastCueAt = cues.maxOfOrNull { it.first } ?: 0
        val endsAt = startedAt + lastCueAt
        TimerService.start(appContext, title, text, endsAt)

        for ((atMs, key) in cues) {
            val playAt = startedAt + atMs
            handler.postAtTime({ fire(key) }, playAt)
            // A duck request in the past fires at once, which is harmless.
            handler.postAtTime({ duck() }, playAt - FOCUS_LEAD_MS)
        }
        handler.postAtTime({ main.post { finish() } }, endsAt + TAIL_MS)

        return startedAt
    }

    /** Drops everything armed and ends the session. */
    fun cancel() {
        clearTimers()
        active = false
        releaseFocus()
        TimerService.stop(appContext)
    }

    /** The Stop button on the notification. Dart is told, and owns what next. */
    fun stopFromNotification() {
        cancel()
        main.post { onStopped?.invoke() }
    }

    /** Updates what the notification says, while Dart is awake to say it. */
    fun describe(title: String, text: String) {
        if (active) TimerService.describe(title, text)
    }

    /** The session ran to its end on its own. */
    private fun finish() {
        active = false
        releaseFocus()
        TimerService.stop(appContext)
    }

    private fun fire(key: String) {
        val id = soundIds[key]
        if (id != null) pool?.play(id, 1f, 1f, 1, 0, 1f)
        main.post { onFired?.invoke(key) }
    }

    // --- audio focus -------------------------------------------------------
    //
    // Requested per cue rather than for the session: holding focus for twenty
    // minutes would leave the user's music quiet for twenty minutes. Each cue
    // pushes the release out, so a run of "three, two, one, go" ducks once
    // rather than four times.

    private val release = Runnable { releaseFocus() }

    private fun duck() {
        val audio = appContext.getSystemService(AudioManager::class.java) ?: return
        if (focusRequest == null) {
            val request = AudioFocusRequest
                .Builder(AudioManager.AUDIOFOCUS_GAIN_TRANSIENT_MAY_DUCK)
                .setAudioAttributes(attributes)
                .setWillPauseWhenDucked(false)
                .build()
            audio.requestAudioFocus(request)
            focusRequest = request
        }
        handler?.removeCallbacks(release)
        handler?.postDelayed(release, FOCUS_TAIL_MS)
    }

    private fun releaseFocus() {
        val request = focusRequest ?: return
        focusRequest = null
        appContext.getSystemService(AudioManager::class.java)
            ?.abandonAudioFocusRequest(request)
    }

    // --- sound loading -----------------------------------------------------

    private fun load(keys: Set<String>, done: () -> Unit) {
        val pool = ensurePool()
        val renderer = this.renderer ?: return done()

        // Forget clips whose file has gone — the renderer drops the cache when
        // the phone's voice changes, and a stale sample would say the old one.
        soundIds.entries.removeAll { (key, id) ->
            if (renderer.fileFor(key).exists()) false else { pool.unload(id); true }
        }

        val missing = keys.filter {
            !soundIds.containsKey(it) && renderer.fileFor(it).exists()
        }
        if (missing.isEmpty()) return done()

        onLoaded = done
        loadPending.clear()
        for (key in missing) {
            val id = pool.load(renderer.fileFor(key).path, 1)
            if (id == 0) continue
            loadPending.add(id)
            soundIds[key] = id
        }
        if (loadPending.isEmpty()) {
            onLoaded = null
            done()
        }
    }

    private fun ensurePool(): SoundPool {
        pool?.let { return it }
        val created = SoundPool.Builder()
            .setMaxStreams(MAX_STREAMS)
            .setAudioAttributes(attributes)
            .build()
        created.setOnLoadCompleteListener { _, sampleId, status ->
            main.post {
                if (status != 0) soundIds.entries.removeAll { it.value == sampleId }
                loadPending.remove(sampleId)
                if (loadPending.isEmpty()) {
                    val callback = onLoaded
                    onLoaded = null
                    callback?.invoke()
                }
            }
        }
        pool = created
        return created
    }

    private fun ensureHandler(): Handler {
        handler?.let { return it }
        // Its own thread, so a busy main thread cannot make a cue late.
        val created = HandlerThread("cues").also { it.start() }
        thread = created
        return Handler(created.looper).also { handler = it }
    }

    private fun clearTimers() {
        handler?.removeCallbacksAndMessages(null)
    }

    /** Lets go of the activity's callbacks; the session itself carries on. */
    fun detachListeners() {
        onFired = null
        onStopped = null
    }
}
