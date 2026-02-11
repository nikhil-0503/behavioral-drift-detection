package com.example.behavioral_drift_app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log

/**
 * Restarts the MonitoringForegroundService after device reboot
 * so that app usage tracking and midnight-reset scheduling resume
 * automatically. The foreground service handles rescheduling the
 * midnight AlarmManager alarm in its onCreate().
 */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED) {
            Log.d("BootReceiver", "Boot completed — restarting monitoring service")

            // Clear stale blocked state from previous day if we rebooted past midnight
            val blockedPrefs = context.getSharedPreferences("blocked_apps", Context.MODE_PRIVATE)
            blockedPrefs.edit().clear().apply()

            val serviceIntent = Intent(context, MonitoringForegroundService::class.java)
            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    context.startForegroundService(serviceIntent)
                } else {
                    context.startService(serviceIntent)
                }
            } catch (e: Exception) {
                Log.w("BootReceiver", "Foreground service start blocked: ${e.message}")
            }
        }
    }
}
