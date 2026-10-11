package com.anvuman.talking_stopwatch

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
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

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        CueEngine.attach(applicationContext)

        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        this.channel = channel

        CueEngine.onFired = { key -> channel.invokeMethod("fired", key) }
        CueEngine.onStopped = { channel.invokeMethod("stopped", null) }

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
                CueEngine.warm(phrases) { failed -> result.success(failed) }
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

            else -> result.notImplemented()
        }
    }

    private companion object {
        const val CHANNEL = "com.anvuman.talking_stopwatch/cues"
    }
}
