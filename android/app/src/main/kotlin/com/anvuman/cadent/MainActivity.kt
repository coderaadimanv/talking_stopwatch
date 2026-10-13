package com.anvuman.cadent

import android.Manifest
import android.content.ActivityNotFoundException
import android.content.Intent
import android.content.pm.PackageManager
import android.media.AudioManager
import android.media.RingtoneManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * The channel between Dart and [CueEngine].
 *
 * Nothing here decides anything. Dart sends the whole cue list and the engine
 * plays it, which is why the activity can be torn down mid-session without the
 * workout noticing.
 */
class MainActivity : FlutterActivity() {
    private var channel: MethodChannel? = null

    /// The tone being replaced and the call waiting on it, while the system's
    /// picker is in front. Null at every other moment.
    private var picking: String? = null
    private var pickResult: MethodChannel.Result? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Point the volume keys at the voice.
        //
        // By default they move whichever stream is making a noise, and the
        // ringer when nothing is. Cues are a word every few minutes, so for
        // almost the whole session nothing is — which means someone standing
        // over a phone in a stand, pressing volume up because the countdown
        // is too quiet, is turning up their ringtone and hearing no
        // difference. One line, and the keys mean what the user thinks they
        // mean for as long as this screen is open.
        volumeControlStream = AudioManager.STREAM_MUSIC
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        CueEngine.attach(applicationContext)
        // A session that died without tidying up may have left the phone
        // silent. Put it back before anything else happens.
        TimerService.restoreIfStranded(applicationContext)

        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        this.channel = channel

        CueEngine.onFired = { key -> channel.invokeMethod("fired", key) }
        CueEngine.onStopped = { channel.invokeMethod("stopped", null) }
        CueEngine.onPaused = { paused -> channel.invokeMethod("paused", paused) }

        channel.setMethodCallHandler { call, result -> handle(call, result) }
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        // The session outlives the UI, so let go of the channel but leave the
        // engine running: it is still talking to someone in a gym.
        CueEngine.detachListeners()
        channel?.setMethodCallHandler(null)
        channel = null
        super.cleanUpFlutterEngine(flutterEngine)
    }

    private fun handle(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "available" -> CueEngine.available { result.success(it) }

            "warm" -> {
                val phrases = call.argument<Map<String, String>>("phrases").orEmpty()
                val tones = call.argument<Map<String, ByteArray>>("tones").orEmpty()
                CueEngine.warm(phrases, tones) { failed -> result.success(failed) }
            }

            "schedule" -> {
                val at = call.argument<List<Int>>("at").orEmpty()
                val keys = call.argument<List<String>>("keys").orEmpty()
                if (at.size != keys.size) {
                    result.error("bad_args", "at and keys must match", null)
                    return
                }
                val startedAt = CueEngine.schedule(
                    at.indices.map { at[it] to keys[it] },
                    (call.argument<Int>("leadMs") ?: 250).toLong(),
                    call.argument<String>("title") ?: "Workout",
                    call.argument<String>("text") ?: "",
                    countUp = call.argument<Boolean>("countUp") ?: false,
                )
                result.success(startedAt)
            }

            "cancel" -> {
                CueEngine.cancel()
                result.success(null)
            }

            "elapsed" -> result.success(CueEngine.elapsedMs())

            "isPaused" -> result.success(CueEngine.isPaused())

            "pause" -> {
                CueEngine.pause()
                result.success(null)
            }

            "resume" -> {
                CueEngine.resume()
                result.success(null)
            }

            "describe" -> {
                CueEngine.describe(
                    call.argument<String>("title") ?: "Workout",
                    call.argument<String>("text") ?: "",
                )
                result.success(null)
            }

            "keepAwake" -> {
                val on = call.argument<Boolean>("on") ?: false
                if (on) {
                    window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                } else {
                    window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                }
                result.success(null)
            }

            // Only decides whether the service's notification is visible. The
            // session runs either way, so a refusal is not worth reporting.
            "askToNotify" -> {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
                    checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) !=
                    PackageManager.PERMISSION_GRANTED
                ) {
                    requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 1)
                }
                result.success(null)
            }

            // Asked by the settings screen, to explain a lock screen that
            // stayed empty. Nothing here acts on the answer: the session runs
            // whatever it is.
            "canNotify" -> result.success(TimerService.canNotify(this))

            "openNotifySettings" -> {
                openNotifySettings()
                result.success(null)
            }

            // The user's own sounds. Android only — see `pickSound` on the
            // Dart side for why iOS answers nothing at all.
            "ownSounds" -> result.success(OwnSounds.names(applicationContext))

            "pickSound" -> {
                val key = call.argument<String>("key")
                if (key == null) {
                    result.error("bad_args", "pickSound needs a key", null)
                } else if (picking != null) {
                    // A second picker while the first is up would leave one of
                    // the two calls waiting for a result that never comes.
                    result.success(null)
                } else {
                    picking = key
                    pickResult = result
                    if (!openPicker()) {
                        picking = null
                        pickResult = null
                        result.success(null)
                    }
                }
            }

            "clearSound" -> {
                call.argument<String>("key")?.let {
                    OwnSounds.clear(applicationContext, it)
                    CueEngine.forget(it)
                }
                result.success(null)
            }

            "canSilence" -> result.success(TimerService.canSilence(this))

            "silence" -> {
                TimerService.silence(this, call.argument<Boolean>("on") ?: false)
                result.success(null)
            }

            // There is no prompt for this one. Do Not Disturb access is
            // granted on a system screen and nowhere else.
            "openSilenceSettings" -> {
                openSettings(
                    Intent(Settings.ACTION_NOTIFICATION_POLICY_ACCESS_SETTINGS),
                )
                result.success(null)
            }

            else -> result.notImplemented()
        }
    }

    /**
     * The system's picker, showing the phone's notification sounds.
     *
     * A system screen, not a list of our own: it needs no permission, it
     * already knows every sound the phone has, and it is the one the user
     * recognises. Answers whether it opened at all — a device can be without
     * it, and a promise of a picker that never appears is worse than no
     * picker.
     */
    private fun openPicker(): Boolean = try {
        startActivityForResult(
            Intent(RingtoneManager.ACTION_RINGTONE_PICKER)
                .putExtra(
                    RingtoneManager.EXTRA_RINGTONE_TYPE,
                    RingtoneManager.TYPE_NOTIFICATION,
                )
                .putExtra(RingtoneManager.EXTRA_RINGTONE_TITLE, "Pick a sound")
                // Nothing is not a choice here: a tone that plays nothing is
                // what turning the cue off is for, one screen up.
                .putExtra(RingtoneManager.EXTRA_RINGTONE_SHOW_SILENT, false)
                .putExtra(RingtoneManager.EXTRA_RINGTONE_SHOW_DEFAULT, false),
            PICK_SOUND,
        )
        true
    } catch (_: ActivityNotFoundException) {
        false
    }

    /**
     * What the picker chose, copied before the grant that came with it
     * expires. Everything about why that copy happens is in [OwnSounds].
     */
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != PICK_SOUND) return

        val key = picking
        val result = pickResult
        picking = null
        pickResult = null
        if (key == null || result == null) return

        val extra = RingtoneManager.EXTRA_RINGTONE_PICKED_URI
        val uri = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            data?.getParcelableExtra(extra, Uri::class.java)
        } else {
            @Suppress("DEPRECATION")
            data?.getParcelableExtra<Uri>(extra)
        }
        if (resultCode != RESULT_OK || uri == null) {
            // Backed out, or picked silence. Nothing changes.
            result.success(null)
            return
        }
        val title = OwnSounds.save(applicationContext, key, uri)
        // The clip is already decoded in memory from an earlier session, and
        // replacing the file underneath it would change nothing.
        if (title != null) CueEngine.forget(key)
        result.success(title)
    }

    /**
     * The system's own notification screen for this app.
     *
     * Deliberately not another in-app prompt. Android allows
     * POST_NOTIFICATIONS exactly one dialog: after a refusal
     * `requestPermissions` reports denied without showing anything, so a
     * button that promised to ask would quietly do nothing. This screen
     * always works, and the app's details screen is the fallback for a build
     * that is missing the first.
     */
    private fun openNotifySettings() {
        openSettings(
            Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
                .putExtra(Settings.EXTRA_APP_PACKAGE, packageName),
        )
    }

    /**
     * Opens a system screen, falling back to this app's details page.
     *
     * Every one of these actions is optional for a device to implement, and a
     * missing one throws rather than doing nothing. The details page exists
     * everywhere and has what is being asked for somewhere inside it.
     */
    private fun openSettings(intent: Intent) {
        val routes = listOf(
            intent,
            Intent(
                Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                Uri.fromParts("package", packageName, null),
            ),
        )
        for (route in routes) {
            try {
                startActivity(route)
                return
            } catch (_: ActivityNotFoundException) {
                // Try the next one.
            }
        }
    }

    private companion object {
        const val CHANNEL = "com.anvuman.cadent/cues"
        const val PICK_SOUND = 2
    }
}
