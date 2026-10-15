package com.anvuman.cadent

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

    /**
     * How long one of the user's own sounds is allowed to play.
     *
     * Ours are a quarter of a second by design. A notification sound the user
     * picked can be any length at all, and one still ringing when the next cue
     * lands is how a timer stops being readable by ear. Our own tones are
     * never capped — they are already short, and there is no reason to put a
     * fade on something that has already finished.
     */
    private const val OWN_SOUND_MS = 1500L

    /** Taken off the end of that, so a cut-off sound does not click. */
    private const val OWN_FADE_MS = 250L

    /** Steps in the fade. Five is inaudibly smooth and costs five messages. */
    private const val FADE_STEPS = 5

    private lateinit var appContext: Context
    private var renderer: PhraseRenderer? = null

    private var thread: HandlerThread? = null
    private var handler: Handler? = null
    private val main = Handler(Looper.getMainLooper())

    private var pool: SoundPool? = null
    private val soundIds = mutableMapOf<String, Int>()

    /** Clips that are the user's own, and so have to be kept short. */
    private val capped = mutableSetOf<String>()
    private val loadPending = mutableSetOf<Int>()
    private var onLoaded: (() -> Unit)? = null

    private var focusRequest: AudioFocusRequest? = null

    /** uptimeMillis of cue time zero, and whether a session is armed. */
    private var startedAt = 0L
    private var active = false

    /**
     * The list it was handed, kept so the session can be paused and picked up
     * again without Dart. Pausing playback is a playback job, and the buttons
     * that do it are on a notification that outlives the UI.
     */
    private var cues: List<Pair<Int, String>> = emptyList()

    /** Elapsed time at the moment of pausing, or null while running. */
    private var pausedAt: Long? = null

    private var endsAt = 0L
    private var countingUp = false

    /**
     * Drops a clip from memory so the next session loads it afresh.
     *
     * Needed because [SoundPool] holds decoded audio, not a file handle: once
     * a tone has been loaded, replacing the file underneath it changes
     * nothing at all. Without this, picking your own sound would keep playing
     * ours until the app was killed — which is both wrong and the kind of
     * wrong that looks like the feature not working.
     *
     * Takes the name a sound is filed under, not a clip name; see
     * [OwnSounds.idOf] for why those differ.
     */
    fun forget(id: String) {
        // Every clip that sound stands in for, across every set — the pool is
        // keyed by clip name (`tone-wood-work`) and this is handed the name a
        // sound is filed under (`tone-work`). Dropping only an exact match
        // would leave the old clip loaded and playing, which is the whole
        // thing this exists to prevent.
        val gone = soundIds.keys.filter { OwnSounds.idOf(it) == id }
        for (key in gone) {
            soundIds.remove(key)?.let { pool?.unload(it) }
            capped.remove(key)
        }
    }

    /** Told to Dart as cues play, and when the notification is used. */
    var onFired: ((String) -> Unit)? = null
    var onStopped: (() -> Unit)? = null
    var onPaused: ((Boolean) -> Unit)? = null

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
        pausedAt?.let { return it }
        val elapsed = SystemClock.uptimeMillis() - startedAt
        return if (elapsed < 0) 0 else elapsed
    }

    fun isPaused(): Boolean = active && pausedAt != null

    fun available(callback: (Boolean) -> Unit) {
        renderer?.available(callback) ?: callback(false)
    }

    /**
     * Renders anything new, puts the bundled tones in beside it, loads every
     * clip into memory, then calls back.
     *
     * Dart awaits this before starting, which is what buys the right to be
     * exact afterwards: by the time the first cue is due there is nothing left
     * to decode, allocate or ask the speech engine for.
     *
     * A tone needs no speech engine, so a phone with no voice at all can still
     * run a session in tone mode — the render step fails every phrase, and the
     * tones go in and play regardless.
     */
    fun warm(
        phrases: Map<String, String>,
        tones: Map<String, ByteArray>,
        callback: (List<String>) -> Unit,
    ) {
        val renderer = this.renderer ?: return callback(phrases.keys.toList())
        renderer.render(phrases) { failedKeys ->
            // After rendering, never before: rendering is what notices the
            // phone's voice has changed and drops the whole cache, and a tone
            // written ahead of that would be deleted on the way past.
            renderer.install(tones)
            // Which clips are the user's own, in clip names rather than in
            // the names they are filed under — `fire` is handed a clip key.
            capped.clear()
            val own = OwnSounds.names(appContext).keys
            capped.addAll(
                (phrases.keys + tones.keys).filter { OwnSounds.idOf(it) in own }
            )
            load((phrases.keys - failedKeys.toSet()) + tones.keys) {
                callback(failedKeys)
            }
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
        countUp: Boolean = false,
    ): Long {
        clearTimers()

        this.cues = cues
        pausedAt = null
        countingUp = countUp
        startedAt = SystemClock.uptimeMillis() + leadMs
        active = true

        val lastCueAt = cues.maxOfOrNull { it.first } ?: 0
        endsAt = startedAt + lastCueAt
        // A stopwatch has no end to count down to, and the end of its armed
        // window is not one: it would show a countdown to nothing.
        TimerService.start(appContext, title, text, if (countUp) 0L else endsAt)

        armFrom(0)
        return startedAt
    }

    /** Posts every cue from [elapsed] onwards. */
    private fun armFrom(elapsed: Long) {
        val handler = ensureHandler()
        for ((atMs, key) in cues) {
            if (atMs < elapsed) continue
            val playAt = startedAt + atMs
            handler.postAtTime({ fire(key) }, playAt)
            // A duck request in the past fires at once, which is harmless.
            handler.postAtTime({ duck() }, playAt - FOCUS_LEAD_MS)
        }
        if (!countingUp) {
            handler.postAtTime({ main.post { finish() } }, endsAt + TAIL_MS)
        }
    }

    /**
     * Holds the session where it is: the cues stop, the clock stops, and the
     * service stays up so the notification and the wake lock are still there
     * to come back to.
     *
     * Done here rather than in Dart because the buttons that call it are on a
     * notification that outlives the UI — and because the list is already
     * here, so picking it up again needs nothing from anybody.
     */
    fun pause() {
        if (!active || pausedAt != null) return
        pausedAt = elapsedMs() ?: 0
        clearTimers()
        releaseFocus()
        TimerService.setPaused(true)
        main.post { onPaused?.invoke(true) }
    }

    fun resume() {
        val from = pausedAt ?: return
        pausedAt = null
        // Re-anchor so the clock picks up where it stopped rather than where
        // it would have been.
        val now = SystemClock.uptimeMillis()
        startedAt = now - from
        endsAt = startedAt + (cues.maxOfOrNull { it.first } ?: 0)
        TimerService.setPaused(false, if (countingUp) 0L else endsAt)
        armFrom(from)
        main.post { onPaused?.invoke(false) }
    }

    /** Drops everything armed and ends the session. */
    fun cancel() {
        clearTimers()
        active = false
        pausedAt = null
        cues = emptyList()
        releaseFocus()
        TimerService.stop(appContext)
    }

    /** The Stop button on the notification. Dart is told, and owns what next. */
    fun stopFromNotification() {
        cancel()
        main.post { onStopped?.invoke() }
    }

    /** The Pause / Resume button on the notification. */
    fun togglePauseFromNotification() {
        if (pausedAt == null) pause() else resume()
    }

    /** Updates what the notification says, while Dart is awake to say it. */
    fun describe(title: String, text: String) {
        if (active) TimerService.describe(title, text)
    }

    /** The session ran to its end on its own. */
    private fun finish() {
        active = false
        pausedAt = null
        cues = emptyList()
        releaseFocus()
        TimerService.stop(appContext)
    }

    private fun fire(key: String) {
        val id = soundIds[key]
        if (id != null) {
            val stream = pool?.play(id, 1f, 1f, 1, 0, 1f) ?: 0
            if (stream != 0 && key in capped) fadeOut(stream)
        }
        main.post { onFired?.invoke(key) }
    }

    /**
     * Brings one of the user's own sounds down and stops it.
     *
     * On the cue thread, so a busy main thread cannot stretch a fade — the
     * same reason the cues themselves are posted there.
     */
    private fun fadeOut(stream: Int) {
        val handler = ensureHandler()
        val from = OWN_SOUND_MS - OWN_FADE_MS
        for (step in 1..FADE_STEPS) {
            val at = from + OWN_FADE_MS * step / FADE_STEPS
            val volume = 1f - step.toFloat() / FADE_STEPS
            handler.postDelayed({
                if (volume <= 0f) pool?.stop(stream)
                else pool?.setVolume(stream, volume, volume)
            }, at)
        }
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
        onPaused = null
    }
}
