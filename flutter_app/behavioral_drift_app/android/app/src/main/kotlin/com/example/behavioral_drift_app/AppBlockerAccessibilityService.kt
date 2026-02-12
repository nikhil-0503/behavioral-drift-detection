package com.example.behavioral_drift_app

import android.accessibilityservice.AccessibilityService
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.accessibility.AccessibilityEvent
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale

/**
 * Accessibility service that:
 *  1. Detects foreground app changes via TYPE_WINDOW_STATE_CHANGED.
 *  2. If the foreground app is in the blocked list → overlay immediately.
 *  3. Runs a 10-second watchdog timer that re-checks limits even when
 *     the user stays inside the same app (handles timer-expiry-mid-usage).
 */
class AppBlockerAccessibilityService : AccessibilityService() {

    private val TAG = "AppBlockerA11y"
    private var lastForegroundPkg: String? = null
    private val handler = Handler(Looper.getMainLooper())
    private var watchdogRunnable: Runnable? = null
    private var sessionPkg: String? = null
    private var sessionStartMs: Long = 0
    private var sessionBaselineSeconds: Int = 0
    private var sessionDate: String = ""

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event?.eventType != AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) return
        val pkg = event.packageName?.toString() ?: return

        ensureDailyResetIfNeeded()

        // Ignore our own package and system UI
        if (pkg == packageName ||
            pkg.startsWith("com.android.systemui") ||
            pkg == "com.android.launcher"
        ) return

        lastForegroundPkg = pkg
        startSessionIfNeeded(pkg)
        checkAndBlock(pkg)
    }

    /**
     * Check if the given package should be blocked.
     * First checks the blocked_apps SharedPreferences (set by foreground service).
     * Then does a live UsageStatsManager check as a fallback.
     */
    private fun checkAndBlock(pkg: String) {
        val blockedPrefs = getSharedPreferences("blocked_apps", Context.MODE_PRIVATE)

        // Fast path: already marked blocked by foreground service
        if (blockedPrefs.getBoolean(pkg, false)) {
            launchOverlay(pkg)
            return
        }

        // Slow path: real-time usage check for immediate enforcement
        val trackedPrefs = getSharedPreferences("tracked_apps", Context.MODE_PRIVATE)
        val limitMinutes = trackedPrefs.getInt(pkg, -1)
        if (limitMinutes < 0) return // not tracked

        val usedSeconds = getLiveUsedSeconds(pkg)
        if (usedSeconds >= (limitMinutes * 60)) {
            // Mark as blocked so future checks are fast-path
            blockedPrefs.edit().putBoolean(pkg, true).apply()
            launchOverlay(pkg)
        }
    }

    private fun startSessionIfNeeded(pkg: String) {
        val today = todayKey()
        if (sessionPkg == pkg && sessionDate == today && sessionStartMs > 0) return
        sessionPkg = pkg
        sessionDate = today
        sessionStartMs = System.currentTimeMillis()
        sessionBaselineSeconds = getUsageTodaySeconds(pkg)
    }

    private fun ensureDailyResetIfNeeded() {
        val prefs = getSharedPreferences("monitoring_prefs", Context.MODE_PRIVATE)
        val today = todayKey()
        val lastReset = prefs.getString("last_reset_date", null)
        if (lastReset == today) return

        val blockedPrefs = getSharedPreferences("blocked_apps", Context.MODE_PRIVATE)
        blockedPrefs.edit().clear().apply()
        prefs.edit().putString("last_reset_date", today).apply()
        sessionStartMs = 0
        sessionBaselineSeconds = 0
        sessionDate = today
    }

    private fun getForegroundPackageFromUsageStats(): String? {
        val usm = getSystemService(Context.USAGE_STATS_SERVICE) as? UsageStatsManager
            ?: return null
        val end = System.currentTimeMillis()
        val start = end - 5_000
        val recentStats = usm.queryUsageStats(UsageStatsManager.INTERVAL_DAILY, start, end)
        if (recentStats.isNullOrEmpty()) return null

        val foreground = recentStats
            .filter { it.lastTimeUsed > 0 }
            .maxByOrNull { it.lastTimeUsed }
            ?: return null

        val pkg = foreground.packageName
        if (pkg == packageName ||
            pkg == "com.android.launcher" ||
            pkg.startsWith("com.android.systemui") ||
            pkg.startsWith("com.google.android.apps.nexuslauncher")
        ) return null

        return pkg
    }

    private fun getLiveUsedSeconds(pkg: String): Int {
        startSessionIfNeeded(pkg)
        val elapsedSeconds = ((System.currentTimeMillis() - sessionStartMs) / 1000).toInt()
            .coerceAtLeast(0)
        return sessionBaselineSeconds + elapsedSeconds
    }

    private fun getUsageTodaySeconds(packageName: String): Int {
        val usm = getSystemService(Context.USAGE_STATS_SERVICE) as? UsageStatsManager
            ?: return 0
        val cal = Calendar.getInstance()
        cal.set(Calendar.HOUR_OF_DAY, 0)
        cal.set(Calendar.MINUTE, 0)
        cal.set(Calendar.SECOND, 0)
        cal.set(Calendar.MILLISECOND, 0)
        val dayStart = cal.timeInMillis
        val now = System.currentTimeMillis()

        val stats = usm.queryUsageStats(UsageStatsManager.INTERVAL_DAILY, dayStart, now)
        var totalMs: Long = 0
        for (s in stats) {
            if (s.packageName == packageName) {
                totalMs += s.totalTimeInForeground
            }
        }
        return (totalMs / 1000).toInt()
    }

    private fun todayKey(): String {
        return SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date())
    }

    private fun launchOverlay(pkg: String) {
        Log.d(TAG, "Blocking $pkg — launching overlay")
        val intent = Intent(this, BlockOverlayActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
            putExtra("blocked_package", pkg)
        }
        try {
            startActivity(intent)
        } catch (e: Exception) {
            Log.w(TAG, "Overlay launch failed: ${e.message}")
        }
    }

    override fun onInterrupt() {
        // Required override – no-op
    }

    override fun onServiceConnected() {
        super.onServiceConnected()
        val info = serviceInfo
        info.eventTypes = AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED
        info.feedbackType = android.accessibilityservice.AccessibilityServiceInfo.FEEDBACK_GENERIC
        info.notificationTimeout = 200
        serviceInfo = info

        ensureDailyResetIfNeeded()

        // Start watchdog timer — re-checks the current foreground app
        // every 10 seconds to catch timer expiry while user is inside app
        startWatchdog()
    }

    private fun startWatchdog() {
        watchdogRunnable?.let { handler.removeCallbacks(it) }
        watchdogRunnable = object : Runnable {
            override fun run() {
                ensureDailyResetIfNeeded()
                val foreground = getForegroundPackageFromUsageStats()
                if (foreground != null) {
                    if (foreground != lastForegroundPkg) {
                        lastForegroundPkg = foreground
                        startSessionIfNeeded(foreground)
                    }
                    checkAndBlock(foreground)
                } else {
                    lastForegroundPkg?.let { checkAndBlock(it) }
                }
                handler.postDelayed(this, 3_000) // re-check every 3s
            }
        }
        handler.postDelayed(watchdogRunnable!!, 3_000)
    }

    override fun onDestroy() {
        watchdogRunnable?.let { handler.removeCallbacks(it) }
        super.onDestroy()
    }
}
