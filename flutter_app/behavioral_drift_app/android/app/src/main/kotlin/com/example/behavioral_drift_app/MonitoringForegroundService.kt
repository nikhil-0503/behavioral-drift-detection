package com.example.behavioral_drift_app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import java.util.Calendar
import java.util.Timer
import java.util.TimerTask

/**
 * Foreground service that polls usage stats every 30 seconds and
 * marks apps as blocked in SharedPreferences when their limit is exceeded.
 * The accessibility service then picks up the blocked flag.
 */
class MonitoringForegroundService : Service() {

    private val CHANNEL_ID = "behavioral_drift_monitoring"
    private val NOTIFICATION_ID = 1001
    private var timer: Timer? = null

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val notification = buildNotification()
        startForeground(NOTIFICATION_ID, notification)

        // Poll every 30 seconds
        timer?.cancel()
        timer = Timer()
        timer?.scheduleAtFixedRate(object : TimerTask() {
            override fun run() {
                checkUsageLimits()
            }
        }, 0, 30_000)

        return START_STICKY // restart if killed
    }

    override fun onDestroy() {
        timer?.cancel()
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun checkUsageLimits() {
        val trackedPrefs = getSharedPreferences("tracked_apps", Context.MODE_PRIVATE)
        val blockedPrefs = getSharedPreferences("blocked_apps", Context.MODE_PRIVATE)
        val editor = blockedPrefs.edit()

        val usm = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val cal = Calendar.getInstance()
        cal.set(Calendar.HOUR_OF_DAY, 0)
        cal.set(Calendar.MINUTE, 0)
        cal.set(Calendar.SECOND, 0)
        cal.set(Calendar.MILLISECOND, 0)
        val start = cal.timeInMillis
        val end = System.currentTimeMillis()
        val stats = usm.queryUsageStats(UsageStatsManager.INTERVAL_DAILY, start, end)

        val allTracked = trackedPrefs.all
        for ((pkg, limitObj) in allTracked) {
            val limitMinutes = (limitObj as? Int) ?: continue
            var totalMs: Long = 0
            for (s in stats) {
                if (s.packageName == pkg) {
                    totalMs += s.totalTimeInForeground
                }
            }
            val usedMinutes = totalMs / 60000
            if (usedMinutes >= limitMinutes) {
                editor.putBoolean(pkg, true)
            }
        }
        editor.apply()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Behavior Monitoring",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Monitors app usage in background"
            }
            val nm = getSystemService(NotificationManager::class.java)
            nm.createNotificationChannel(channel)
        }
    }

    private fun buildNotification(): Notification {
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }
        return builder
            .setContentTitle("Timeo is monitoring your usage")
            .setContentText("Tracking app limits in background")
            .setSmallIcon(android.R.drawable.ic_menu_recent_history)
            .setOngoing(true)
            .build()
    }
}
