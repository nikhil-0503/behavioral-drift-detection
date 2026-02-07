package com.example.behavioral_drift_app

import android.accessibilityservice.AccessibilityService
import android.content.Context
import android.content.Intent
import android.os.Build
import android.view.accessibility.AccessibilityEvent

/**
 * Accessibility service that detects foreground app changes and blocks
 * apps whose daily limit has been exceeded.
 *
 * When a blocked app comes to the foreground, launches BlockOverlayActivity
 * to cover the screen with an "app blocked" message.
 */
class AppBlockerAccessibilityService : AccessibilityService() {

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event?.eventType != AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) return
        val pkg = event.packageName?.toString() ?: return

        // Ignore our own package
        if (pkg == packageName) return

        val blockedPrefs = getSharedPreferences("blocked_apps", Context.MODE_PRIVATE)
        if (blockedPrefs.getBoolean(pkg, false)) {
            // App is blocked → show overlay
            val intent = Intent(this, BlockOverlayActivity::class.java).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
                putExtra("blocked_package", pkg)
            }
            startActivity(intent)
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
    }
}
