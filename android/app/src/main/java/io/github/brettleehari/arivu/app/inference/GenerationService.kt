package io.github.brettleehari.arivu.app.inference

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import android.util.Log
import io.github.brettleehari.arivu.app.ArivuApp
import io.github.brettleehari.arivu.app.R

/**
 * Keeps the process at foreground priority while a reply is being written, so a brief app switch
 * does not kill generation (spine: C10). Type shortService (D-002): no extra permission, no
 * notification permission prompt; Android allows about 3 minutes, which covers a full reply.
 */
class GenerationService : Service() {

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val nm = getSystemService(NotificationManager::class.java)
        nm.createNotificationChannel(
            NotificationChannel(CHANNEL, getString(R.string.notification_channel), NotificationManager.IMPORTANCE_LOW),
        )
        val notification = Notification.Builder(this, CHANNEL)
            .setSmallIcon(R.drawable.ic_stat_writing)  // spine: C10 — monochrome status-bar icon
            .setContentTitle(getString(R.string.notification_writing))
            .setOngoing(true)
            .build()
        try {
            if (Build.VERSION.SDK_INT >= 34) {
                startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_SHORT_SERVICE)
            } else {
                startForeground(NOTIFICATION_ID, notification)
            }
        } catch (e: Exception) {
            // Not allowed (e.g. started from background). Generation still runs in-process.
            Log.w(TAG, "startForeground refused", e)
        }
        synchronized(Companion) {
            running = true
            // stop() may have arrived before we were foreground; stopping earlier would crash
            // with ForegroundServiceDidNotStartInTimeException.
            if (stopRequested) {
                stopRequested = false
                running = false
                stopSelf()
            }
        }
        return START_NOT_STICKY
    }

    /** API 35+: shortService time limit reached. spine: C10 (D-003) */
    override fun onTimeout(startId: Int, fgsType: Int) = handleTimeout()

    /**
     * API 34 calls only this overload. Without it a reply running past ~3 min on Android 14 is never
     * stopped and the system ANRs the app (leaves/architecture.md B5). spine: C10
     */
    @Deprecated("Superseded by onTimeout(Int, Int) on API 35+; still the only callback on API 34.")
    override fun onTimeout(startId: Int) = handleTimeout()

    private fun handleTimeout() {
        Log.w(TAG, "shortService timeout")
        (application as ArivuApp).inference.onServiceTimeout()
        synchronized(Companion) { running = false }
        stopSelf()
    }

    companion object {
        private const val TAG = "arivu-service"
        private const val CHANNEL = "generation"
        private const val NOTIFICATION_ID = 1

        private var running = false
        private var stopRequested = false

        fun start(context: Context) {
            synchronized(Companion) { stopRequested = false }
            try {
                context.startForegroundService(context.generationServiceIntent())
            } catch (e: Exception) {
                Log.w(TAG, "could not start service", e)
            }
        }

        fun stop(context: Context) {
            synchronized(Companion) {
                if (running) {
                    running = false
                    context.stopService(context.generationServiceIntent())
                } else {
                    stopRequested = true
                }
            }
        }
    }
}
