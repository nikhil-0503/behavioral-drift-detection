package com.example.behavioral_drift_app

import android.app.Activity
import android.os.Bundle
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView
import android.view.Gravity
import android.graphics.Color
import android.view.View

/**
 * Full-screen overlay shown when a monitored app exceeds its daily limit.
 * Uses an accountability-focused (firm but not abusive) tone.
 */
class BlockOverlayActivity : Activity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val blockedPkg = intent.getStringExtra("blocked_package") ?: "this app"

        val layout = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setBackgroundColor(Color.parseColor("#1A1A2E"))
            setPadding(64, 64, 64, 64)
        }

        val iconText = TextView(this).apply {
            text = "⛔"
            textSize = 64f
            gravity = Gravity.CENTER
        }

        val title = TextView(this).apply {
            text = "Time's Up"
            textSize = 28f
            setTextColor(Color.WHITE)
            gravity = Gravity.CENTER
            setPadding(0, 32, 0, 16)
        }

        val message = TextView(this).apply {
            text = "You've exceeded your daily limit for this app.\n\n" +
                    "You set this boundary for a reason. " +
                    "Respect the commitment you made to yourself.\n\n" +
                    "Every minute beyond your limit is a step away from the person you want to be."
            textSize = 16f
            setTextColor(Color.parseColor("#AAAAAA"))
            gravity = Gravity.CENTER
            setPadding(0, 0, 0, 48)
        }

        val button = Button(this).apply {
            text = "I understand — close this app"
            setTextColor(Color.WHITE)
            setBackgroundColor(Color.parseColor("#6C3FEE"))
            setPadding(32, 16, 32, 16)
            setOnClickListener {
                finish()
                // Navigate user to home screen
                val homeIntent = android.content.Intent(android.content.Intent.ACTION_MAIN)
                homeIntent.addCategory(android.content.Intent.CATEGORY_HOME)
                homeIntent.flags = android.content.Intent.FLAG_ACTIVITY_NEW_TASK
                startActivity(homeIntent)
            }
        }

        layout.addView(iconText)
        layout.addView(title)
        layout.addView(message)
        layout.addView(button)
        setContentView(layout)
    }

    override fun onBackPressed() {
        // Block back button – force user to use the dismiss button
        // (intentionally empty)
    }
}
