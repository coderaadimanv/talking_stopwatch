package com.anvuman.talking_stopwatch

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import android.os.SystemClock

/**
 * Keeps the session alive while the phone is in a pocket.
 *
 * Two jobs, and neither of them is timing. First, it is a foreground service,
 * which is what stops Android freezing the process the moment the screen goes
 * off. Second, it holds a partial wake lock, without which the device sleeps
 * between cues and [SystemClock.uptimeMillis] — the clock the whole schedule is
 * pinned to — quietly stops advancing.
 *
 * The notification is the only way to stop a shouting phone from the lock
 * screen, so it has a Stop button. Its countdown is drawn by Android from a
 * target time, so nothing here ticks.
 */
class TimerService : Service() {
    private var wakeLock: PowerManager.WakeLock? = null
    private var title = "Workout"
    private var text = ""
    private var endsAtWallClock = 0L
    private var paused = false

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        instance = this
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP -> {
                // The user tapped Stop on the notification. The engine tells
                // Dart, which decides what the session does next.
                CueEngine.stopFromNotification()
                return START_NOT_STICKY
            }
            ACTION_PAUSE -> {
                CueEngine.togglePauseFromNotification()
                return START_NOT_STICKY
            }
            else -> {
                title = intent?.getStringExtra(EXTRA_TITLE) ?: title
                text = intent?.getStringExtra(EXTRA_TEXT) ?: text
                val endsAtUptime = intent?.getLongExtra(EXTRA_ENDS_AT, 0L) ?: 0L
                endsAtWallClock = if (endsAtUptime > 0) {
                    System.currentTimeMillis() + (endsAtUptime - SystemClock.uptimeMillis())
                } else {
                    // No end: count up from now instead.
                    -System.currentTimeMillis()
                }
                startForeground(
                    NOTIFICATION_ID,
                    build(),
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK,
                )
                acquireWakeLock()
            }
        }
        return START_NOT_STICKY
    }

    override fun onDestroy() {
        wakeLock?.let { if (it.isHeld) it.release() }
        wakeLock = null
        instance = null
        super.onDestroy()
    }

    /** Changes what the notification says, without restarting anything. */
    private fun update(title: String, text: String, endsAtUptime: Long? = null) {
        this.title = title
        this.text = text
        if (endsAtUptime != null && endsAtUptime > 0) {
            // A reschedule after pause or skip moves the finishing line.
            endsAtWallClock =
                System.currentTimeMillis() + (endsAtUptime - SystemClock.uptimeMillis())
        }
        getSystemService(NotificationManager::class.java)
            ?.notify(NOTIFICATION_ID, build())
    }

    private fun acquireWakeLock() {
        if (wakeLock?.isHeld == true) return
        val power = getSystemService(PowerManager::class.java) ?: return
        wakeLock = power.newWakeLock(
            PowerManager.PARTIAL_WAKE_LOCK,
            "talking_stopwatch:session",
        ).also {
            // A timeout so that a bug here cannot flatten the battery: no
            // workout runs longer than this, and the service releases it
            // properly when the session ends.
            it.acquire(4 * 60 * 60 * 1000L)
        }
    }

    /**
     * The channel the session notification lives on.
     *
     * Importance is DEFAULT rather than LOW, and that is the whole reason this
     * notification shows on the lock screen. Android treats anything below
     * DEFAULT as a "silent" notification, and phones routinely hide silent
     * notifications from the lock screen — which is exactly where someone
     * mid-workout is looking. The noise DEFAULT would normally bring is turned
     * off here instead: no sound, no vibration, and the notification itself
     * only ever alerts once.
     *
     * The id is versioned because a channel's importance can only be set when
     * it is created. Android ignores later changes on purpose — the settings
     * belong to the user, not the app — so raising it means a new channel and
     * deleting the old one. Any future change to importance needs the same.
     */
    private fun ensureChannel(manager: NotificationManager?) {
        manager?.deleteNotificationChannel(RETIRED_CHANNEL_ID)
        if (manager?.getNotificationChannel(CHANNEL_ID) != null) return
        manager?.createNotificationChannel(
            NotificationChannel(
                CHANNEL_ID,
                "Running session",
                NotificationManager.IMPORTANCE_DEFAULT,
            ).apply {
                setShowBadge(false)
                setSound(null, null)
                enableVibration(false)
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
            },
        )
    }

    private fun build(): Notification {
        val manager = getSystemService(NotificationManager::class.java)
        ensureChannel(manager)

        val open = PendingIntent.getActivity(
            this,
            0,
            Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        val stop = PendingIntent.getService(
            this,
            1,
            Intent(this, TimerService::class.java).setAction(ACTION_STOP),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        val pause = PendingIntent.getService(
            this,
            2,
            Intent(this, TimerService::class.java).setAction(ACTION_PAUSE),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )

        return Notification.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_notification)
            .setContentTitle(title)
            // The phase is kept while held, so resuming goes straight back to
            // showing it, but a held session says so: "Work" over a number
            // that is not moving would be a lie.
            .setContentText(if (paused) "Paused" else text)
            .setContentIntent(open)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            // Nothing here is private: it is a workout timer. Saying so means
            // the phase and the countdown still show on a lock screen set to
            // hide sensitive content.
            .setVisibility(Notification.VISIBILITY_PUBLIC)
            .setCategory(
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    Notification.CATEGORY_STOPWATCH
                } else {
                    Notification.CATEGORY_PROGRESS
                },
            )
            // Pause first: it is the one reached for most, and on a lock
            // screen the first action is the easiest to hit.
            .addAction(
                Notification.Action.Builder(
                    null,
                    if (paused) "Resume" else "Pause",
                    pause,
                ).build(),
            )
            .addAction(
                Notification.Action.Builder(null, "Stop", stop).build(),
            )
            .apply {
                // Android draws the chronometer itself from this one time, so
                // nothing in this app has to tick to keep it honest. A paused
                // session has no moving number, so it shows none: a countdown
                // running on while the workout is held would be a lie.
                if (paused) {
                    setShowWhen(false)
                    setUsesChronometer(false)
                } else {
                    setShowWhen(true)
                    setUsesChronometer(true)
                    if (endsAtWallClock > 0) {
                        setWhen(endsAtWallClock)
                        setChronometerCountDown(true)
                    } else {
                        setWhen(-endsAtWallClock)
                        setChronometerCountDown(false)
                    }
                }
            }
            .build()
    }

    companion object {
        private const val CHANNEL_ID = "session.v2"

        // The first channel, created at IMPORTANCE_LOW. Deleted on sight so
        // an app updated from that build does not keep the old settings.
        private const val RETIRED_CHANNEL_ID = "session"
        private const val NOTIFICATION_ID = 1
        private const val ACTION_STOP = "com.anvuman.talking_stopwatch.STOP"
        private const val ACTION_PAUSE = "com.anvuman.talking_stopwatch.PAUSE"
        private const val EXTRA_TITLE = "title"
        private const val EXTRA_TEXT = "text"
        private const val EXTRA_ENDS_AT = "endsAt"

        /**
         * Whether a session notification would actually be seen.
         *
         * Two independent switches can hide it and both have to be asked
         * about: the app-level permission, which Android 13 offers once and
         * never again after a refusal, and this channel, which the user can
         * switch off from the notification itself without touching the
         * permission. Either one off means an empty lock screen and no Pause
         * or Stop button — while the session runs exactly as before, which is
         * why nothing here is treated as an error.
         *
         * A channel that does not exist yet is not a refusal. It is created
         * the first time the service starts.
         */
        fun canNotify(context: Context): Boolean {
            val manager =
                context.getSystemService(NotificationManager::class.java) ?: return false
            if (!manager.areNotificationsEnabled()) return false
            val channel = manager.getNotificationChannel(CHANNEL_ID) ?: return true
            return channel.importance != NotificationManager.IMPORTANCE_NONE
        }

        /** The running service, so the engine can talk to it directly. */
        private var instance: TimerService? = null

        fun start(context: Context, title: String, text: String, endsAtUptime: Long) {
            val running = instance
            if (running != null) {
                running.update(title, text, endsAtUptime)
                return
            }
            context.startForegroundService(
                Intent(context, TimerService::class.java)
                    .putExtra(EXTRA_TITLE, title)
                    .putExtra(EXTRA_TEXT, text)
                    .putExtra(EXTRA_ENDS_AT, endsAtUptime),
            )
        }

        fun stop(context: Context) {
            context.stopService(Intent(context, TimerService::class.java))
        }

        fun describe(title: String, text: String) {
            instance?.update(title, text)
        }

        // Holds or releases the notification's countdown. [endsAtUptime] is
        // the new finishing line on resuming, since time spent paused does
        // not count towards it.
        fun setPaused(paused: Boolean, endsAtUptime: Long = 0L) {
            val service = instance ?: return
            service.paused = paused
            service.update(
                service.title,
                service.text,
                endsAtUptime.takeIf { it > 0 },
            )
        }
    }
}
