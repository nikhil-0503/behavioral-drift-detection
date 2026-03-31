package com.example.behavioral_drift_app

import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import android.util.Log
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale
import java.util.Timer
import java.util.TimerTask

/**
 * Foreground service that:
 *  1. Polls usage stats every 15 seconds (fast enough for real-time blocking).
 *  2. Immediately marks apps as blocked in SharedPreferences when their
 *     limit is exceeded, so the AccessibilityService can react instantly.
 *  3. Launches BlockOverlayActivity directly when a blocked app is in
 *     the foreground (belt-and-suspenders alongside accessibility).
 *  4. Schedules a midnight AlarmManager alarm to reset all timers daily.
 */
class MonitoringForegroundService : Service() {

    private val CHANNEL_ID = "behavioral_drift_monitoring"
    private val NOTIFICATION_ID = 1001
    private val TAG = "MonitorFgSvc"
    private var timer: Timer? = null

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        scheduleMidnightReset()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val notification = buildNotification()
        startForeground(NOTIFICATION_ID, notification)

        // Handle midnight-reset action forwarded from MidnightResetReceiver
        if (intent?.action == ACTION_MIDNIGHT_RESET) {
            performMidnightReset()
            scheduleMidnightReset() // reschedule for next midnight
        }

        // Poll every 5 seconds for tighter enforcement
        timer?.cancel()
        timer = Timer()
        timer?.scheduleAtFixedRate(object : TimerTask() {
            override fun run() {
                checkUsageLimits()
            }
        }, 0, 5_000)

        return START_STICKY // restart if killed
    }

    override fun onDestroy() {
        timer?.cancel()
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    // ──────────── CORE ENFORCEMENT ────────────

    private fun checkUsageLimits() {
        ensureDailyResetIfNeeded()
        val trackedPrefs = getSharedPreferences("tracked_apps", Context.MODE_PRIVATE)
        val blockedPrefs = getSharedPreferences("blocked_apps", Context.MODE_PRIVATE)
        val editor = blockedPrefs.edit()

        val usm = getSystemService(Context.USAGE_STATS_SERVICE) as? UsageStatsManager ?: return
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
            val usedMinutes = totalMs / 60_000
            if (usedMinutes >= limitMinutes) {
                val wasBlocked = blockedPrefs.getBoolean(pkg, false)
                editor.putBoolean(pkg, true)
                if (!wasBlocked) {
                    Log.d(TAG, "Blocking $pkg: $usedMinutes min >= $limitMinutes min limit")
                }
            }
        }
        editor.apply()

        // Also check if the current foreground app is now blocked
        // and proactively launch overlay
        launchOverlayIfForegroundBlocked(usm, blockedPrefs)
    }

    /**
     * If the app currently in the foreground is in the blocked list,
     * immediately launch BlockOverlayActivity. This handles the case
     * where the user is INSIDE the target app when the timer expires —
     * they don't need to switch back to Timeo.
     */
    private fun launchOverlayIfForegroundBlocked(
        usm: UsageStatsManager,
        blockedPrefs: android.content.SharedPreferences
    ) {
        // Query last 5 seconds of usage to find current foreground app
        val end = System.currentTimeMillis()
        val start = end - 5_000
        val recentStats = usm.queryUsageStats(UsageStatsManager.INTERVAL_DAILY, start, end)
        if (recentStats.isNullOrEmpty()) return

        // The app with the most recent lastTimeUsed is the foreground app
        val foreground = recentStats
            .filter { it.lastTimeUsed > 0 }
            .maxByOrNull { it.lastTimeUsed }
            ?: return

        val fgPkg = foreground.packageName
        // Don't block ourselves or system UI
        if (fgPkg == packageName ||
            fgPkg == "com.android.launcher" ||
            fgPkg.startsWith("com.android.systemui") ||
            fgPkg.startsWith("com.google.android.apps.nexuslauncher")
        ) return

        if (blockedPrefs.getBoolean(fgPkg, false)) {
            val intent = Intent(this, BlockOverlayActivity::class.java).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
                putExtra("blocked_package", fgPkg)
            }
            try {
                startActivity(intent)
            } catch (e: Exception) {
                Log.w(TAG, "Could not launch block overlay: ${e.message}")
            }
        }
    }

    // ──────────── MIDNIGHT RESET ────────────

    private fun scheduleMidnightReset() {
        val alarmMgr = getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val intent = Intent(this, MidnightResetReceiver::class.java)
        val pi = PendingIntent.getBroadcast(
            this, 0, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // Next midnight
        val cal = Calendar.getInstance().apply {
            add(Calendar.DAY_OF_YEAR, 1)
            set(Calendar.HOUR_OF_DAY, 0)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 5) // 5 sec past midnight to be safe
            set(Calendar.MILLISECOND, 0)
        }

        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                alarmMgr.setExactAndAllowWhileIdle(
                    AlarmManager.RTC_WAKEUP, cal.timeInMillis, pi
                )
            } else {
                alarmMgr.setExact(AlarmManager.RTC_WAKEUP, cal.timeInMillis, pi)
            }
            Log.d(TAG, "Midnight reset scheduled for ${cal.time}")
        } catch (e: Exception) {
            Log.w(TAG, "Could not schedule midnight alarm: ${e.message}")
            // Fallback: use inexact alarm
            alarmMgr.set(AlarmManager.RTC_WAKEUP, cal.timeInMillis, pi)
        }
    }

    private fun performMidnightReset() {
        Log.d(TAG, "Performing midnight reset")
        // Clear all blocked apps
        val blockedPrefs = getSharedPreferences("blocked_apps", Context.MODE_PRIVATE)
        blockedPrefs.edit().clear().apply()
        saveLastResetDate()
        // Reset tracked app limits stay the same — only usage resets
        // The Flutter side will reset DB counters when it next starts
        Log.d(TAG, "Midnight reset complete: all blocks cleared")
    }

    private fun ensureDailyResetIfNeeded() {
        val prefs = getSharedPreferences("monitoring_prefs", Context.MODE_PRIVATE)
        val lastReset = prefs.getString("last_reset_date", null)
        val today = todayKey()
        if (lastReset != null && lastReset == today) return

        val blockedPrefs = getSharedPreferences("blocked_apps", Context.MODE_PRIVATE)
        blockedPrefs.edit().clear().apply()
        saveLastResetDate()
    }

    private fun saveLastResetDate() {
        val prefs = getSharedPreferences("monitoring_prefs", Context.MODE_PRIVATE)
        prefs.edit().putString("last_reset_date", todayKey()).apply()
    }

    private fun todayKey(): String {
        return SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date())
    }

    // ──────────── NOTIFICATION ────────────

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
            .setContentText("Real-time limit enforcement active")
            .setSmallIcon(android.R.drawable.ic_menu_recent_history)
            .setOngoing(true)
            .build()
    }

    companion object {
        const val ACTION_MIDNIGHT_RESET = "com.example.behavioral_drift_app.MIDNIGHT_RESET"
    }
}
