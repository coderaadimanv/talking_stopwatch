package com.anvuman.talking_stopwatch

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
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
            else -> {
                title = intent?.getStringExtra(EXTRA_TITLE) ?: title
                text = intent?.getStringExtra(EXTRA_TEXT) ?: text
                val endsAtUptime = intent?.getLongExtra(EXTRA_ENDS_AT, 0L) ?: 0L
                endsAtWallClock = if (endsAtUptime > 0) {
                    System.currentTimeMillis() + (endsAtUptime - SystemClock.uptimeMillis())
                } else {
                    0L
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

    private fun build(): Notification {
        val manager = getSystemService(NotificationManager::class.java)
        if (manager?.getNotificationChannel(CHANNEL_ID) == null) {
            manager?.createNotificationChannel(
                NotificationChannel(
                    CHANNEL_ID,
                    "Running session",
                    // Low: the app's whole job is making noise on purpose, so
                    // the notification itself should be silent.
                    NotificationManager.IMPORTANCE_LOW,
                ).apply { setShowBadge(false) },
            )
        }

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

        return Notification.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_notification)
            .setContentTitle(title)
            .setContentText(text)
            .setContentIntent(open)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .addAction(
                Notification.Action.Builder(null, "Stop", stop).build(),
            )
            .apply {
                if (endsAtWallClock > 0) {
                    // Android draws the countdown itself from this target.
                    setWhen(endsAtWallClock)
                    setShowWhen(true)
                    setUsesChronometer(true)
                    setChronometerCountDown(true)
                }
            }
            .build()
    }

    companion object {
        private const val CHANNEL_ID = "session"
        private const val NOTIFICATION_ID = 1
        private const val ACTION_STOP = "com.anvuman.talking_stopwatch.STOP"
        private const val EXTRA_TITLE = "title"
        private const val EXTRA_TEXT = "text"
        private const val EXTRA_ENDS_AT = "endsAt"

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
    }
}
