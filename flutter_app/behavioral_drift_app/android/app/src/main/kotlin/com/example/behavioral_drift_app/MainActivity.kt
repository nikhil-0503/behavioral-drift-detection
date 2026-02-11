package com.example.behavioral_drift_app

import android.app.AppOpsManager
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Process
import android.provider.Settings
import android.text.TextUtils
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.Calendar

class MainActivity : FlutterActivity() {

    private val PERM_CHANNEL = "com.behavioral_drift/permissions"
    private val MON_CHANNEL = "com.behavioral_drift/monitoring"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // ───── PERMISSIONS CHANNEL ─────
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, PERM_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "checkPermissions" -> {
                        val map = HashMap<String, Boolean>()
                        map["usageStats"] = hasUsageStatsPermission()
                        map["accessibility"] = isAccessibilityEnabled()
                        map["overlay"] = hasOverlayPermission()
                        result.success(map)
                    }
                    "requestUsageStats" -> {
                        startActivity(Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS))
                        result.success(null)
                    }
                    "requestAccessibility" -> {
                        startActivity(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS))
                        result.success(null)
                    }
                    "requestOverlay" -> {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                            val intent = Intent(
                                Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                                Uri.parse("package:$packageName")
                            )
                            startActivity(intent)
                        }
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }

        // ───── MONITORING CHANNEL ─────
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, MON_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getUsageToday" -> {
                        val pkg = call.argument<String>("packageName")
                        if (pkg == null) {
                            result.error("INVALID", "packageName required", null)
                            return@setMethodCallHandler
                        }
                        val seconds = getUsageTodaySeconds(pkg)
                        result.success(seconds)
                    }
                    "getInstalledApps" -> {
                        val apps = getInstalledAppsList()
                        result.success(apps)
                    }
                    "addTrackedApp" -> {
                        // Store in SharedPreferences so the foreground service knows
                        val pkg = call.argument<String>("packageName") ?: ""
                        val limit = call.argument<Int>("limitMinutes") ?: 30
                        val prefs = getSharedPreferences("tracked_apps", Context.MODE_PRIVATE)
                        prefs.edit().putInt(pkg, limit).apply()
                        result.success(true)
                    }
                    "blockApp" -> {
                        val pkg = call.argument<String>("packageName") ?: ""
                        val prefs = getSharedPreferences("blocked_apps", Context.MODE_PRIVATE)
                        prefs.edit().putBoolean(pkg, true).apply()
                        result.success(true)
                    }
                    "startMonitoringService" -> {
                        val intent = Intent(this, MonitoringForegroundService::class.java)
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            startForegroundService(intent)
                        } else {
                            startService(intent)
                        }
                        result.success(true)
                    }
                    "midnightReset" -> {
                        // Clear all blocked apps from SharedPreferences
                        val blockedPrefs = getSharedPreferences("blocked_apps", Context.MODE_PRIVATE)
                        blockedPrefs.edit().clear().apply()
                        result.success(true)
                    }
                    "getUsageHistory" -> {
                        val pkg = call.argument<String>("packageName")
                        val days = call.argument<Int>("days") ?: 14
                        if (pkg == null) {
                            result.error("INVALID", "packageName required", null)
                            return@setMethodCallHandler
                        }
                        val history = getUsageHistoryDays(pkg, days)
                        result.success(history)
                    }
                    "getBulkUsageToday" -> {
                        val packages = call.argument<List<String>>("packages")
                        if (packages == null) {
                            result.error("INVALID", "packages list required", null)
                            return@setMethodCallHandler
                        }
                        val usageMap = HashMap<String, Int>()
                        for (pkg in packages) {
                            usageMap[pkg] = getUsageTodaySeconds(pkg)
                        }
                        result.success(usageMap)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    // ───── PERMISSION CHECKS ─────

    private fun hasUsageStatsPermission(): Boolean {
        val appOps = getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            appOps.unsafeCheckOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS,
                Process.myUid(),
                packageName
            )
        } else {
            @Suppress("DEPRECATION")
            appOps.checkOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS,
                Process.myUid(),
                packageName
            )
        }
        return mode == AppOpsManager.MODE_ALLOWED
    }

    private fun isAccessibilityEnabled(): Boolean {
        val enabledServices = Settings.Secure.getString(
            contentResolver,
            Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
        ) ?: return false
        val colonSplitter = TextUtils.SimpleStringSplitter(':')
        colonSplitter.setString(enabledServices)
        while (colonSplitter.hasNext()) {
            val svc = colonSplitter.next()
            // Match common formats Android exposes for accessibility services:
            //  - com.example/.Service
            //  - com.example/com.example.Service
            // Also accept any entry that ends with the service class name.
            if (svc.equals("$packageName/.AppBlockerAccessibilityService", ignoreCase = true)
                || svc.equals("$packageName/$packageName.AppBlockerAccessibilityService", ignoreCase = true)
                || svc.endsWith(".AppBlockerAccessibilityService", ignoreCase = true)
            ) {
                return true
            }
        }
        return false
    }

    private fun hasOverlayPermission(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            Settings.canDrawOverlays(this)
        } else {
            true
        }
    }

    // ───── USAGE STATS ─────

    private fun getUsageTodaySeconds(packageName: String): Int {
        val usm = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val cal = Calendar.getInstance()
        cal.set(Calendar.HOUR_OF_DAY, 0)
        cal.set(Calendar.MINUTE, 0)
        cal.set(Calendar.SECOND, 0)
        cal.set(Calendar.MILLISECOND, 0)
        val start = cal.timeInMillis
        val end = System.currentTimeMillis()

        val stats = usm.queryUsageStats(UsageStatsManager.INTERVAL_DAILY, start, end)
        var totalMs: Long = 0
        for (s in stats) {
            if (s.packageName == packageName) {
                totalMs += s.totalTimeInForeground
            }
        }
        return (totalMs / 1000).toInt()
    }

    /**
     * Returns a map of "yyyy-MM-dd" -> totalSeconds for the given package
     * over the last [days] days using UsageStatsManager.
     */
    private fun getUsageHistoryDays(packageName: String, days: Int): List<Map<String, Any>> {
        val usm = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val result = mutableListOf<Map<String, Any>>()
        val sdf = java.text.SimpleDateFormat("yyyy-MM-dd", java.util.Locale.US)

        for (d in days downTo 0) {
            val cal = Calendar.getInstance()
            cal.add(Calendar.DAY_OF_YEAR, -d)
            cal.set(Calendar.HOUR_OF_DAY, 0)
            cal.set(Calendar.MINUTE, 0)
            cal.set(Calendar.SECOND, 0)
            cal.set(Calendar.MILLISECOND, 0)
            val dayStart = cal.timeInMillis

            cal.set(Calendar.HOUR_OF_DAY, 23)
            cal.set(Calendar.MINUTE, 59)
            cal.set(Calendar.SECOND, 59)
            cal.set(Calendar.MILLISECOND, 999)
            val dayEnd = cal.timeInMillis

            val stats = usm.queryUsageStats(UsageStatsManager.INTERVAL_DAILY, dayStart, dayEnd)
            var totalMs: Long = 0
            for (s in stats) {
                if (s.packageName == packageName) {
                    totalMs += s.totalTimeInForeground
                }
            }
            val dateStr = sdf.format(java.util.Date(dayStart))
            result.add(mapOf("date" to dateStr, "seconds" to (totalMs / 1000).toInt()))
        }
        return result
    }

    private fun getInstalledAppsList(): List<Map<String, String>> {
        val pm = packageManager
        val apps = pm.getInstalledApplications(PackageManager.GET_META_DATA)
        val result = mutableListOf<Map<String, String>>()
        for (app in apps) {
            // Skip system apps without a launcher icon
            if (app.flags and ApplicationInfo.FLAG_SYSTEM != 0) {
                if (pm.getLaunchIntentForPackage(app.packageName) == null) continue
            }
            val label = pm.getApplicationLabel(app).toString()
            result.add(
                mapOf(
                    "packageName" to app.packageName,
                    "appName" to label
                )
            )
        }
        result.sortBy { it["appName"]?.lowercase() }
        return result
    }
}
