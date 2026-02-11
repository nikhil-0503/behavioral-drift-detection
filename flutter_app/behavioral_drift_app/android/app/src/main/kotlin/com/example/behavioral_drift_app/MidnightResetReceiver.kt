package com.example.behavioral_drift_app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log

/**
 * BroadcastReceiver triggered by AlarmManager at midnight.
 * Forwards the reset action to MonitoringForegroundService so it can
 * clear all blocked apps and reschedule the next midnight alarm.
 *
 * Also clears blocked_apps SharedPreferences directly in case the
 * foreground service is momentarily unavailable.
 */
class MidnightResetReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        Log.d("MidnightReset", "Midnight reset alarm fired")

        // Immediately clear blocked apps so overlay stops
        val blockedPrefs = context.getSharedPreferences("blocked_apps", Context.MODE_PRIVATE)
        blockedPrefs.edit().clear().apply()

        // Forward to foreground service to reschedule next alarm
        val serviceIntent = Intent(context, MonitoringForegroundService::class.java).apply {
            action = MonitoringForegroundService.ACTION_MIDNIGHT_RESET
        }
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(serviceIntent)
            } else {
                context.startService(serviceIntent)
            }
        } catch (e: Exception) {
            Log.w("MidnightReset", "Could not restart service: ${e.message}")
        }
    }
}
